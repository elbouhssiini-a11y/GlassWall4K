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
        case .invalidImage: "Image ma salatch."
        case .photoAccessDenied: "Authorization Photos ma3titch. 7el Settings."
        case .downloadFailed: "Download fail."
        case .saveFailed: "Save f Photos fail."
        }
    }
}

enum WallpaperMediaService {
    static func downloadImageData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WallpaperMediaError.downloadFailed
        }
        return data
    }

    static func saveToPhotos(from url: URL) async throws {
        let data = try await downloadImageData(from: url)
        guard UIImage(data: data) != nil else {
            throw WallpaperMediaError.invalidImage
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw WallpaperMediaError.photoAccessDenied
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }
        } catch {
            throw WallpaperMediaError.saveFailed
        }
    }

    static func temporaryShareFile(from url: URL, titled title: String) async throws -> URL {
        let data = try await downloadImageData(from: url)
        let safeName = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName)-\(UUID().uuidString.prefix(8)).jpg")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
