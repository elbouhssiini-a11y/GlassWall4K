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

    private static let diskKey = "app.settings.disk.v1"

    nonisolated(unsafe) private static var cached: AppAdSettings?
    nonisolated(unsafe) private static var cachedAt: Date?
    private static let cacheTTL: TimeInterval = 20

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

        // Fetch both — panel may update GitHub while Firestore REST is stale/rate-limited.
        async let firestoreTask = fetchFirestore(session: session)
        async let githubTask = fetchGitHubMirror(session: session)
        let firestore = await firestoreTask
        let github = await githubTask

        if let chosen = newest(firestore, github) {
            remember(chosen)
            return chosen
        }

        if let disk = loadDisk() {
            remember(disk)
            return disk
        }

        return .disabled
    }

    private static func newest(_ firestore: AppAdSettings?, _ github: AppAdSettings?) -> AppAdSettings? {
        switch (firestore, github) {
        case let (fs?, gh?):
            let left = parseDate(fs.updatedAt)
            let right = parseDate(gh.updatedAt)
            if left == nil, right == nil { return gh }
            if let left, let right { return left >= right ? fs : gh }
            if left != nil { return fs }
            return gh
        case let (fs?, nil):
            return fs
        case let (nil, gh?):
            return gh
        case (nil, nil):
            return nil
        }
    }

    private static func parseDate(_ raw: String) -> Date? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if let date = ISO8601DateFormatter().date(from: value) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value)
    }

    private static func remember(_ settings: AppAdSettings) {
        cached = settings
        cachedAt = Date()
        persistDisk(settings)
    }

    private static func fetchFirestore(session: URLSession) async -> AppAdSettings? {
        for attempt in 0..<3 {
            do {
                var request = URLRequest(url: documentURL)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.timeoutInterval = 12
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { return nil }

                if http.statusCode == 429 || http.statusCode == 503 {
                    try? await Task.sleep(nanoseconds: UInt64(350_000_000 * (attempt + 1)))
                    continue
                }
                guard (200...299).contains(http.statusCode) else { return nil }

                let doc = try JSONDecoder().decode(FirestoreSettingsDocument.self, from: data)
                return doc.toDomain()
            } catch {
                try? await Task.sleep(nanoseconds: UInt64(250_000_000 * (attempt + 1)))
            }
        }
        return nil
    }

    private static func fetchGitHubMirror(session: URLSession) async -> AppAdSettings? {
        let base = GitHubAssetsConfiguration.settingsURL
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))]
        guard let url = components.url else { return nil }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 12
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let dto = try JSONDecoder().decode(GitHubAppSettingsDTO.self, from: data)
            return dto.toDomain()
        } catch {
            return nil
        }
    }

    private static func persistDisk(_ settings: AppAdSettings) {
        guard let data = try? JSONEncoder().encode(DiskAppSettings(settings)) else { return }
        UserDefaults.standard.set(data, forKey: diskKey)
    }

    private static func loadDisk() -> AppAdSettings? {
        guard let data = UserDefaults.standard.data(forKey: diskKey) else { return nil }
        guard let disk = try? JSONDecoder().decode(DiskAppSettings.self, from: data) else { return nil }
        return disk.toDomain()
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
            ),
            appOpenMinBackgroundSeconds: max(
                0,
                min(600, fields.int("appOpenMinBackgroundSeconds") ?? 2)
            ),
            introEnabled: fields.bool("introEnabled") ?? false,
            introShowEveryLaunch: fields.bool("introShowEveryLaunch") ?? false,
            introVersion: max(1, fields.int("introVersion") ?? 1),
            introTitle: fields.string("introTitle")
                ?? "Welcome to Wallora Glass",
            introSubtitle: fields.string("introSubtitle")
                ?? "Browse Live & iOS wallpapers. Save favorites and download in one tap.",
            introImageURL: fields.string("introImageURL") ?? "",
            introVideoURL: fields.string("introVideoURL") ?? "",
            introMaxSeconds: max(0, min(120, fields.int("introMaxSeconds") ?? 0)),
            introButtonTitle: {
                let value = fields.string("introButtonTitle")?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return value.isEmpty ? "Get Started" : value
            }(),
            updatedAt: fields.string("updatedAt") ?? ""
        )
    }
}

private struct GitHubAppSettingsDTO: Decodable {
    let adsEnabled: Bool?
    let adsMode: String?
    let appOpenAdUnitId: String?
    let interstitialAdUnitId: String?
    let interstitialEveryNOpens: Int?
    let interstitialEveryNDownloads: Int?
    let appOpenMinBackgroundSeconds: Int?
    let introEnabled: Bool?
    let introShowEveryLaunch: Bool?
    let introVersion: Int?
    let introTitle: String?
    let introSubtitle: String?
    let introImageURL: String?
    let introVideoURL: String?
    let introMaxSeconds: Int?
    let introButtonTitle: String?
    let updatedAt: String?

    func toDomain() -> AppAdSettings {
        let mode: AdsMode = adsMode?.lowercased() == "production" ? .production : .test
        let button = introButtonTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return AppAdSettings(
            adsEnabled: adsEnabled ?? false,
            adsMode: mode,
            appOpenAdUnitId: appOpenAdUnitId ?? "",
            interstitialAdUnitId: interstitialAdUnitId ?? "",
            interstitialEveryNOpens: max(1, interstitialEveryNOpens ?? 4),
            interstitialEveryNDownloads: max(1, interstitialEveryNDownloads ?? 3),
            appOpenMinBackgroundSeconds: max(0, min(600, appOpenMinBackgroundSeconds ?? 2)),
            introEnabled: introEnabled ?? false,
            introShowEveryLaunch: introShowEveryLaunch ?? false,
            introVersion: max(1, introVersion ?? 1),
            introTitle: (introTitle?.isEmpty == false) ? introTitle! : "Welcome to Wallora Glass",
            introSubtitle: introSubtitle
                ?? "Browse Live & iOS wallpapers. Save favorites and download in one tap.",
            introImageURL: introImageURL ?? "",
            introVideoURL: introVideoURL ?? "",
            introMaxSeconds: max(0, min(120, introMaxSeconds ?? 0)),
            introButtonTitle: button.isEmpty ? "Get Started" : button,
            updatedAt: updatedAt ?? ""
        )
    }
}

private struct DiskAppSettings: Codable {
    var adsEnabled: Bool
    var adsMode: String
    var appOpenAdUnitId: String
    var interstitialAdUnitId: String
    var interstitialEveryNOpens: Int
    var interstitialEveryNDownloads: Int
    var appOpenMinBackgroundSeconds: Int
    var introEnabled: Bool
    var introShowEveryLaunch: Bool
    var introVersion: Int
    var introTitle: String
    var introSubtitle: String
    var introImageURL: String
    var introVideoURL: String
    var introMaxSeconds: Int
    var introButtonTitle: String
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case adsEnabled, adsMode, appOpenAdUnitId, interstitialAdUnitId
        case interstitialEveryNOpens, interstitialEveryNDownloads, appOpenMinBackgroundSeconds
        case introEnabled, introShowEveryLaunch, introVersion, introTitle, introSubtitle
        case introImageURL, introVideoURL, introMaxSeconds, introButtonTitle, updatedAt
    }

    init(_ settings: AppAdSettings) {
        adsEnabled = settings.adsEnabled
        adsMode = settings.adsMode.rawValue
        appOpenAdUnitId = settings.appOpenAdUnitId
        interstitialAdUnitId = settings.interstitialAdUnitId
        interstitialEveryNOpens = settings.interstitialEveryNOpens
        interstitialEveryNDownloads = settings.interstitialEveryNDownloads
        appOpenMinBackgroundSeconds = settings.appOpenMinBackgroundSeconds
        introEnabled = settings.introEnabled
        introShowEveryLaunch = settings.introShowEveryLaunch
        introVersion = settings.introVersion
        introTitle = settings.introTitle
        introSubtitle = settings.introSubtitle
        introImageURL = settings.introImageURL
        introVideoURL = settings.introVideoURL
        introMaxSeconds = settings.introMaxSeconds
        introButtonTitle = settings.introButtonTitle
        updatedAt = settings.updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        adsEnabled = try c.decode(Bool.self, forKey: .adsEnabled)
        adsMode = try c.decode(String.self, forKey: .adsMode)
        appOpenAdUnitId = try c.decode(String.self, forKey: .appOpenAdUnitId)
        interstitialAdUnitId = try c.decode(String.self, forKey: .interstitialAdUnitId)
        interstitialEveryNOpens = try c.decode(Int.self, forKey: .interstitialEveryNOpens)
        interstitialEveryNDownloads = try c.decode(Int.self, forKey: .interstitialEveryNDownloads)
        appOpenMinBackgroundSeconds = try c.decode(Int.self, forKey: .appOpenMinBackgroundSeconds)
        introEnabled = try c.decode(Bool.self, forKey: .introEnabled)
        introShowEveryLaunch = try c.decode(Bool.self, forKey: .introShowEveryLaunch)
        introVersion = try c.decode(Int.self, forKey: .introVersion)
        introTitle = try c.decode(String.self, forKey: .introTitle)
        introSubtitle = try c.decode(String.self, forKey: .introSubtitle)
        introImageURL = try c.decodeIfPresent(String.self, forKey: .introImageURL) ?? ""
        introVideoURL = try c.decodeIfPresent(String.self, forKey: .introVideoURL) ?? ""
        introMaxSeconds = try c.decodeIfPresent(Int.self, forKey: .introMaxSeconds) ?? 0
        introButtonTitle = try c.decode(String.self, forKey: .introButtonTitle)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    func toDomain() -> AppAdSettings {
        AppAdSettings(
            adsEnabled: adsEnabled,
            adsMode: adsMode == "production" ? .production : .test,
            appOpenAdUnitId: appOpenAdUnitId,
            interstitialAdUnitId: interstitialAdUnitId,
            interstitialEveryNOpens: max(1, interstitialEveryNOpens),
            interstitialEveryNDownloads: max(1, interstitialEveryNDownloads),
            appOpenMinBackgroundSeconds: max(0, min(600, appOpenMinBackgroundSeconds)),
            introEnabled: introEnabled,
            introShowEveryLaunch: introShowEveryLaunch,
            introVersion: max(1, introVersion),
            introTitle: introTitle,
            introSubtitle: introSubtitle,
            introImageURL: introImageURL,
            introVideoURL: introVideoURL,
            introMaxSeconds: max(0, min(120, introMaxSeconds)),
            introButtonTitle: introButtonTitle,
            updatedAt: updatedAt ?? ""
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
