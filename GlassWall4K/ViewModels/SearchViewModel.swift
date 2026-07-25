//
//  SearchViewModel.swift
//  GlassWall4K
//

import Foundation
import Observation

/// Catalog for the Live Wallpapers tab (legacy filename kept for Xcode project references).
@Observable
@MainActor
final class SearchViewModel {
    private(set) var results: [Wallpaper] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let repository: any WallpaperRepository
    private let category: Category

    init(
        repository: (any WallpaperRepository)? = nil,
        category: Category = .liveWallpapers
    ) {
        self.repository = repository ?? AppDependencies.shared.wallpaperRepository
        self.category = category
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        FirestoreWallpaperRepository.invalidateCache()

        do {
            results = try await repository.fetchCategory(category)
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }

        isLoading = false
    }
}
