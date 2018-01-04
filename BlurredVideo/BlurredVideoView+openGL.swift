import UIKit
import AVKit
import GLKit

class BlurredVideoView: GLKView {
    var player: AVPlayer!
    var output: AVPlayerItemVideoOutput!
    var item: AVPlayerItem!
    var displayLink: CADisplayLink!

    var ciContext: CIContext!

    var blurRadius: Double = 6.0

    var image: CIImage? {
        didSet {
            display()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    func setup() {
        guard let eaglContext = EAGLContext(api: .openGLES3) else {
            fatalError("Unable to get OpenGL context!")
        }

        context = eaglContext
        ciContext = CIContext(eaglContext: context, options: [kCIContextWorkingColorSpace : NSNull()])

        enableSetNeedsDisplay = false
        isOpaque = true
    }

    func play(stream: URL, withBlur blur: Double? = nil) {
        if let blur = blur {
            blurRadius = blur
        }

        item = AVPlayerItem(url: stream)
        output = AVPlayerItemVideoOutput()
        item.add(output)

        player = AVPlayer(playerItem: item)

        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkUpdated(link:)))
        displayLink.preferredFramesPerSecond = 20
        displayLink.add(to: .main, forMode: .commonModes)

        player.play()
    }

    func stop() {
        player.rate = 0
        displayLink.remove(from: .main, forMode: .commonModes)
    }

    @objc func displayLinkUpdated(link: CADisplayLink) {
        let time = output.itemTime(forHostTime: CACurrentMediaTime())
        guard output.hasNewPixelBuffer(forItemTime: time),
            let pixbuf = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) else { return }
        let rect = CGRect(origin: .zero, size: CGSize(width: CVPixelBufferGetWidth(pixbuf), height: CVPixelBufferGetHeight(pixbuf)))
        let baseImg = CIImage(cvImageBuffer: pixbuf)
        let blurImg = baseImg.clampedToExtent().applyingGaussianBlur(sigma: blurRadius).cropped(to: rect)
        image = blurImg
    }

    override func draw(_ rect: CGRect) {
        guard let image = image else { return }
        let scale = window?.screen.scale ?? 1.0
        let destRect = rect.applying(CGAffineTransform(scaleX: scale, y: scale))

        ciContext.draw(image, in: destRect, from: image.extent)
    }
}
