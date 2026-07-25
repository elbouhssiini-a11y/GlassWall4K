//
//  CachedRemoteImage.swift
//  GlassWall4K
//

import SwiftUI
import UIKit

struct CachedRemoteImage: View {
    let url: URL
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if failed {
                Color.clear
            } else {
                ProgressView()
                    .tint(.white.opacity(0.8))
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .clipped()
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        if let cached = MediaCache.cachedImage(for: url) {
            image = cached
            failed = false
            return
        }

        failed = false
        do {
            let loaded = try await MediaCache.loadImage(from: url)
            guard !Task.isCancelled else { return }
            image = loaded
        } catch {
            guard !Task.isCancelled else { return }
            failed = true
        }
    }
}
