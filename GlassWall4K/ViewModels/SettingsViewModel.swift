//
//  SettingsViewModel.swift
//  GlassWall4K
//

import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    var notice: String?

    var shareItems: [Any] {
        ["Check out Wallora Glass — 4K & iOS wallpapers."]
    }

    private var clearNoticeTask: Task<Void, Never>?

    func clearImageCache() {
        URLCache.shared.removeAllCachedResponses()
        FirestoreWallpaperRepository.invalidateCache()
        FirestoreAppSettingsRepository.invalidateCache()

        notice = "Cache cleared."
        clearNoticeTask?.cancel()
        clearNoticeTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            notice = nil
        }
    }
}
