//
//  File.swift
//  Bidon
//
//  Created by Bidon Team on 09.08.2022.
//

import Foundation


struct ConfigurationRequest: Request {
    var route: Route = .config
    var method: HTTPTask.HTTPMethod = .post
    var headers: [HTTPTask.HTTPHeader: String] = .default()
    var timeout: TimeInterval = 10
    var body: RequestBody?
    
    struct RequestBody: Encodable, Tokenized {
        var device: DeviceModel?
        var session: SessionModel?
        var app: AppModel?
        var user: UserModel?
        var geo: GeoModel?
        var ext: String?
        var test: Bool
        var token: String?
        var segmentId: String?
        var adapters: AdaptersInfo
    }
    
    struct ResponseBody: Decodable, Tokenized {
        var adaptersInitializationParameters: AdaptersInitialisationParameters
        var token: String?
        var segmentId: String?

        enum CodingKeys: String, CodingKey {
            case adaptersInitializationParameters = "init"
            case token = "token"
            case segmentId = "segment_id"
        }
    }
    
    init(_ build: (ConfigurationRequestBuilder) -> ()) {
        let builder = ConfigurationRequestBuilder()
        build(builder)
        
        self.body = RequestBody(
            device: builder.device,
            session: builder.session,
            app: builder.app,
            user: builder.user,
            geo: builder.geo,
            ext: builder.encodedExt,
            test: builder.testMode,
            adapters: builder.adapters
        )
    }
}
