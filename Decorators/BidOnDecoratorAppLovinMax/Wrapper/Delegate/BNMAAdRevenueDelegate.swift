//
//  BNMAAdRevenueDelegate.swift
//  AppLovinDecorator
//
//  Created by Stas Kochkin on 05.07.2022.
//

import Foundation
import BidOn
import AppLovinSDK


@objc public protocol BNMAAdRevenueDelegate: AnyObject {
    func didPayRevenue(for ad: Ad)
}
