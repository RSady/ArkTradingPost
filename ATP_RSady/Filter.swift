//
//  Filter.swift
//  ArkTradingPost
//
//  Created by Ryan Sady on 3/9/19.
//  Copyright © 2019 Ryan Sady. All rights reserved.
//

import Foundation

public struct Filter {

    var serverType, platform, postType, rating : String?
    
    init() {}
    
    init(serverType: String? = nil, platform: String? = nil, postType: String? = nil, rating: String? = nil) {
        self.serverType = serverType
        self.platform = platform
        self.postType = postType
        self.rating = rating
    }
}
