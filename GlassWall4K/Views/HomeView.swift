//
//  HomeView.swift
//  GlassWall4K
//

import SwiftUI

struct HomeView: View {
    let namespace: Namespace.ID

    @State private var viewModel = HomeViewModel(category: .iosWallpapers)

    private let horizontalInset = GlassMetrics.horizontalInset
    private let gridSpacing = GlassMetrics.gridSpacing

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: gridSpacing),
            GridItem(.flexible(), spacing: gridSpacing)
        ]
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 16) {
                contentSection
            }
            .padding(.top, 4)
        }
        .background {
            GlassScreenBackground()
        }
        .task {
            await viewModel.loadHome()
            MediaCache.prefetch(wallpapers: viewModel.latestWallpapers, videoLimit: 0)
        }
        .refreshable {
            await viewModel.loadHome()
            MediaCache.prefetch(wallpapers: viewModel.latestWallpapers, videoLimit: 0)
        }
        .navigationDestination(for: Wallpaper.self) { wallpaper in
            WallpaperDetailView(
                wallpaper: wallpaper,
                wallpapers: viewModel.latestWallpapers,
                namespace: namespace
            )
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if let errorMessage = viewModel.errorMessage {
            ErrorStateView(message: errorMessage) {
                Task { await viewModel.loadHome() }
            }
            .frame(minHeight: 420)
        } else if viewModel.isLoading && viewModel.latestWallpapers.isEmpty {
            LoadingGridView()
                .frame(minHeight: 420)
        } else if viewModel.latestWallpapers.isEmpty {
            EmptyStateView(
                title: "No iOS 27 wallpapers",
                message: "Upload some iOS 27 wallpapers from the admin panel.",
                systemName: "iphone"
            )
            .frame(minHeight: 420)
        } else {
            LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                ForEach(viewModel.latestWallpapers) { wallpaper in
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
        }
    }
}

#Preview("Light") {
    HomePreviewHost()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    HomePreviewHost()
        .preferredColorScheme(.dark)
}

private struct HomePreviewHost: View {
    @Namespace private var namespace

    var body: some View {
        NavigationStack {
            HomeView(namespace: namespace)
                .navigationTitle("iOS 27")
                .toolbarTitleDisplayMode(.inlineLarge)
                .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}
