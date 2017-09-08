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
import SKYKit

class ViewController: UIViewController, ARSCNViewDelegate, QRCodesTrackerDelegate {

    @IBOutlet var sceneView: ARSCNView!
    let tracker = QRCodesTracker()
    var store = [QRCode: SCNNode]()
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
        let skygear = SKYContainer.default()
        skygear.auth.signupAnonymously(completionHandler: { _, error in
            if error != nil {
                print("Signup Error: \(error!.localizedDescription)")
                return
            }
            // Start the ARSession.
            self.sceneView.session.run(configuration)
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    func qrCodesDidUpdate(_ QRCodes: Set<QRCode>, at frame: ARFrame) {
        print("before \(Set(store.keys).map { $0.payload })")
        let accumulatedQRCodes = Set(store.keys)
        // intersection() will pick up elements in LHS by testing in playgroud
        // so put newer QR codes on LHS to get latest position
        let persisted = QRCodes.intersection(accumulatedQRCodes)
        let discovered = QRCodes.subtracting(accumulatedQRCodes)
        DispatchQueue.main.async {
            for QRCode in persisted {
                // if hit test success
                if let result = frame.hitTest(QRCode.midpoint, types: [.featurePoint] ).first {
                    // find out the node that the QR code is representing
                    if let node = self.store[QRCode] {
                        // update position
                        node.transform = SCNMatrix4(result.worldTransform)
                    }
                }
            }
            for QRCode in discovered {
                // if hit test success
                if let result = frame.hitTest(QRCode.midpoint, types: [.featurePoint] ).first {
                    // fetch QRCode.payload model
                    let cube = SCNNode(geometry: SCNBox(width: 0.02, height: 0.02, length: 0.02, chamferRadius: 0.0))
                    // add to session, position and record down
                    self.sceneView.scene.rootNode.addChildNode(cube)
                    cube.transform = SCNMatrix4(result.worldTransform)
                    self.store[QRCode] = cube
                }
            }
            print("after \(Set(self.store.keys).map { $0.payload })")
        }
    }
}
