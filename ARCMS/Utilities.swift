//
//  Utilities.swift
//  ARCMS
//
//  Created by siuming on 30/8/2017.
//  Copyright © 2017年 Oursky Limited. All rights reserved.
//

import Vision

// In this app, VNBarcodeObservation(s) are considered as equal if lhs.payload == rhs.payload
extension VNBarcodeObservation {
    // Any comparsion must directly call this func, else will call the static func conformed to Equalable which cannot be overrided
    static func == (lhs: VNBarcodeObservation, rhs: VNBarcodeObservation) -> Bool {
        // print("called")
        return lhs.payloadStringValue == rhs.payloadStringValue
    }
    static func != (lhs: VNBarcodeObservation, rhs: VNBarcodeObservation) -> Bool {
        return !(lhs == rhs)
    }
}

// Swift still not complete the API of NSCountedSet, so I write myself
extension Array where Element: VNBarcodeObservation {
    func subtracting(_ other: [Element]) -> [Element] {
        var subtracted = self
        for element in other {
            // used extension above
            // if you use index(of:), "called" will not be printed
            if let index = subtracted.index(where: { $0 == element }) {
                subtracted.remove(at: index)
            }
        }
        return subtracted
    }
    func intersection(_ other: [Element]) -> [Element] {
        var result = [Element]()
        for element in other {
            if self.contains(where: { $0 == element }) {
                // append other's element, so newer [Element] should be passed as argument for keeping boundingBox updated
                result.append(element)
            }
        }
        return result
    }
}
