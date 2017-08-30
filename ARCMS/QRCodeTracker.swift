//
//  QRCodeTracker.swift
//  ARCMS
//
//  Created by siuming on 29/8/2017.
//  Copyright © 2017年 Oursky Limited. All rights reserved.
//

import ARKit
import Vision

protocol QRCodeTrackerDelegate {
    func qrCodesDidUpdate(_ qrCodes: [VNBarcodeObservation], at frame: ARFrame)
}

class QRCodeTracker: NSObject, ARSessionDelegate {
    
    var delegate: QRCodeTrackerDelegate?
    var processingFrame: ARFrame?
    var currentQRCodes = [VNBarcodeObservation]() {
        didSet {
            let newPayloads = currentQRCodes.map { $0.payloadStringValue ?? "" }
            let oldPayloads = oldValue.map { $0.payloadStringValue ?? "" }
            // both are already sorted, can be compared directly
            if newPayloads.sorted() != oldPayloads.sorted() {
                delegate?.qrCodesDidUpdate(currentQRCodes, at: processingFrame!)
            }
        }
    }
    // reference: https://goo.gl/W9rF4n
    lazy var detectQRCodesRequest: VNDetectBarcodesRequest = {
        let detectBarcodesRequest = VNDetectBarcodesRequest { (request, error) in
            if let observations = request.results as? [VNBarcodeObservation] {
                self.currentQRCodes = observations
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
        DispatchQueue.global(qos: .background).async {
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
