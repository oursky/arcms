//
//  QRCode.swift
//  ARCMS
//
//  Created by siuming on 1/9/2017.
//  Copyright © 2017年 Oursky Limited. All rights reserved.
//

import Vision

class QRCode: Hashable {
    let midpoint: CGPoint
    let payload: String
    var hashValue: Int {
        return payload.hashValue &* 16777619
    }
    
    init(in observation: VNBarcodeObservation) {
        // right click -> "Jump to Definition" to read docs about coordinates
        var bounds = observation.boundingBox
        // flip coordinates to meet hit testing requirement on origin, ref: https://goo.gl/m6VNDn
        bounds = bounds.applying(CGAffineTransform(scaleX: 1, y: -1))
        bounds = bounds.applying(CGAffineTransform(translationX: 0, y: 1))
        midpoint = CGPoint(x: bounds.midX, y: bounds.midY)
        payload = observation.payloadStringValue ?? ""
    }
    
    static func ==(lhs: QRCode, rhs: QRCode) -> Bool {
        return lhs.payload == rhs.payload
    }
}
