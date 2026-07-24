//
//  FavoritesEmptyState.swift
//  GlassWall4K
//

import SwiftUI

struct FavoritesEmptyState: View {
    @State private var isAppeared = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.pulse, options: .repeating.speed(0.35), isActive: isAppeared)
                .frame(width: 88, height: 88)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                }
                .glassEffectIfAvailable(in: .circle)
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
                .scaleEffect(isAppeared ? 1 : 0.86)
                .opacity(isAppeared ? 1 : 0)

            VStack(spacing: 8) {
                Text("No Favorites Yet")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Save wallpapers you love and they'll appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .glassChrome(material: .regularMaterial, borderOpacity: 0.16, shadowOpacity: 0.08)
            .opacity(isAppeared ? 1 : 0)
            .offset(y: isAppeared ? 0 : 12)
        }
        .padding(.horizontal, GlassMetrics.horizontalInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                isAppeared = true
            }
        }
    }
}

#Preview("Light") {
    FavoritesEmptyState()
        .preferredColorScheme(.light)
        .background(Color(.systemGroupedBackground))
}

#Preview("Dark") {
    FavoritesEmptyState()
        .preferredColorScheme(.dark)
        .background(Color(.systemGroupedBackground))
}
