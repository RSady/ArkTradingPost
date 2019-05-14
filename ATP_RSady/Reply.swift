//
//  Reply.swift
//  ArkTradingPost
//
//  Created by Ryan Sady on 3/6/19.
//  Copyright © 2019 Ryan Sady. All rights reserved.
//

import Foundation

struct Reply {
    var id, postId, userId, username, body: String?
    var created: Date?
    
    init() {}
    
    init(id: String? = nil, postId: String? = nil, userId: String? = nil, username: String? = nil, body: String? = nil, created: Date? = nil) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.body = body
        self.created = created
        self.username = username
    }
}
