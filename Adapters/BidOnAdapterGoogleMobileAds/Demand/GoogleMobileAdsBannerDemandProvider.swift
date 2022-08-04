//
//  GoogleMobileAdsBannerDemandProvider.swift
//  GoogleMobileAdsAdapter
//
//  Created by Stas Kochkin on 08.07.2022.
//

import Foundation
import BidOn
import GoogleMobileAds
import UIKit


internal final class GoogleMobileAdsBannerDemandProvider: NSObject {
    private let item: (Price) -> LineItem?
    private let context: AdViewContext
    
    private var response: DemandProviderResponse?
    private var _item: LineItem?
    
    private lazy var banner: GADBannerView = {
        let banner = GADBannerView(adSize: context.adSize)
        banner.delegate = self
        banner.paidEventHandler = { [weak self] _ in
            guard
                let self = self,
                let wrapped = self.wrapped(ad: self.banner)
            else { return }
            
            self.delegate?.provider(self, didPayRevenueFor: wrapped)
        }
        return banner
    }()
    
    weak var delegate: DemandProviderDelegate?
    weak var adViewDelegate: DemandProviderAdViewDelegate?

    init(
        context: AdViewContext,
        item: @escaping (Price) -> LineItem?
    ) {
        self.context = context
        self.item = item
        super.init()
    }
}


extension GoogleMobileAdsBannerDemandProvider: AdViewDemandProvider {
    func request(
        pricefloor: Price,
        response: @escaping DemandProviderResponse
    ) {
        guard let item = item(pricefloor) else {
            response(nil, SdkError.message("Line item was not found for pricefloor \(pricefloor)"))
            return
        }
        
        self.response = response
        self._item = item
        
        let request = GADRequest()
        banner.adUnitID = item.adUnitId
        banner.rootViewController = context.rootViewController
        
        banner.load(request)
    }

    func notify(_ event: AuctionEvent) {}
    
    func cancel() {
        response?(nil, SdkError.cancelled)
        response = nil
    }
    
    func adView(for ad: Ad) -> AdView? {
        return banner
    }
    
    private func wrapped(ad: GADBannerView) -> Ad? {
        guard
            banner === ad,
            let item = _item
        else { return nil }
        
        return BNGADResponseInfoWrapper(
            ad,
            item: item
        )
    }
}


extension GoogleMobileAdsBannerDemandProvider: GADBannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        guard let wrapped = wrapped(ad: bannerView) else { return }
        response?(wrapped, nil)
        response = nil
    }
    
    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        guard wrapped(ad: bannerView) != nil else { return }
        response?(nil, SdkError(error))
    }
    
    func bannerViewWillPresentScreen(_ bannerView: GADBannerView) {
        guard let wrapped = wrapped(ad: bannerView) else { return }
        adViewDelegate?.provider(self, willPresentModalView: wrapped)
    }
    
    func bannerViewDidDismissScreen(_ bannerView: GADBannerView) {
        guard let wrapped = wrapped(ad: bannerView) else { return }
        adViewDelegate?.provider(self, didDismissModalView: wrapped)
    }
    
    func bannerViewDidRecordClick(_ bannerView: GADBannerView) {
        guard let wrapped = wrapped(ad: bannerView) else { return }
        delegate?.provider(self, didClick: wrapped)
    }
}


extension AdViewContext {
    var adSize: GADAdSize {
        switch (format, isAdaptive) {
        case (.mrec, _): return GADAdSizeMediumRectangle
        case (.banner, false): return GADAdSizeBanner
        case (.leaderboard, false): return GADAdSizeLeaderboard
        default: return GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
        }
    }
    
    private var window: UIWindow? {
        if let windon = rootViewController?.view.window {
            return windon
        }
            
        if #available(iOS 15, *) {
            return UIApplication
                .shared
                .connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .compactMap { $0 as? UIWindowScene }
                .first?
                .windows
                .first
        } else {
            return UIApplication
                .shared
                .windows
                .first
        }
    }
    
    private var width: CGFloat {
        guard let window = window else { return 0 }
        if #available(iOS 11, *) {
            return window.bounds.inset(by: window.safeAreaInsets).width
        } else {
            return window.bounds.width
        }
    }
}


extension GADBannerView: AdView {
    public var isAdaptive: Bool { return true }
}