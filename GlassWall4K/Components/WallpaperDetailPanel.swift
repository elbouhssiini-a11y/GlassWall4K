//
//  WallpaperDetailPanel.swift
//  GlassWall4K
//

import SwiftUI

struct WallpaperDetailPanel: View {
    var isFavorite: Bool = false
    var isDownloading: Bool = false
    var isShareBusy: Bool = false
    var onFavorite: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onDownload: (() -> Void)? = nil

    private let buttonSize: CGFloat = 50
    private let iconSize: CGFloat = 20

    var body: some View {
        HStack(spacing: 0) {
            detailAction(
                title: "Favorite",
                systemName: isFavorite ? "heart.fill" : "heart",
                isBusy: false,
                action: onFavorite
            )

            detailAction(
                title: "Share",
                systemName: "square.and.arrow.up",
                isBusy: isShareBusy,
                action: onShare
            )

            detailAction(
                title: "Download",
                systemName: "arrow.down.to.line",
                isBusy: isDownloading,
                action: onDownload
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func detailAction(
        title: String,
        systemName: String,
        isBusy: Bool,
        action: (() -> Void)?
    ) -> some View {
        Button {
            guard !isBusy else { return }
            action?()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: buttonSize, height: buttonSize)
                        .overlay {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8)
                        }

                    if isBusy {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: systemName)
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(.white)
                            .symbolRenderingMode(.hierarchical)
                    }
                }

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel(title)
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.indigo, .black], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

        VStack {
            Spacer()
            WallpaperDetailPanel(isFavorite: true)
        }
    }
}
