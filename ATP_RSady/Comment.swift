//
//  Comment.swift
//  ArkTradingPost
//
//  Created by Ryan Sady on 3/1/19.
//  Copyright © 2019 Ryan Sady. All rights reserved.
//

import Foundation

public struct Comment {
    var id, postId, userId, body: String?
    var created: Date?
    
    init() { }
    
    init(id: String? = nil, postId: String? = nil, userId: String? = nil, body: String? = nil, created: Date? = nil) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.body = body
        self.created = created
    }
    
}
