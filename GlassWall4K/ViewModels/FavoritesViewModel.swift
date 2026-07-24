//
//  FavoritesViewModel.swift
//  GlassWall4K
//

import Foundation
import Observation

@Observable
@MainActor
final class FavoritesViewModel {
    private let favorites: FavoritesStore

    init(favorites: FavoritesStore? = nil) {
        self.favorites = favorites ?? FavoritesStore.shared
    }

    var favoriteWallpapers: [Wallpaper] {
        favorites.wallpapers
    }

    var isEmpty: Bool {
        favorites.wallpapers.isEmpty
    }

    func loadFavorites() async {
        // FavoritesStore already keeps local state synced.
    }
}
