//
//  AdEvent.swift
//  AppLovinMAX-Demo
//
//  Created by Stas Kochkin on 07.07.2022.
//

import Foundation
import SwiftUI
import MobileAdvertising


enum AdEvent {
    case didStartAuction
    case didStartAuctionRound(id: String, pricefloor: Price)
    case didCompleteAuctionRound(id: String)
    case didCompleteAuction(ad: Ad?)
    case didReceive(ad: Ad)
    case didLoad(ad: Ad)
    case didFail(id: String, error: Error)
    case didDisplay(ad: Ad)
    case didHide(ad: Ad)
    case didClick(ad: Ad)
    case didDisplayFail(ad: Ad, error: Error)
    case didPay(ad: Ad)
    case didGenerateCreativeId(id: String, ad: Ad)
    case didReward(ad: Ad, reward: Reward)
    case didExpand(ad: Ad)
    case didCollapse(ad: Ad)
}


extension AdEvent {
    var title: Text {
        switch self {
        case .didStartAuction:
            return Text("The auction has been started")
        case .didStartAuctionRound(let id, _):
            return Text("A round of auction ") + Text("\"\(id)\"").bold() + Text(" has been launched")
        case .didCompleteAuctionRound(let id):
            return Text("Auction round ") + Text("\"\(id)\"").bold() + Text(" has been ended")
        case .didCompleteAuction:
            return Text("The auction has ended")
        case .didReceive:
            return Text("An ad was received")
        case .didLoad:
            return Text("Ad is ready to show")
        case .didFail:
            return Text("No ad is ready for show")
        case .didDisplay:
            return Text("The ad was shown")
        case .didPay:
            return Text("Revenue was received from an ad")
        case .didHide:
            return Text("The ad did hide")
        case .didClick:
            return Text("The Ad has been clicked")
        case .didDisplayFail:
            return Text("An attempt to display ads was unsuccessful")
        case .didGenerateCreativeId:
            return Text("The ad did generate creative id")
        case .didReward(_, let reward):
            return Text("The ad did receive reward: ") + Text("\"\(reward.amount)\"").bold() + Text(" of ") + Text(reward.label).bold()
        case .didExpand:
            return Text("The ad did expand")
        case .didCollapse:
            return Text("The ad did collapse")
        }
    }
    
    var subtitle: Text {
        let text: String
        switch self {
        case .didStartAuction:
            text = ""
        case .didStartAuctionRound(_, let pricefloor):
            text = "Pricefloor: \(pricefloor.pretty)"
        case .didCompleteAuctionRound:
            text = ""
        case .didCompleteAuction:
            text = ""
        case .didPay(let ad):
            text = ad.text
        case .didReward(let ad, _):
            text = ad.text
        case .didHide(let ad):
            text = ad.text
        case .didClick(let ad):
            text = ad.text
        case .didLoad(let ad):
            text = ad.text
        case .didExpand(let ad):
            text = ad.text
        case .didCollapse(let ad):
            text = ad.text
        case .didReceive(let ad):
            text = ad.text
        case .didDisplay(ad: let ad):
            text = ad.text
        case .didGenerateCreativeId(let id, let ad):
            text = "CID: \(id), \(ad)"
        case .didDisplayFail(_, let error):
            text = error.localizedDescription
        case .didFail(_, let error):
            text =  error.localizedDescription
        }
        
        return Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    var bage: some View {
        switch self {
        case .didStartAuction, .didCompleteAuction, .didStartAuctionRound, .didCompleteAuctionRound:
            return Image(systemName: "bolt")
                .foregroundColor(.orange)
        case .didReceive:
            return Image(systemName: "cart")
                .foregroundColor(.blue)
        case .didGenerateCreativeId:
            return Image(systemName: "magnifyingglass")
                .foregroundColor(.purple)
        case .didPay:
            return Image(systemName: "banknote")
                .foregroundColor(.green)
        default:
            return Image(systemName: "arrow.down")
                .foregroundColor(.primary)
        }
    }
}


private extension Price {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
    
    var pretty: String {
        isUnknown ? "-" : Price.formatter.string(from: self as NSNumber) ?? "-"
    }
}


extension Ad {
    var text: String {
        "Ad #\(id.prefix(3))... from \(dsp), price: \(price.pretty)"
    }
}

