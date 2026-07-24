//
//  DetailActionButton.swift
//  GlassWall4K
//

import SwiftUI

struct DetailActionButton: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    let systemName: String
    let style: Style
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemName)
                    .font(.body.weight(.semibold))

                Text(title)
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(style == .primary ? Color.white : Color.primary)
        .background {
            if style == .primary {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.accentColor.gradient)
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.clear)
                    .glassEffectIfAvailable(in: .roundedRect(cornerRadius: 18))
            }
        }
        .shadow(
            color: style == .primary ? Color.accentColor.opacity(0.28) : Color.black.opacity(0.06),
            radius: style == .primary ? 16 : 10,
            y: 6
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        DetailActionButton(title: "Download", systemName: "arrow.down.circle.fill", style: .primary)
        DetailActionButton(title: "Save to Favorites", systemName: "heart", style: .secondary)
    }
    .padding()
}
