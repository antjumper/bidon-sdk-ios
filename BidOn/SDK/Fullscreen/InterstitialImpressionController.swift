//
//  InterstitialImpressionController.swift
//  BidOn
//
//  Created by Stas Kochkin on 16.08.2022.
//

import Foundation
import UIKit



final class InterstitialImpressionController: NSObject, FullscreenImpressionController {
    typealias Context = UIViewController
    
    weak var delegate: FullscreenImpressionControllerDelegate?
    
    private let provider: InterstitialDemandProvider
    private let impression: Impression
    
    required init(demand: Demand) throws {
        guard let provider = demand.provider as? InterstitialDemandProvider else {
            throw SdkError.internalInconsistency
        }
        
        self.provider = provider
        self.impression = FullscreenImpression(demand: demand)
        
        super.init()
        
        provider.delegate = self
    }
    
    func show(from context: UIViewController) {
        provider.show(ad: impression.ad, from: context)
    }
}


extension InterstitialImpressionController: DemandProviderDelegate {
    func providerWillPresent(_ provider: DemandProvider) {
        delegate?.willPresent(impression)
    }
    
    func providerDidHide(_ provider: DemandProvider) {
        delegate?.didHide(impression)
    }
    
    func providerDidClick(_ provider: DemandProvider) {
        delegate?.didClick(impression)
    }
    
    func providerDidFailToDisplay(_ provider: DemandProvider, error: Error) {
        delegate?.didFailToPresent(impression, error: error)
    }
}
