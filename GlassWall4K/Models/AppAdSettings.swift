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

    static let iosTestUnits = (
        appOpen: "ca-app-pub-3940256099942544/5575463023",
        interstitial: "ca-app-pub-3940256099942544/4411468910"
    )

    static let disabled = AppAdSettings(
        adsEnabled: false,
        adsMode: .test,
        appOpenAdUnitId: "",
        interstitialAdUnitId: "",
        interstitialEveryNOpens: 3,
        interstitialEveryNDownloads: 3
    )

    var activeAppOpenUnitId: String {
        guard adsEnabled else { return "" }
        if adsMode == .test { return Self.iosTestUnits.appOpen }
        return appOpenAdUnitId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var activeInterstitialUnitId: String {
        guard adsEnabled else { return "" }
        if adsMode == .test { return Self.iosTestUnits.interstitial }
        return interstitialAdUnitId.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
