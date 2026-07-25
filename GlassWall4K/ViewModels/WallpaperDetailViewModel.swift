//
//  WallpaperDetailViewModel.swift
//  GlassWall4K
//

import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class WallpaperDetailViewModel {
    let wallpaper: Wallpaper

    private(set) var isFavorite: Bool
    private(set) var isDownloading = false
    private(set) var isSharing = false
    private(set) var statusMessage: String?
    var shareItems: [Any] = []
    var isSharePresented = false

    private let favorites: FavoritesStore

    init(wallpaper: Wallpaper, favorites: FavoritesStore? = nil) {
        self.wallpaper = wallpaper
        let store = favorites ?? FavoritesStore.shared
        self.favorites = store
        self.isFavorite = store.contains(wallpaper.id)
    }

    func toggleFavorite() {
        isFavorite = favorites.toggle(wallpaper)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        statusMessage = isFavorite ? "Added to Favorites" : "Removed from Favorites"
        clearStatusLater()
    }

    func download() async {
        guard !isDownloading else { return }
        isDownloading = true
        statusMessage = "Downloading…"
        defer { isDownloading = false }

        do {
            if let videoURL = wallpaper.videoURL {
                try await WallpaperMediaService.saveVideoToPhotos(from: videoURL)
            } else {
                try await WallpaperMediaService.saveToPhotos(from: wallpaper.imageURL)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            statusMessage = "Saved to Photos"
            AdsManager.shared.recordDownloadAndMaybeShowInterstitial(
                from: AdsPresenter.topViewController()
            )
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            statusMessage = error.localizedDescription
        }

        clearStatusLater()
    }

    func share() async {
        guard !isSharing else { return }
        isSharing = true
        statusMessage = "Preparing share…"

        do {
            let mediaURL = wallpaper.videoURL ?? wallpaper.imageURL
            let file = try await WallpaperMediaService.temporaryShareFile(
                from: mediaURL,
                titled: wallpaper.title,
                isVideo: wallpaper.isLive
            )
            shareItems = [file]
            isSharePresented = true
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
            clearStatusLater()
        }

        isSharing = false
    }

    private func clearStatusLater() {
        let message = statusMessage
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if statusMessage == message {
                statusMessage = nil
            }
        }
    }
}
