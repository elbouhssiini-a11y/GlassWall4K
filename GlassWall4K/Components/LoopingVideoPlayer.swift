//
//  LoopingVideoPlayer.swift
//  GlassWall4K
//

import AVFoundation
import AVKit
import SwiftUI

struct LoopingVideoPlayer: UIViewRepresentable {
    let url: URL
    var isActive: Bool = true
    /// When false, plays once and calls `onEnded`.
    var loops: Bool = true
    var onEnded: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onEnded: onEnded)
    }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.configure(url: url, isActive: isActive, loops: loops, onEnded: context.coordinator.fireEnded)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        context.coordinator.onEnded = onEnded
        uiView.configure(url: url, isActive: isActive, loops: loops, onEnded: context.coordinator.fireEnded)
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
        uiView.tearDown()
    }

    final class Coordinator {
        var onEnded: (() -> Void)?

        init(onEnded: (() -> Void)?) {
            self.onEnded = onEnded
        }

        func fireEnded() {
            onEnded?()
        }
    }
}

final class PlayerContainerView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var looper: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?
    private var currentURL: URL?
    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var isActive = true
    private var loops = true
    private var onEnded: (() -> Void)?
    private var didFireEnded = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = true
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.isHidden = true
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

    func configure(url: URL, isActive: Bool, loops: Bool = true, onEnded: (() -> Void)? = nil) {
        self.isActive = isActive
        self.loops = loops
        self.onEnded = onEnded

        if !isActive {
            pauseOnly()
            return
        }

        if currentURL == url, queuePlayer != nil {
            queuePlayer?.play()
            return
        }

        tearDown()
        currentURL = url
        didFireEnded = false

        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ])
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 1

        let player = AVQueuePlayer(playerItem: item)
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = false
        player.actionAtItemEnd = loops ? .none : .pause

        if loops {
            looper = AVPlayerLooper(player: player, templateItem: item)
        } else {
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.handleEnded()
            }
        }

        queuePlayer = player
        playerLayer.player = player

        statusObservation = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                if item.status == .readyToPlay {
                    self.playerLayer.isHidden = false
                    if self.isActive {
                        player.play()
                    }
                } else if item.status == .failed, !self.loops {
                    self.handleEnded()
                }
            }
        }

        player.play()
    }

    private func handleEnded() {
        guard !didFireEnded else { return }
        didFireEnded = true
        onEnded?()
    }

    private func pauseOnly() {
        queuePlayer?.pause()
        playerLayer.isHidden = true
    }

    func tearDown() {
        statusObservation?.invalidate()
        statusObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        queuePlayer?.pause()
        looper?.disableLooping()
        looper = nil
        queuePlayer = nil
        playerLayer.player = nil
        playerLayer.isHidden = true
        currentURL = nil
        didFireEnded = false
    }
}
