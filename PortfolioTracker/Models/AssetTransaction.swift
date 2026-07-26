//
//  AssetTransaction.swift
//  PortfolioTracker
//

import Foundation
import SwiftData

enum TransactionType: String, Codable, CaseIterable {
    case buy = "BUY"
    case sell = "SELL"
    case dividend = "DIVIDEND"
}

@Model
final class AssetTransaction {
    var type: TransactionType
    var units: Double
    var pricePerUnit: Double
    var date: Date
    var createdAt: Date
    var asset: Asset?
    var broker: Broker?
    var inrExchangeRate: Double?
    
    init(
        type: TransactionType,
        units: Double,
        pricePerUnit: Double,
        date: Date = Date(),
        createdAt: Date = Date(),
        asset: Asset? = nil,
        broker: Broker? = nil,
        inrExchangeRate: Double? = nil
    ) {
        self.type = type
        self.units = units
        self.pricePerUnit = pricePerUnit
        self.date = date
        self.createdAt = createdAt
        self.asset = asset
        self.broker = broker
        self.inrExchangeRate = inrExchangeRate
    }
}
