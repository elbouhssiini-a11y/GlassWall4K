//
//  FirestoreAppSettingsRepository.swift
//  GlassWall4K
//

import Foundation

enum FirestoreAppSettingsRepository {
    private static let documentURL = URL(
        string:
            "https://firestore.googleapis.com/v1/projects/\(FirestoreConfiguration.projectID)/databases/(default)/documents/settings/app"
    )!

    nonisolated(unsafe) private static var cached: AppAdSettings?
    nonisolated(unsafe) private static var cachedAt: Date?
    private static let cacheTTL: TimeInterval = 60

    static func invalidateCache() {
        cached = nil
        cachedAt = nil
    }

    static func load(session: URLSession = .shared) async -> AppAdSettings {
        if
            let cached,
            let cachedAt,
            Date().timeIntervalSince(cachedAt) < cacheTTL
        {
            return cached
        }

        do {
            var request = URLRequest(url: documentURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return .disabled
            }

            let doc = try JSONDecoder().decode(FirestoreSettingsDocument.self, from: data)
            let settings = doc.toDomain()
            cached = settings
            cachedAt = Date()
            return settings
        } catch {
            return cached ?? .disabled
        }
    }
}

private struct FirestoreSettingsDocument: Decodable {
    let fields: [String: FirestoreSettingsValue]?

    func toDomain() -> AppAdSettings {
        let fields = fields ?? [:]
        let modeRaw = fields.string("adsMode")?.lowercased()
        let mode: AdsMode = modeRaw == "production" ? .production : .test
        let legacyEvery = max(1, fields.int("interstitialEveryN") ?? 3)
        return AppAdSettings(
            adsEnabled: fields.bool("adsEnabled") ?? false,
            adsMode: mode,
            appOpenAdUnitId: fields.string("appOpenAdUnitId") ?? "",
            interstitialAdUnitId: fields.string("interstitialAdUnitId") ?? "",
            interstitialEveryNOpens: max(1, fields.int("interstitialEveryNOpens") ?? legacyEvery),
            interstitialEveryNDownloads: max(
                1,
                fields.int("interstitialEveryNDownloads") ?? legacyEvery
            )
        )
    }
}

private struct FirestoreSettingsValue: Decodable {
    let stringValue: String?
    let booleanValue: Bool?
    let integerValue: String?
    let doubleValue: Double?
}

private extension Dictionary where Key == String, Value == FirestoreSettingsValue {
    func string(_ key: String) -> String? { self[key]?.stringValue }
    func bool(_ key: String) -> Bool? { self[key]?.booleanValue }
    func int(_ key: String) -> Int? {
        if let raw = self[key]?.integerValue, let value = Int(raw) { return value }
        if let value = self[key]?.doubleValue { return Int(value) }
        return nil
    }
}
