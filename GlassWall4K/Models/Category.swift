//
//  Category.swift
//  GlassWall4K
//

import Foundation

struct Category: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let icon: String

    nonisolated static let iosWallpapers = Category(
        id: "ios-wallpapers",
        name: "iOS 27",
        icon: "iphone"
    )

    /// Catalog id kept as `4k-wallpapers` for existing Firestore/manifest data.
    nonisolated static let liveWallpapers = Category(
        id: "4k-wallpapers",
        name: "Live Wallpapers",
        icon: "play.circle"
    )

    /// Legacy alias.
    nonisolated static let fourKWallpapers = liveWallpapers

    nonisolated static let all: [Category] = [.iosWallpapers, .liveWallpapers]

    nonisolated func matches(_ wallpaperCategory: String) -> Bool {
        if wallpaperCategory.compare(name, options: .caseInsensitive) == .orderedSame {
            return true
        }
        if id == Self.iosWallpapers.id {
            return wallpaperCategory.compare("iOS Wallpapers", options: .caseInsensitive) == .orderedSame
                || wallpaperCategory.compare("iOS 27 Wallpapers", options: .caseInsensitive) == .orderedSame
        }
        if id == Self.liveWallpapers.id {
            return wallpaperCategory.compare("4K Wallpapers", options: .caseInsensitive) == .orderedSame
                || wallpaperCategory.compare("4K", options: .caseInsensitive) == .orderedSame
        }
        return false
    }
}
