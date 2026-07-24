//
//  FloatingDetailToolbar.swift
//  GlassWall4K
//

import SwiftUI

struct FloatingDetailToolbar: View {
    var isFavorite: Bool = false
    var isShareBusy: Bool = false
    var onBack: (() -> Void)? = nil
    var onFavorite: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil

    var body: some View {
        HStack {
            GlassIconButton(systemName: "chevron.backward", action: onBack)

            Spacer()

            HStack(spacing: 12) {
                GlassIconButton(
                    systemName: isFavorite ? "heart.fill" : "heart",
                    isEmphasized: isFavorite,
                    action: onFavorite
                )

                if isShareBusy {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 44, height: 44)
                        .background {
                            Circle().fill(.ultraThinMaterial)
                        }
                } else {
                    GlassIconButton(systemName: "square.and.arrow.up", action: onShare)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }
}
