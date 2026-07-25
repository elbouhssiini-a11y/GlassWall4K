//
//  IntroView.swift
//  GlassWall4K
//

import SwiftUI

struct IntroView: View {
    let settings: AppAdSettings
    var onContinue: () -> Void

    @State private var playURL: URL?
    @State private var isLoadingVideo = false
    @State private var didContinue = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            mediaLayer
                .ignoresSafeArea()

            if isLoadingVideo, playURL == nil {
                ProgressView()
                    .tint(.white)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .task(id: settings.introVideoURL) {
            await prepareVideo()
        }
    }

    @ViewBuilder
    private var mediaLayer: some View {
        if let imageURL = settings.resolvedIntroImageURL {
            CachedRemoteImage(url: imageURL)
        }

        if let playURL {
            IntroVideoPlayer(url: playURL, maxSeconds: settings.introMaxSeconds) {
                finish()
            }
        } else if settings.resolvedIntroVideoURL == nil, settings.resolvedIntroImageURL == nil {
            Color.black
        }
    }

    private func finish() {
        guard !didContinue else { return }
        didContinue = true
        onContinue()
    }

    private func prepareVideo() async {
        guard let remote = settings.resolvedIntroVideoURL else {
            playURL = nil
            isLoadingVideo = false
            try? await Task.sleep(for: .milliseconds(500))
            finish()
            return
        }

        isLoadingVideo = true
        defer { isLoadingVideo = false }

        if let local = try? await MediaCache.cachedFileURL(for: remote) {
            playURL = local
            return
        }

        playURL = remote
    }
}
