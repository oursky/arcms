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
import PKHUD
import Photos

class ARViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    // MARK: ARKit / ARSCNView
    var sceneView: ARSCNView!
    var session = ARSession()
    var sessionConfig: ARSessionConfiguration = ARWorldTrackingSessionConfiguration()

    // MARK: Vision
    var imageRequestHandler: VNSequenceRequestHandler!

    var lineView: LineView!
    var centerPt: UIView!

    var virtualObject: VirtualObject?
    var voDownloader = VODownloader()

    var recentVirtualObjectDistances = [CGFloat]()

    // MARK: state
    var debug = false

    // MARK: Core Image
    var qrDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneViewSetup()
        debugIndicatorSetup()
        photoTakingSetup()

        // Non-view setup
        imageRequestHandler = VNSequenceRequestHandler()

        if let camera = sceneView.pointOfView?.camera {
            camera.wantsHDR = true
            camera.wantsExposureAdaptation = true
            camera.exposureOffset = -1
            camera.minimumExposure = -1
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

    // MARK: Planes
    private func restartPlaneDetection () {
        // configure session
        if let worldSessionConfig = sessionConfig as? ARWorldTrackingSessionConfiguration {
            worldSessionConfig.planeDetection = .horizontal
            session.run(worldSessionConfig, options: [.resetTracking, .removeExistingAnchors])
        }
    }

    // MARK: View setup
    private func sceneViewSetup() {
        sceneView = ARSCNView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height))
        sceneView.showsStatistics = debug
        sceneView.delegate = self
        session.delegate = self
        sceneView.session = session

        sceneView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sceneView)
    }

    private func debugIndicatorSetup() {
        lineView = LineView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height))
        lineView.backgroundColor = .clear
        view.addSubview(lineView)

        centerPt = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        centerPt.backgroundColor = .red
        centerPt.backgroundColor = centerPt.backgroundColor
        centerPt.isHidden = true
        view.addSubview(centerPt)
    }

    private func photoTakingSetup() {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        button.setImage(#imageLiteral(resourceName: "shutter"), for: .normal)
        button.setImage(#imageLiteral(resourceName: "shutterPressed"), for: .highlighted)
        button.addTarget(self, action: #selector(takeScreenShot), for: .touchUpInside)
        view.addSubview(button)

        button.translatesAutoresizingMaskIntoConstraints = false
        let buttonMargin = button.layoutMarginsGuide
        let viewMargin = view.layoutMarginsGuide

        buttonMargin.bottomAnchor.constraint(equalTo: viewMargin.bottomAnchor, constant: -25).isActive = true
        buttonMargin.centerXAnchor.constraint(equalTo: viewMargin.centerXAnchor, constant: 0).isActive = true
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
            guard retval != nil else {
                showIndicator(false)
                HUD.hide(animated: true)
                return
            }

            showIndicator(true)
            let (corners, message) = retval!
            print("corners \(corners)")
            print("message \(message)")

            drawFocusSquare(corners: corners)

            let centroid = Utilities.intersection(u1: corners[0], u2: corners[2], v1: corners[1], v2: corners[3])
            print("centroid \(centroid)")

            if let url = URL(string: message) {
                let modelName = url.pathComponents.last!
                if virtualObject != nil && virtualObject?.modelName == modelName {
                    renderVirtualObjectByScreenPos(screenPos: centroid, virtualObject: virtualObject)
                } else {
                    if !voDownloader.isLoading() && !voDownloader.isInvalid(url: url) {
                        DispatchQueue.main.async {
                            HUD.show(.progress)
                        }
                    }

                    if voDownloader.isInvalid(url: url) {
                        showInvalidError()
                        return
                    }

                    print("Try download from \(url.absoluteString)")
                    voDownloader.downloadVirtualObject(url: url, completion: { virtualObject in
                        guard virtualObject != nil else {
                            if self.virtualObject != nil && (self.virtualObject?.isEqual(virtualObject))! {
                                return
                            }

                            if self.voDownloader.isInvalid(url: url) {
                                DispatchQueue.main.async {
                                    HUD.show(.labeledError(title: "Error", subtitle: "Fail to load the object"))
                                }
                            }
                            return
                        }
                        print("[ARVC] Object loaded")
                        self.virtualObject?.removeFromParentNode()
                        self.virtualObject = virtualObject
                        self.virtualObject?.viewController = self
                        DispatchQueue.main.async {
                            if virtualObject?.modelName != "" {
                                let modelName = virtualObject?.modelName
                                print(modelName!)
                                HUD.flash(.labeledSuccess(title: "Sucess", subtitle: "\(modelName!) is loaded"), delay: 0.5)
                            } else {
                                HUD.flash(.success, delay: 0.5)
                            }
                        }
                    })
                }

            } else {
                showNotURLError()
                print("Incorrect url: \(message)")
            }
        }
    }

    // MARK: HUD wrap-up
    private func showErrorHUD(title: String, subtitle: String) {
        DispatchQueue.main.async {
            if !HUD.isVisible {
                HUD.show(.labeledError(title: title, subtitle: subtitle))
            }
        }
    }

    private func showNotURLError() {
        showErrorHUD(title: "Error", subtitle: "This is not a url")

    }

    private func showInvalidError() {
        showErrorHUD(title: "Error", subtitle: "Fail to load the object")
    }

    // input the image and return the four corners (topLeft -> topRight -> bottomRight -> bottomLeft) and the decoded content of the qr code if any
    func extractQRInfo(ciImage: CIImage) -> (corners: [CGPoint], String)? {
        let features = qrDetector?.features(in: ciImage)
        guard features?.count != 0 else { return nil }

        // currently only picking the fist qr code detected
        if let feature = (features?.first) as? CIQRCodeFeature {
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
        if debug {
            lineView.isHidden = !show
            centerPt.isHidden = !show
        } else {
            lineView.isHidden = true
            centerPt.isHidden = true
        }
    }

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

    // MARK: Photo taking
    @objc func takeScreenShot(_ sender: UIButton) {
        let takeScreenshotBlock = {
            UIImageWriteToSavedPhotosAlbum(self.sceneView.snapshot(), nil, nil, nil)
            DispatchQueue.main.async {
                // Briefly flash the screen.
                let flashOverlay = UIView(frame: self.sceneView.frame)
                flashOverlay.backgroundColor = UIColor.white
                self.sceneView.addSubview(flashOverlay)
                UIView.animate(withDuration: 0.25, animations: {
                    flashOverlay.alpha = 0.0
                }, completion: { _ in
                    flashOverlay.removeFromSuperview()
                })
            }
        }

        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            takeScreenshotBlock()
        case .restricted, .denied:
            let title = "Photos access denied"
            let message = "Please enable Photos access for this application in Settings > Privacy to allow saving screenshots."
            showErrorHUD(title: title, subtitle: message)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ (authorizationStatus) in
                if authorizationStatus == .authorized {
                    takeScreenshotBlock()
                }
            })
        }
    }
}
