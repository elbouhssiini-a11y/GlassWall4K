//
//  RepositoryFactory.swift
//  GlassWall4K
//

import Foundation

/// Factory for constructing repository implementations.
/// Priority: Firestore (admin catalog) → GitHub manifest → local mock.
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
                MockWallpaperRepository(),
            ]
        )
    }
}
