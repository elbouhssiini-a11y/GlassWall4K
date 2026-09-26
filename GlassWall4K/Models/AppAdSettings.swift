//
//  AppAdSettings.swift
//  GlassWall4K
//

import Foundation

enum AdsMode: String, Sendable {
    case test
    case production
}

struct AppAdSettings: Sendable, Equatable {
    var adsEnabled: Bool
    var adsMode: AdsMode
    var appOpenAdUnitId: String
    var interstitialAdUnitId: String
    var interstitialEveryNOpens: Int
    var interstitialEveryNDownloads: Int
    /// Seconds in background before App Open may show on return.
    var appOpenMinBackgroundSeconds: Int

    var introEnabled: Bool
    var introShowEveryLaunch: Bool
    var introVersion: Int
    var introTitle: String
    var introSubtitle: String
    var introImageURL: String
    var introVideoURL: String
    /// Max seconds to play before entering app. 0 = play until natural end.
    var introMaxSeconds: Int
    var introButtonTitle: String
    /// ISO-8601 from panel — used to pick newest remote source.
    var updatedAt: String

    #if DEBUG
    static let iosTestUnits = (
        appOpen: "ca-app-pub-3940256099942544/5575463023",
        interstitial: "ca-app-pub-3940256099942544/4411468910"
    )
    #endif

    static let disabled = AppAdSettings(
        adsEnabled: false,
        adsMode: .test,
        appOpenAdUnitId: "",
        interstitialAdUnitId: "",
        interstitialEveryNOpens: 4,
        interstitialEveryNDownloads: 3,
        appOpenMinBackgroundSeconds: 2,
        introEnabled: false,
        introShowEveryLaunch: false,
        introVersion: 1,
        introTitle: "Welcome to Wallora Glass",
        introSubtitle: "Browse Live & iOS wallpapers. Save favorites and download in one tap.",
        introImageURL: "",
        introVideoURL: "",
        introMaxSeconds: 0,
        introButtonTitle: "Get Started",
        updatedAt: ""
    )

    var activeAppOpenUnitId: String {
        guard adsEnabled else { return "" }
        #if DEBUG
        if adsMode == .test { return Self.iosTestUnits.appOpen }
        #endif
        guard adsMode == .production else { return "" }
        return appOpenAdUnitId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var activeInterstitialUnitId: String {
        guard adsEnabled else { return "" }
        #if DEBUG
        if adsMode == .test { return Self.iosTestUnits.interstitial }
        #endif
        guard adsMode == .production else { return "" }
        return interstitialAdUnitId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var resolvedIntroImageURL: URL? {
        let raw = introImageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    var resolvedIntroVideoURL: URL? {
        let raw = introVideoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }
}
