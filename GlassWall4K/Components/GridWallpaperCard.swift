//
//  GridWallpaperCard.swift
//  GlassWall4K
//

import SwiftUI

struct GridWallpaperCard: View {
    let wallpaper: Wallpaper
    var namespace: Namespace.ID?
    var cornerRadius: CGFloat = GlassMetrics.cardCornerRadius

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

                    AsyncImage(url: wallpaper.thumbnailURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            EmptyView()
                        case .empty:
                            ProgressView()
                                .tint(.white.opacity(0.8))
                        @unknown default:
                            EmptyView()
                        }
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
            .accessibilityLabel(wallpaper.title)
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

struct WallpaperPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.955 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
