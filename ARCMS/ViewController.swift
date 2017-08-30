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
    var currentNodes = [VNBarcodeObservation: SCNNode]()
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
    
    func qrCodesDidUpdate(_ qrCodes: [VNBarcodeObservation], at frame: ARFrame) {
        DispatchQueue.main.async {
            var oldQRCodes = Array(self.currentNodes.keys)
            print("oldQRCodes \(oldQRCodes.map({ $0.payloadStringValue ?? "" }))")
            for qrCode in qrCodes {
                if let hitTestResult = self.hitTest(against: qrCode, at: frame) {
                    // case persisted (in new and in old)
                    if let i = oldQRCodes.index(where: { $0.payloadStringValue == qrCode.payloadStringValue }) {
                        print("+persisted \(oldQRCodes[i].payloadStringValue ?? "")")
                        // update node transform
                        let key = oldQRCodes[i]
                        self.currentNodes[key]?.transform = SCNMatrix4(hitTestResult.worldTransform)
                        // remove to prevent double counting
                        oldQRCodes.remove(at: i)
                        continue
                    // case newly found (in new not in old)
                    } else {
                        print("+newly found \(qrCode.payloadStringValue ?? "")")
                        // load model
                        let cube = SCNBox(width: 0.02, height: 0.02, length: 0.02, chamferRadius: 0.0)
                        let node = SCNNode(geometry: cube)
                        self.sceneView.scene.rootNode.addChildNode(node)
                        self.currentNodes[qrCode] = node
                    }
                } else {
                    // if hit testing fails, treat the QR code is not detected
                    print("-hit testing fails")
                }
            }
            // case no longer found (in old not in new)
            for (index, oldQRCode) in oldQRCodes.enumerated() {
                if !qrCodes.contains(where: { $0.payloadStringValue == oldQRCode.payloadStringValue }) {
                    print("-no longer found \(oldQRCode.payloadStringValue ?? "")")
                    let key = oldQRCodes[index]
                    self.currentNodes[key]?.removeFromParentNode()
                    self.currentNodes[key] = nil
                }
            }
            print("newQRCodes \(Array(self.currentNodes.keys).map({ $0.payloadStringValue ?? "" }))")
        }
    }
    
    func hitTest(against barcode: VNBarcodeObservation, at frame: ARFrame) -> ARHitTestResult? {
        // right click -> "Jump to Definition" to read docs about coordinates
        var rect = barcode.boundingBox
        // flip coordinates to meet hit testing requirement on origin, ref: https://goo.gl/m6VNDn
        rect = rect.applying(CGAffineTransform(scaleX: 1, y: -1))
        rect = rect.applying(CGAffineTransform(translationX: 0, y: 1))
        let midpoint = CGPoint(x: rect.midX, y: rect.midY)
        let hitTestResults = frame.hitTest(midpoint, types: [.featurePoint] )
        return hitTestResults.first
    }
}
