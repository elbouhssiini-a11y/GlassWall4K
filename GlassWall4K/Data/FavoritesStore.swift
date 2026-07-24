//
//  FavoritesStore.swift
//  GlassWall4K
//

import Foundation
import Observation

@Observable
@MainActor
final class FavoritesStore {
    static let shared = FavoritesStore()

    private(set) var wallpapers: [Wallpaper] = []

    private let storageKey = "glasswall4k.favoriteWallpapers"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func contains(_ id: String) -> Bool {
        wallpapers.contains { $0.id == id }
    }

    @discardableResult
    func toggle(_ wallpaper: Wallpaper) -> Bool {
        if let index = wallpapers.firstIndex(where: { $0.id == wallpaper.id }) {
            wallpapers.remove(at: index)
            persist()
            return false
        }

        wallpapers.insert(wallpaper, at: 0)
        persist()
        return true
    }

    func remove(id: String) {
        wallpapers.removeAll { $0.id == id }
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            wallpapers = []
            return
        }

        do {
            wallpapers = try makeDecoder().decode([Wallpaper].self, from: data)
        } catch {
            wallpapers = []
        }
    }

    private func persist() {
        do {
            let data = try makeEncoder().encode(wallpapers)
            defaults.set(data, forKey: storageKey)
        } catch {
            // Keep in-memory state even if disk write fails.
        }
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
