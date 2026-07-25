//
//  GridWallpaperCard.swift
//  GlassWall4K
//

import SwiftUI

struct GridWallpaperCard: View {
    let wallpaper: Wallpaper
    var namespace: Namespace.ID?
    var cornerRadius: CGFloat = GlassMetrics.cardCornerRadius
    /// Play muted looping preview for Live items (visible cells only).
    var playsLivePreview: Bool = true

    @State private var isVisible = false

    var body: some View {
        Color.clear
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .background {
                ZStack {
                    LinearGradient(
                        colors: wallpaper.placeholderGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    CachedRemoteImage(url: wallpaper.thumbnailURL)

                    if playsLivePreview, let videoURL = wallpaper.videoURL, isVisible {
                        LoopingVideoPlayer(url: videoURL, isActive: isVisible)
                    }

                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            .clear,
                            Color.black.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .overlay(alignment: .topLeading) {
                if wallpaper.isLive {
                    Label("LIVE", systemImage: "play.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.45), in: Capsule())
                        .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.32),
                                Color.white.opacity(0.08),
                                Color.primary.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
            }
            .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .modifier(HeroTransitionSourceModifier(
                id: wallpaper.id,
                namespace: namespace,
                cornerRadius: cornerRadius
            ))
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
            .accessibilityLabel(wallpaper.isLive ? "\(wallpaper.title), Live" : wallpaper.title)
    }
}

private struct HeroTransitionSourceModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID?
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if let namespace {
            if #available(iOS 18.0, *) {
                content
                    .matchedTransitionSource(id: id, in: namespace) { source in
                        source
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
            } else {
                content
            }
        } else {
            content
        }
    }
}
