//
//  ViewController.swift
//  ARDemo
//
//  Created by Anson Leung on 11/7/2017.
//  Copyright © 2017 Anson Leung. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    // MARK: ARKit / ARSCNView
    var sceneView: ARSCNView!
    var session = ARSession()
    var sessionConfig: ARSessionConfiguration = ARWorldTrackingSessionConfiguration()

    // MARK: Vision
    var imageRequestHandler: VNSequenceRequestHandler!

    var virtualObject: VirtualObject?

    var lineView: LineView!
    var centerPt: UIView!

    var position: CGPoint? {
        didSet {
            virtualObject?.translateBasedOnScreenPos(position!, instantly: true, infinitePlane: false)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        sceneView = ARSCNView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height))
        sceneView.showsStatistics = true
        sceneView.delegate = self
        session.delegate = self
        sceneView.session = session

        sceneView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sceneView)

        lineView = LineView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height))
        lineView.backgroundColor = .clear
        view.addSubview(lineView)

        centerPt = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        centerPt.backgroundColor = .red
        centerPt.backgroundColor = centerPt.backgroundColor
        centerPt.isHidden = true
        view.addSubview(centerPt)

        view.setNeedsUpdateConstraints()

//        print("view \(view.frame)")

        // Non-view setup
        imageRequestHandler = VNSequenceRequestHandler()

        if let camera = sceneView.pointOfView?.camera {
            camera.wantsHDR = true
            camera.wantsExposureAdaptation = true
            camera.exposureOffset = -1
            camera.minimumExposure = -1
        }

        DispatchQueue.global().async {
            self.virtualObject = Cup()
            self.virtualObject?.loadModel()
            self.virtualObject?.viewController = self
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Prevent the screen from being dimmed after a while.
        UIApplication.shared.isIdleTimerDisabled = true

        // Start the ARSession.
        restartPlaneDetection()
    }

    override func updateViewConstraints() {
//        let viewMargins = view.layoutMarginsGuide
//        let sceneViewMargins = sceneView.layoutMarginsGuide
//        sceneViewMargins.topAnchor.constraint(equalTo: viewMargins.topAnchor, constant: 0).isActive = true
//        sceneViewMargins.bottomAnchor.constraint(equalTo: viewMargins.bottomAnchor, constant: 0).isActive = true
//        sceneViewMargins.leftAnchor.constraint(equalTo: viewMargins.leftAnchor, constant: 0).isActive = true
//        sceneViewMargins.rightAnchor.constraint(equalTo: viewMargins.rightAnchor, constant: 0).isActive = true

        super.updateViewConstraints()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidLayoutSubviews() {
//        print(view.frame)
//        print(sceneView.frame)
    }

    // MARK: Planes
    func restartPlaneDetection () {

        // configure session
        if let worldSessionConfig = sessionConfig as? ARWorldTrackingSessionConfiguration {
            worldSessionConfig.planeDetection = .horizontal
            session.run(worldSessionConfig, options: [.resetTracking, .removeExistingAnchors])
        }

    }

    // MARK: ARSessionDelegate
    var counter: Int = 0
    // check once after this interval
    var checkInterval = 5

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        counter = (counter + 1) % checkInterval

        if counter == 0 {
            print("searching for QR code")
            let requests = [VNDetectBarcodesRequest(completionHandler: completionHandler)]
            guard let _ = try? imageRequestHandler.perform(requests, on: frame.capturedImage) else {
                print("fail to perform barcode-request")
                return
            }
        }
    }

    func completionHandler(request: VNRequest, error: Error?) {
        if error != nil { print(error as Any) }
        //        print("request \(request)")

        guard let results = request.results as? [VNBarcodeObservation] else {
            print("[VC] no results found")
            return
        }

        if results.count == 0 { showIndicator(false) } else { showIndicator(true) }

        // Loopm through the found results
        for result in results {

            // Cast the result to a barcode-observation
            if let barcode = result as? VNBarcodeObservation {

                // Print barcode-values
                print("Symbology: \(barcode.symbology.rawValue)")

                if let desc = barcode.barcodeDescriptor as? CIQRCodeDescriptor {
                    print("errorCorrectedPayload \(desc.errorCorrectedPayload.count)")
                    let content = String(data: desc.errorCorrectedPayload, encoding: .utf8)
                    print("Description: \(desc.description)")

                    // FIXME: This currently returns nil. I did not find any docs on how to encode the data properly so far.
                    print("Payload: \(String(describing: content))")
                    print("Error-Correction-Level: \(desc.errorCorrectionLevel)")
                    print("Symbol-Version: \(desc.symbolVersion)")
                    print("Bounding box: \(barcode.boundingBox)")

                    let topLeft = CGPoint(x:barcode.topLeft.y*view.frame.width, y: barcode.topLeft.x*view.frame.height)
                    let topRight = CGPoint(x: barcode.topRight.y*view.frame.width, y: barcode.topRight.x*view.frame.height)
                    let bottomRight = CGPoint(x: barcode.bottomRight.y*view.frame.width, y: barcode.bottomRight.x*view.frame.height)
                    let bottomLeft = CGPoint(x: barcode.bottomLeft.y*view.frame.width, y: barcode.bottomLeft.x*view.frame.height)

                    print("Points \(topLeft) \(topRight) \(bottomRight) \(bottomLeft)")

                    let pts = [topLeft, topRight, bottomRight, bottomLeft]
                    lineView.setPoints(pts)

                    let centroid = Utilities.intersection(u1: topLeft, u2: bottomRight, v1: topRight, v2: bottomLeft)
                    //                    let centroid = Utilities.getIntersectionOfLines(line1: (topLeft, bottomRight), line2: (topRight, bottomLeft))
                    print("centroid \(centroid)")
                    centerPt.frame = CGRect(x: centroid.x, y: centroid.y, width: 5, height: 5)

                    position = centroid
                }
            }
        }
    }

    func showIndicator(_ show: Bool) {
        lineView.isHidden = !show
        centerPt.isHidden = !show
    }

    // MARK: Virutal Object Manipulation
    func resetVirtualObject() {
        guard (virtualObject != nil) else { return }
        virtualObject?.unloadModel()
        virtualObject?.removeFromParentNode()
        virtualObject = nil
    }

    func worldPositionFromScreenPosition(_ position: CGPoint,
                                         objectPos: SCNVector3?,
                                         infinitePlane: Bool = false) -> (position: SCNVector3?, planeAnchor: ARPlaneAnchor?, hitAPlane: Bool) {

        // -------------------------------------------------------------------------------
        // 1. Always do a hit test against exisiting plane anchors first.
        //    (If any such anchors exist & only within their extents.)

        let planeHitTestResults = sceneView.hitTest(position, types: .existingPlaneUsingExtent)
        if let result = planeHitTestResults.first {

            print("Successfully hit test with anchor")

            let planeHitTestPosition = SCNVector3.positionFromTransform(result.worldTransform)
            let planeAnchor = result.anchor

            // Return immediately - this is the best possible outcome.
            return (planeHitTestPosition, planeAnchor as? ARPlaneAnchor, true)
        }

        // -------------------------------------------------------------------------------
        // 2. Collect more information about the environment by hit testing against
        //    the feature point cloud, but do not return the result yet.

        var featureHitTestPosition: SCNVector3?
        var highQualityFeatureHitTestResult = false

        let highQualityfeatureHitTestResults = sceneView.hitTestWithFeatures(position, coneOpeningAngleInDegrees: 18, minDistance: 0.2, maxDistance: 2.0)

        if !highQualityfeatureHitTestResults.isEmpty {

            print("Successfully hit test with feature")

            let result = highQualityfeatureHitTestResults[0]
            featureHitTestPosition = result.position
            highQualityFeatureHitTestResult = true
        }

        // -------------------------------------------------------------------------------
        // 3. If desired or necessary (no good feature hit test result): Hit test
        //    against an infinite, horizontal plane (ignoring the real world).

        if (infinitePlane || !highQualityFeatureHitTestResult) {

            print("Successfully hit test with infinite, horizontal plane")

            let pointOnPlane = objectPos ?? SCNVector3Zero

            let pointOnInfinitePlane = sceneView.hitTestWithInfiniteHorizontalPlane(position, pointOnPlane)
            if pointOnInfinitePlane != nil {
                return (pointOnInfinitePlane, nil, true)
            }
        }

        // -------------------------------------------------------------------------------
        // 4. If available, return the result of the hit test against high quality
        //    features if the hit tests against infinite planes were skipped or no
        //    infinite plane was hit.

        if highQualityFeatureHitTestResult {
            return (featureHitTestPosition, nil, false)
        }

        // -------------------------------------------------------------------------------
        // 5. As a last resort, perform a second, unfiltered hit test against features.
        //    If there are no features in the scene, the result returned here will be nil.

        let unfilteredFeatureHitTestResults = sceneView.hitTestWithFeatures(position)
        if !unfilteredFeatureHitTestResults.isEmpty {

            print("Successfully commit unfiltered hit test")

            let result = unfilteredFeatureHitTestResults[0]
            return (result.position, nil, false)
        }

        print("Fail to complete any hit test")
        return (nil, nil, false)
    }

    var recentVirtualObjectDistances = [CGFloat]()

    func setNewVirtualObjectPosition(_ pos: SCNVector3) {

        // in case you want to limit the distance of the object from the camera, you may these codes

//        guard let object = virtualObject, let cameraTransform = sceneView.session.currentFrame?.camera.transform else {
//            return
//        }

//                recentVirtualObjectDistances.removeAll()

//        let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
//        let cameraToPosition = pos - cameraWorldPos

        // Limit the distance of the object from the camera to a maximum of 10 meters.
//                cameraToPosition.setMaximumLength(10)

//        object.position = cameraWorldPos + cameraToPosition

        guard let object = virtualObject else {
            return
        }

        recentVirtualObjectDistances.removeAll()

        object.position = pos

        if object.parent == nil {
            sceneView.scene.rootNode.addChildNode(object)
        }
    }

    func updateVirtualObjectPosition(_ pos: SCNVector3, _ filterPosition: Bool) {
        guard let object = virtualObject else {
            return
        }

        guard let cameraTransform = session.currentFrame?.camera.transform else {
            return
        }

        let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
        var cameraToPosition = pos - cameraWorldPos

        // Limit the distance of the object from the camera to a maximum of 10 meters.
//        cameraToPosition.setMaximumLength(10)

        // Compute the average distance of the object from the camera over the last ten
        // updates. If filterPosition is true, compute a new position for the object
        // with this average. Notice that the distance is applied to the vector from
        // the camera to the content, so it only affects the percieved distance of the
        // object - the averaging does _not_ make the content "lag".
        let hitTestResultDistance = CGFloat(cameraToPosition.length())

        recentVirtualObjectDistances.append(hitTestResultDistance)
        recentVirtualObjectDistances.keepLast(10)

        if filterPosition {
            let averageDistance = recentVirtualObjectDistances.average!

            cameraToPosition.setLength(Float(averageDistance))
            let averagedDistancePos = cameraWorldPos + cameraToPosition

            object.position = averagedDistancePos
        } else {
            object.position = cameraWorldPos + cameraToPosition
        }
    }

    func moveVirtualObjectToPosition(_ pos: SCNVector3?, _ instantly: Bool, _ filterPosition: Bool) {

        guard let newPosition = pos else {
            if virtualObject == nil {
                resetVirtualObject()
            }
            return
        }

        if instantly {
            setNewVirtualObjectPosition(newPosition)
        } else {
            updateVirtualObjectPosition(newPosition, filterPosition)
        }
    }

}
