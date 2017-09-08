//
//  ModelsManager.swift
//  ARCMS
//
//  Created by siuming on 8/9/2017.
//  Copyright © 2017年 Oursky Limited. All rights reserved.
//

import PromiseKit
import SKYKit

class ModelsManager {
    func fetchModel(named modelName: String) -> String {
        let fileManager = FileManager.default
        // ref: https://goo.gl/vkHzyK
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let modelDirectory = cachesDirectory.appendingPathComponent(modelName, isDirectory: true)
        if fileManager.fileExists(atPath: modelDirectory.path) {
            // fetch from cache
            return modelDirectory.appendingPathComponent("\(modelName).scn").path
        } else {
            // fetch from skygear
            return ""
        }
    }
    
    func skygearQuery() -> Promise<Any> {
        return PromiseKit.wrap(SKYContainer.default().publicCloudDatabase.perform)
    }
    
    func fetchModelFromSkygear(named modelName: String) {
        let query = SKYQuery(recordType: "model", predicate: NSPredicate(format: "name == %@", modelName))
        SKYContainer.default().publicCloudDatabase.perform(query) { (results, error) in "" }
    }
}
