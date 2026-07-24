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

    nonisolated static let fourKWallpapers = Category(
        id: "4k-wallpapers",
        name: "4K Wallpapers",
        icon: "4k.tv"
    )

    nonisolated static let all: [Category] = [.iosWallpapers, .fourKWallpapers]

    /// Accepts current name plus legacy "iOS Wallpapers" for existing data.
    nonisolated func matches(_ wallpaperCategory: String) -> Bool {
        if wallpaperCategory.compare(name, options: .caseInsensitive) == .orderedSame {
            return true
        }
        if id == Self.iosWallpapers.id {
            return wallpaperCategory.compare("iOS Wallpapers", options: .caseInsensitive) == .orderedSame
        }
        return false
    }
}
