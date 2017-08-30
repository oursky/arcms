//
//  ViewController.swift
//  ARCMS
//
//  Created by siuming on 28/8/2017.
//  Copyright © 2017年 Oursky Limited. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate, QRCodeTrackerDelegate {

    @IBOutlet var sceneView: ARSCNView!
    let tracker = QRCodeTracker()
    var isFetching = false {
        didSet {
            // if value changes
            if isFetching != oldValue {
                if isFetching {
                    // show spinner
                    print("show pinner")
                } else {
                    // dismiss spinner
                    print("dismiss pinner")
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.session.delegate = tracker
        tracker.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    func qrCodesDidUpdate(_ barcodes: [VNBarcodeObservation]) {
        print(barcodes.map({ $0.payloadStringValue ?? "" }))
    }
}
