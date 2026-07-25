//
//  RelatedWallpapersStrip.swift
//  GlassWall4K
//

import SwiftUI

struct RelatedWallpapersStrip: View {
    let wallpapers: [Wallpaper]
    let selectedID: String
    var onSelect: (Wallpaper) -> Void

    private let thumbWidth: CGFloat = 96
    private let thumbHeight: CGFloat = 171
    private let cornerRadius: CGFloat = 14

    var body: some View {
        if wallpapers.count > 1 {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(wallpapers) { wallpaper in
                            relatedThumb(wallpaper)
                                .id(wallpaper.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .onAppear {
                    proxy.scrollTo(selectedID, anchor: .center)
                }
                .onChange(of: selectedID) { _, newID in
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
            .padding(.bottom, 10)
        }
    }

    private func relatedThumb(_ wallpaper: Wallpaper) -> some View {
        let isSelected = wallpaper.id == selectedID

        return Button {
            onSelect(wallpaper)
        } label: {
            ZStack {
                LinearGradient(
                    colors: wallpaper.placeholderGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                CachedRemoteImage(url: wallpaper.thumbnailURL)
                    .clipped()

                if wallpaper.isLive {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.black.opacity(0.45), in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(5)
                }
            }
            .frame(width: thumbWidth, height: thumbHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
            }
            .shadow(
                color: .black.opacity(isSelected ? 0.4 : 0.22),
                radius: isSelected ? 12 : 6,
                y: isSelected ? 5 : 3
            )
            .scaleEffect(isSelected ? 1.12 : 1)
            .zIndex(isSelected ? 1 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(wallpaper.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
