//
//  SearchView.swift
//  GlassWall4K
//

import SwiftUI

/// 4K Wallpapers tab (legacy filename kept for Xcode project references).
struct SearchView: View {
    let namespace: Namespace.ID

    @State private var viewModel = SearchViewModel(category: .fourKWallpapers)

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
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if let errorMessage = viewModel.errorMessage {
            ErrorStateView(message: errorMessage) {
                Task { await viewModel.load() }
            }
            .frame(minHeight: 420)
        } else if viewModel.isLoading && viewModel.results.isEmpty {
            LoadingGridView()
                .frame(minHeight: 420)
        } else if viewModel.results.isEmpty {
            EmptyStateView(
                title: "No 4K Wallpapers",
                message: "Upload some 4K Wallpapers from the admin panel.",
                systemName: "4k.tv"
            )
            .frame(minHeight: 420)
        } else {
            LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                ForEach(viewModel.results) { wallpaper in
                    NavigationLink(value: wallpaper) {
                        GridWallpaperCard(
                            wallpaper: wallpaper,
                            namespace: namespace,
                            cornerRadius: 24
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
    SearchPreviewHost()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    SearchPreviewHost()
        .preferredColorScheme(.dark)
}

private struct SearchPreviewHost: View {
    @Namespace private var namespace

    var body: some View {
        NavigationStack {
            SearchView(namespace: namespace)
                .navigationTitle("4K Wallpapers")
                .toolbarTitleDisplayMode(.inlineLarge)
                .navigationDestination(for: Wallpaper.self) { wallpaper in
                    WallpaperDetailView(wallpaper: wallpaper, namespace: namespace)
                }
        }
    }
}
