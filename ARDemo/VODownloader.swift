//
//  VODownloader.swift
//  ARDemo
//
//  Created by Anson Leung on 13/7/2017.
//  Copyright © 2017 Anson Leung. All rights reserved.
//

import UIKit
import SceneKit

class VODownloader: NSObject {

    var loadedSCN = [URL]()
    var loadingSCN = [URL]()

    func downloadSCN(url: URL, completion:@escaping (_ virtualObject: VirtualObject) -> Void) {
        DispatchQueue.global().async {
            guard !self.loadingSCN.contains(url) && !self.loadedSCN.contains(url) else {return}
            do {
                print("Start downloading the scn file from \(url.absoluteString)")
                self.loadingSCN.append(url)

                // TODO: the SceneKit does not download texture files itself not following what is mentioned here:
                // https://developer.apple.com/documentation/scenekit/scnscenesource.loadingoption/1522982-assetdirectoryurls
                var baseURL = URL(string: "http://\(url.host!):\(String(describing: url.port!))")
                baseURL = baseURL?.appendingPathComponent(url.pathComponents[0]+url.pathComponents[1], isDirectory: true)
                var textureURL = baseURL?.appendingPathComponent("textures", isDirectory: true)
                print("baseurl \(String(describing: baseURL?.absoluteString))")
                print("textureurl \(String(describing: textureURL?.absoluteString))")
                let textures = NSURL(string: "textures")
//                let scene = try SCNScene(url: url, options: [.assetDirectoryURLs: [textures, baseURL, textureURL]])
//                let scene = try SCNScene(url: url)
                let scene = try SCNScene(url: url, options: [.overrideAssetURLs: true, .assetDirectoryURLs: [baseURL!]])
                let virtualObject = VirtualObject()
                virtualObject.loadModel(scene)
                self.loadedSCN.append(url)
                self.removeFromLoading(url: url)
                completion(virtualObject)
            } catch {
                self.removeFromLoading(url: url)
                print("Error: fail to load the scn scene from \(url.absoluteString)")
            }
        }
    }

    // MARK: ARViewControllerDelegate
//    func didReadQRCode(message: String) {
//        if let url = URL(string: message) {
//            downloadSCN(url: url, completion: { virtualObject in
//                self.loadedSCN.append(url)
//                self.removeFromLoading(url: url)
//                self.arViewController.virtualObject = virtualObject
//            })
//        } else {
//            print("Incorrect url: \(message)")
//        }
//    }

    func removeFromLoading(url: URL) {
        let i = self.loadingSCN.index(of: url)
        if i != nil {
            self.loadingSCN.remove(at: i!)
        }
    }
}
