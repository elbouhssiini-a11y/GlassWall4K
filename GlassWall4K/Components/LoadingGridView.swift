//
//  LoadingGridView.swift
//  GlassWall4K
//

import SwiftUI

struct LoadingGridView: View {
    private let columns = [
        GridItem(.flexible(), spacing: GlassMetrics.gridSpacing),
        GridItem(.flexible(), spacing: GlassMetrics.gridSpacing)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: GlassMetrics.gridSpacing) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: GlassMetrics.cardRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .overlay {
                        ProgressView()
                            .controlSize(.regular)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: GlassMetrics.cardRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
                    }
            }
        }
        .padding(.horizontal, GlassMetrics.horizontalInset)
        .accessibilityLabel("Loading wallpapers")
    }
}

#Preview {
    LoadingGridView()
        .background(GlassScreenBackground())
}
