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

    /// One App Open slot: cold start OR return from background — never both at once, never twice.
    private var appOpenOpportunityPending = false
    private var appOpenPresenterRetries = 0
    private var wentToBackgroundAt: Date?

    private let opensKey = "ads.detailOpenCount"
    private let downloadsKey = "ads.downloadCount"
    private let appOpenMaxAge: TimeInterval = 4 * 60 * 60
    /// Ignore tiny background blips (Control Center, etc.).
    private let minBackgroundForAppOpen: TimeInterval = 1.5

    private override init() {
        super.init()
    }

    func start() async {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }

        await Self.startMobileAds()
        await refreshSettings()
        isReady = true

        // Cold start → show App Open once.
        try? await Task.sleep(nanoseconds: 500_000_000)
        requestAppOpenOnce()
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

        let backgroundedAt = wentToBackgroundAt
        wentToBackgroundAt = nil

        guard let backgroundedAt else { return }
        guard Date().timeIntervalSince(backgroundedAt) >= minBackgroundForAppOpen else { return }

        requestAppOpenOnce()
    }

    /// Call when opening a wallpaper detail. Shows interstitial every N opens.
    func recordDetailOpenAndMaybeShowInterstitial(from root: UIViewController?) {
        maybeShowInterstitial(
            counterKey: opensKey,
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
        isShowingFullScreen = true
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
            guard appOpenPresenterRetries < 4 else {
                appOpenOpportunityPending = false
                return
            }
            appOpenPresenterRetries += 1
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 350_000_000)
                self.presentPendingAppOpenIfPossible()
            }
            return
        }

        // Consume opportunity before present → no second show.
        appOpenOpportunityPending = false
        appOpenPresenterRetries = 0
        isShowingFullScreen = true
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
    nonisolated func adDidDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isShowingFullScreen = false
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
            self.isShowingFullScreen = false
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

enum AdsPresenter {
    @MainActor
    static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root =
            base
            ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController

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
