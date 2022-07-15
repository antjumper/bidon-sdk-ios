//
//  Defines.swift
//  MobileAdvertising
//
//  Created by Stas Kochkin on 15.06.2022.
//

import Foundation


@objc public enum AdType: Int {
    case banner = 0
    case interstitial
    case rewarded
}



public enum SDKError: Error, CustomStringConvertible {
    case generic(error: Error)
    case message(String)
    case unknown
    
    case noFill
    case cancelled
    case internalInconsistency
    case invalidPresentationState
    case unableToFindRootViewController
    
    public var description: String {
        switch self {
        case .noFill:
            return "No fill"
        case .internalInconsistency:
            return "Inconsistent state"
        case .unknown:
            return "Unknown"
        case .cancelled:
            return "Request has been cancelled"
        case .invalidPresentationState:
            return "Invalid presentation state"
        case .unableToFindRootViewController:
            return "Unable to find root view controller"
        case .generic(let error):
            return error.localizedDescription
        case .message(let message):
            return message
        }
    }
    
    public init(_ message: String) {
        self = .message(message)
    }
    
    public init(_ error: Error?) {
        if let error = error as? SDKError {
            self = error
        } else if let error = error {
            self = .generic(error: error)
        } else {
            self = .unknown
        }
    }
}



