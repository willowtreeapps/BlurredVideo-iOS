//
//  BlurredVideoMetalView.swift
//  BlurredVideo
//
//  Created by Greg Niemann on 11/15/17.
//  Copyright © 2017 Greg Niemann. All rights reserved.
//

import UIKit
import MetalKit
import AVKit

class BlurredVideoMetalView: MTKView {
    var blurRadius: Double = 6.0
    var player: AVPlayer!

    private var output: AVPlayerItemVideoOutput!
    private var displayLink: CADisplayLink!
    private var playerItemObserver: NSKeyValueObservation?

    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private lazy var commandQueue: MTLCommandQueue? = {
        return self.device!.makeCommandQueue()
    }()

    private lazy var content: CIContext = {
        return CIContext(mtlDevice: self.device!, options: [kCIContextWorkingColorSpace : NSNull()])
    }()

    private var image: CIImage? {
        didSet {
            draw()
        }
    }

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device ?? MTLCreateSystemDefaultDevice())
        setup()
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        device = MTLCreateSystemDefaultDevice()
        setup()
    }

    private func setup() {
        framebufferOnly = false
        isPaused = false
        enableSetNeedsDisplay = false
    }

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
        image = baseImg.clampedToExtent()
                        .applyingGaussianBlur(sigma: blurRadius)
                        .cropped(to: baseImg.extent)
    }

    override func draw(_ rect: CGRect) {
        guard let image = image,
              let currentDrawable = currentDrawable,
              let commandBuffer = commandQueue?.makeCommandBuffer()
                else {
            return
        }
        let currentTexture = currentDrawable.texture
        let drawingBounds = CGRect(origin: .zero, size: drawableSize)

        let scaleX = drawableSize.width / image.extent.width
        let scaleY = drawableSize.height / image.extent.height
        let scaledImage = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        content.render(scaledImage, to: currentTexture, commandBuffer: commandBuffer, bounds: drawingBounds, colorSpace: colorSpace)

        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}
