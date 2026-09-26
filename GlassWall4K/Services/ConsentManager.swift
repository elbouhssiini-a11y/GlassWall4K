//
//  ConsentManager.swift
//  GlassWall4K
//

import UIKit
import UserMessagingPlatform

/// Updates Google UMP consent before any ad request.
/// Privacy policy configured for the AdMob message:
/// https://sites.google.com/view/privacy-policy-elbouhssini
@MainActor
final class ConsentManager {
    static let shared = ConsentManager()

    private var didGatherThisSession = false
    private var isGathering = false

    private init() {}

    /// True only after a consent info update, when UMP allows ad requests.
    var canRequestAds: Bool {
        UMPConsentInformation.sharedInstance.canRequestAds
    }

    /// One consent pass per process. Later calls do not present the form again.
    func gatherConsentIfNeeded() async {
        if didGatherThisSession {
            return
        }
        if isGathering {
            while isGathering {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            return
        }

        isGathering = true
        defer {
            isGathering = false
            didGatherThisSession = true
        }

        let parameters = UMPRequestParameters()
        parameters.tagForUnderAgeOfConsent = false
        #if DEBUG
        // Force the EEA form on this test device only. Release builds never set this.
        UMPConsentInformation.sharedInstance.reset()
        log("DEBUG mode enabled")
        let debugSettings = UMPDebugSettings()
        debugSettings.testDeviceIdentifiers = ["E1E4AA12-6B4F-4E74-9ED6-C150418C6E56"]
        debugSettings.geography = .EEA
        parameters.debugSettings = debugSettings
        log("DEBUG test device configured")
        #endif

        log("Requesting consent info")

        let updateError = await requestConsentInfoUpdate(parameters)
        if let updateError {
            log("Consent update failed: \(updateError.localizedDescription)")
            logAdsGate()
            return
        }

        let consentRequired = UMPConsentInformation.sharedInstance.consentStatus == .required
        if consentRequired {
            log("Consent required")
            log("Presenting consent form")
        }

        let presentError = await presentFormIfRequired()
        if let presentError {
            log("Consent form failed: \(presentError.localizedDescription)")
        } else if consentRequired {
            log("Consent completed")
        }

        logAdsGate()
    }

    private func requestConsentInfoUpdate(_ parameters: UMPRequestParameters) async -> Error? {
        await withCheckedContinuation { continuation in
            UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { error in
                continuation.resume(returning: error)
            }
        }
    }

    private func presentFormIfRequired() async -> Error? {
        await withCheckedContinuation { continuation in
            UMPConsentForm.loadAndPresentIfRequired(from: nil) { error in
                continuation.resume(returning: error)
            }
        }
    }

    private func logAdsGate() {
        if canRequestAds {
            log("Ads can load")
        } else {
            log("Ads should remain disabled")
        }
    }

    private func log(_ message: String) {
        #if DEBUG
        print("[Consent] \(message)")
        #endif
    }
}
