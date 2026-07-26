//
//  Asset.swift
//  PortfolioTracker
//

import Foundation
import SwiftData

enum TaxAssetType: String, CaseIterable, Identifiable, Codable {
    case equity = "equity"
    case debt = "debt"
    case other = "other"
    
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .equity: return "Equity (Stocks/MFs)"
        case .debt: return "Debt/Fixed Income"
        case .other: return "Other/Alternate"
        }
    }
}

enum TaxCountry: String, CaseIterable, Identifiable, Codable {
    case india = "India"
    case us = "United States"
    
    var id: String { self.rawValue }
}

enum HoldingType: String, CaseIterable, Identifiable, Codable {
    case investment = "investment"
    case bankBalance = "bankBalance"
    case fixedDeposit = "fixedDeposit"
    
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .investment: return "Investment (Stocks/MF)"
        case .bankBalance: return "Bank Balance"
        case .fixedDeposit: return "Fixed Deposit"
        }
    }
}

@Model
final class Asset {
    var name: String
    var currentPrice: Double
    var category: Category?
    var subCategory: SubCategory?
    
    @Relationship(deleteRule: .cascade, inverse: \AssetTransaction.asset)
    var transactions: [AssetTransaction] = []
    
    @Relationship(deleteRule: .cascade, inverse: \AssetNote.asset)
    var notes: [AssetNote] = []
    
    @Relationship(deleteRule: .cascade, inverse: \StockValueAnalysis.asset)
    var valueAnalysis: StockValueAnalysis?
    
    @Relationship(deleteRule: .cascade, inverse: \StockDCFAnalysis.asset)
    var dcfAnalysis: StockDCFAnalysis?
    
    @Relationship(deleteRule: .cascade, inverse: \AssetReminder.asset)
    var reminders: [AssetReminder] = []
    
    // Tax properties for FIFO Planner (optional for backward compatibility)
    var taxAssetTypeRaw: String? = "equity"
    var taxCountryRaw: String? = nil
    var holdingTypeRaw: String? = "investment"
    
    // Alternate statement names / aliases for automatic import matching
    var aliasesRaw: String? = ""
    
    var aliases: [String] {
        get {
            guard let raw = aliasesRaw, !raw.isEmpty else { return [] }
            return raw.components(separatedBy: "|||")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            aliasesRaw = newValue.joined(separator: "|||")
        }
    }
    
    func addAlias(_ alias: String) {
        let clean = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.localizedCaseInsensitiveCompare(name) != .orderedSame else { return }
        var current = aliases
        if !current.contains(where: { $0.localizedCaseInsensitiveCompare(clean) == .orderedSame }) {
            current.append(clean)
            self.aliases = current
        }
    }
    
    var taxAssetType: TaxAssetType {
        get {
            TaxAssetType(rawValue: taxAssetTypeRaw ?? "equity") ?? .equity
        }
        set {
            taxAssetTypeRaw = newValue.rawValue
        }
    }
    
    var taxCountry: TaxCountry {
        get {
            if let country = taxCountryRaw, let parsed = TaxCountry(rawValue: country) {
                return parsed
            }
            // Smart auto-inference for backward compatibility
            if let categoryCode = category?.currencyCode, categoryCode == "INR" {
                return .india
            } else {
                return .us
            }
        }
        set {
            taxCountryRaw = newValue.rawValue
        }
    }
    
    var holdingType: HoldingType {
        get {
            HoldingType(rawValue: holdingTypeRaw ?? "investment") ?? .investment
        }
        set {
            holdingTypeRaw = newValue.rawValue
        }
    }
    
    init(name: String, currentPrice: Double = 0.0, category: Category? = nil) {
        self.name = name
        self.currentPrice = currentPrice
        self.category = category
        self.taxAssetTypeRaw = "equity"
        self.taxCountryRaw = nil
        self.holdingTypeRaw = "investment"
    }
}
