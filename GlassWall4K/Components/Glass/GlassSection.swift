//
//  GlassSection.swift
//  GlassWall4K
//

import SwiftUI

struct GlassSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(GlassColors.secondaryText)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                content
            }
            .glassCard(
                cornerRadius: GlassMetrics.sectionCornerRadius,
                material: .regularMaterial,
                borderOpacity: 0.16,
                shadow: .soft
            )
        }
    }
}

struct GlassSectionDivider: View {
    var leadingInset: CGFloat = 54

    var body: some View {
        Divider()
            .padding(.leading, leadingInset)
            .opacity(0.55)
            .accessibilityHidden(true)
    }
}

#Preview {
    GlassSection(title: "General") {
        Text("Appearance")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, GlassMetrics.rowHorizontalPadding)
            .padding(.vertical, GlassMetrics.rowVerticalPadding)
    }
    .padding()
    .background(GlassScreenBackground())
}
