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
    func qrCodesDidUpdate(persisted: [VNBarcodeObservation], removed: [VNBarcodeObservation], added: [VNBarcodeObservation], at frame: ARFrame)
}

class QRCodesTracker: NSObject, ARSessionDelegate {
    
    var delegate: QRCodesTrackerDelegate?
    var processingFrame: ARFrame?
    var currentQRCodes = [VNBarcodeObservation]() {
        didSet {
            if !currentQRCodes.elementsEqual(oldValue, by: ==) {
                let persisted = oldValue.intersection(currentQRCodes)
                let removed = oldValue.subtracting(currentQRCodes)
                let added = currentQRCodes.subtracting(oldValue)
                delegate?.qrCodesDidUpdate(persisted: persisted, removed: removed, added: added, at: processingFrame!)
            }
        }
    }
    // reference: https://goo.gl/W9rF4n
    lazy var detectQRCodesRequest: VNDetectBarcodesRequest = {
        let detectBarcodesRequest = VNDetectBarcodesRequest { (request, error) in
            if let observations = request.results as? [VNBarcodeObservation] {
                // sorted for convenience in comparsion in didSet
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
