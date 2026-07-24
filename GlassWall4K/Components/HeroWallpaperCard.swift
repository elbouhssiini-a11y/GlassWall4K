//
//  HeroWallpaperCard.swift
//  GlassWall4K
//

import SwiftUI

struct HeroWallpaperCard: View {
    let title: String
    let subtitle: String
    let gradient: [Color]

    private let cornerRadius: CGFloat = 30

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.25))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(24)
        }
        .overlay(alignment: .topLeading) {
            Text("Featured")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffectIfAvailable(in: .capsule)
                .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
    }
}

#Preview {
    HeroWallpaperCard(
        title: "Aurora Dreams",
        subtitle: "Captured in 4K resolution",
        gradient: [.purple, .indigo, .blue]
    )
    .padding()
    .frame(height: 380)
}
