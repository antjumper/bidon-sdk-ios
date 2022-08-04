//
//  AdProtocol.swift
//  MobileAdvertising
//
//  Created by Stas Kochkin on 04.07.2022.
//

import Foundation


public typealias Price = Double
public typealias Currency = String


public extension Price {
    static let unknown: Price = 0
    
    var isUnknown: Bool {
        return isNaN || isZero || isInfinite
    }
}


public extension Currency {
    static var `default` = "USD"
}


@objc public protocol Ad {
    var id: String { get }
    var price: Price { get }
    var currency: Currency { get }
    var networkName: String { get }
    var dsp: String? { get }
    
    var wrapped: AnyObject { get }
}


extension Ad {
    var description: String {
        return "Ad Wrapper #\(id), network: \(networkName), dsp: \(dsp ?? "-"), revenue: \(price) \(currency). Wrapped \(wrapped)"
    }
}


internal struct HashableAd: Hashable  {
    var ad: Ad

    init(ad: Ad) {
        self.ad = ad
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ad.id)
    }
    
    static func == (lhs: HashableAd, rhs: HashableAd) -> Bool {
        return lhs.ad.id == rhs.ad.id
    }
}