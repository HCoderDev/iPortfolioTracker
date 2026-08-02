//
//  AssetDetailView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct AssetDetailView: View {
    let asset: Asset
    
    var body: some View {
        if asset.holdingType.isNonUnitized {
            ContractAssetDetailView(asset: asset)
        } else {
            MarketAssetDetailView(asset: asset)
        }
    }
}
