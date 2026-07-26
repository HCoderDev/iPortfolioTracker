//
//  CategorySnapshot.swift
//  PortfolioTracker
//

import Foundation
import SwiftData

@Model
final class CategorySnapshot {
    var categoryName: String
    var currencyCode: String
    var investedValue: Double
    var currentValue: Double
    var exchangeRateToINR: Double
    var investedValueINR: Double
    var currentValueINR: Double
    
    var portfolioSnapshot: PortfolioSnapshot?
    
    @Relationship(deleteRule: .cascade, inverse: \AssetSnapshot.categorySnapshot)
    var assetSnapshots: [AssetSnapshot] = []
    
    init(
        categoryName: String,
        currencyCode: String,
        investedValue: Double,
        currentValue: Double,
        exchangeRateToINR: Double,
        investedValueINR: Double,
        currentValueINR: Double,
        portfolioSnapshot: PortfolioSnapshot? = nil
    ) {
        self.categoryName = categoryName
        self.currencyCode = currencyCode
        self.investedValue = investedValue
        self.currentValue = currentValue
        self.exchangeRateToINR = exchangeRateToINR
        self.investedValueINR = investedValueINR
        self.currentValueINR = currentValueINR
        self.portfolioSnapshot = portfolioSnapshot
    }
}
