//
//  SearchChip.swift
//  GlassWall4K
//

import SwiftUI

struct SearchChip: View {
    let title: String
    var systemName: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 8) {
                if let systemName {
                    Image(systemName: systemName)
                        .font(.subheadline.weight(.semibold))
                }

                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .capsuleGlassChrome(material: .ultraThinMaterial)
            .contentShape(Capsule())
        }
        .buttonStyle(GlassPressButtonStyle())
    }
}

#Preview {
    HStack {
        SearchChip(title: "Nature", systemName: "clock")
        SearchChip(title: "Anime", systemName: "clock")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
