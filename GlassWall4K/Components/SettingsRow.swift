//
//  SettingsRow.swift
//  GlassWall4K
//

import SwiftUI

struct SettingsNavigationRow: View {
    let title: String
    let systemName: String
    var tint: Color = .accentColor
    var value: String? = nil
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            SettingsGlyph(systemName: systemName, tint: tint)

            Text(title)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

struct SettingsToggleRow: View {
    let title: String
    let systemName: String
    var tint: Color = .accentColor
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn.animation(.spring(response: 0.3, dampingFraction: 0.8))) {
            HStack(spacing: 14) {
                SettingsGlyph(systemName: systemName, tint: tint)
                Text(title)
            }
        }
        .tint(.accentColor)
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

struct SettingsActionRow: View {
    let title: String
    let systemName: String
    var tint: Color = .accentColor
    var role: ButtonRole? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Button(role: role) {
            action?()
        } label: {
            HStack(spacing: 14) {
                SettingsGlyph(
                    systemName: systemName,
                    tint: role == .destructive ? .red : tint
                )

                Text(title)
                    .foregroundStyle(role == .destructive ? Color.red : Color.primary)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressButtonStyle())
    }
}

struct SettingsGlyph: View {
    let systemName: String
    var tint: Color = .accentColor

    var body: some View {
        Image(systemName: systemName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
            }
    }
}

#Preview {
    VStack {
        SettingsNavigationRow(
            title: "Appearance",
            systemName: "circle.lefthalf.filled",
            showsChevron: true
        )
        SettingsToggleRow(
            title: "Haptic Feedback",
            systemName: "waveform",
            isOn: .constant(true)
        )
        SettingsActionRow(
            title: "Clear Image Cache",
            systemName: "trash",
            tint: .orange,
            role: .destructive
        )
    }
    .padding()
    .glassChrome()
    .padding()
    .background(Color(.systemGroupedBackground))
}
