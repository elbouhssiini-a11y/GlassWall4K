//
//  FirestoreWallpaperRepository.swift
//  GlassWall4K
//

import Foundation

/// Reads wallpaper catalog from Firestore (admin panel source of truth).
/// Image files stay on GitHub; Firestore only stores metadata + URLs.
struct FirestoreWallpaperRepository: WallpaperRepository {
    private let session: URLSession
    private let listURL: URL

    nonisolated(unsafe) private static var cachedWallpapers: [Wallpaper]?
    nonisolated(unsafe) private static var cachedAt: Date?
    private static let cacheTTL: TimeInterval = 30

    init(
        session: URLSession = .shared,
        listURL: URL = FirestoreConfiguration.wallpapersListURL
    ) {
        self.session = session
        self.listURL = listURL
    }

    static func invalidateCache() {
        cachedWallpapers = nil
        cachedAt = nil
    }

    func fetchFeatured() async throws -> [Wallpaper] {
        try await loadWallpapers().filter(\.featured).sortedByCatalogOrder()
    }

    func fetchLatest() async throws -> [Wallpaper] {
        try await loadWallpapers().sorted { $0.createdAt > $1.createdAt }
    }

    func fetchTrending() async throws -> [Wallpaper] {
        Array(try await loadWallpapers().sortedByCatalogOrder().prefix(8))
    }

    func fetchCategory(_ category: Category) async throws -> [Wallpaper] {
        try await loadWallpapers()
            .filter {
                category.matches($0.category)
            }
            .sortedByCatalogOrder()
    }

    func search(_ query: String) async throws -> [Wallpaper] {
        let wallpapers = try await loadWallpapers()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return wallpapers.sortedByCatalogOrder() }

        return wallpapers.filter { wallpaper in
            wallpaper.title.localizedCaseInsensitiveContains(trimmed)
                || wallpaper.category.localizedCaseInsensitiveContains(trimmed)
                || wallpaper.resolution.localizedCaseInsensitiveContains(trimmed)
        }
        .sortedByCatalogOrder()
    }

    private func loadWallpapers() async throws -> [Wallpaper] {
        if
            let cachedWallpapers = Self.cachedWallpapers,
            let cachedAt = Self.cachedAt,
            Date().timeIntervalSince(cachedAt) < Self.cacheTTL
        {
            return cachedWallpapers
        }

        let fresh = try await fetchAllPages().sortedByCatalogOrder()
        Self.cachedWallpapers = fresh
        Self.cachedAt = Date()
        return fresh
    }

    private func fetchAllPages() async throws -> [Wallpaper] {
        var results: [Wallpaper] = []
        var nextPageToken: String?
        var pages = 0

        repeat {
            pages += 1
            if pages > 10 { break }

            var components = URLComponents(url: listURL, resolvingAgainstBaseURL: false)
            var items = components?.queryItems ?? []
            if let nextPageToken {
                items.append(URLQueryItem(name: "pageToken", value: nextPageToken))
            }
            components?.queryItems = items

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

            let page = try JSONDecoder().decode(FirestoreListResponse.self, from: data)
            results.append(contentsOf: page.documents?.compactMap { $0.toWallpaper() } ?? [])
            nextPageToken = page.nextPageToken
        } while nextPageToken != nil

        return results
    }
}

// MARK: - Firestore REST DTOs

private struct FirestoreListResponse: Decodable {
    let documents: [FirestoreDocument]?
    let nextPageToken: String?
}

private struct FirestoreDocument: Decodable {
    let name: String
    let fields: [String: FirestoreValue]?

    func toWallpaper() -> Wallpaper? {
        guard let fields else { return nil }

        let fallbackID = name.split(separator: "/").last.map(String.init) ?? UUID().uuidString
        guard
            let title = fields.string("title"),
            let imageURLString = fields.string("imageURL"),
            let thumbnailURLString = fields.string("thumbnailURL"),
            let imageURL = URL(string: imageURLString),
            let thumbnailURL = URL(string: thumbnailURLString)
        else {
            return nil
        }

        let createdAt = WallpaperDateParser.parse(fields.string("createdAt")) ?? Date()
        let sortOrder = fields.int("sortOrder") ?? 9999

        return Wallpaper(
            id: fields.string("id") ?? fallbackID,
            title: title,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            category: fields.string("category") ?? Category.iosWallpapers.name,
            resolution: fields.string("resolution") ?? "4K",
            featured: fields.bool("featured") ?? false,
            sortOrder: sortOrder,
            createdAt: createdAt
        )
    }
}

private struct FirestoreValue: Decodable {
    let stringValue: String?
    let booleanValue: Bool?
    let integerValue: String?
    let doubleValue: Double?
    let nullValue: String?
}

private extension Dictionary where Key == String, Value == FirestoreValue {
    func string(_ key: String) -> String? {
        self[key]?.stringValue
    }

    func bool(_ key: String) -> Bool? {
        self[key]?.booleanValue
    }

    func int(_ key: String) -> Int? {
        if let raw = self[key]?.integerValue, let value = Int(raw) {
            return value
        }
        if let value = self[key]?.doubleValue {
            return Int(value)
        }
        return nil
    }
}

enum WallpaperDateParser {
    static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }

        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: value) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }
}
