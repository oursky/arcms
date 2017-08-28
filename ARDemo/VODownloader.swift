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
import SKYKit
import ZIPFoundation

class VODownloader {
    private var loadedSCN = [String]()
    private var loadingSCN = [String]()
    private var loadedVO = [String: VirtualObject]()
    private var invalidName = [String]()
    var isLoading: Bool {
        return loadingSCN.count > 0
    }
    // unit: MB
    private var cacheSize = 50.0

    private func isInvalid(name: String) -> Bool {
        return invalidName.contains(name)
    }

    func getURLOfVirtualObject(named name: String, completion:@escaping (_ virtualObject: VirtualObject?) -> Void) {

        guard !self.loadingSCN.contains(name) else {
            completion(nil)
            return
        }

        guard !self.loadedSCN.contains(name) else {
            print("[VODownloader] Cached object in memory")
            completion(self.loadedVO[name])
            return
        }

        self.startLoading(name)

        let query = SKYQuery(recordType: "model", predicate: NSPredicate(format: "name == %@", name))
        SKYContainer.default().publicCloudDatabase.perform(query) { (results, error) in
            if error != nil {
                print ("error querying todos: \(error!)")
                completion(nil)
                return
            }
            // todo get [url] for [models]
            print ("Received \(results!.count) models.")
            let record = results?.first
            guard record != nil else {
                self.endLoading(name: name)
                self.invalidName.append(name)
                completion(nil)
                return
            }
            let model = record as! SKYRecord
            print ("Got a model \(model["name"])")
            if let asset = model.object(forKey: "model") as? SKYAsset {
                let url = asset.url
                print("Start downloading the scn file from \(url.absoluteString)")
                self.downloadVirtualObject(named: name, url: url, completion: { scene in
                    guard scene != nil else {
                        self.endLoading(name: name)
                        completion(nil)
                        return
                    }
                    let virtualObject = VirtualObject()
                    virtualObject.modelName = name
                    print("Model name \(virtualObject.modelName)")
                    virtualObject.loadModel(scene!)
                    self.loadedSCN.append(name)
                    self.loadedVO[name] = virtualObject
                    self.endLoading(name: name)
                    completion(virtualObject)
                    //
                    //                    self.updateCacheInDisk()
                })
            } else {
                completion(nil)
                return
            }
        }
    }

    private func startLoading(_ name: String) {
        loadingSCN.append(name)
    }

    func downloadVirtualObject(named name: String, url: URL, completion:@escaping (_ scene: SCNScene?) -> Void) {
        let fileManager = FileManager.default
        let docURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).last!
        let parentURL = docURL.appendingPathComponent(name, isDirectory: true)
        // overwrite existing cache
        if fileManager.fileExists(atPath: parentURL.path) {
            do {
                try fileManager.removeItem(at: parentURL)
            } catch {
                completion(nil)
                return
            }
        }

        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            let targetFileURL = parentURL.appendingPathComponent(name + ".zip")
            return (targetFileURL, [.removePreviousFile, .createIntermediateDirectories])
        }

        Alamofire.download(url, to: destination).response { response in
            debugPrint(response.error ?? "")
            if response.error == nil, let zipURL = response.destinationURL {
                do {
                    let before = try fileManager.contentsOfDirectory(atPath: parentURL.path)
                    debugPrint("before unzip", before)

                    try fileManager.unzipItem(at: zipURL, to: parentURL)

                    let after = try fileManager.contentsOfDirectory(atPath: parentURL.path)
                    debugPrint("after unzip", after)

                    let scnURL = parentURL.appendingPathComponent(name + ".scn")
                    let scene = try? SCNScene(url: scnURL)
                    completion(scene)
                } catch {
                    print("Extraction of ZIP archive failed with error:\(error)")
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        }
    }

    private func endLoading(name: String) {
        let i = loadingSCN.index(of: name)
        if i != nil {
            loadingSCN.remove(at: i!)
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
            filesArray = try sortByDate(ofFiles: filesArray)
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

    private func sortByDate(ofFiles files: [URL]) throws -> [URL] {
        return try files.sorted { (first, second) -> Bool in
            let firstDateKey = try first.resourceValues(forKeys: [.contentAccessDateKey])
            let firstAccessDate = firstDateKey.contentAccessDate

            let secondDateKey = try second.resourceValues(forKeys: [.contentAccessDateKey])
            let secondAccessDate = secondDateKey.contentAccessDate

            return firstAccessDate! < secondAccessDate!
        }
    }
}
