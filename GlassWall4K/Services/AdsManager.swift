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

        await Self.startMobileAds()
        FirestoreAppSettingsRepository.invalidateCache()
        await refreshSettings()
        isReady = true

        guard !deferAppOpen else { return }

        // Wait for SwiftUI window / root VC — App Open needs a presenter.
        try? await Task.sleep(nanoseconds: 900_000_000)
        requestAppOpenOnce()
    }

    /// Cold-start App Open after intro/main UI is ready.
    func presentLaunchAppOpenIfNeeded() {
        guard isReady else { return }
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
        if next.adsEnabled {
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
        guard !shouldSuppressIntroResume else { return }
        // Intro owns this resume when enabled — App Open runs after intro finishes.
        if IntroStore.shouldShow(using: settings) { return }

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
        guard settings.adsEnabled else { return }
        guard !settings.activeAppOpenUnitId.isEmpty else { return }
        guard !isShowingFullScreen else { return }
        guard !appOpenOpportunityPending else { return }

        appOpenOpportunityPending = true
        appOpenPresenterRetries = 0
        presentPendingAppOpenIfPossible()
    }

    private func presentPendingAppOpenIfPossible(from root: UIViewController? = nil) {
        guard appOpenOpportunityPending else { return }
        guard settings.adsEnabled, !settings.activeAppOpenUnitId.isEmpty else {
            appOpenOpportunityPending = false
            return
        }
        guard !isShowingFullScreen else { return }

        guard isAppOpenFresh, let appOpenAd else {
            Task { await loadAppOpen(thenPresentPending: true) }
            return
        }

        guard let presenter = root ?? AdsPresenter.topViewController() else {
            guard appOpenPresenterRetries < 16 else {
                appOpenOpportunityPending = false
                return
            }
            appOpenPresenterRetries += 1
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                self.presentPendingAppOpenIfPossible()
            }
            return
        }

        // Consume opportunity before present → no second show.
        appOpenOpportunityPending = false
        appOpenPresenterRetries = 0
        beginFullScreenAdSession()
        appOpenAd.present(fromRootViewController: presenter)
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
        let unitId = settings.activeInterstitialUnitId
        guard !unitId.isEmpty else {
            interstitial = nil
            return
        }

        let ad = await Self.loadInterstitialAd(unitId: unitId)
        ad?.fullScreenContentDelegate = self
        interstitial = ad
    }

    private func loadAppOpen(thenPresentPending: Bool = false) async {
        let unitId = settings.activeAppOpenUnitId
        guard !unitId.isEmpty else {
            clearAppOpen()
            appOpenOpportunityPending = false
            return
        }

        let ad = await Self.loadAppOpenAd(unitId: unitId)
        ad?.fullScreenContentDelegate = self
        appOpenAd = ad
        appOpenLoadTime = ad == nil ? nil : Date()

        guard thenPresentPending else { return }
        if ad == nil {
            appOpenOpportunityPending = false
            return
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
        presentPendingAppOpenIfPossible()
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
            GADInterstitialAd.load(withAdUnitID: unitId, request: GADRequest()) { ad, _ in
                continuation.resume(returning: ad)
            }
        }
    }

    private nonisolated static func loadAppOpenAd(unitId: String) async -> GADAppOpenAd? {
        await withCheckedContinuation { continuation in
            GADAppOpenAd.load(withAdUnitID: unitId, request: GADRequest()) { ad, _ in
                continuation.resume(returning: ad)
            }
        }
    }
}

extension AdsManager: GADFullScreenContentDelegate {
    nonisolated func adWillPresentFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        Task { @MainActor [weak self] in
            self?.beginFullScreenAdSession()
        }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        Task { @MainActor [weak self] in
            guard let self else { return }
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
