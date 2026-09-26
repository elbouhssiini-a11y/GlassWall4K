//
//  RootView.swift
//  GlassWall4K
//

import SwiftUI

private enum LaunchGate {
    case loading
    case intro
    case main
}

struct RootView: View {
    @EnvironmentObject private var ads: AdsManager
    @State private var gate: LaunchGate = .loading
    /// Cold-start gate must run once per process — `.task` can re-fire after interstitial.
    @State private var didRunColdStartGate = false

    var body: some View {
        Group {
            switch gate {
            case .loading:
                ZStack {
                    Color.black.ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
            case .intro:
                IntroView(settings: ads.settings) {
                    finishIntroAndEnterMain()
                }
            case .main:
                ContentView()
            }
        }
        .task {
            await AdsManager.shared.start(deferAppOpen: true)
            // CRITICAL: fullscreen ads can make this `.task` run again when the view
            // re-appears. Never treat that as a cold start or intro will loop.
            guard !didRunColdStartGate else { return }
            didRunColdStartGate = true

            let settings = AdsManager.shared.settings
            if IntroStore.shouldShow(using: settings) {
                #if DEBUG
                print("[Ads] AppOpen launch gate=intro, present waits until intro finishes")
                #endif
                gate = .intro
            } else {
                #if DEBUG
                print("[Ads] AppOpen launch gate=main, scheduling present")
                #endif
                gate = .main
                AdsManager.shared.presentLaunchAppOpenIfNeeded()
            }
        }
    }

    private func finishIntroAndEnterMain() {
        withAnimation(.easeInOut(duration: 0.25)) {
            gate = .main
        }
        #if DEBUG
        print("[Ads] AppOpen intro finished, scheduling present")
        #endif
        AdsManager.shared.presentLaunchAppOpenIfNeeded()
    }
}
