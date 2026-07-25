//
//  MediaCache.swift
//  GlassWall4K
//

import AVFoundation
import Foundation
import UIKit

enum MediaCache {
    private static let memoryImageCache = NSCache<NSURL, UIImage>()
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache.shared
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    static func configureSharedURLCache() {
        let cache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 512 * 1024 * 1024,
            diskPath: "wallora-media-cache"
        )
        URLCache.shared = cache
        memoryImageCache.countLimit = 120
        memoryImageCache.totalCostLimit = 80 * 1024 * 1024
    }

    static func cachedImage(for url: URL) -> UIImage? {
        memoryImageCache.object(forKey: url as NSURL)
    }

    static func storeImage(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        memoryImageCache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    static func clear() {
        memoryImageCache.removeAllObjects()
        URLCache.shared.removeAllCachedResponses()
    }

    @discardableResult
    static func loadImage(from url: URL) async throws -> UIImage {
        if let cached = cachedImage(for: url) {
            return cached
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }

        storeImage(image, for: url)
        return image
    }

    /// Download remote media (follows redirects) into disk cache for reliable AVPlayer playback.
    /// GitHub release URLs often fail as streamed AVURLAsset (attachment + redirects).
    static func cachedFileURL(for remoteURL: URL) async throws -> URL {
        let source = normalizedDownloadURL(remoteURL)
        let fileURL = diskCacheURL(for: source)

        if FileManager.default.fileExists(atPath: fileURL.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? NSNumber,
           size.intValue > 0 {
            return fileURL
        }

        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let tempURL = directory.appendingPathComponent(UUID().uuidString + ".tmp")
        let request = URLRequest(url: source, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 120)
        let (tempDownload, response) = try await session.download(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        if FileManager.default.fileExists(atPath: tempURL.path) {
            try? FileManager.default.removeItem(at: tempURL)
        }
        try FileManager.default.moveItem(at: tempDownload, to: tempURL)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: fileURL)
        return fileURL
    }

    private static func normalizedDownloadURL(_ url: URL) -> URL {
        guard let host = url.host?.lowercased(),
              host.contains("github.com"),
              url.path.contains("/releases/download/")
        else {
            return url
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        return components?.url ?? url
    }

    private static func diskCacheURL(for url: URL) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = caches.appendingPathComponent("wallora-video-cache", isDirectory: true)
        let name = StableHash.hex(of: url.absoluteString)
        let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
        return folder.appendingPathComponent("\(name).\(ext)")
    }

    /// Warm thumb (and video playable metadata) so Live grid / detail feel instant.
    static func prefetch(wallpapers: [Wallpaper], thumbLimit: Int = 24, videoLimit: Int = 8) {
        let thumbs = Array(wallpapers.prefix(thumbLimit).map(\.thumbnailURL))
        let videos = Array(wallpapers.prefix(videoLimit).compactMap(\.videoURL))

        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                for url in thumbs {
                    group.addTask {
                        _ = try? await loadImage(from: url)
                    }
                }
            }
        }

        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                for url in videos {
                    group.addTask {
                        let asset = AVURLAsset(url: url)
                        _ = try? await asset.load(.isPlayable)
                    }
                }
            }
        }
    }
}

private enum StableHash {
    static func hex(of string: String) -> String {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = 127 &* hash &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }
}
