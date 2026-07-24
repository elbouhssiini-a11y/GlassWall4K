//
//  GlassButton.swift
//  GlassWall4K
//

import SwiftUI

struct GlassPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct GlassButton: View {
    let title: String
    var systemName: String? = nil
    var isDestructive: Bool = false
    var action: (() -> Void)? = nil

    @State private var feedbackToken = 0

    var body: some View {
        Button {
            feedbackToken += 1
            action?()
        } label: {
            HStack(spacing: 10) {
                if let systemName {
                    Image(systemName: systemName)
                        .font(.body.weight(.semibold))
                }

                Text(title)
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(isDestructive ? GlassColors.destructive : GlassColors.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 18)
            .capsuleGlassChrome(material: .ultraThinMaterial)
            .contentShape(Capsule())
        }
        .buttonStyle(GlassPressButtonStyle())
        .sensoryFeedback(.selection, trigger: feedbackToken)
        .accessibilityLabel(title)
    }
}

#Preview {
    VStack(spacing: 12) {
        GlassButton(title: "Continue", systemName: "arrow.right")
        GlassButton(title: "Clear Cache", systemName: "trash", isDestructive: true)
    }
    .padding()
    .background(GlassScreenBackground())
}
