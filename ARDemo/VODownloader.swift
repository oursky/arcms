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

    private var loadedSCN = [URL]()
    private var loadingSCN = [URL]()
    private var loadedVO = [String: VirtualObject]()
    private var invalidURL = [URL]()

    func downloadVirtualObject(url: URL, completion:@escaping (_ virtualObject: VirtualObject?) -> Void) {
        DispatchQueue.global().async {
            guard !self.loadingSCN.contains(url) else {
                completion(nil)
                return
            }

            guard !self.loadedSCN.contains(url) else {
                print("[VODownloader] Cached object in memory")
                completion(self.loadedVO[url.absoluteString])
                return
            }

            print("Start downloading the scn file from \(url.absoluteString)")
            guard !self.isInvalid(url: url) else {
                print("Invalid url \(url.absoluteString)")
                completion(nil)
                return
            }
            self.startLoading(url: url)

            self.downloadSCN(url: url, completion: { scene in
                guard scene != nil else {
                    self.endLoading(url: url)
                    self.invalidURL.append(url)
                    completion(nil)
                    return
                }
                let virtualObject = VirtualObject()
                virtualObject.modelName = url.pathComponents.last!
                print("Model name \(virtualObject.modelName)")
                virtualObject.loadModel(scene!)
                self.loadedSCN.append(url)
                self.loadedVO[url.absoluteString] = virtualObject
                self.endLoading(url: url)
                completion(virtualObject)
            })
        }
    }

    private func startLoading(url: URL) {
        loadingSCN.append(url)
    }

    private func endLoading(url: URL) {
        let i = loadingSCN.index(of: url)
        if i != nil {
            loadingSCN.remove(at: i!)
        }
    }

    // Assumption: the url must be in this format http://$host/$fileID
    // (this link returns a json containing the paths to all texture files as well as the .scn file)
    // loand the scn file in http://$host/$fileID/$fileID.scn while the textures in http://$host/$fileID/textures
    private func downloadSCN(url: URL, completion:@escaping (_ scn: SCNScene?) -> Void) {
        let modelName = url.pathComponents.last!
        let (rootURL, textureURL) = self.prepareDirs(rootDir:modelName)

        guard rootURL != nil && textureURL != nil else {
            completion(nil)
            return
        }

        // if this file exists, load from disk directly
        let filemgr = FileManager.default
        let scnSaveURL = rootURL?.appendingPathComponent(modelName.appending(".scn"))
        if filemgr.fileExists(atPath: (scnSaveURL?.path)!, isDirectory: nil) {
            print("[VODownload] \(modelName) found in \((scnSaveURL?.path)!), load from disk directly")
            self.loadScn(scnURL: scnSaveURL!) { scn in
                completion(scn)
            }
            return
        }

        Alamofire.request(url).responseJSON { response in
            guard let json = response.result.value as! [String: Any]? else {
                print("Unable to receive the texture json from \(url.absoluteString)")
                completion(nil)
                return
            }
            guard var filesToDownload = json["textures"] as? [String] else {
                print("No \"textures\" entry in the returned json")
                completion(nil)
                return
            }

            guard let scnFilename = json["scn"] as? String else {
                completion(nil)
                return
            }

            filesToDownload.append(scnFilename)
            print(filesToDownload)

            self.downloadFiles(filesToDownload, from: url, to: rootURL!) { success in
                if !success {
                    completion(nil)
                }

                let scnSaveURL = rootURL?.appendingPathComponent(scnFilename)
                self.loadScn(scnURL: scnSaveURL!) { scn in
                    completion(scn)
                }
            }
        }
    }

    private func prepareDirs(rootDir: String) -> (rootURL: URL?, textureURL: URL?) {
        let filemgr = FileManager.default
        let docURL = filemgr.urls(for: .documentDirectory, in: .userDomainMask).last
        let rootURL = docURL?.appendingPathComponent(rootDir, isDirectory: true)
        let textureURL = rootURL?.appendingPathComponent("textures", isDirectory: true)
        // if the both directories exist, it implies that the file has been downloaded -> return the urls
        // if only root diretory exists but not texture directory, the file was downloaded incompletely, remove them and re-download
        if filemgr.fileExists(atPath: (rootURL?.path)!) {
            if filemgr.fileExists(atPath: (textureURL?.path)!) { return (rootURL, textureURL) } else { try? filemgr.removeItem(at: rootURL!) }
        }
        do {
            try filemgr.createDirectory(at: rootURL!, withIntermediateDirectories: false, attributes: nil)
            try filemgr.createDirectory(at: textureURL!, withIntermediateDirectories: false, attributes: nil)
        } catch let error {
            print("Fail to create directory\n Error: \(error)")
            return (nil, nil)
        }

        return (rootURL, textureURL)
    }

    private func loadScn(scnURL: URL, completion:@escaping (_ scn: SCNScene?) -> Void) {
        do {
            let scnFile = try SCNScene(url: scnURL)
            completion(scnFile)
        } catch let error {
            completion(nil)
            print("Error in writing/reading scn file: \(error)")
        }
    }

    private func downloadFile(from src: URL,
                              to dest: URL,
                              completion:@escaping (_ successful: Bool) -> Void) {
        Alamofire.request(src).responseData { response in
            do {
                try response.data?.write(to: dest, options: .atomicWrite)
                completion(true)
            } catch let error {
                print("Error in downloadFile from \(src.absoluteString) to \(dest.absoluteString): \(error)")
                completion(false)
            }
        }
    }

    private func downloadFiles(_ files: [String],
                               from  srcRootURL: URL,
                               to destRootURL: URL,
                               completion:@escaping(_ successful: Bool) -> Void) {
        var count = 0
        var errCount = 0
        for file in files {
            let src = srcRootURL.appendingPathComponent(file)
            let dest = destRootURL.appendingPathComponent(file)
            downloadFile(from: src, to: dest) { success in
                if !success {
                    errCount += 1
                    print("Fail to download \(src)")
                    completion(false)
                    return
                }
                count += 1
                if count >= files.count {
                    if errCount == 0 { completion(success) }
                }
            }
        }
    }

    private func isInvalid(url: URL) -> Bool {
        return invalidURL.contains(url)
    }

    func isLoading() -> Bool {
        return !(loadingSCN.count == 0)
    }
}
