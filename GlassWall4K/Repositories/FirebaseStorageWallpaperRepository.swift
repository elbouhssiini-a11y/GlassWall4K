//
//  FirebaseStorageWallpaperRepository.swift
//  GlassWall4K
//

import Foundation

struct FirebaseStorageWallpaperRepository: WallpaperRepository {
    private let repository: RemoteWallpaperRepository

    init(remote: any WallpaperRemoteDataSource = FirebaseStorageRemoteDataSource()) {
        self.repository = RemoteWallpaperRepository(remote: remote)
    }

    func fetchFeatured() async throws -> [Wallpaper] {
        try await repository.fetchFeatured()
    }

    func fetchLatest() async throws -> [Wallpaper] {
        try await repository.fetchLatest()
    }

    func fetchTrending() async throws -> [Wallpaper] {
        try await repository.fetchTrending()
    }

    func fetchCategory(_ category: Category) async throws -> [Wallpaper] {
        try await repository.fetchCategory(category)
    }

    func search(_ query: String) async throws -> [Wallpaper] {
        try await repository.search(query)
    }
}
