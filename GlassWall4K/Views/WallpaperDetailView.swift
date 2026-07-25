//
//  WallpaperDetailView.swift
//  GlassWall4K
//

import SwiftUI

struct WallpaperDetailView: View {
    let wallpapers: [Wallpaper]
    let namespace: Namespace.ID

    @Environment(\.dismiss) private var dismiss
    @State private var currentID: String
    @State private var scrollID: String?
    @State private var settledID: String
    @State private var allowHeavyMedia = false
    @State private var viewModel: WallpaperDetailViewModel
    @State private var showsLockScreen = false
    @State private var settleTask: Task<Void, Never>?

    init(wallpaper: Wallpaper, wallpapers: [Wallpaper]? = nil, namespace: Namespace.ID) {
        let list = (wallpapers?.isEmpty == false) ? wallpapers! : [wallpaper]
        self.wallpapers = list
        self.namespace = namespace
        _currentID = State(initialValue: wallpaper.id)
        _scrollID = State(initialValue: wallpaper.id)
        _settledID = State(initialValue: wallpaper.id)
        _viewModel = State(initialValue: WallpaperDetailViewModel(wallpaper: wallpaper))
    }

    private var currentWallpaper: Wallpaper {
        wallpapers.first(where: { $0.id == currentID }) ?? viewModel.wallpaper
    }

    private var settledWallpaper: Wallpaper {
        wallpapers.first(where: { $0.id == settledID }) ?? currentWallpaper
    }

    /// Same catalog first, then the rest — keeps the strip useful in mixed lists.
    private var relatedWallpapers: [Wallpaper] {
        let current = currentWallpaper
        let sameCategory = wallpapers.filter { $0.category == current.category }
        if sameCategory.count > 1 {
            return sameCategory
        }
        return wallpapers
    }

    var body: some View {
        ZStack {
            // Static thumb bleed for status-bar gap — updates only after swipe settles.
            CachedRemoteImage(url: settledWallpaper.thumbnailURL)
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            GeometryReader { geo in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(wallpapers) { item in
                            wallpaperPage(item, size: geo.size)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .id(item.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $scrollID)
                .scrollIndicators(.hidden)
            }
            .ignoresSafeArea(.all)

            if showsLockScreen {
                LockScreenOverlay()
                    .transition(.opacity)
            }

            if !showsLockScreen {
                VStack(spacing: 0) {
                    FloatingDetailToolbar(onBack: { dismiss() })

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

                    RelatedWallpapersStrip(
                        wallpapers: relatedWallpapers,
                        selectedID: currentID
                    ) { wallpaper in
                        selectWallpaper(wallpaper.id, animated: true)
                    }

                    WallpaperDetailPanel(
                        isFavorite: viewModel.isFavorite,
                        isDownloading: viewModel.isDownloading,
                        isShareBusy: viewModel.isSharing,
                        onFavorite: { viewModel.toggleFavorite() },
                        onShare: { Task { await viewModel.share() } },
                        onDownload: { Task { await viewModel.download() } }
                    )
                }
                .transition(.opacity)
            }
        }
        .background(Color.black.ignoresSafeArea(.all))
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .modifier(ZoomNavigationTransitionModifier(id: currentWallpaper.id, namespace: namespace))
        .sheet(isPresented: $viewModel.isSharePresented) {
            ActivityShareSheet(items: viewModel.shareItems)
        }
        .onChange(of: scrollID) { _, newID in
            guard let newID, newID != currentID else { return }
            currentID = newID
            scheduleSettle(for: newID)
        }
        .onAppear {
            allowHeavyMedia = true
            prefetchNeighbors(around: currentID)
        }
        .onDisappear {
            settleTask?.cancel()
            allowHeavyMedia = false
        }
        .statusBarHidden(showsLockScreen)
    }

    private func wallpaperPage(_ wallpaper: Wallpaper, size: CGSize) -> some View {
        let isSettledActive = allowHeavyMedia && wallpaper.id == settledID

        return ZStack {
            LinearGradient(
                colors: wallpaper.placeholderGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Thumb only while swiping — keeps paging light.
            CachedRemoteImage(url: wallpaper.thumbnailURL)
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()

            if isSettledActive {
                if let videoURL = wallpaper.videoURL {
                    LoopingVideoPlayer(url: videoURL, isActive: true)
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .transition(.opacity)
                } else {
                    CachedRemoteImage(url: wallpaper.imageURL)
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .transition(.opacity)
                }
            }

            LinearGradient(
                colors: [
                    .black.opacity(showsLockScreen ? 0.12 : 0),
                    .clear,
                    .clear,
                    .black.opacity(showsLockScreen ? 0.22 : 0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.22)) {
                showsLockScreen.toggle()
            }
        }
    }

    private func selectWallpaper(_ id: String, animated: Bool) {
        if animated {
            withAnimation(.easeInOut(duration: 0.2)) {
                scrollID = id
                currentID = id
            }
        } else {
            scrollID = id
            currentID = id
        }
        scheduleSettle(for: id)
    }

    private func scheduleSettle(for id: String) {
        settleTask?.cancel()
        // Keep only thumbs while paging; attach full image / video after the scroll rests.
        allowHeavyMedia = false

        settleTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled, currentID == id else { return }
            let previousSettled = settledID
            settledID = id
            allowHeavyMedia = true
            if viewModel.wallpaper.id != id,
               let next = wallpapers.first(where: { $0.id == id }) {
                viewModel = WallpaperDetailViewModel(wallpaper: next)
            }
            showsLockScreen = false
            prefetchNeighbors(around: id)

            if previousSettled != id {
                AdsManager.shared.recordSwipeAndMaybeShowInterstitial(
                    from: AdsPresenter.topViewController()
                )
            }
        }
    }

    private func prefetchNeighbors(around id: String) {
        guard let index = wallpapers.firstIndex(where: { $0.id == id }) else { return }
        var urls: [URL] = [wallpapers[index].thumbnailURL]
        if index > 0 { urls.append(wallpapers[index - 1].thumbnailURL) }
        if index + 1 < wallpapers.count { urls.append(wallpapers[index + 1].thumbnailURL) }

        let unique = Array(Set(urls))
        Task.detached(priority: .utility) {
            for url in unique {
                _ = try? await MediaCache.loadImage(from: url)
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
