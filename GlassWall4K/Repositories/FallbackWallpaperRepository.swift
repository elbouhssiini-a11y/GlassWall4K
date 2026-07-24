//
//  FallbackWallpaperRepository.swift
//  GlassWall4K
//

import Foundation

/// Tries remote sources in order, then local mock.
struct FallbackWallpaperRepository: WallpaperRepository {
    private let sources: [any WallpaperRepository]

    init(sources: [any WallpaperRepository]) {
        self.sources = sources
    }

    init(
        primary: any WallpaperRepository,
        fallback: any WallpaperRepository
    ) {
        self.sources = [primary, fallback]
    }

    func fetchFeatured() async throws -> [Wallpaper] {
        await load { try await $0.fetchFeatured() }
    }

    func fetchLatest() async throws -> [Wallpaper] {
        await load { try await $0.fetchLatest() }
    }

    func fetchTrending() async throws -> [Wallpaper] {
        await load { try await $0.fetchTrending() }
    }

    func fetchCategory(_ category: Category) async throws -> [Wallpaper] {
        await load { try await $0.fetchCategory(category) }
    }

    func search(_ query: String) async throws -> [Wallpaper] {
        await load { try await $0.search(query) }
    }

    private func load(
        _ operation: (any WallpaperRepository) async throws -> [Wallpaper]
    ) async -> [Wallpaper] {
        for source in sources {
            do {
                return try await operation(source)
            } catch {
                continue
            }
        }
        return []
    }
}
