//
//  BannerManager.swift
//  BidOn
//
//  Created by Stas Kochkin on 26.08.2022.
//

import Foundation
import UIKit


protocol BannerAdManagerDelegate: AuctionControllerDelegate {
    func didFailToLoad(_ error: Error)
    func didLoad(_ ad: Ad)
}

final class BannerAdManager: NSObject {
    fileprivate enum State {
        case idle
        case preparing
        case auction(controller: AuctionController)
        case loading(controller: WaterfallController)
        case ready(demand: Demand)
    }
    
    @Injected(\.networkManager)
    private var networkManager: NetworkManager
    
    @Injected(\.sdk)
    private var sdk: Sdk
    
    private var state: State = .idle
    
    let placement: String
    
    weak var delegate: BannerAdManagerDelegate?
    
    init(placement: String = "") {
        self.placement = placement
        super.init()
    }
    
    var demand: Demand? {
        switch state {
        case .ready(let demand): return demand
        default: return nil
        }
    }
    
    func prepareForReuse() {
        state = .idle
    }
    
    func loadAd(context: AdViewContext) {
        guard state.isIdle else {
            Logger.warning("Banner ad manager is not idle. Loading attempt is prohibited.")
            return
        }
        
        state = .preparing
        
        let auctionId: String = UUID().uuidString
        
        let request = AuctionRequest { (builder: AdViewAuctionRequestBuilder) in
            builder.withPlacement(placement)
            builder.withAdaptersRepository(sdk.adaptersRepository)
            builder.withEnvironmentRepository(sdk.environmentRepository)
            builder.withAuctionId(auctionId)
            builder.withExt(sdk.ext)
        }
        
        Logger.verbose("Banner ad manager performs request: \(request)")
        
        networkManager.perform(
            request: request
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let response):
                Logger.verbose("Banner ad manager performs request: \(request)")
                
                let auction = ConcurrentAuctionController { (builder: AdViewConcurrentAuctionControllerBuilder) in
                    builder.withAdaptersRepository(self.sdk.adaptersRepository)
                    builder.withRounds(response.rounds, lineItems: response.lineItems)
                    builder.withPricefloor(response.minPrice)
                    builder.withDelegate(self)
                    builder.withContext(context)
                    builder.withAuctionId(auctionId)
                }
                
                auction.load()
                self.state = .auction(controller: auction)
                
                break
            case .failure(let error):
                self.state = .idle
                Logger.warning("Banner ad manager did fail to load ad with error: \(error)")
            }
        }
    }
}


extension BannerAdManager: AuctionControllerDelegate {
    func controllerDidStartAuction(_ controller: AuctionController) {
        delegate?.controllerDidStartAuction(controller)
    }
    
    func controller(_ controller: AuctionController, didStartRound round: AuctionRound, pricefloor: Price) {
        delegate?.controller(controller, didStartRound: round, pricefloor: pricefloor)
    }
    
    func controller(_ controller: AuctionController, didReceiveAd ad: Ad, provider: DemandProvider) {
        delegate?.controller(controller, didReceiveAd: ad, provider: provider)
    }
    
    func controller(_ controller: AuctionController, didCompleteRound round: AuctionRound) {
        delegate?.controller(controller, didCompleteRound: round)
    }
    
    func controller(_ controller: AuctionController, completeAuction winner: Ad) {
        let waterfall = DefaultWaterfallController(
            controller.waterfall,
            timeout: .unknown
        )
        
        state = .loading(controller: waterfall)

        waterfall.delegate = self
        waterfall.load()
        
        delegate?.controller(controller, completeAuction: winner)
    }
    
    func controller(_ controller: AuctionController, failedAuction error: Error) {
        delegate?.controller(controller, failedAuction: error)
    }
}


extension BannerAdManager: WaterfallControllerDelegate {
    func controller(_ controller: WaterfallController, didLoadDemand demand: Demand) {
        state = .ready(demand: demand)
        delegate?.didLoad(demand.ad)
    }
    
    func controller(_ controller: WaterfallController, didFailToLoad error: SdkError) {
        state = .idle
        delegate?.didFailToLoad(error)
    }
}


private extension BannerAdManager.State {
    var isIdle: Bool {
        switch self {
        case .idle: return true
        default: return false
        }
    }
}
