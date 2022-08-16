//
//  AuctionContoller.swift
//  MobileAdvertising
//
//  Created by Stas Kochkin on 30.06.2022.
//

import Foundation


internal typealias ConcurrentAuction = Auction<ConcurrentAuctionRound>


final class ConcurrentAuctionController: AuctionController {
    var waterfall: Waterfall {
        Waterfall(
            repository
                .ads
                .sorted { comparator.compare($0, $1) }
                .compactMap { repository.demand(for: $0) }
        )
    }
    
    let id: String
    
    private let auction: ConcurrentAuction
    private let comparator: AuctionComparator
    private let adType: AdType
    private let pricefloor: Price
    
    weak var delegate: AuctionControllerDelegate?
    
    private lazy var active = Set<ConcurrentAuctionRound>()
    private lazy var repository = AdsRepository()
    
    private var roundTimer: Timer?
    
    private var currentPrice: Price {
        let current = repository
            .ads
            .sorted { comparator.compare($0, $1) }
            .first?
            .price
        return current ?? pricefloor
    }
    
    init<T>(_ build: (T) -> ()) where T: ConcurrentAuctionControllerBuilder {
        let builder = T()
        build(builder)
        
        self.id = builder.auctionId
        self.delegate = builder.delegate
        self.comparator = builder.comparator
        self.auction = builder.auction
        self.pricefloor = builder.pricefloor
        self.adType = builder.adType
    }
    
    func load() {
        guard active.isEmpty else { return }
        
        repository.clear()
        
        Logger.verbose("\(adType.rawValue.capitalized) auction will perform: \(auction)")
        
        delegate?.controllerDidStartAuction(self)
        auction.root.forEach(perform)
    }
    
    private func provider<T>(for ad: Ad) -> T? {
        return repository.provider(for: ad) as? T
    }
    
    private func finish() {
        Logger.verbose("\(adType.rawValue.capitalized) auction did complete")
        
        active.forEach { $0.cancel() }
        active.removeAll()
        
        let ads = repository.ads.sorted { comparator.compare($0, $1) }
        
        if let winner = ads.first {
            ads.suffix(ads.count - 1).forEach {
                let provider = repository.provider(for: $0)
                provider?.notify(.lose(winner))
            }
            
            let provider = repository.provider(for: winner)
            provider?.notify(.win(winner))
            
            Logger.verbose("\(adType.rawValue.capitalized) auction did found winner: \(winner.description)")
            delegate?.controller(self, completeAuction: winner)
        } else {
            delegate?.controller(self, failedAuction: SdkError.internalInconsistency)
        }
    }
    
    private func perform(round: ConcurrentAuctionRound) {
        let pricefloor = currentPrice
        let adType = self.adType
        
        active.insert(round)
        delegate?.controller(self, didStartRound: round, pricefloor: pricefloor)
        
        if round.timeout.isNormal {
            let timer = Timer.scheduledTimer(withTimeInterval: round.timeout, repeats: false) { _ in
                Logger.warning("\(adType.rawValue.capitalized) auction \(round) execution exceeded timeout.")
                round.cancel()
            }
            RunLoop.current.add(timer, forMode: .default)
            self.roundTimer = timer
        }
        
        Logger.verbose("Perform \(round)")
        round.perform(
            pricefloor: pricefloor,
            demand: { [weak self] result in
                switch result {
                case .success(let demand):
                    self?.receive(demand: demand)
                case .failure(let error):
                    Logger.debug("\(adType.rawValue.capitalized) auction round: \(round) did receive error: \(error)")
                }
            },
            completion: { [weak self] in
                guard let self = self else { return }
                
                Logger.verbose("\(adType.rawValue.capitalized) auction complete round: \(round)")
                
                self.delegate?.controller(self, didCompleteRound: round)
                self.active.remove(round)
                self.roundTimer?.invalidate()
                
                let seeds = self.auction.seeds(of: round)
                if seeds.isEmpty && self.active.isEmpty {
                    self.finish()
                } else {
                    seeds.forEach(self.perform)
                }
            }
        )
    }
    
    private func receive(demand: Demand) {
        guard demand.ad.price > pricefloor else {
            Logger.debug("\(adType.rawValue.capitalized) auction received bid: \(demand.ad.description) price is lower than pricefloor: \(pricefloor)")
            return
        }
        
        Logger.verbose("\(adType.rawValue.capitalized) auction did receive bid: \(demand.ad.description) from \(demand.provider)")
        
        repository.register(demand: demand)
        
        delegate?.controller(
            self,
            didReceiveAd: demand.ad,
            provider: demand.provider
        )
    }
}