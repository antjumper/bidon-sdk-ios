//
//  EnvironmentRepository.swift
//  BidOn
//
//  Created by Stas Kochkin on 05.08.2022.
//

import Foundation


internal typealias EnvironmentRepository = Repository<EnvironmentType, Environment>


extension EnvironmentRepository {
    convenience init() {
        self.init("com.ads.adapters-repository.queue")
        self[.device] = DeviceManager()
    }
}



