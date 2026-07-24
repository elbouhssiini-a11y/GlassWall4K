//
//  GlassCard.swift
//  GlassWall4K
//

import SwiftUI

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = GlassMetrics.cardRadius
    var material: Material = .ultraThinMaterial
    var borderOpacity: Double = 0.18
    var shadow: GlassShadow = .card

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(material)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                GlassColors.borderHighlight.opacity(borderOpacity),
                                GlassColors.borderHighlight.opacity(borderOpacity * 0.35),
                                Color.primary.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            .glassShadow(shadow)
    }
}

struct CapsuleGlassCardModifier: ViewModifier {
    var material: Material = .ultraThinMaterial
    var isEmphasized: Bool = false

    func body(content: Content) -> some View {
        content
            .background {
                Capsule(style: .continuous)
                    .fill(isEmphasized ? Material.thinMaterial : material)
            }
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        GlassColors.borderHighlight.opacity(isEmphasized ? 0.28 : 0.16),
                        lineWidth: 0.7
                    )
            }
            .glassShadow(isEmphasized ? .chipSelected : .chip)
    }
}

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = GlassMetrics.cardRadius
    var material: Material = .ultraThinMaterial
    var borderOpacity: Double = 0.18
    var shadow: GlassShadow = .card
    @ViewBuilder var content: Content

    var body: some View {
        content
            .glassCard(
                cornerRadius: cornerRadius,
                material: material,
                borderOpacity: borderOpacity,
                shadow: shadow
            )
    }
}

extension View {
    func glassCard(
        cornerRadius: CGFloat = GlassMetrics.cardRadius,
        material: Material = .ultraThinMaterial,
        borderOpacity: Double = 0.18,
        shadow: GlassShadow = .card
    ) -> some View {
        modifier(
            GlassCardModifier(
                cornerRadius: cornerRadius,
                material: material,
                borderOpacity: borderOpacity,
                shadow: shadow
            )
        )
    }

    /// Compatibility alias used throughout the app.
    func glassChrome(
        cornerRadius: CGFloat = GlassMetrics.cardRadius,
        material: Material = .ultraThinMaterial,
        borderOpacity: Double = 0.18,
        shadowOpacity: Double = 0.1
    ) -> some View {
        glassCard(
            cornerRadius: cornerRadius,
            material: material,
            borderOpacity: borderOpacity,
            shadow: shadowOpacity >= 0.1 ? .card : .soft
        )
    }

    func capsuleGlassChrome(
        material: Material = .ultraThinMaterial,
        isEmphasized: Bool = false
    ) -> some View {
        modifier(CapsuleGlassCardModifier(material: material, isEmphasized: isEmphasized))
    }
}
