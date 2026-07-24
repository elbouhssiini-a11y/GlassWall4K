//
//  GlassScreenBackground.swift
//  GlassWall4K
//

import SwiftUI

struct GlassScreenBackground: View {
    var body: some View {
        ZStack {
            GlassColors.screenBackground

            LinearGradient(
                colors: [
                    GlassColors.accent.opacity(0.08),
                    Color.clear,
                    Color.primary.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .opacity(0.35)
                .offset(x: 120, y: -180)
                .allowsHitTesting(false)

            Circle()
                .fill(.thinMaterial)
                .frame(width: 220, height: 220)
                .blur(radius: 50)
                .opacity(0.25)
                .offset(x: -140, y: 260)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview("Light") {
    GlassScreenBackground()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    GlassScreenBackground()
        .preferredColorScheme(.dark)
}
