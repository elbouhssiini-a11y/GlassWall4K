//
//  IntroVideoPlayer.swift
//  GlassWall4K
//

import AVFoundation
import SwiftUI

/// One-shot fullscreen video for intro. Calls `onFinished` when playback ends,
/// hits `maxSeconds`, or fails.
struct IntroVideoPlayer: UIViewRepresentable {
    let url: URL
    /// 0 = play until natural end.
    var maxSeconds: Int = 0
    var onFinished: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    func makeUIView(context: Context) -> IntroPlayerView {
        let view = IntroPlayerView()
        view.play(
            url: url,
            maxSeconds: maxSeconds,
            onFinished: context.coordinator.finish
        )
        return view
    }

    func updateUIView(_ uiView: IntroPlayerView, context: Context) {
        context.coordinator.onFinished = onFinished
        uiView.play(
            url: url,
            maxSeconds: maxSeconds,
            onFinished: context.coordinator.finish
        )
    }

    static func dismantleUIView(_ uiView: IntroPlayerView, coordinator: Coordinator) {
        uiView.tearDown()
    }

    final class Coordinator {
        var onFinished: () -> Void
        private var didFinish = false

        init(onFinished: @escaping () -> Void) {
            self.onFinished = onFinished
        }

        func finish() {
            guard !didFinish else { return }
            didFinish = true
            onFinished()
        }
    }
}

final class IntroPlayerView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var player: AVPlayer?
    private var currentURL: URL?
    private var currentMaxSeconds: Int = 0
    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var durationTask: Task<Void, Never>?
    private var onFinished: (() -> Void)?
    private var didFinish = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = true
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = UIColor.clear.cgColor
        layer.addSublayer(playerLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func play(url: URL, maxSeconds: Int, onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
        let capped = max(0, min(120, maxSeconds))

        if currentURL == url, currentMaxSeconds == capped, player != nil {
            player?.play()
            return
        }

        tearDown()
        didFinish = false
        currentURL = url
        currentMaxSeconds = capped

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause
        self.player = player
        playerLayer.player = player

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.finish()
        }

        statusObservation = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self.playerLayer.isHidden = false
                    player.play()
                    self.scheduleStop(for: item, maxSeconds: capped)
                case .failed:
                    self.finish()
                default:
                    break
                }
            }
        }

        player.play()
    }

    private func scheduleStop(for item: AVPlayerItem, maxSeconds: Int) {
        durationTask?.cancel()
        durationTask = Task { @MainActor [weak self] in
            let natural = try? await item.asset.load(.duration).seconds
            let full = (natural?.isFinite == true) ? max(0.5, natural!) : 8

            let limit: Double
            if maxSeconds > 0 {
                limit = min(full, Double(maxSeconds))
            } else {
                limit = full
            }

            try? await Task.sleep(for: .seconds(limit + 0.05))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        durationTask?.cancel()
        player?.pause()
        onFinished?()
    }

    func tearDown() {
        durationTask?.cancel()
        durationTask = nil
        statusObservation?.invalidate()
        statusObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
        playerLayer.player = nil
        currentURL = nil
        currentMaxSeconds = 0
    }
}
