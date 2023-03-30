//
//  MediationObserver.swift
//  Bidon
//
//  Created by Bidon Team on 31.08.2022.
//

import Foundation


fileprivate struct DemandObservation {
    var networkId: String
    var roundId: String
    var adUnitId: String?
    var adId: String? = nil
    var status: DemandReportStatus = .unknown
    var eCPM: Price = .unknown
    var isRoundWinner: Bool = false
    var isAuctionWinner: Bool = false
    var bidRequestTimestamp: TimeInterval? = Date.timestamp(.wall, units: .milliseconds)
    var bidResponeTimestamp: TimeInterval?
    var fillRequestTimestamp: TimeInterval?
    var fillResponseTimestamp: TimeInterval?
}


fileprivate struct RoundObservation {
    var roundId: String
    var pricefloor: Price
}


final class BaseMediationObserver: MediationObserver {
    let auctionId: String
    let auctionConfigurationId: Int
    let adType: AdType
        
    var report: MediationAttemptReportModel {
        let rounds: [RoundReportModel] = roundObservations.map { round in
            let demands = demandObservations
                .filter { $0.roundId == round.roundId }
            
            let winner = demands.first { $0.isRoundWinner }
            
            return RoundReportModel(
                roundId: round.roundId,
                pricefloor: round.pricefloor,
                winnerECPM: winner?.eCPM,
                winnerNetworkId: winner?.networkId,
                demands: demands.map { DemandReportModel($0) }
            )
        }
        
        let winner = demandObservations.first { $0.isAuctionWinner }
        let result = AuctionResultReportModel(
            status: winner != nil ? .success : .fail,
            winnerNetworkId: winner?.networkId,
            winnerECPM: winner?.eCPM,
            winnerAdUnitId: winner?.adUnitId
        )
        
        return MediationAttemptReportModel(
            auctionId: auctionId,
            auctionConfigurationId: auctionConfigurationId,
            rounds: rounds,
            result: result
        )
    }
    
    @Atomic
    private var demandObservations: [DemandObservation] = []
    
    @Atomic
    private var roundObservations: [RoundObservation] = []
    
    @Atomic
    private(set) var firedLineItems: [LineItem] = []
    
    init(
        auctionId id: String,
        auctionConfigurationId configurationId: Int,
        adType: AdType
    ) {
        self.adType = adType
        self.auctionId = id
        self.auctionConfigurationId = configurationId
    }
    
    func log(_ event: MediationEvent) {
        Logger.debug("[\(adType)] [Auction: \(auctionId)] " + event.description)
        
        switch event {
        case .roundStart(let round, let pricefloor):
            roundObservations.append(
                RoundObservation(
                    roundId: round.id,
                    pricefloor: pricefloor
                )
            )
        case .bidRequest(let round, let adapter, let lineItem):
            lineItem.map { self.firedLineItems.append($0) }
            demandObservations.append(
                DemandObservation(
                    networkId: adapter.identifier,
                    roundId: round.id,
                    adUnitId: lineItem?.adUnitId
                )
            )
        case .bidResponse(let round, let adapter, let bid):
            demandObservations.update(
                condition: { $0.roundId == round.id && $0.networkId == adapter.identifier }
            ) { observation in
                observation.adId = bid.ad.id
                observation.eCPM = bid.eCPM
                observation.bidResponeTimestamp = Date.timestamp(.wall, units: .milliseconds)
            }
        case .bidError(let round, let adapter, let error):
            demandObservations.update(
                condition: { $0.roundId == round.id && $0.networkId == adapter.identifier }
            ) { observation in
                observation.status = DemandReportStatus(error)
                observation.bidResponeTimestamp = Date.timestamp(.wall, units: .milliseconds)
            }
        case .roundFinish(_, let winner):
            if let winner = winner {
                demandObservations.update(
                    condition: { $0.adId == winner.ad.id }
                ) { observation in
                    observation.isRoundWinner = true
                }
            }
        case .fillRequest(let bid):
            demandObservations.update(
                condition: { $0.adId == bid.ad.id }
            ) { observation in
                observation.fillRequestTimestamp = Date.timestamp(.wall, units: .milliseconds)
            }
        case .fillResponse(let bid):
            demandObservations.update(
                condition: { $0.adId == bid.ad.id }
            ) { observation in
                observation.fillResponseTimestamp = Date.timestamp(.wall, units: .milliseconds)
                observation.status = .win
                observation.isAuctionWinner = true
            }
            demandObservations.update(
                condition: { $0.adId != bid.ad.id && $0.status.isUnknown }
            ) { observation in
                observation.status = .lose
            }
        case .fillError(let bid, let error):
            demandObservations.update(
                condition: { $0.adId == bid.ad.id }
            ) { observation in
                observation.fillResponseTimestamp = Date.timestamp(.wall, units: .milliseconds)
                observation.status = DemandReportStatus(error)
            }
        default:
            break
        }
    }
}


private extension DemandReportModel {
    init(_ observation: DemandObservation) {
        self.networkId = observation.networkId
        self.adUnitId = observation.adUnitId
        self.eCPM = observation.eCPM
        self.status = observation.status
        self.bidStartTimestamp = observation.bidRequestTimestamp?.uint
        self.bidFinishTimestamp = observation.bidResponeTimestamp?.uint
        self.fillStartTimestamp = observation.fillRequestTimestamp?.uint
        self.fillFinishTimestamp = observation.fillResponseTimestamp?.uint
    }
}


private extension Array where Element == DemandObservation {
    mutating func update(
        condition: (Element) -> Bool,
        mutation: (inout Element) -> ()
    ) {
        self = map { element in
            guard condition(element) else { return element }
            var element = element
            mutation(&element)
            return element
        }
    }
}