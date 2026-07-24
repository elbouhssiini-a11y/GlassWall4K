//
//  HomeViewModel.swift
//  GlassWall4K
//

import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    private(set) var latestWallpapers: [Wallpaper] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let repository: any WallpaperRepository
    private let category: Category

    init(
        repository: (any WallpaperRepository)? = nil,
        category: Category = .iosWallpapers
    ) {
        self.repository = repository ?? AppDependencies.shared.wallpaperRepository
        self.category = category
    }

    func loadHome() async {
        isLoading = true
        errorMessage = nil
        FirestoreWallpaperRepository.invalidateCache()

        do {
            latestWallpapers = try await repository.fetchCategory(category)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
