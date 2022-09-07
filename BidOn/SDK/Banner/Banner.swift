//
//  AdContainerView.swift
//  MobileAdvertising
//
//  Created by Stas Kochkin on 08.07.2022.
//

import Foundation
import UIKit


@objc(BDBanner)
public final class Banner: UIView, AdView {
    @objc public var autorefreshInterval: TimeInterval = 15 {
        didSet { scheduleRefreshIfNeeded() }
    }
    
    @objc public var isAutorefreshing: Bool = true {
        didSet {
            isAutorefreshing ?
            scheduleRefreshIfNeeded() :
            viewManager.cancelRefreshTimer()
        }
    }
    
    @objc public var format: AdViewFormat = .banner
    
    @objc public var rootViewController: UIViewController?
    
    @objc public var delegate: AdViewDelegate?
    
    @Injected(\.sdk)
    private var sdk: Sdk
    
    @Injected(\.networkManager)
    private var networkManager: NetworkManager
    
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
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    final override public func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        refreshIfNeeded()
    }
    
    @objc public func loadAd() {
        let ctx = AdViewContext(
            format: format,
            size: format.preferredSize,
            isAdaptive: true,
            rootViewController: rootViewController
        )
        
        adManager.loadAd(context: ctx)
    }
    
    private final func refreshIfNeeded() {
        guard
            let demand = adManager.demand,
            let adView = demand.provider.container(for: demand.ad)
        else { return }
        
        if viewManager.isRefreshGranted || !viewManager.isAdPresented {
            Logger.verbose("Banner \(self) will refresh ad view")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.viewManager.present(
                    demand: demand,
                    view: adView,
                    size: self.format.preferredSize
                )
            }
        }
    }
    
    private final func scheduleRefreshIfNeeded() {
        guard isAutorefreshing, autorefreshInterval > 0, viewManager.isRefreshGranted else { return }
        weak var weakSelf = self
        
        Logger.verbose("Banner \(self) did start refresh timer with interval: \(autorefreshInterval)s")
        
        adManager.prepareForReuse()
        viewManager.schedule(autorefreshInterval, block: weakSelf?.refreshIfNeeded)
        
        loadAd()
    }
}


extension Banner: BannerAdManagerDelegate {
    func adManager(_ adManager: BannerAdManager, didFailToLoad error: SdkError) {
        delegate?.adObject(self, didFailToLoadAd: error)
    }
    
    func adManager(_ adManager: BannerAdManager, didLoad demand: AdViewDemand) {
        delegate?.adObject(self, didLoadAd: demand.ad)
        refreshIfNeeded()
    }
    
    func adManagerDidStartAuction(_ adManager: BannerAdManager) {
        delegate?.adObjectDidStartAuction?(self)
        
    }
    
    func adManager(_ adManager: BannerAdManager, didStartAuctionRound round: AuctionRound, pricefloor: Price) {
        delegate?.adObject?(
            self,
            didStartAuctionRound: round.id,
            pricefloor: pricefloor
        )
    }

    func adManager(
        _ adManager: BannerAdManager,
        didReceiveBid ad: Ad,
        provider: DemandProvider
    ) {
        provider.revenueDelegate = self
        delegate?.adObject?(self, didReceiveBid: ad)
    }
    
    func adManager(_ adManager: BannerAdManager, didCompleteAuctionRound round: AuctionRound) {
        delegate?.adObject?(self, didCompleteAuctionRound: round.id)
    }

    func adManager(_ adManager: BannerAdManager, didCompleteAuction winner: Ad?) {
        delegate?.adObject?(self, didCompleteAuction: winner)
    }
}


extension Banner: BannerViewManagerDelegate {
    func viewManager(_ viewManager: BannerViewManager, didRecordImpression impression: Impression) {
        networkManager.perform(request: ImpressionRequest { builder in
            builder.withEnvironmentRepository(sdk.environmentRepository)
            builder.withExt(sdk.ext)
            builder.withImpression(impression)
        }) { result in
            Logger.debug("Sent show with result: \(result)")
        }
        
        scheduleRefreshIfNeeded()
        delegate?.adObject?(self, didRecordImpression: impression.ad)
    }
    
    func viewManager(_ viewManager: BannerViewManager, didRecordClick impression: Impression) {
        delegate?.adObject?(self, didRecordClick: impression.ad)
    }
    
    func viewManager(_ viewManager: BannerViewManager, willPresentModalView impression: Impression) {
        delegate?.adView(self, willPresentScreen: impression.ad)
    }
    
    func viewManager(_ viewManager: BannerViewManager, didDismissModalView impression: Impression) {
        delegate?.adView(self, didDismissScreen: impression.ad)
    }
    
    func viewManager(_ viewManager: BannerViewManager, willLeaveApplication impression: Impression) {
        delegate?.adView(self, willLeaveApplication: impression.ad)
    }
}


extension Banner: DemandProviderRevenueDelegate {
    public func provider(
        _ provider: DemandProvider,
        didPayRevenueFor ad: Ad
    ) {
        delegate?.adObject?(self, didPayRevenue: ad)
        sdk.trackAdRevenue(ad, adType: .banner)
    }
}

