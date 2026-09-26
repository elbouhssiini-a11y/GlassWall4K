//
//  AdsManager.swift
//  GlassWall4K
//

import Combine
import Foundation
import GoogleMobileAds
import UIKit

@MainActor
final class AdsManager: NSObject, ObservableObject {
    static let shared = AdsManager()

    @Published private(set) var settings: AppAdSettings = .disabled
    @Published private(set) var isReady = false

    private var interstitial: GADInterstitialAd?
    private var appOpenAd: GADAppOpenAd?
    private var appOpenLoadTime: Date?
    private var isStarting = false
    private var isShowingFullScreen = false
    /// Blocks intro resume across ad present → dismiss → foreground.
    private var introResumeBlockedUntil: Date?
    private var lastAdSessionEndedAt: Date?
    /// Bumps on every full-screen ad begin/end so RootView can detect ad-tainted leaves.
    private(set) var adSessionEpoch = 0

    /// Exposed so RootView can ignore ad-driven backgrounding.
    var isFullScreenAdSessionActive: Bool { isShowingFullScreen }

    /// One App Open slot: cold start OR return from background — never both at once, never twice.
    private var appOpenOpportunityPending = false
    private var appOpenPresenterRetries = 0
    private var wentToBackgroundAt: Date?

    private let opensKey = "ads.detailOpenCount"
    private let swipesKey = "ads.detailSwipeCount"
    private let downloadsKey = "ads.downloadCount"
    private let appOpenMaxAge: TimeInterval = 4 * 60 * 60

    private override init() {
        super.init()
    }

    func start(deferAppOpen: Bool = false) async {
        if isReady {
            if !deferAppOpen {
                requestAppOpenOnce()
            }
            return
        }

        if isStarting {
            while isStarting {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            return
        }

        isStarting = true
        defer { isStarting = false }

        await ConsentManager.shared.gatherConsentIfNeeded()

        if Self.hasAdMobApplicationID, ConsentManager.shared.canRequestAds {
            Self.configureDebugTestDevice()
            await Self.startMobileAds()
        }
        FirestoreAppSettingsRepository.invalidateCache()
        await refreshSettings()
        isReady = true

        guard !deferAppOpen else {
            logAppOpen(
                "deferred inside start ad=\(appOpenAd != nil) enabled=\(settings.adsEnabled) mode=\(settings.adsMode.rawValue) canRequestAds=\(ConsentManager.shared.canRequestAds)"
            )
            return
        }

        // Wait for SwiftUI window / root VC — App Open needs a presenter.
        try? await Task.sleep(nanoseconds: 900_000_000)
        requestAppOpenOnce()
    }

    /// Cold-start App Open after intro/main UI is ready.
    func presentLaunchAppOpenIfNeeded() {
        guard isReady else {
            logAppOpen("presentLaunch skipped isReady=false")
            return
        }
        logAppOpen(
            "presentLaunch scheduled ad=\(appOpenAd != nil) pending=\(appOpenOpportunityPending) enabled=\(settings.adsEnabled) mode=\(settings.adsMode.rawValue) canRequestAds=\(ConsentManager.shared.canRequestAds)"
        )
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            requestAppOpenOnce()
        }
    }

    /// Call when the main UI is on screen so a pending App Open can present.
    func notifyRootUIReady() {
        guard isReady else { return }
        presentPendingAppOpenIfPossible()
    }

    func refreshSettings() async {
        let next = await FirestoreAppSettingsRepository.load()
        settings = next
        #if DEBUG
        print(
            "[Ads] settings mode=\(next.adsMode.rawValue) enabled=\(next.adsEnabled) appOpen=\(next.activeAppOpenUnitId) interstitial=\(next.activeInterstitialUnitId) everyOpens=\(next.interstitialEveryNOpens) everyDownloads=\(next.interstitialEveryNDownloads) backgroundSeconds=\(next.appOpenMinBackgroundSeconds) consent=\(ConsentManager.shared.canRequestAds) hasAppID=\(Self.hasAdMobApplicationID)"
        )
        #endif
        if next.adsEnabled, Self.hasAdMobApplicationID, ConsentManager.shared.canRequestAds {
            if !next.activeInterstitialUnitId.isEmpty {
                await loadInterstitial()
            } else {
                interstitial = nil
            }
            if !next.activeAppOpenUnitId.isEmpty {
                await loadAppOpen()
            } else {
                clearAppOpen()
                appOpenOpportunityPending = false
            }
        } else {
            #if DEBUG
            print(
                "[Ads] Skipping load enabled=\(next.adsEnabled) hasAppID=\(Self.hasAdMobApplicationID) consent=\(ConsentManager.shared.canRequestAds)"
            )
            #endif
            interstitial = nil
            clearAppOpen()
            appOpenOpportunityPending = false
        }
    }

    func handleDidEnterBackground() {
        wentToBackgroundAt = Date()
    }

    /// Return from background → show App Open once.
    func handleBecameActive() {
        guard isReady else { return }
        guard settings.adsEnabled, !settings.activeAppOpenUnitId.isEmpty else { return }
        // Never request App Open while / right after a full-screen ad (including interstitial).
        guard !shouldSuppressIntroResume else {
            logAppOpen("skip resume full screen session active")
            return
        }
        // Intro owns this resume when enabled — App Open runs after intro finishes.
        if IntroStore.shouldShow(using: settings) {
            logAppOpen("skip resume introEnabled=true")
            return
        }

        let backgroundedAt = wentToBackgroundAt
        wentToBackgroundAt = nil

        guard let backgroundedAt else { return }
        let requiredSeconds = TimeInterval(max(0, settings.appOpenMinBackgroundSeconds))
        guard Date().timeIntervalSince(backgroundedAt) >= requiredSeconds else { return }

        requestAppOpenOnce()
    }

    /// True while a full-screen ad is up, or shortly after, so intro must not steal focus.
    var shouldSuppressIntroResume: Bool {
        if isShowingFullScreen { return true }
        if let until = introResumeBlockedUntil, Date() < until { return true }
        // Extra safety after dismiss — AdMob lifecycle callbacks can reorder vs become-active.
        if let ended = lastAdSessionEndedAt, Date().timeIntervalSince(ended) < 20 {
            return true
        }
        return false
    }

    /// Call before / while presenting any full-screen ad.
    func beginFullScreenAdSession() {
        isShowingFullScreen = true
        adSessionEpoch += 1
        // Cover present + watch + dismiss + foreground.
        introResumeBlockedUntil = Date().addingTimeInterval(600)
        NotificationCenter.default.post(name: .adsFullScreenSessionBegan, object: nil)
    }

    /// Call when full-screen ad is gone.
    func endFullScreenAdSession() {
        isShowingFullScreen = false
        adSessionEpoch += 1
        lastAdSessionEndedAt = Date()
        // Keep blocking long enough that become-active after dismiss cannot reopen intro.
        introResumeBlockedUntil = Date().addingTimeInterval(20)
        NotificationCenter.default.post(name: .adsFullScreenSessionEnded, object: nil)
    }

    /// Call when opening a wallpaper detail. Shows interstitial every N opens.
    func recordDetailOpenAndMaybeShowInterstitial(from root: UIViewController?) {
        maybeShowInterstitial(
            counterKey: opensKey,
            everyN: settings.interstitialEveryNOpens,
            from: root
        )
    }

    /// Call after each settled swipe between wallpapers. Shows interstitial every N swipes.
    func recordSwipeAndMaybeShowInterstitial(from root: UIViewController?) {
        maybeShowInterstitial(
            counterKey: swipesKey,
            everyN: settings.interstitialEveryNOpens,
            from: root
        )
    }

    /// Call after a successful wallpaper download. Shows interstitial every N downloads.
    func recordDownloadAndMaybeShowInterstitial(from root: UIViewController?) {
        maybeShowInterstitial(
            counterKey: downloadsKey,
            everyN: settings.interstitialEveryNDownloads,
            from: root
        )
    }

    private func maybeShowInterstitial(
        counterKey: String,
        everyN: Int,
        from root: UIViewController?
    ) {
        guard settings.adsEnabled else { return }
        guard !settings.activeInterstitialUnitId.isEmpty else { return }
        guard !isShowingFullScreen else { return }

        let count = UserDefaults.standard.integer(forKey: counterKey) + 1
        UserDefaults.standard.set(count, forKey: counterKey)

        let every = max(1, everyN)
        guard count % every == 0 else { return }
        showInterstitial(from: root)
    }

    func showInterstitial(from root: UIViewController?) {
        guard !isShowingFullScreen else { return }
        guard let interstitial else {
            Task { await loadInterstitial() }
            return
        }
        guard let root else { return }
        // Arm BEFORE present so any background notification is already suppressed.
        beginFullScreenAdSession()
        interstitial.fullScreenContentDelegate = self
        interstitial.present(fromRootViewController: root)
    }

    /// Marks a single opportunity; present runs at most once until next open/resume.
    private func requestAppOpenOnce() {
        logAppOpen(
            "eligibility ad=\(appOpenAd != nil) enabled=\(settings.adsEnabled) mode=\(settings.adsMode.rawValue) unitEmpty=\(settings.activeAppOpenUnitId.isEmpty) canRequestAds=\(ConsentManager.shared.canRequestAds) showingFullScreen=\(isShowingFullScreen) pending=\(appOpenOpportunityPending) introEnabled=\(IntroStore.shouldShow(using: settings))"
        )
        guard settings.adsEnabled else {
            logAppOpen("skip adsEnabled=false")
            return
        }
        guard !settings.activeAppOpenUnitId.isEmpty else {
            logAppOpen("skip unit empty")
            return
        }
        guard !isShowingFullScreen else {
            logAppOpen("skip already showing full screen")
            return
        }
        guard !appOpenOpportunityPending else {
            logAppOpen("skip opportunity already pending")
            return
        }

        appOpenOpportunityPending = true
        appOpenPresenterRetries = 0
        presentPendingAppOpenIfPossible()
    }

    private func presentPendingAppOpenIfPossible(from root: UIViewController? = nil) {
        guard appOpenOpportunityPending else {
            logAppOpen("skip present pending=false")
            return
        }
        guard settings.adsEnabled, !settings.activeAppOpenUnitId.isEmpty else {
            logAppOpen("skip present enabled=\(settings.adsEnabled) unitEmpty=\(settings.activeAppOpenUnitId.isEmpty)")
            appOpenOpportunityPending = false
            return
        }
        guard !isShowingFullScreen else {
            logAppOpen("skip present showingFullScreen=true pending stays true")
            return
        }

        guard isAppOpenFresh, let appOpenAd else {
            logAppOpen("skip present ad missing or stale, reloading thenPresent=true")
            Task { await loadAppOpen(thenPresentPending: true) }
            return
        }

        guard let presenter = root ?? AdsPresenter.topViewController() else {
            guard appOpenPresenterRetries < 16 else {
                logAppOpen("skip present no view controller after 16 retries")
                appOpenOpportunityPending = false
                return
            }
            appOpenPresenterRetries += 1
            logAppOpen("skip present no view controller retry=\(appOpenPresenterRetries)")
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                self.presentPendingAppOpenIfPossible()
            }
            return
        }

        logAppOpen(
            "present() vc=\(type(of: presenter)) presenting=\(presenter.presentedViewController != nil) window=\(presenter.viewIfLoaded?.window != nil)"
        )
        // Consume opportunity before present → no second show.
        appOpenOpportunityPending = false
        appOpenPresenterRetries = 0
        beginFullScreenAdSession()
        appOpenAd.present(fromRootViewController: presenter)
    }

    private func logAppOpen(_ message: String) {
        #if DEBUG
        print("[Ads] AppOpen \(message)")
        #endif
    }

    private var isAppOpenFresh: Bool {
        guard let appOpenLoadTime else { return false }
        return Date().timeIntervalSince(appOpenLoadTime) < appOpenMaxAge
    }

    private func clearAppOpen() {
        appOpenAd = nil
        appOpenLoadTime = nil
    }

    private func loadInterstitial() async {
        guard ConsentManager.shared.canRequestAds, Self.hasAdMobApplicationID else {
            interstitial = nil
            return
        }
        let unitId = settings.activeInterstitialUnitId
        guard !unitId.isEmpty else {
            #if DEBUG
            print("[Ads] Interstitial unit empty")
            #endif
            interstitial = nil
            return
        }

        let ad = await Self.loadInterstitialAd(unitId: unitId)
        ad?.fullScreenContentDelegate = self
        interstitial = ad
    }

    private func loadAppOpen(thenPresentPending: Bool = false) async {
        guard ConsentManager.shared.canRequestAds, Self.hasAdMobApplicationID else {
            clearAppOpen()
            appOpenOpportunityPending = false
            return
        }
        let unitId = settings.activeAppOpenUnitId
        guard !unitId.isEmpty else {
            #if DEBUG
            print("[Ads] AppOpen unit empty")
            #endif
            clearAppOpen()
            appOpenOpportunityPending = false
            return
        }

        let ad = await Self.loadAppOpenAd(unitId: unitId)
        ad?.fullScreenContentDelegate = self
        appOpenAd = ad
        appOpenLoadTime = ad == nil ? nil : Date()
        logAppOpen(
            "load complete ad=\(appOpenAd != nil) fresh=\(isAppOpenFresh) pending=\(appOpenOpportunityPending) thenPresent=\(thenPresentPending) enabled=\(settings.adsEnabled) mode=\(settings.adsMode.rawValue) canRequestAds=\(ConsentManager.shared.canRequestAds)"
        )

        guard thenPresentPending else { return }
        if ad == nil {
            appOpenOpportunityPending = false
            return
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
        presentPendingAppOpenIfPossible()
    }

    /// Release has no production AdMob App ID. Starting the SDK without one crashes.
    private nonisolated static var hasAdMobApplicationID: Bool {
        let raw = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String
        return !(raw?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    /// Marks this iPhone as an AdMob test device in Debug only. Production unit IDs stay unchanged.
    private nonisolated static func configureDebugTestDevice() {
        #if DEBUG
        GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = [
            "587bb9bac418aff0cedb745e2769b4c0"
        ]
        #endif
    }

    private nonisolated static func startMobileAds() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            GADMobileAds.sharedInstance().start { _ in
                continuation.resume()
            }
        }
    }

    private nonisolated static func loadInterstitialAd(unitId: String) async -> GADInterstitialAd? {
        await withCheckedContinuation { continuation in
            GADInterstitialAd.load(withAdUnitID: unitId, request: GADRequest()) { ad, error in
                logLoadResult(type: "Interstitial", unitId: unitId, ad: ad, error: error)
                continuation.resume(returning: ad)
            }
        }
    }

    private nonisolated static func loadAppOpenAd(unitId: String) async -> GADAppOpenAd? {
        await withCheckedContinuation { continuation in
            GADAppOpenAd.load(withAdUnitID: unitId, request: GADRequest()) { ad, error in
                logLoadResult(type: "AppOpen", unitId: unitId, ad: ad, error: error)
                continuation.resume(returning: ad)
            }
        }
    }

    private nonisolated static func logLoadResult(
        type: String,
        unitId: String,
        ad: (any GADFullScreenPresentingAd)?,
        error: Error?
    ) {
        #if DEBUG
        if error == nil, let ad {
            let responseInfo = (ad as? GADInterstitialAd)?.responseInfo
                ?? (ad as? GADAppOpenAd)?.responseInfo
            print("[Ads] Loaded type=\(type) unit=\(unitId) responseInfo=\(String(describing: responseInfo))")
            return
        }
        let nsError = error as NSError?
        let responseInfo = nsError?.userInfo[GADErrorUserInfoKeyResponseInfo]
        print(
            "[Ads] Load failed type=\(type) unit=\(unitId) domain=\(nsError?.domain ?? "nil") code=\(nsError.map { String($0.code) } ?? "nil") description=\(nsError?.localizedDescription ?? "nil") userInfo=\(String(describing: nsError?.userInfo ?? [:])) responseInfo=\(String(describing: responseInfo))"
        )
        #else
        _ = type
        _ = unitId
        _ = ad
        _ = error
        #endif
    }
}

extension AdsManager: GADFullScreenContentDelegate {
    nonisolated func adWillPresentFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        Task { @MainActor [weak self] in
            if ad is GADAppOpenAd {
                self?.logAppOpen("willPresent")
            }
            self?.beginFullScreenAdSession()
        }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if ad is GADAppOpenAd {
                self.logAppOpen("dismissed")
            }
            self.endFullScreenAdSession()
            if ad is GADAppOpenAd {
                self.clearAppOpen()
                // Preload next open — do not present again until next launch/resume.
                await self.loadAppOpen(thenPresentPending: false)
            } else {
                await self.loadInterstitial()
            }
        }
    }

    nonisolated func ad(
        _ ad: any GADFullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: any Error
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if ad is GADAppOpenAd {
                let nsError = error as NSError
                self.logAppOpen(
                    "present failed domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription) userInfo=\(nsError.userInfo)"
                )
            }
            self.endFullScreenAdSession()
            self.appOpenOpportunityPending = false
            if ad is GADAppOpenAd {
                self.clearAppOpen()
                await self.loadAppOpen(thenPresentPending: false)
            } else {
                await self.loadInterstitial()
            }
        }
    }
}

extension Notification.Name {
    static let adsFullScreenSessionBegan = Notification.Name("adsFullScreenSessionBegan")
    static let adsFullScreenSessionEnded = Notification.Name("adsFullScreenSessionEnded")
}

enum AdsPresenter {
    @MainActor
    static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root: UIViewController?
        if let base {
            root = base
        } else {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let windows = scenes.flatMap(\.windows)
            let window =
                windows.first(where: \.isKeyWindow)
                ?? windows.first(where: { !$0.isHidden && $0.alpha > 0.01 && $0.rootViewController != nil })
            root = window?.rootViewController
        }

        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }
}
