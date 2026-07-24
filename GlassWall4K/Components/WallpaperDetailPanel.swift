//
//  WallpaperDetailPanel.swift
//  GlassWall4K
//

import SwiftUI

struct WallpaperDetailPanel: View {
    var isDownloading: Bool = false
    var onDownload: (() -> Void)? = nil

    var body: some View {
        HStack {
            Spacer(minLength: 0)

            Button {
                guard !isDownloading else { return }
                onDownload?()
            } label: {
                Group {
                    if isDownloading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                .frame(width: 64, height: 64)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isDownloading)
            .background {
                Circle()
                    .fill(Color.accentColor.gradient)
            }
            .shadow(color: Color.accentColor.opacity(0.35), radius: 18, y: 8)
            .accessibilityLabel("Download")
        }
    }
}
