//
//  API_Errors.swift
//  ArkTradingPost
//
//  Created by Ryan Sady on 3/2/19.
//  Copyright © 2019 Ryan Sady. All rights reserved.
//

import Foundation

enum APIErrors: Error {
    case noUser
    case noPost
    case noData
    case parseError
    case userDataError
    case unverifiedEmail
}

extension APIErrors: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noData:
            return NSLocalizedString("No Data Found.  Please Try Again", comment: "No Data Found")
        case .noPost:
            return NSLocalizedString("No Post Data Found.  Please Try Again", comment: "No Post Data")
        case .noUser:
            return NSLocalizedString("No User Found.  Please sign in.", comment: "No User")
        case .parseError:
            return NSLocalizedString("There was an error parsing the data from the server.  Please try again.", comment: "Parse Error")
        case .userDataError:
            return NSLocalizedString("No user data found.  Please try logging in again.", comment: "No User")
        case .unverifiedEmail:
            return NSLocalizedString("Please verify your email address.", comment: "Unverified Email")
        }
    }
}
