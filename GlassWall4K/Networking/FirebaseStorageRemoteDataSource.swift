//
//  FirebaseStorageRemoteDataSource.swift
//  GlassWall4K
//

import Foundation

struct FirebaseStorageRemoteDataSource: WallpaperRemoteDataSource {
    private let manifestURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        manifestURL: URL = FirebaseStorageConfiguration.manifestURL,
        session: URLSession = .shared
    ) {
        self.manifestURL = manifestURL
        self.session = session
        self.decoder = WallpaperJSONDecoder.make()
    }

    func fetchManifest() async throws -> WallpaperManifestDTO {
        var request = URLRequest(url: manifestURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw WallpaperRemoteError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw WallpaperRemoteError.httpStatus(http.statusCode)
        }

        do {
            return try decoder.decode(WallpaperManifestDTO.self, from: data)
        } catch {
            throw WallpaperRemoteError.decodingFailed
        }
    }
}
