//
//  FITrackerDetailView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct FITrackerDetailView: View {
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Asset.name) private var assets: [Asset]
    @Query(sort: \Currency.code) private var currencies: [Currency]
    
    private var totalNetworthInINR: Double {
        assets.reduce(0.0) { sum, asset in
            guard let cat = asset.category else { return sum }
            let rate = PortfolioMetrics.currentInrExchangeRate(for: cat, currencies: currencies)
            return sum + PortfolioMetrics.currentValueInINR(for: asset, rate: rate)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                FICalculationCard(currentNetWorth: totalNetworthInINR)
            }
            .padding(20)
        }
        .navigationTitle("Time to FI")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        FITrackerDetailView()
    }
}
