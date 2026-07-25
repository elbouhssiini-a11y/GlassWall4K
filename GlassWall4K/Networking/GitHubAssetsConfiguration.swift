//
//  GitHubAssetsConfiguration.swift
//  GlassWall4K
//

import Foundation

enum GitHubAssetsConfiguration {
    static let owner = "elbouhssiini-a11y"
    static let repository = "glasswall4k-assets"
    static let branch = "main"
    static let manifestPath = "manifest.json"
    static let settingsPath = "settings.json"

    static var manifestURL: URL {
        URL(string: "https://raw.githubusercontent.com/\(owner)/\(repository)/\(branch)/\(manifestPath)")!
    }

    static var settingsURL: URL {
        URL(string: "https://raw.githubusercontent.com/\(owner)/\(repository)/\(branch)/\(settingsPath)")!
    }
}
