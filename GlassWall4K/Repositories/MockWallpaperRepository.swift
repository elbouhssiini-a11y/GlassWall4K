//
//  MockWallpaperRepository.swift
//  GlassWall4K
//

import Foundation

/// Local placeholder repository. Replace with a GitHub-backed repository later.
struct MockWallpaperRepository: WallpaperRepository {
    func fetchFeatured() async throws -> [Wallpaper] {
        MockWallpaperData.wallpapers.filter(\.featured).sortedByCatalogOrder()
    }

    func fetchLatest() async throws -> [Wallpaper] {
        MockWallpaperData.wallpapers.sorted { $0.createdAt > $1.createdAt }
    }

    func fetchTrending() async throws -> [Wallpaper] {
        Array(MockWallpaperData.wallpapers.sortedByCatalogOrder().prefix(8))
    }

    func fetchCategory(_ category: Category) async throws -> [Wallpaper] {
        MockWallpaperData.wallpapers
            .filter {
                category.matches($0.category)
            }
            .sortedByCatalogOrder()
    }

    func search(_ query: String) async throws -> [Wallpaper] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return MockWallpaperData.wallpapers.sortedByCatalogOrder()
        }

        return MockWallpaperData.wallpapers.filter { wallpaper in
            wallpaper.title.localizedCaseInsensitiveContains(trimmed)
                || wallpaper.category.localizedCaseInsensitiveContains(trimmed)
                || wallpaper.resolution.localizedCaseInsensitiveContains(trimmed)
        }
        .sortedByCatalogOrder()
    }
}
