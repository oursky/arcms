//
//  VODownloader.swift
//  ARDemo
//
//  Created by Anson Leung on 13/7/2017.
//  Copyright © 2017 Anson Leung. All rights reserved.
//

import UIKit
import SceneKit
import Alamofire

class VODownloader: NSObject {

    var loadedSCN = [URL]()
    var loadingSCN = [URL]()
    var loadedVO = [String: VirtualObject]()

    func downloadVirtualObject(url: URL, completion:@escaping (_ virtualObject: VirtualObject?) -> Void) {
        DispatchQueue.global().async {
            guard !self.loadingSCN.contains(url) && !self.loadedSCN.contains(url)
                else {
                    if self.loadedSCN.contains(url) {
                        completion(self.loadedVO[url.absoluteString])
                    }
                    return
            }
            print("Start downloading the scn file from \(url.absoluteString)")
            self.loadingSCN.append(url)

            self.downloadSCN(url: url, completion: { scene in
                guard scene != nil else {
                    completion(nil)
                    return
                }
                let virtualObject = VirtualObject()
                virtualObject.modelName = url.pathComponents.last!
                virtualObject.loadModel(scene!)
                self.loadedSCN.append(url)
                self.loadedVO[url.absoluteString] = virtualObject
                self.removeFromLoading(url: url)
                completion(virtualObject)
            })
        }
    }

    private func removeFromLoading(url: URL) {
        let i = self.loadingSCN.index(of: url)
        if i != nil {
            self.loadingSCN.remove(at: i!)
        }
    }

    //Assumption: the url must be in this format http://$host/$fileID (this link retursn a json containing the names of all texture files)
    // loand the scn file in http://$host/$fileID/$fileID.scn while the textures in http://$host/$fileID/textures
    private func downloadSCN(url: URL, completion:@escaping (_ scn: SCNScene?) -> Void) {
        Alamofire.request(url).responseJSON { response in
            if let json = response.result.value as! [String: [String]]? {
                if let textures = json["textures"] {
                    print(textures)
                    let filemgr = FileManager.default
                    let docPath = filemgr.urls(for: .documentDirectory, in: .userDomainMask).last

                    self.downloadTextures(textures, remoteRootURL: url, completion: { sucess in
                        if sucess {
                            let filename = "\(url.pathComponents.last!).scn"
                            let scnURL = url.appendingPathComponent(filename)
                            Alamofire.request(scnURL).responseData { response in
                                if response.data != nil {
                                    do {
                                        let scnSaveURL = docPath?.appendingPathComponent(filename)
                                        try response.data?.write(to: scnSaveURL!, options: .atomicWrite)
                                        let localScnURL = docPath?.appendingPathComponent(filename)
                                        let scnFile = try SCNScene(url: localScnURL!)
                                        completion(scnFile)
                                        return
                                    } catch let error as NSError {
                                        completion(nil)
                                        print("Error in writing/reading scn file: \(error)")
                                        return
                                    }
                                }
                            }
                        } else {
                            completion(nil)
                        }
                    })
                }
            }
        }
    }

    private func downloadFile(from source: URL, to destination: URL, completion:@escaping (_ successful: Bool) -> Void) {

        Alamofire.request(source).responseData { response in
            do {
                try response.data?.write(to: destination, options: .atomicWrite)
                completion(true)
            } catch let error as NSError {
                print("Error in downloadFile from \(source.absoluteString) to \(destination.absoluteString): \(error)")
                completion(false)
            }
        }

    }

    private func downloadTexture(_ textureFilename: String,
                                 _ remoteRootURL: URL, to destination: URL,
                                 completion:@escaping(_ successful: Bool) -> Void) {
        let textureURL = remoteRootURL.appendingPathComponent(textureFilename)
        print("Downloading texture \(textureFilename) from \(textureURL.absoluteString)")
        downloadFile(from: textureURL, to: destination) { success in
            completion(success)
        }

    }

    private func downloadTextures(_ textures: [String], remoteRootURL: URL, completion:@escaping(_ successful: Bool) -> Void) {
        do {
            let filemgr = FileManager.default
            let docPath = filemgr.urls(for: .documentDirectory, in: .userDomainMask).last
            let textureURL = docPath?.appendingPathComponent("textures", isDirectory: true)
            var isDir: ObjCBool = false
            if filemgr.fileExists(atPath: (textureURL?.path)!, isDirectory: &isDir) { try filemgr.removeItem(at: textureURL!) }
            try filemgr.createDirectory(at: textureURL!, withIntermediateDirectories: false, attributes: nil)
            var count = 0
            for texture in textures {
                let destination = textureURL?.appendingPathComponent(texture)
                downloadTexture(texture,
                                remoteRootURL.appendingPathComponent("textures", isDirectory: true),
                                to: destination!,
                                completion: { success in
                    if !success {
                        print("Fail to download \(texture)")
                        completion(false)
                        return
                    }
                    count += 1
                    if count >= textures.count {
                        completion(success)
                    }
                })
            }
        } catch let error as NSError {
            print("Error in downloading textures: \(error)")
            completion(false)
        }
    }
}
