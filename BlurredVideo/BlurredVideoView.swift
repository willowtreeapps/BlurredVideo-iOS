//
// BlurredVideoView.swift
//
// Created by Greg Niemann on 10/4/17.
// Copyright (c) 2017 WillowTree, Inc. All rights reserved.
//

import UIKit
import AVKit

class BlurredVideoView: UIView {
    var blurRadius: Double = 6.0
    var player: AVPlayer!

    private var output: AVPlayerItemVideoOutput!
    private var displayLink: CADisplayLink!
    private var context: CIContext = CIContext(options: [kCIContextWorkingColorSpace : NSNull()])
    private var playerItemObserver: NSKeyValueObservation?

    func play(stream: URL, withBlur blur: Double? = nil, completion:  (()->Void)? = nil) {
        layer.isOpaque = true
        blurRadius = blur ?? blurRadius

        let item = AVPlayerItem(url: stream)
        output = AVPlayerItemVideoOutput(outputSettings: nil)
        item.add(output)

        playerItemObserver = item.observe(\.status) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            self?.playerItemObserver = nil
            self?.setupDisplayLink()

            self?.player.play()
            completion?()
        }

        player = AVPlayer(playerItem: item)
    }

    func stop() {
        player.rate = 0
        displayLink.invalidate()
    }

    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkUpdated(link:)))
        displayLink.preferredFramesPerSecond = 20
        displayLink.add(to: .main, forMode: .commonModes)
    }

    @objc private func displayLinkUpdated(link: CADisplayLink) {
        let time = output.itemTime(forHostTime: CACurrentMediaTime())
        guard output.hasNewPixelBuffer(forItemTime: time),
              let pixbuf = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) else { return }
        let baseImg = CIImage(cvImageBuffer: pixbuf)
        let blurImg = baseImg.clampedToExtent().applyingGaussianBlur(sigma: blurRadius).cropped(to: baseImg.extent)

        guard let cgImg = context.createCGImage(blurImg, from: blurImg.extent) else { return }

        layer.contents = cgImg
    }
}
