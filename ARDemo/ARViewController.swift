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

class ARViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    // MARK: ARKit / ARSCNView
    var sceneView: ARSCNView!
    var session = ARSession()
    var sessionConfig: ARSessionConfiguration = ARWorldTrackingSessionConfiguration()

    // MARK: Vision
    var imageRequestHandler: VNSequenceRequestHandler!

    var virtualObject: VirtualObject?

    var lineView: LineView!
    var centerPt: UIView!

    // MARK: Core Image
    var qrDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil)

//    var position: CGPoint? {
//        didSet {
//            virtualObject?.translateBasedOnScreenPos(position!, instantly: true, infinitePlane: false)
//        }
//    }

    weak var delegate: ARViewControllerDelegate?

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

        enableEnvironmentMapWithIntensity(25.0)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Prevent the screen from being dimmed after a while.
        UIApplication.shared.isIdleTimerDisabled = true

        // Start the ARSession.
        restartPlaneDetection()
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
    var checkInterval = 10

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        counter = (counter + 1) % checkInterval

        if counter == 0 {
            print("searching for QR code")

            let ciImage = CIImage(cvImageBuffer: frame.capturedImage)
            let retval = extractQRInfo(ciImage: ciImage)
//            print("retval \(retval)")
            guard retval != nil else {
                showIndicator(false)
                return
            }

            showIndicator(true)
            let (corners, message) = retval!
            print("corners \(corners)")
            print("message \(message)")

            delegate?.didReadQRCode(message: message)

            drawFocusSquare(corners: corners)

            let centroid = Utilities.intersection(u1: corners[0], u2: corners[2], v1: corners[1], v2: corners[3])
            print("centroid \(centroid)")
            renderVirtualObjectByScreenPos(screenPos: centroid, virtualObject: virtualObject)
        }
    }

    // input the image and return the four corners (topLeft -> topRight -> bottomRight -> bottomLeft) and the decoded content of the qr code if any
    func extractQRInfo(ciImage: CIImage) -> (corners: [CGPoint], String)? {
        let features = qrDetector?.features(in: ciImage)
        guard features?.count != 0 else { return nil }

        // currently only picking the fist qr code detected
        if let feature = (features?.first) as? CIQRCodeFeature {
//            print("[QR] detected content \(feature.messageString)")
            guard feature.messageString != nil else { return nil }
            let topLeft = CGPoint(x: feature.topLeft.y/2, y: feature.topLeft.x/2)
            let topRight = CGPoint(x: feature.topRight.y/2, y: feature.topRight.x/2)
            let bottomRight = CGPoint(x: feature.bottomRight.y/2, y: feature.bottomRight.x/2)
            let bottomLeft = CGPoint(x: feature.bottomLeft.y/2, y: feature.bottomLeft.x/2)
            let corners = [topLeft, topRight, bottomRight, bottomLeft]
            return (corners, feature.messageString!)
        } else {
            return nil
        }
    }

    func drawFocusSquare(corners: [CGPoint]) {
        let centroid = Utilities.intersection(u1: corners[0], u2: corners[2], v1: corners[1], v2: corners[3])
        centerPt.frame = CGRect(x: centroid.x, y: centroid.y, width: 5, height: 5)
        lineView.setPoints(corners)
    }

    func renderVirtualObjectByScreenPos(screenPos: CGPoint, virtualObject: VirtualObject?) {
        guard virtualObject != nil else {return}

        if !(virtualObject?.modelLoaded)! { virtualObject?.loadModel() }

        virtualObject?.translateBasedOnScreenPos(screenPos, instantly: true, infinitePlane: false)
    }

    // MARK: ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {

            // If light estimation is enabled, update the intensity of the model's lights and the environment map
            if let lightEstimate = self.session.currentFrame?.lightEstimate {
                self.enableEnvironmentMapWithIntensity(lightEstimate.ambientIntensity / 100)
            } else {
                self.enableEnvironmentMapWithIntensity(25)
            }
        }
    }

    func showIndicator(_ show: Bool) {
        lineView.isHidden = !show
        centerPt.isHidden = !show
    }

    // MARK: Virutal Object Manipulation
    func resetVirtualObject() {
        guard virtualObject != nil else { return }
        virtualObject?.unloadModel()
        virtualObject?.removeFromParentNode()
        virtualObject = nil
    }

    struct ARPosition {
        let position: SCNVector3?
        let planeAnchor: ARPlaneAnchor?
        let hitAPlane: Bool
    }

    func worldPositionFromScreenPosition(_ position: CGPoint,
                                         objectPos: SCNVector3?,
                                         infinitePlane: Bool = false) -> ARPosition {

        // -------------------------------------------------------------------------------
        // 1. Always do a hit test against exisiting plane anchors first.
        //    (If any such anchors exist & only within their extents.)

        let planeHitTestResults = sceneView.hitTest(position, types: .existingPlaneUsingExtent)
        if let result = planeHitTestResults.first {

            print("Successfully hit test with anchor")

            let planeHitTestPosition = SCNVector3.positionFromTransform(result.worldTransform)
            let planeAnchor = result.anchor

            // Return immediately - this is the best possible outcome.
            return ARPosition(position: planeHitTestPosition, planeAnchor: planeAnchor as? ARPlaneAnchor, hitAPlane: true)
        }

        // -------------------------------------------------------------------------------
        // 2. Collect more information about the environment by hit testing against
        //    the feature point cloud, but do not return the result yet.

        var featureHitTestPosition: SCNVector3?
        var highQualityFeatureHitTestResult = false

        let highQualityfeatureHitTestResults = sceneView.hitTestWithFeatures(position,
                                                                             coneOpeningAngleInDegrees: 18,
                                                                             minDistance: 0.2,
                                                                             maxDistance: 2.0)

        if !highQualityfeatureHitTestResults.isEmpty {

            print("Successfully hit test with feature")

            let result = highQualityfeatureHitTestResults[0]
            featureHitTestPosition = result.position
            highQualityFeatureHitTestResult = true
        }

        // -------------------------------------------------------------------------------
        // 3. If desired or necessary (no good feature hit test result): Hit test
        //    against an infinite, horizontal plane (ignoring the real world).

        if infinitePlane || !highQualityFeatureHitTestResult {

            print("Successfully hit test with infinite, horizontal plane")

            let pointOnPlane = objectPos ?? SCNVector3Zero

            let pointOnInfinitePlane = sceneView.hitTestWithInfiniteHorizontalPlane(position, pointOnPlane)
            if pointOnInfinitePlane != nil {
                return ARPosition(position: pointOnInfinitePlane, planeAnchor: nil, hitAPlane: true)
            }
        }

        // -------------------------------------------------------------------------------
        // 4. If available, return the result of the hit test against high quality
        //    features if the hit tests against infinite planes were skipped or no
        //    infinite plane was hit.

        if highQualityFeatureHitTestResult {
            return ARPosition(position: featureHitTestPosition, planeAnchor: nil, hitAPlane: false)
        }

        // -------------------------------------------------------------------------------
        // 5. As a last resort, perform a second, unfiltered hit test against features.
        //    If there are no features in the scene, the result returned here will be nil.

        let unfilteredFeatureHitTestResults = sceneView.hitTestWithFeatures(position)
        if !unfilteredFeatureHitTestResults.isEmpty {

            print("Successfully commit unfiltered hit test")

            let result = unfilteredFeatureHitTestResults[0]
            return ARPosition(position: result.position, planeAnchor: nil, hitAPlane: false)
        }

        print("Fail to complete any hit test")
        return ARPosition(position: nil, planeAnchor: nil, hitAPlane: false)
    }

    var recentVirtualObjectDistances = [CGFloat]()

    func setNewVirtualObjectPosition(_ pos: SCNVector3) {

        // in case you want to limit the distance of the object from the camera, you may need these codes

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

    func enableEnvironmentMapWithIntensity(_ intensity: CGFloat) {
        if sceneView.scene.lightingEnvironment.contents == nil {
            if let environmentMap = UIImage(named: "art.scnassets/sharedImages/environment_blur.exr") {
                sceneView.scene.lightingEnvironment.contents = environmentMap
            } else {
                print("Unable to load environment map")
            }
        }
        sceneView.scene.lightingEnvironment.intensity = intensity
    }

}

protocol ARViewControllerDelegate: class {
    func didReadQRCode(message: String)
}
