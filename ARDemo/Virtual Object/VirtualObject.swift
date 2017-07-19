//
//  VirtualObject.swift
//  ARDemo
//
//  Created by Anson Leung on 11/7/2017.
//  Copyright © 2017 Anson Leung. All rights reserved.
//

import Foundation
import SceneKit
import ARKit

class VirtualObject: SCNNode {

    var modelName: String = ""
    var fileExtension: String = ""
    var modelLoaded: Bool = false

    override init() {
        super.init()
        self.name = "Virtual object root node"
    }

    init(modelName: String, fileExtension: String) {
        super.init()
        self.name = "Virtual object root node"
        self.modelName = modelName
        self.fileExtension = fileExtension
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadModel() {
        print("[VirtualObject] loading model \(modelName).\(fileExtension) in art.scnassets/\(modelName)")

        guard let virtualObjectScene = SCNScene(named: "\(modelName).\(fileExtension)", inDirectory: "art.scnassets/\(modelName)") else {
            print("[VirtualObject] fail to load model")
            return
        }

        for child in virtualObjectScene.rootNode.childNodes {
            child.geometry?.firstMaterial?.lightingModel = .physicallyBased
            child.movabilityHint = .fixed
        }

        self.addChildNode(virtualObjectScene.rootNode)

        print("[VirtualObject] model loaded")

        modelLoaded = true
    }

    func loadModel(_ virtualObjectScene: SCNScene) {
        for child in virtualObjectScene.rootNode.childNodes {
            child.geometry?.firstMaterial?.lightingModel = .physicallyBased
            child.movabilityHint = .fixed
        }

        self.addChildNode(virtualObjectScene.rootNode)

        print("[VirtualObject] model loaded")

        modelLoaded = true
    }

    func unloadModel() {
        for child in self.childNodes {
            child.removeFromParentNode()
        }

        modelLoaded = false
    }
}
