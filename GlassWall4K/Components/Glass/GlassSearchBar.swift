//
//  GlassSearchBar.swift
//  GlassWall4K
//

import SwiftUI

struct GlassSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search wallpapers..."

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(GlassColors.secondaryText)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFocused)
                .submitLabel(.search)
                .accessibilityLabel(placeholder)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .glassEffectIfAvailable(in: .capsule)
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(
                    GlassColors.borderHighlight.opacity(isFocused ? 0.28 : 0.16),
                    lineWidth: 0.8
                )
        }
        .glassShadow(.search)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
        .animation(.smooth(duration: 0.2), value: text.isEmpty)
    }
}

#Preview {
    struct GlassSearchBarPreview: View {
        @State private var query = ""

        var body: some View {
            GlassSearchBar(text: $query)
                .padding()
                .background(GlassScreenBackground())
        }
    }

    return GlassSearchBarPreview()
}
