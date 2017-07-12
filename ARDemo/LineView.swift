//
//  LineView.swift
//  ARDemo
//
//  Created by Anson Leung on 11/7/2017.
//  Copyright © 2017 Anson Leung. All rights reserved.
//

import UIKit

class LineView: UIView {

    var points: [CGPoint]?

    override func draw(_ rect: CGRect) {
        guard points != nil && points?.count != 0 else { return }

        let aPath = UIBezierPath()
        aPath.move(to: (points?.first)!)

        for point in (points?[1..<(points?.count)!])! {
            aPath.addLine(to: point)
        }

        aPath.close()

        UIColor.red.withAlphaComponent(0.5).set()
        aPath.stroke()
        aPath.fill()
    }

    func setPoints(_ points: [CGPoint]) {
        self.points = points
        setNeedsDisplay()
    }

}
