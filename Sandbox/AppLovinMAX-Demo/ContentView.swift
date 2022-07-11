//
//  ContentView.swift
//  AppLovinMAX-Demo
//
//  Created by Stas Kochkin on 28.06.2022.
//

import SwiftUI
import Combine
import AppLovinDecorator


struct ContentView: View {
    @EnvironmentObject var app: ApplicationDelegate
    
    var body: some View {
        if app.isInitialized {
            HomeView()
        } else {
            LogoProgressView()
        }
    }
}


fileprivate struct LogoProgressView: View {
    var body: some View {
        if #available(iOS 15, *) {
            content.foregroundStyle(
                LinearGradient(
                    colors: [.blue, .purple, .red],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
            )
        } else {
            content.foregroundColor(.red)
        }
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .imageScale(.large)
            ZStack {
                Text("AppLovin MAX ❤️ Bidon")
                    .font(Font.system(
                        size: 16,
                        weight: .heavy,
                        design: .monospaced
                    ))
                    .offset(x: 0.5, y: 0.5)
                Text("AppLovin MAX ❤️ Bidon")
                    .foregroundColor(.primary)
                    .font(Font.system(
                        size: 16,
                        weight: .heavy,
                        design: .monospaced
                    ))
            }
            ProgressView()
                .progressViewStyle(.circular)
        }
    }
}


final class ContentViewModel: ObservableObject {
    private lazy var interstitial: BNMAInterstitialAd = {
        let interstitial = BNMAInterstitialAd(
            adUnitIdentifier: "YOUR_AD_UNIT_ID",
            sdk: applovin
        )
        return interstitial
    }()
    
    func appear() {
        interstitial.loadAd()
    }
    
    func present() {
        interstitial.show()
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
