//
//  RootView.swift
//  GlassWall4K
//

import SwiftUI
import UIKit

private enum LaunchGate {
    case loading
    case intro
    case main
}

struct RootView: View {
    @EnvironmentObject private var ads: AdsManager
    @State private var gate: LaunchGate = .loading
    @State private var didFinishLaunch = false
    /// Cold-start gate must run once per process — `.task` can re-fire after interstitial.
    @State private var didRunColdStartGate = false
    /// Armed only on a real Home/app-switcher background — never for interstitial.
    @State private var pendingResumeAt: Date?
    @State private var pendingResumeEpoch: Int?
    /// After intro → main (and usually App Open), block resume intro briefly.
    @State private var lastIntroFinishedAt: Date?

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
                gate = .intro
            } else {
                gate = .main
                AdsManager.shared.presentLaunchAppOpenIfNeeded()
            }
            didFinishLaunch = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            armRealLeaveIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            presentIntroAfterRealLeaveIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .adsFullScreenSessionBegan)) { _ in
            cancelPendingResume()
        }
        .onReceive(NotificationCenter.default.publisher(for: .adsFullScreenSessionEnded)) { _ in
            cancelPendingResume()
        }
    }

    private func finishIntroAndEnterMain() {
        lastIntroFinishedAt = Date()
        cancelPendingResume()
        withAnimation(.easeInOut(duration: 0.25)) {
            gate = .main
        }
        AdsManager.shared.presentLaunchAppOpenIfNeeded()
    }

    private func cancelPendingResume() {
        pendingResumeAt = nil
        pendingResumeEpoch = nil
    }

    private func armRealLeaveIfNeeded() {
        guard didFinishLaunch else { return }
        guard gate == .main else { return }

        // Interstitial / App Open background the process — never treat that as leave.
        if ads.shouldSuppressIntroResume { return }
        if ads.isFullScreenAdSessionActive { return }
        // Must be truly backgrounded (not just inactive overlay).
        guard UIApplication.shared.applicationState == .background else { return }

        pendingResumeAt = Date()
        pendingResumeEpoch = ads.adSessionEpoch
    }

    private func presentIntroAfterRealLeaveIfNeeded() {
        guard didFinishLaunch else { return }
        guard gate == .main else {
            cancelPendingResume()
            return
        }

        // Still inside / right after an ad session → stay on main.
        if ads.shouldSuppressIntroResume || ads.isFullScreenAdSessionActive {
            cancelPendingResume()
            return
        }

        // Intro just finished (cold start → App Open) — do not bounce back to intro.
        if let finishedAt = lastIntroFinishedAt, Date().timeIntervalSince(finishedAt) < 45 {
            cancelPendingResume()
            return
        }

        guard let leftAt = pendingResumeAt, let epoch = pendingResumeEpoch else { return }

        // Any ad presented/dismissed since we armed → not a clean leave/return.
        guard epoch == ads.adSessionEpoch else {
            cancelPendingResume()
            return
        }

        // Consume immediately so a second active event cannot re-trigger.
        cancelPendingResume()

        guard IntroStore.shouldShow(using: ads.settings) else { return }
        // Real leave only (Home / app switcher), not a short ad flicker.
        guard Date().timeIntervalSince(leftAt) >= 2.0 else { return }

        withAnimation(.easeInOut(duration: 0.25)) {
            gate = .intro
        }
    }
}
