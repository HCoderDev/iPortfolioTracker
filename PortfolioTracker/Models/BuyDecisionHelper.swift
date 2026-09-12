//
//  BuyDecisionHelper.swift
//  PortfolioTracker
//

import Foundation
import SwiftData
import SwiftUI

enum BuyDecisionRating: String, CaseIterable, Identifiable, Codable {
    case strongBuy = "Strong Buy"
    case buy = "Buy"
    case accumulate = "Accumulate"
    case hold = "Hold"
    case avoidSell = "Avoid / Sell"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .strongBuy: return .green
        case .buy: return AppTheme.gain
        case .accumulate: return .blue
        case .hold: return .orange
        case .avoidSell: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .strongBuy: return "flame.fill"
        case .buy: return "cart.fill.badge.plus"
        case .accumulate: return "chart.line.uptrend.xyaxis"
        case .hold: return "pause.fill"
        case .avoidSell: return "exclamationmark.triangle.fill"
        }
    }
}

@Model
final class BuyDecisionHelper {
    var id: UUID
    var name: String
    var ticker: String
    var currentPrice: Double
    var currencyCode: String
    var notes: String
    var updatedAt: Date
    
    // Target price thresholds (upper bounds for rating bands)
    var strongBuyPrice: Double
    var buyPrice: Double
    var accumulatePrice: Double
    var holdPrice: Double
    var avoidPrice: Double
    
    @Relationship(deleteRule: .nullify) var asset: Asset?
    
    init(
        id: UUID = UUID(),
        name: String = "",
        ticker: String = "",
        currentPrice: Double = 0.0,
        currencyCode: String = "USD",
        notes: String = "",
        strongBuyPrice: Double = 0.0,
        buyPrice: Double = 0.0,
        accumulatePrice: Double = 0.0,
        holdPrice: Double = 0.0,
        avoidPrice: Double = 0.0,
        asset: Asset? = nil
    ) {
        self.id = id
        self.name = name
        self.ticker = ticker
        self.currentPrice = currentPrice
        self.currencyCode = currencyCode
        self.notes = notes
        self.updatedAt = Date()
        self.strongBuyPrice = strongBuyPrice
        self.buyPrice = buyPrice
        self.accumulatePrice = accumulatePrice
        self.holdPrice = holdPrice
        self.avoidPrice = avoidPrice
        self.asset = asset
    }
    
    var activeName: String {
        asset?.name ?? (name.isEmpty ? "Unnamed Entry" : name)
    }
    
    var activeTicker: String {
        asset?.ticker ?? ticker
    }
    
    var activePrice: Double {
        asset?.currentPrice ?? currentPrice
    }
    
    var activeCurrencyCode: String {
        asset?.category?.currencyCode ?? (currencyCode.isEmpty ? "USD" : currencyCode)
    }
    
    var currencySymbol: String {
        switch activeCurrencyCode.uppercased() {
        case "INR": return "₹"
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        default: return "$"
        }
    }
    
    var currentRating: BuyDecisionRating {
        let cmp = activePrice
        guard cmp > 0 else { return .hold }
        
        if strongBuyPrice > 0 && cmp <= strongBuyPrice {
            return .strongBuy
        } else if buyPrice > 0 && cmp <= buyPrice {
            return .buy
        } else if accumulatePrice > 0 && cmp <= accumulatePrice {
            return .accumulate
        } else if holdPrice > 0 && cmp <= holdPrice {
            return .hold
        } else {
            return .avoidSell
        }
    }
}
