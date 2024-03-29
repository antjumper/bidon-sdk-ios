//
//  AdContainerView.swift
//  MobileAdvertising
//
//  Created by Bidon Team on 08.07.2022.
//

import Foundation
import UIKit


@objc(BDNBannerView)
public final class BannerView: UIView, AdView {
    @available(*, unavailable)
    @objc public var autorefreshInterval: TimeInterval = 15
    
    @available(*, unavailable)
    @objc public var isAutorefreshing: Bool = false
    
    @objc public let placement: String
    
    @objc public var format: BannerFormat = .banner
    
    @objc public var rootViewController: UIViewController?
    
    @objc public var delegate: AdViewDelegate?
    
    @objc public var isReady: Bool { return adManager.bid != nil }
    
    @objc private(set) public
    lazy var extras: [String : AnyHashable] = [:] {
        didSet {
            adManager.extras = extras
            viewManager.extras = extras
        }
    }
    
    @Injected(\.sdk)
    private var sdk: Sdk
    
    @Injected(\.networkManager)
    private var networkManager: NetworkManager
    
    private var context: AdViewContext {
        return AdViewContext(
            format: format,
            size: format.preferredSize,
            rootViewController: rootViewController
        )
    }
    
    private lazy var viewManager: BannerViewManager = {
        let manager = BannerViewManager()
        manager.container = self
        manager.delegate = self
        return manager
    }()
    
    private lazy var adManager: BannerAdManager = {
        let manager = BannerAdManager()
        manager.delegate = self
        return manager
    }()
    
    @objc
    public init(
        frame: CGRect,
        placement: String = BidonSdk.defaultPlacement
    ) {
        self.placement = placement
        super.init(frame: frame)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc public func setExtraValue(
        _ value: AnyHashable?,
        for key: String
    ) {
        extras[key] = value
    }
    
    @objc public func loadAd(
        with pricefloor: Price = BidonSdk.defaultMinPrice
    ) {
        adManager.loadAd(
            context: context,
            pricefloor: pricefloor
        )
    }
    
    @objc(notifyLossAd:winner:eCPM:)
    public func notify(
        loss ad: Ad,
        winner demandId: String,
        eCPM: Price
    ) {
        guard
            let bid = adManager.bid,
            !viewManager.isImpressionTracked
        else { return }
        
        let impression = AdViewImpression(bid: bid, format: format)
        
        let request = LossRequest { (builder: AdViewLossRequestBuilder) in
            builder.withEnvironmentRepository(sdk.environmentRepository)
            builder.withTestMode(sdk.isTestMode)
            builder.withExt(extras, sdk.extras)
            builder.withImpression(impression)
            builder.withFormat(format)
            builder.withExternalWinner(demandId: demandId, eCPM: eCPM)
        }
        
        networkManager.perform(request: request) { result in
            Logger.debug("Sent loss with result: \(result)")
        }
        
        viewManager.hide()
    }
    
    private final func presentIfNeeded() {
        guard
            let bid = adManager.bid,
            let adView = bid.provider.container(opaque: bid.ad)
        else { return }
        
        Logger.verbose("Banner \(self) will refresh ad view")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.adManager.prepareForReuse()
            self.viewManager.present(
                bid: bid,
                view: adView,
                context: self.context
            )
        }
    }
}


extension BannerView: BannerAdManagerDelegate {
    func adManager(_ adManager: BannerAdManager, didFailToLoad error: SdkError) {
        delegate?.adObject(self, didFailToLoadAd: error.nserror)
    }
    
    func adManager(_ adManager: BannerAdManager, didLoad ad: Ad) {
        delegate?.adObject(self, didLoadAd: ad)
        presentIfNeeded()
    }
    
    func adManager(_ adManager: BannerAdManager, didPayRevenue revenue: AdRevenue, ad: Ad) {
        delegate?.adObject?(self, didPay: revenue, ad: ad)
    }
}


extension BannerView: BannerViewManagerDelegate {
    func viewManager(_ viewManager: BannerViewManager, didRecordImpression ad: Ad) {
        delegate?.adObject?(self, didRecordImpression: ad)
    }
    
    func viewManager(_ viewManager: BannerViewManager, didRecordClick ad: Ad) {
        delegate?.adObject?(self, didRecordClick: ad)
    }
    
    func viewManager(_ viewManager: BannerViewManager, willPresentModalView ad: Ad) {
        delegate?.adView(self, willPresentScreen: ad)
    }
    
    func viewManager(_ viewManager: BannerViewManager, didDismissModalView ad: Ad) {
        delegate?.adView(self, didDismissScreen: ad)
    }
    
    func viewManager(_ viewManager: BannerViewManager, willLeaveApplication ad: Ad) {
        delegate?.adView(self, willLeaveApplication: ad)
    }
}


