//
//  ViewController.swift
//  BlurredVideo
//
//  Created by Greg Niemann on 11/13/17.
//  Copyright (c) 2017 WillowTree, Inc. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet var slider: UISlider!
    @IBOutlet var blurLabel: UILabel!
    @IBOutlet var videoView: BlurredVideoMPSView!
    
    let streamURL = URL(string: "https://bitdash-a.akamaihd.net/content/MI201109210084_1/m3u8s/f08e80da-bf1d-4e3d-8899-f0f6155f6efa.m3u8")!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let sliderHeight = view.bounds.height - 2 * (blurLabel.bounds.height + 10)
        slider.widthAnchor.constraint(equalToConstant: sliderHeight).isActive = true
        slider.transform = CGAffineTransform(rotationAngle: .pi / -2)
        
        videoView.play(stream: streamURL, withBlur: Double(slider.value)) {
            self.videoView.player.isMuted = true
        }
    }
    
    @IBAction func onSliderChange(_ sender: UISlider) {
        videoView.blurRadius = Double(sender.value)
    }
}

