//
//  RepositoryFactory.swift
//  GlassWall4K
//

import Foundation

/// Factory for constructing repository implementations.
/// Remote priority: Firestore, then GitHub manifest.
/// `useRemote: false` stays on local mock for previews and tests.
enum RepositoryFactory {
    static func makeWallpaperRepository(
        useRemote: Bool = true
    ) -> any WallpaperRepository {
        guard useRemote else {
            return MockWallpaperRepository()
        }

        return FallbackWallpaperRepository(
            sources: [
                FirestoreWallpaperRepository(),
                GitHubWallpaperRepository(),
            ]
        )
    }
}
