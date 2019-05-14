//
//  Post.swift
//  ArkTradingPost
//
//  Created by Ryan Sady on 3/1/19.
//  Copyright © 2019 Ryan Sady. All rights reserved.
//

import Foundation
import UIKit

public struct Post {
    var id, title, body: String?
    var postType: PostType?
    var platform: Platform?
    var serverType: ServerType?
    var price: String?
    var created: Date?
    var userId, username, fulfilledBy: String?
    var status: PostStatus?
    var commentCount: Int?
    var images: [UIImage]?
    var imageCount: Int?
    var searchText: String?
    
    init() { }
    
    init(id: String? = nil, title: String? = nil, body: String? = nil, postType: PostType? = nil, platform: Platform? = nil, serverType: ServerType? = nil, price: String? = nil, created: Date? = nil, userId: String? = nil, username: String? = nil, fulfilledBy: String? = nil, status: PostStatus? = nil, commentCount: Int? = nil, images: [UIImage]? = nil, imageCount: Int? = nil, searchText: String? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.postType = postType
        self.platform = platform
        self.serverType = serverType
        self.price = price
        self.created = created
        self.userId = userId
        self.username = username
        self.fulfilledBy = fulfilledBy
        self.status = status
        self.commentCount = commentCount
        self.images = images
        self.imageCount = imageCount
        self.searchText = searchText
    }
}
