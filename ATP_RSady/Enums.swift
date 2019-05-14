//
//  Enums.swift
//  ArkTradingPost
//
//  Created by Ryan Sady on 3/1/19.
//  Copyright © 2019 Ryan Sady. All rights reserved.
//

import Foundation

public enum Platform: String, CaseIterable {
    case empty = ""
    case pc = "PC"
    case playstation = "PS4"
    case nintendoSwitch = "Switch"
    case xbox = "Xbox"
}

public enum ServerType:  String, CaseIterable {
    case empty = ""
    case pve = "Official PvE"
    case pvp = "Official PvP"
}

public enum PostType: String, CaseIterable {
    case empty = ""
    case forSale = "For Sale"
    case wantToBuy = "Want to Buy"
}

public enum PostStatus: String, CaseIterable {
    case closed = "closed"
    case active = "active"
    case pendingReview = "pending_review"
    case approved = "approved"
    case suspended = "suspended"
}


