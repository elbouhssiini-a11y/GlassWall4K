//
//  IntroStore.swift
//  GlassWall4K
//

import Foundation

enum IntroStore {
    /// A real process launch. Background return is not a new launch.
    static func shouldShow(using settings: AppAdSettings) -> Bool {
        settings.introEnabled
    }
}
