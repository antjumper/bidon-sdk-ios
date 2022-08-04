//
//  GADResponseWrapper.swift
//  GoogleMobileAdsAdapter
//
//  Created by Stas Kochkin on 06.07.2022.
//

import Foundation
import GoogleMobileAds
import BidOn


protocol ResponseInfoProvider {
    var info: GADResponseInfo? { get }
}


final internal class BNGADResponseInfoWrapper: NSObject, Ad {
    var id: String
    var price: Price
    var wrapped: AnyObject

    let currency: Currency = .default
    let networkName: String = "admob"
    let dsp: String? = nil

    init(
        id: String,
        price: Price,
        wrapped: AnyObject
    ) {
        self.id = id
        self.price = price
        self.wrapped = wrapped
        
        super.init()
    }
    
    convenience init(
        _ provider: ResponseInfoProvider,
        item: LineItem
    ) {
        self.init(
            id: provider.info?.responseIdentifier ?? item.adUnitId,
            price: item.pricefloor,
            wrapped: provider.info ?? NSNull()
        )
    }
}


extension GADBannerView: ResponseInfoProvider {
    var info: GADResponseInfo? { responseInfo }
}


