//
//  GlassCategoryChip.swift
//  GlassWall4K
//

import SwiftUI

struct GlassCategoryChip: View {
    let title: String
    let symbolName: String
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    @State private var feedbackToken = 0

    var body: some View {
        Button {
            feedbackToken += 1
            action?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbolName)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHidden(true)

                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isSelected ? GlassColors.primaryText : GlassColors.secondaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .capsuleGlassChrome(
                material: .ultraThinMaterial,
                isEmphasized: isSelected
            )
            .contentShape(Capsule())
        }
        .buttonStyle(GlassPressButtonStyle())
        .sensoryFeedback(.selection, trigger: feedbackToken)
        .animation(.spring(response: 0.32, dampingFraction: 0.76), value: isSelected)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    HStack {
        GlassCategoryChip(title: "iOS 27", symbolName: "iphone", isSelected: true)
        GlassCategoryChip(title: "Live", symbolName: "play.circle", isSelected: false)
    }
    .padding()
    .background(GlassScreenBackground())
}
