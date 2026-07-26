//
//  AssetSnapshot.swift
//  PortfolioTracker
//

import Foundation
import SwiftData

@Model
final class AssetSnapshot {
    var assetName: String
    var units: Double
    var currentPrice: Double
    var investedValue: Double
    var currentValue: Double
    var investedValueINR: Double
    var currentValueINR: Double
    
    var categorySnapshot: CategorySnapshot?
    
    init(
        assetName: String,
        units: Double,
        currentPrice: Double,
        investedValue: Double,
        currentValue: Double,
        investedValueINR: Double,
        currentValueINR: Double,
        categorySnapshot: CategorySnapshot? = nil
    ) {
        self.assetName = assetName
        self.units = units
        self.currentPrice = currentPrice
        self.investedValue = investedValue
        self.currentValue = currentValue
        self.investedValueINR = investedValueINR
        self.currentValueINR = currentValueINR
        self.categorySnapshot = categorySnapshot
    }
}
