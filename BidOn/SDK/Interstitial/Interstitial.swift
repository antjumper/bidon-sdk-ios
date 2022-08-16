//
//  Interstitial.swift
//  BidOn
//
//  Created by Stas Kochkin on 04.08.2022.
//

import Foundation
import UIKit


@objc(BDInterstitial)
public final class Interstitial: NSObject, FullscreenAd {
    fileprivate enum State {
        case idle
        case preparing
        case auction(controller: AuctionController)
        case loading(controller: WaterfallController)
        case ready(demand: Demand)
        case impression(controller: FullscreenImpressionController)
    }
    
    @Injected(\.networkManager)
    private var networkManager: NetworkManager
    
    @Injected(\.sdk)
    private var sdk: Sdk
       
    private var state: State = .idle
    
    @objc public var delegate: FullscreenAdDelegate?
    
    @objc public let placement: String
    
    @objc public init(placement: String = "") {
        self.placement = placement
        super.init()
    }
    
    @objc public func loadAd() {
        guard state.isIdle else {
            Logger.warning("Trying to load already loading interstitial")
            return
        }
                
        let auctionId: String = UUID().uuidString
        
        let request = AuctionRequest { (builder: InterstitialAuctionRequestBuilder) in
            builder.withPlacement(placement)
            builder.withAdaptersRepository(sdk.adaptersRepository)
            builder.withEnvironmentRepository(sdk.environmentRepository)
            builder.withAuctionId(auctionId)
            builder.withExt(sdk.ext)
        }
        
        networkManager.perform(
            request: request
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let response):
                let auction = ConcurrentAuctionController { (builder: InterstitialConcurrentAuctionControllerBuilder) in
                    builder.withAdaptersRepository(self.sdk.adaptersRepository)
                    builder.withRounds(response.rounds, lineItems: response.lineItems)
                    builder.withPricefloor(response.minPrice)
                    builder.withDelegate(self)
                    builder.withAuctionId(auctionId)
                }
                
                auction.load()
                self.state = .auction(controller: auction)
                
                break
            case .failure(let error):
                self.state = .idle
                self.delegate?.adObject(self, didFailToLoadAd: error)
            }
        }
    }
    
    @objc public func show(from rootViewController: UIViewController) {
        switch state {
        case .ready(let demand):
            let controller = try! FullscreenImpressionController(demand: demand)
            state = .impression(controller: controller)
            controller.delegate = self
            controller.show(from: rootViewController)
        default:
            delegate?.fullscreenAd(self, didFailToPresentAd: SdkError.invalidPresentationState)
        }
    }
}


extension Interstitial: AuctionControllerDelegate {
    func controllerDidStartAuction(_ controller: AuctionController) {}
    
    func controller(
        _ contoller: AuctionController,
        didStartRound round: AuctionRound,
        pricefloor: Price
    ) {
        delegate?.adObject?(
            self,
            didStartAuctionRound: round.id,
            pricefloor: pricefloor
        )
    }
    
    func controller(
        _ controller: AuctionController,
        didReceiveAd ad: Ad,
        provider: DemandProvider
    ) {
        delegate?.adObject?(self, didReceiveBid: ad)
    }
    
    func controller(
        _ contoller: AuctionController,
        didCompleteRound round: AuctionRound
    ) {
        delegate?.adObject?(
            self,
            didCompleteAuctionRound: round.id
        )
    }
    
    func controller(_ controller: AuctionController, completeAuction winner: Ad) {
        delegate?.adObject?(self, didCompleteAuction: winner)
        let waterfall = DefaultWaterfallController(controller.waterfall, timeout: .unknown)
        waterfall.delegate = self
        state = .loading(controller: waterfall)
        waterfall.load()
    }
    
    func controller(_ controller: AuctionController, failedAuction error: Error) {
        state = .idle
        delegate?.adObject?(self, didCompleteAuction: nil)
        delegate?.adObject(self, didFailToLoadAd: error)
    }
}


extension Interstitial: WaterfallControllerDelegate {
    func controller(_ controller: WaterfallController, didLoadDemand demand: Demand) {
        state = .ready(demand: demand)
        delegate?.adObject(self, didLoadAd: demand.ad)
    }
    
    func controller(_ controller: WaterfallController, didFailToLoad error: SdkError) {
        state = .idle
        delegate?.adObject(self, didFailToLoadAd: error)
    }
}


extension Interstitial: FullscreenImpressionControllerDelegate {
    func controller(_ controller: FullscreenImpressionController, didPresent ad: Ad) {
        delegate?.fullscreenAd(self, willPresentAd: ad)
    }
    
    func controller(_ controller: FullscreenImpressionController, didHide ad: Ad) {
        state = .idle
        delegate?.fullscreenAd(self, didDismissAd: ad)
    }
    
    func controller(_ controller: FullscreenImpressionController, didClick ad: Ad) {
        delegate?.adObject?(self, didRecordClick: ad)
    }
    
    func controller(_ controller: FullscreenImpressionController, didFailToDisplay ad: Ad, error: Error) {
        state = .idle
        delegate?.fullscreenAd(self, didFailToPresentAd: error)
    }
}


private extension Interstitial.State {
    var isIdle: Bool {
        switch self {
        case .idle: return true
        default: return false
        }
    }
}