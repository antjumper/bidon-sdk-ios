//
//  BNMAAdWrapper.swift
//  AppLovinDecorator
//
//  Created by Stas Kochkin on 04.07.2022.
//

import Foundation
import AppLovinSDK
import MobileAdvertising


final class BNMAAdWrapper: NSObject, Ad {
    private let _wrapped: MAAd
    
    var wrapped: AnyObject { _wrapped }
    
    var id: String { _wrapped.adUnitIdentifier }
    var price: Price { _wrapped.revenue }
    var dsp: String { _wrapped.networkName }
    
    init(_ wrapped: MAAd) {
        self._wrapped = wrapped
        super.init()
    }
}


extension MAAd {
    var wrapped: Ad { BNMAAdWrapper(self) }
}