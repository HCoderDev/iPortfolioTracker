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
    
    // Configurable Transaction extensions
    var rawTypeRaw: String?
    var notes: String?
    
    var rawType: String {
        get {
            if let raw = rawTypeRaw, !raw.isEmpty {
                return raw
            }
            return type.rawValue
        }
        set {
            rawTypeRaw = newValue
            if let legacy = TransactionType(rawValue: newValue) {
                self.type = legacy
            } else if newValue.uppercased().contains("SELL") || newValue.uppercased().contains("WITHDRAWAL") || newValue.uppercased().contains("MATURITY") {
                self.type = .sell
            } else if newValue.uppercased().contains("DIVIDEND") || newValue.uppercased().contains("INTEREST") || newValue.uppercased().contains("BONUS") {
                self.type = .dividend
            } else {
                self.type = .buy
            }
        }
    }
    
    var amount: Double {
        get {
            units * pricePerUnit
        }
        set {
            if units == 0 {
                units = 1.0
            }
            pricePerUnit = newValue / units
        }
    }
    
    var config: TransactionTypeConfig {
        TransactionTypeRegistry.config(for: rawType, holdingType: asset?.holdingType)
    }
    
    init(
        type: TransactionType = .buy,
        rawType: String? = nil,
        units: Double = 1.0,
        pricePerUnit: Double,
        date: Date = Date(),
        notes: String? = nil,
        createdAt: Date = Date(),
        asset: Asset? = nil,
        broker: Broker? = nil,
        inrExchangeRate: Double? = nil
    ) {
        self.type = type
        self.rawTypeRaw = rawType ?? type.rawValue
        self.units = units
        self.pricePerUnit = pricePerUnit
        self.date = date
        self.notes = notes
        self.createdAt = createdAt
        self.asset = asset
        self.broker = broker
        self.inrExchangeRate = inrExchangeRate
    }
}
