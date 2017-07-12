//
//  Cup.swift
//  ARDemo
//
//  Created by Anson Leung on 12/7/2017.
//  Copyright © 2017 Anson Leung. All rights reserved.
//

import Foundation

class Cup: VirtualObject {

    override init() {
        super.init(modelName: "cup", fileExtension: "scn")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
