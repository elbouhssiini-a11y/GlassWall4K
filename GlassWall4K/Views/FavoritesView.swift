//
//  FavoritesView.swift
//  GlassWall4K
//

import SwiftUI

struct FavoritesView: View {
    let namespace: Namespace.ID

    private let horizontalInset = GlassMetrics.horizontalInset
    private let gridSpacing = GlassMetrics.gridSpacing

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: gridSpacing),
            GridItem(.flexible(), spacing: gridSpacing)
        ]
    }

    var body: some View {
        let favorites = FavoritesStore.shared

        Group {
            if favorites.wallpapers.isEmpty {
                EmptyStateView(
                    title: "No Favorites Yet",
                    message: "Save wallpapers you love and they'll appear here.",
                    systemName: "heart.slash"
                )
            } else {
                favoritesGrid(favorites.wallpapers)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            GlassScreenBackground()
        }
        .task {
            MediaCache.prefetch(wallpapers: FavoritesStore.shared.wallpapers)
        }
        .navigationDestination(for: Wallpaper.self) { wallpaper in
            WallpaperDetailView(
                wallpaper: wallpaper,
                wallpapers: FavoritesStore.shared.wallpapers,
                namespace: namespace
            )
        }
    }

    private func favoritesGrid(_ wallpapers: [Wallpaper]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                ForEach(wallpapers) { wallpaper in
                    NavigationLink(value: wallpaper) {
                        GridWallpaperCard(
                            wallpaper: wallpaper,
                            namespace: namespace,
                            playsLivePreview: false
                        )
                    }
                    .buttonStyle(WallpaperPressButtonStyle())
                }
            }
            .padding(.horizontal, horizontalInset)
            .padding(.top, 4)
        }
    }
}

#Preview {
    FavoritesPreviewHost()
}

private struct FavoritesPreviewHost: View {
    @Namespace private var namespace

    var body: some View {
        NavigationStack {
            FavoritesView(namespace: namespace)
                .navigationTitle("Favorites")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}
