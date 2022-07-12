//
//  BNFYBImpressionData.swift
//  FyberDecorator
//
//  Created by Stas Kochkin on 11.07.2022.
//

import Foundation
import MobileAdvertising
import FairBidSDK


final class BNFYBImpressionDataWrapper: NSObject, Ad {
    let _wrapped: FYBImpressionData
    
    var id: String { _wrapped.creativeId ?? String(_wrapped.hash) }
    var price: Price { _wrapped.netPayout?.doubleValue ?? 0 }
    var dsp: String { _wrapped.demandSource ?? "fyber" }
    var wrapped: AnyObject { _wrapped }
    
    init(_ wrapped: FYBImpressionData) {
        self._wrapped = wrapped
        super.init()
    }
}


final class EmptyFYBImpressionDataWrapper: NSObject, Ad {
    let id: String
    var price: Price = 0
    var dsp: String = ""
    var wrapped: AnyObject = NSNull()
    
    init(placement: String) {
        self.id = placement
        super.init()
    }
}


extension FYBInterstitial {
    static func wrappedImpressionData(_ placement: String) -> Ad {
        return impressionData(placement)
            .map { BNFYBImpressionDataWrapper($0) } ?? EmptyFYBImpressionDataWrapper(placement: placement)
    }
}


extension FYBRewarded {
    static func wrappedImpressionData(_ placement: String) -> Ad {
        return impressionData(placement)
            .map { BNFYBImpressionDataWrapper($0) } ?? EmptyFYBImpressionDataWrapper(placement: placement)
    }
}


extension FYBBannerAdView {
    var wrappedImpressionData: Ad {
        guard
            let banner = value(forKey: "bannerAd") as? AnyObject,
            let impression = banner.value(forKey: "impressionData") as? FYBImpressionData
        else {
            return EmptyFYBImpressionDataWrapper(placement: options.placementId)
        }
        
        return BNFYBImpressionDataWrapper(impression)
    }
}
