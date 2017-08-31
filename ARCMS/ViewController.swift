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

class ViewController: UIViewController, ARSCNViewDelegate, QRCodesTrackerDelegate {

    @IBOutlet var sceneView: ARSCNView!
    let tracker = QRCodesTracker()
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
    
    func qrCodesDidUpdate(persisted: [VNBarcodeObservation], removed: [VNBarcodeObservation], added: [VNBarcodeObservation], at frame: ARFrame) {
        DispatchQueue.main.async {
            var previousQRCodes = Array(self.currentNodes.keys)
            
            print("previousQRCodes \(previousQRCodes.map { $0.payloadStringValue ?? ""})")
            print("persisted \(persisted.map { $0.payloadStringValue ?? ""})")
            print("removed \(removed.map { $0.payloadStringValue ?? ""})")
            print("added \(added.map { $0.payloadStringValue ?? ""})")
            
            // update persisted position
            for qrCode in persisted {
                // hit test success
                if let result = self.hitTest(against: qrCode, at: frame) {
                    // find out old key
                    if let index = previousQRCodes.index(where: { $0 == qrCode }) {
                        let key = previousQRCodes[index]
                        // find out corresponding node
                        if let node = self.currentNodes[key] {
                            // update position
                            node.transform = SCNMatrix4(result.worldTransform)
                        }
                        // remove to avoid double counting
                        previousQRCodes.remove(at: index)
                    }
                }
            }
            // remove from parent
            for qrCode in removed {
                if let index = previousQRCodes.index(where: { $0 == qrCode }) {
                    let key = previousQRCodes[index]
                    if let node = self.currentNodes[key] {
                        node.removeFromParentNode()
                        self.currentNodes[key] = nil
                    }
                    previousQRCodes.remove(at: index)
                }
            }
            for qrCode in added {
                // hit test
                if let result = self.hitTest(against: qrCode, at: frame) {
                    // fetch
                    let cube = SCNNode(geometry: SCNBox(width: 0.02, height: 0.02, length: 0.02, chamferRadius: 0.0))
                    // add to session and position and record down
                    self.sceneView.scene.rootNode.addChildNode(cube)
                    cube.transform = SCNMatrix4(result.worldTransform)
                    self.currentNodes[qrCode] = cube
                }
            }
            
            let newQRCodes = Array(self.currentNodes.keys)
            print("newQRCodes \(newQRCodes.map { $0.payloadStringValue ?? ""})")
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
