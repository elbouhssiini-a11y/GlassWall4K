//
//  IntroStore.swift
//  GlassWall4K
//

import Foundation

enum IntroStore {
    /// Show on cold start and when leaving the app then coming back.
    static func shouldShow(using settings: AppAdSettings) -> Bool {
        settings.introEnabled
    }
}
