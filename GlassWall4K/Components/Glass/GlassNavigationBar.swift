//
//  GlassNavigationBar.swift
//  GlassWall4K
//

import SwiftUI

struct GlassNavigationBar<Leading: View, Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            leading()

            VStack(spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(GlassColors.primaryText)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(GlassColors.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)

            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard(
            cornerRadius: 24,
            material: .ultraThinMaterial,
            borderOpacity: 0.16,
            shadow: .soft
        )
        .padding(.horizontal, GlassMetrics.horizontalInset)
        .accessibilityElement(children: .contain)
    }
}

extension GlassNavigationBar where Leading == EmptyView, Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) {
            EmptyView()
        } trailing: {
            EmptyView()
        }
    }
}

#Preview {
    VStack {
        GlassNavigationBar(title: "Wallora Glass", subtitle: "4K Wallpapers") {
            Image(systemName: "chevron.backward")
                .frame(width: 28, height: 28)
        } trailing: {
            Image(systemName: "ellipsis")
                .frame(width: 28, height: 28)
        }
        Spacer()
    }
    .background(GlassScreenBackground())
}
