//
//  WallpaperRepository.swift
//  GlassWall4K
//

import Foundation

/// Abstraction over wallpaper data access.
/// Swap `MockWallpaperRepository` for a GitHub-backed implementation later without UI changes.
protocol WallpaperRepository: Sendable {
    func fetchFeatured() async throws -> [Wallpaper]
    func fetchLatest() async throws -> [Wallpaper]
    func fetchTrending() async throws -> [Wallpaper]
    func fetchCategory(_ category: Category) async throws -> [Wallpaper]
    func search(_ query: String) async throws -> [Wallpaper]
}
