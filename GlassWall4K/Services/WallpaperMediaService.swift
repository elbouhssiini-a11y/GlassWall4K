//
//  WallpaperMediaService.swift
//  GlassWall4K
//

import Foundation
import Photos
import UIKit

enum WallpaperMediaError: LocalizedError {
    case invalidImage
    case photoAccessDenied
    case downloadFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: "The image could not be loaded."
        case .photoAccessDenied: "Photo access was denied. Open Settings to allow it."
        case .downloadFailed: "The download failed."
        case .saveFailed: "Could not save to Photos."
        }
    }
}

enum WallpaperMediaService {
    static func downloadData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WallpaperMediaError.downloadFailed
        }
        return data
    }

    static func saveToPhotos(from url: URL) async throws {
        let data = try await downloadData(from: url)
        guard let image = UIImage(data: data) else {
            throw WallpaperMediaError.invalidImage
        }

        // Crop/scale to this device screen so Photos + Set Wallpaper look edge-to-edge.
        let fullscreen = await renderDeviceFullscreen(from: image)
        guard let output = fullscreen.jpegData(compressionQuality: 0.95) else {
            throw WallpaperMediaError.invalidImage
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw WallpaperMediaError.photoAccessDenied
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: output, options: nil)
            }
        } catch {
            throw WallpaperMediaError.saveFailed
        }
    }

    static func saveVideoToPhotos(from url: URL) async throws {
        let data = try await downloadData(from: url)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("live-\(UUID().uuidString).mp4")
        try data.write(to: tempURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw WallpaperMediaError.photoAccessDenied
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
            }
        } catch {
            throw WallpaperMediaError.saveFailed
        }
    }

    static func temporaryShareFile(from url: URL, titled title: String, isVideo: Bool) async throws -> URL {
        let data = try await downloadData(from: url)
        let safeName = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        let fileData: Data
        let ext: String
        if isVideo {
            fileData = data
            ext = "mp4"
        } else {
            guard let image = UIImage(data: data) else {
                throw WallpaperMediaError.invalidImage
            }
            let fullscreen = await renderDeviceFullscreen(from: image)
            guard let jpeg = fullscreen.jpegData(compressionQuality: 0.95) else {
                throw WallpaperMediaError.invalidImage
            }
            fileData = jpeg
            ext = "jpg"
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName)-\(UUID().uuidString.prefix(8)).\(ext)")
        try fileData.write(to: fileURL, options: .atomic)
        return fileURL
    }

    /// Aspect-fill into the device's native pixel size (no letterboxing in Photos).
    @MainActor
    private static func devicePixelSize() -> CGSize {
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) {
            return scene.screen.nativeBounds.size
        }
        return UIScreen.main.nativeBounds.size
    }

    private static func renderDeviceFullscreen(from image: UIImage) async -> UIImage {
        let target = await MainActor.run { devicePixelSize() }
        return renderAspectFill(image: image, targetPixels: target)
    }

    private static func renderAspectFill(image: UIImage, targetPixels: CGSize) -> UIImage {
        let targetW = max(1, targetPixels.width)
        let targetH = max(1, targetPixels.height)

        let sourceW = max(1, image.size.width * image.scale)
        let sourceH = max(1, image.size.height * image.scale)

        let scale = max(targetW / sourceW, targetH / sourceH)
        let drawW = sourceW * scale
        let drawH = sourceH * scale
        let originX = (targetW - drawW) / 2
        let originY = (targetH - drawH) / 2

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: targetW, height: targetH),
            format: format
        )

        return renderer.image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: targetW, height: targetH))
            image.draw(in: CGRect(x: originX, y: originY, width: drawW, height: drawH))
        }
    }
}
