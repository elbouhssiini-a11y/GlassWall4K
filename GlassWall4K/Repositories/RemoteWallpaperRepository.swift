//
//  RemoteWallpaperRepository.swift
//  GlassWall4K
//

import Foundation

/// Wallpaper repository backed by any remote manifest source (Firebase Storage, GitHub, …).
struct RemoteWallpaperRepository: WallpaperRepository {
    private let remote: any WallpaperRemoteDataSource

    init(remote: any WallpaperRemoteDataSource) {
        self.remote = remote
    }

    func fetchFeatured() async throws -> [Wallpaper] {
        try await loadWallpapers().filter(\.featured).sortedByCatalogOrder()
    }

    func fetchLatest() async throws -> [Wallpaper] {
        try await loadWallpapers().sorted { $0.createdAt > $1.createdAt }
    }

    func fetchTrending() async throws -> [Wallpaper] {
        Array(try await loadWallpapers().sortedByCatalogOrder().prefix(8))
    }

    func fetchCategory(_ category: Category) async throws -> [Wallpaper] {
        try await loadWallpapers()
            .filter {
                category.matches($0.category)
            }
            .sortedByCatalogOrder()
    }

    func search(_ query: String) async throws -> [Wallpaper] {
        let wallpapers = try await loadWallpapers()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return wallpapers.sortedByCatalogOrder() }

        return wallpapers.filter { wallpaper in
            wallpaper.title.localizedCaseInsensitiveContains(trimmed)
                || wallpaper.category.localizedCaseInsensitiveContains(trimmed)
                || wallpaper.resolution.localizedCaseInsensitiveContains(trimmed)
        }
        .sortedByCatalogOrder()
    }

    func fetchCategories() async throws -> [Category] {
        try await remote.fetchManifest().categories.map { $0.toDomain() }
    }

    private func loadWallpapers() async throws -> [Wallpaper] {
        try await remote.fetchManifest().wallpapers.map { $0.toDomain() }.sortedByCatalogOrder()
    }
}
