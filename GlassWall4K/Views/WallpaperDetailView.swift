//
//  WallpaperDetailView.swift
//  GlassWall4K
//

import SwiftUI

struct WallpaperDetailView: View {
    let wallpaper: Wallpaper
    let namespace: Namespace.ID

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WallpaperDetailViewModel

    private let horizontalInset: CGFloat = 20

    init(wallpaper: Wallpaper, namespace: Namespace.ID) {
        self.wallpaper = wallpaper
        self.namespace = namespace
        _viewModel = State(initialValue: WallpaperDetailViewModel(wallpaper: wallpaper))
    }

    var body: some View {
        ZStack {
            fullScreenPreview
                .ignoresSafeArea()

            VStack(spacing: 0) {
                FloatingDetailToolbar(
                    isFavorite: viewModel.isFavorite,
                    isShareBusy: viewModel.isSharing,
                    onBack: { dismiss() },
                    onFavorite: { viewModel.toggleFavorite() },
                    onShare: { Task { await viewModel.share() } }
                )

                Spacer(minLength: 0)

                if let statusMessage = viewModel.statusMessage {
                    Text(statusMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.45), in: Capsule())
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                WallpaperDetailPanel(
                    isDownloading: viewModel.isDownloading,
                    onDownload: { Task { await viewModel.download() } }
                )
                .padding(.horizontal, horizontalInset)
                .padding(.bottom, 12)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .modifier(ZoomNavigationTransitionModifier(id: wallpaper.id, namespace: namespace))
        .sheet(isPresented: $viewModel.isSharePresented) {
            ActivityShareSheet(items: viewModel.shareItems)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.statusMessage)
        .task {
            AdsManager.shared.recordDetailOpenAndMaybeShowInterstitial(
                from: AdsPresenter.topViewController()
            )
        }
    }

    private var fullScreenPreview: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                LinearGradient(
                    colors: wallpaper.placeholderGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                AsyncImage(url: wallpaper.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    case .failure:
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 80, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.28))
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    @unknown default:
                        EmptyView()
                    }
                }

                LinearGradient(
                    colors: [
                        .black.opacity(0.28),
                        .clear,
                        .clear,
                        .black.opacity(0.35)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}

private struct ZoomNavigationTransitionModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}
