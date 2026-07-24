//
//  WallpaperCard.swift
//  GlassWall4K
//

import SwiftUI

struct WallpaperCard: View {
    enum Size {
        case large
        case standard

        var width: CGFloat {
            switch self {
            case .large: 220
            case .standard: 160
            }
        }

        var height: CGFloat {
            switch self {
            case .large: 320
            case .standard: 240
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .large: GlassMetrics.cardCornerRadius
            case .standard: 24
            }
        }
    }

    let size: Size
    let gradient: [Color]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)

            LinearGradient(
                colors: gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.88)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.16),
                    .clear,
                    Color.black.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "photo.fill")
                .font(.system(size: size == .large ? 36 : 28))
                .foregroundStyle(.white.opacity(0.34))
                .symbolEffect(.pulse, options: .repeating.speed(0.4))
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        .scrollTransition { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.94)
                .opacity(phase.isIdentity ? 1 : 0.7)
        }
    }
}

#Preview {
    ScrollView(.horizontal) {
        HStack {
            WallpaperCard(
                size: .large,
                gradient: [.indigo, .purple]
            )
            WallpaperCard(
                size: .standard,
                gradient: [.teal, .blue]
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
