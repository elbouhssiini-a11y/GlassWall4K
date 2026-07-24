//
//  GitHubWallpaperRemoteDataSource.swift
//  GlassWall4K
//

import Foundation

struct GitHubWallpaperRemoteDataSource: WallpaperRemoteDataSource {
    private let manifestURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        manifestURL: URL = GitHubAssetsConfiguration.manifestURL,
        session: URLSession = .shared
    ) {
        self.manifestURL = manifestURL
        self.session = session
        self.decoder = WallpaperJSONDecoder.make()
    }

    func fetchManifest() async throws -> WallpaperManifestDTO {
        var components = URLComponents(url: manifestURL, resolvingAgainstBaseURL: false)
        var query = components?.queryItems ?? []
        query.append(URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970))))
        components?.queryItems = query

        guard let url = components?.url else {
            throw WallpaperRemoteError.invalidResponse
        }

        var request = URLRequest(url: url)
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
