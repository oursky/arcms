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

    // unit: MB
    private var cacheSize = 5.0

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

                self.updateCacheInDisk()
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

    private func updateCacheInDisk() {
        let filemgr = FileManager.default
        let docURL = filemgr.urls(for: .documentDirectory, in: .userDomainMask).last
        do {
            let fileSize = getFileSizeInMB(ofURL: docURL!)
            print("Cached files size in disk: \(String(describing: fileSize)) MB")
            if fileSize > cacheSize {
                print("Exceed cache size limit, cleaning up some files")
                try cleanCacheInDisk()
            }
        } catch {
            print("Error in updating cache \((docURL?.absoluteString)!).\n Error: \(error)")
        }
    }

    private func cleanCacheInDisk() throws {
        let filemgr = FileManager.default
        let docURL = filemgr.urls(for: .documentDirectory, in: .userDomainMask).last
        var filesArray = try filemgr.contentsOfDirectory(at: docURL!,
                                                         includingPropertiesForKeys: [.isDirectoryKey, .contentAccessDateKey],
                                                         options: .skipsHiddenFiles)

        do {
            filesArray = try filesArray.sorted { (first, second) -> Bool in
                let firstDateKey = try first.resourceValues(forKeys: [.contentAccessDateKey])
                let firstAccessDate = firstDateKey.contentAccessDate

                let secondDateKey = try second.resourceValues(forKeys: [.contentAccessDateKey])
                let secondAccessDate = secondDateKey.contentAccessDate

                return firstAccessDate! < secondAccessDate!
            }
        } catch {
            print("Error in sorting file array by date.\nError: \(error)")
        }

        print("Files in disk cache \(filesArray)")

        var count = 0
        while count < filesArray.count || getFileSizeInMB(ofURL: docURL!) > cacheSize {
            let file = filesArray[count]
            do {
                print("Removing file at \(file.absoluteString)")
                try filemgr.removeItem(at: file)
            } catch {
                print("Error in removing file at \(file.absoluteString)\nError: \(error)")
            }
            count += 1
        }
    }

    private func getFileSizeInMB(ofURL url: URL) -> Double {
        do {
            return try Double(FileManager.default.allocatedSizeOfDirectory(atUrl: url))/1000000
        } catch {
            print("Error in getting file size of \(url.absoluteString)")
            return 0.0
        }
    }

    // Assumption: the url must be in this format http://$host/$fileID
    // (this link returns a json containing the paths to all texture files as well as the .scn file)
    // loand the scn file in http://$host/$fileID/$fileID.scn while the textures in http://$host/$fileID/textures
    private func downloadSCN(url: URL, completion:@escaping (_ scn: SCNScene?) -> Void) {
        let modelName = url.pathComponents.last!
        let (parentURL, textureURL) = self.prepareDirs(parentDir:modelName)

        guard parentURL != nil && textureURL != nil else {
            completion(nil)
            return
        }

        // if this file exists, load from disk directly
        let filemgr = FileManager.default
        let scnSaveURL = parentURL?.appendingPathComponent(modelName.appending(".scn"))
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

            self.downloadFiles(filesToDownload, from: url, to: parentURL!) { success in
                if !success {
                    completion(nil)
                }

                let scnSaveURL = parentURL?.appendingPathComponent(scnFilename)
                self.loadScn(scnURL: scnSaveURL!) { scn in
                    completion(scn)
                }
            }
        }
    }

    private func prepareDirs(parentDir: String) -> (parentURL: URL?, textureURL: URL?) {
        let filemgr = FileManager.default
        let docURL = filemgr.urls(for: .documentDirectory, in: .userDomainMask).last
        let parentURL = docURL?.appendingPathComponent(parentDir, isDirectory: true)
        let textureURL = parentURL?.appendingPathComponent("textures", isDirectory: true)
        // if the both directories exist, it implies that the file has been downloaded -> return the urls
        // if only root diretory exists but not texture directory, the file was downloaded incompletely, remove them and re-download
        if filemgr.fileExists(atPath: (parentURL?.path)!) {
            if filemgr.fileExists(atPath: (textureURL?.path)!) { return (parentURL, textureURL) } else { try? filemgr.removeItem(at: parentURL!) }
        }
        do {
            try filemgr.createDirectory(at: parentURL!, withIntermediateDirectories: false, attributes: nil)
            try filemgr.createDirectory(at: textureURL!, withIntermediateDirectories: false, attributes: nil)
        } catch let error {
            print("Fail to create directory\n Error: \(error)")
            return (nil, nil)
        }

        return (parentURL, textureURL)
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
