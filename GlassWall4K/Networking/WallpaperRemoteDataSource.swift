//
//  WallpaperRemoteDataSource.swift
//  GlassWall4K
//

import Foundation

protocol WallpaperRemoteDataSource: Sendable {
    func fetchManifest() async throws -> WallpaperManifestDTO
}

enum WallpaperRemoteError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from assets server."
        case .httpStatus(let code):
            "Assets server returned status \(code)."
        case .decodingFailed:
            "Unable to decode wallpaper catalog."
        }
    }
}
