//
//  QRCodesTracker.swift
//  ARCMS
//
//  Created by siuming on 29/8/2017.
//  Copyright © 2017年 Oursky Limited. All rights reserved.
//

import ARKit
import Vision

protocol QRCodesTrackerDelegate {
//    func qrCodesDidUpdate(persisted: Set<QRCode>, discovered: Set<QRCode>, at frame: ARFrame)
    func qrCodesDidUpdate(_ QRCodes: Set<QRCode>, at frame: ARFrame)
}

class QRCodesTracker: NSObject, ARSessionDelegate {
    
    var delegate: QRCodesTrackerDelegate?
    var processingFrame: ARFrame?
    var currentQRCodes = Set<QRCode>() {
        didSet {
            if currentQRCodes != oldValue {
                delegate?.qrCodesDidUpdate(currentQRCodes, at: processingFrame!)
            }
        }
    }
    // reference: https://goo.gl/W9rF4n
    lazy var detectQRCodesRequest: VNDetectBarcodesRequest = {
        let detectBarcodesRequest = VNDetectBarcodesRequest { (request, error) in
            if let observations = request.results as? [VNBarcodeObservation] {
                let qrCodes = observations.map { QRCode(in: $0) }
                // Vision often wrongly detects single QR code to two equivalent
                // Assumption of no twin QR codes in an ARSession is made as a workaround
                self.currentQRCodes = Set(qrCodes)
                self.processingFrame = nil
            } else {
                // fail to cast
                self.processingFrame = nil
            }
        }
        detectBarcodesRequest.symbologies = [.QR]
        return detectBarcodesRequest
    }()
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard processingFrame == nil else { return }
        processingFrame = frame
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: frame.capturedImage)
                try imageRequestHandler.perform([self.detectQRCodesRequest])
            } catch {
                print(error)
                self.processingFrame = nil
            }
        }
    }
}
