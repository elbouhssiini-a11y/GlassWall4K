//
//  EmptyStateView.swift
//  GlassWall4K
//

import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    var systemName: String = "photo.on.rectangle.angled"

    @State private var isAppeared = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemName)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
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
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(message)
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

#Preview {
    EmptyStateView(
        title: "No Wallpapers",
        message: "Nothing to show right now.",
        systemName: "photo.on.rectangle.angled"
    )
    .background(GlassScreenBackground())
}
