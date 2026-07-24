//
//  AppDependencies.swift
//  GlassWall4K
//

import Foundation

/// Dependency injection container.
/// Wallpaper catalog comes from Firestore (admin panel), with GitHub/mock fallback.
@MainActor
final class AppDependencies {
    let wallpaperRepository: any WallpaperRepository
    let categories: [Category]

    init(
        wallpaperRepository: (any WallpaperRepository)? = nil,
        categories: [Category]? = nil
    ) {
        self.wallpaperRepository = wallpaperRepository ?? RepositoryFactory.makeWallpaperRepository()
        self.categories = categories ?? Category.all
    }

    static let shared = AppDependencies()
}
