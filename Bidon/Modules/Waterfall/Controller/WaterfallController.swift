//
//  WaterfallController.swift
//  Bidon
//
//  Created by Bidon Team on 06.09.2022.
//

import Foundation


protocol WaterfallController {
    associatedtype DemandProviderType: DemandProvider
    associatedtype DemandType: Demand where DemandType.Provider == DemandProviderType

    typealias Completion = (Result<DemandType, SdkError>) -> ()
    
    func load(completion: @escaping Completion)
}