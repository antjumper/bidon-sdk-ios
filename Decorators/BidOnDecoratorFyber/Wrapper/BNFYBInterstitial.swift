//
//  BNFYBInterstitial.swift
//  FyberDecorator
//
//  Created by Stas Kochkin on 11.07.2022.
//

import Foundation
import BidOn
import FairBidSDK


@objc public final class BNFYBInterstitial: NSObject {
    private typealias Mediator = FyberInterstitialDemandProvider
    private typealias InterstitialRepository = Repository<String, BNFYBInterstitial>
    
    private static let repository = InterstitialRepository("com.ads.fyber.interstitial.instances.queue")
    
    @objc public static weak var delegate: BNFYBInterstitialDelegate?
    @objc public static weak var auctionDelegate: BNFYBAuctionDelegate?
    
    @objc public static var resolver: AuctionResolver = HigherRevenueAuctionResolver()

    private let placement: String
    
    private var postbid: [InterstitialDemandProvider] {
        FairBid.bn.bidon.interstitialDemandProviders()
    }
    
    private var mediator: Mediator { Mediator(placement: placement) }
    
    private lazy var auction: AuctionController = {
        return try! AuctionControllerBuilder()
            .withAdType(.interstitial)
            .withMediator(mediator)
            .withPostbid(postbid)
            .withDelegate(self)
            .withResolver(BNFYBInterstitial.resolver)
            .build()
    }()
    
    @objc public static func request(_ placement: String) {
        instance(placement).request()
    }
    
    @objc public static func isAvailable(_ placement: String) -> Bool {
        instance(placement).isAvailable()
    }
    
    @objc public static func show(
        _ placement: String,
        options: FYBShowOptions = FYBShowOptions()
    ) {
        instance(placement).show(placement, options: options)
    }
    
    private static func instance(_ placement: String) -> BNFYBInterstitial {
        guard let instance: BNFYBInterstitial = repository[placement] else {
            let instance = BNFYBInterstitial(placement: placement)
            repository[placement] = instance
            return instance
        }
        return instance
    }
    
    private init(placement: String) {
        self.placement = placement
        super.init()
    }
    
    
    private func request() {
        auction.load()
    }
    
    private func isAvailable() -> Bool {
        return !auction.isEmpty
    }
    
    private func show(
        _ placement: String,
        options: FYBShowOptions = FYBShowOptions()
    ) {
        auction.finish { [weak self] provider, ad, error in
            guard let ad = ad else { return }
            guard let provider = provider as? InterstitialDemandProvider else {
                return
            }
            
            provider.delegate = self
            provider._show(ad: ad, from: options.viewController)
        }
    }
}


extension BNFYBInterstitial: AuctionControllerDelegate {
    public func controllerDidStartAuction(_ controller: AuctionController) {
        BNFYBInterstitial.delegate?.interstitialWillRequest(placement)
        BNFYBInterstitial.auctionDelegate?.didStartAuction(placement: placement)
    }
    
    public func controller(
        _ contoller: AuctionController,
        didStartRound round: AuctionRound,
        pricefloor: Price
    ) {
        BNFYBInterstitial.auctionDelegate?.didStartAuctionRound(
            round.id,
            placement: placement,
            pricefloor: pricefloor
        )
    }
    
    public func controller(
        _ controller: AuctionController,
        didReceiveAd ad: Ad,
        provider: DemandProvider
    ) {
        BNFYBInterstitial.auctionDelegate?.didReceiveAd(
            ad,
            placement: placement
        )
    }
    
    public func controller(
        _ contoller: AuctionController,
        didCompleteRound round: AuctionRound
    ) {
        BNFYBInterstitial.auctionDelegate?.didCompleteAuctionRound(
            round.id,
            placement: placement
        )
    }
    
    public func controller(
        _ controller: AuctionController,
        completeAuction winner: Ad
    ) {
        BNFYBInterstitial.delegate?.interstitialIsAvailable(placement)
        BNFYBInterstitial.auctionDelegate?.didCompleteAuction(
            winner,
            placement: placement
        )
    }
    
    public func controller(
        _ controller: AuctionController,
        failedAuction error: Error
    ) {
        BNFYBInterstitial.delegate?.interstitialIsUnavailable(placement)
        BNFYBInterstitial.auctionDelegate?.didCompleteAuction(nil, placement: placement)
    }
}


extension BNFYBInterstitial: DemandProviderDelegate {
    public func provider(_ provider: DemandProvider, didPresent ad: Ad) {
        BNFYBInterstitial.delegate?.interstitialDidShow(placement, impressionData: ad)
    }
    
    public func provider(_ provider: DemandProvider, didHide ad: Ad) {
        BNFYBInterstitial.delegate?.interstitialDidDismiss(placement)
    }
    
    public func provider(_ provider: DemandProvider, didClick ad: Ad) {
        BNFYBInterstitial.delegate?.interstitialDidClick(placement)
    }
    
    public func provider(
        _ provider: DemandProvider,
        didFailToDisplay ad: Ad,
        error: Error
    ) {
        BNFYBInterstitial.delegate?.interstitialDidFail(
            toShow: placement,
            withError: error,
            impressionData: ad
        )
    }
    
    public func provider(_ provider: DemandProvider, didPayRevenueFor ad: Ad) {
        FairBid.bn.trackAdRevenue(
            ad,
            round: auction.auctionRound(for: ad)?.id ?? "",
            adType: .interstitial
        )
    }
}