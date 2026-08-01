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
    case postOffice = "postOffice"
    case epf = "epf"
    case insuranceAnnuity = "insuranceAnnuity"
    
    var id: String { self.rawValue }
    
    var isNonUnitized: Bool {
        self != .investment
    }
    
    var displayName: String {
        switch self {
        case .investment: return "Stocks / Mutual Funds"
        case .bankBalance: return "Bank Balance"
        case .fixedDeposit: return "Fixed Deposit / RD"
        case .postOffice: return "Post Office Scheme (PPF/NSC/MIS)"
        case .epf: return "EPF / Provident Fund"
        case .insuranceAnnuity: return "LIC / Insurance / Annuity"
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
    
    // Metadata for non-unitized assets (FD, EPF, Post Office, LIC)
    var interestRateRaw: Double? = nil
    var principalAmountRaw: Double? = nil
    var maturityDateRaw: Date? = nil
    var payoutFrequencyRaw: String? = nil // "cumulative", "monthly", "quarterly", "annual"
    var premiumAmountRaw: Double? = nil
    var premiumTermYearsRaw: Int? = nil
    var policyNumberRaw: String? = nil
    var institutionNameRaw: String? = nil
    
    // Ticker / Symbol for Stock / MF / US Stock (optional)
    var tickerRaw: String? = ""
    
    var ticker: String {
        get { tickerRaw ?? "" }
        set { tickerRaw = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
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
    
    var interestRate: Double {
        get { interestRateRaw ?? 0.0 }
        set { interestRateRaw = newValue }
    }
    
    var principalAmount: Double {
        get { principalAmountRaw ?? 0.0 }
        set { principalAmountRaw = newValue }
    }
    
    var maturityDate: Date? {
        get { maturityDateRaw }
        set { maturityDateRaw = newValue }
    }
    
    var payoutFrequency: String {
        get { payoutFrequencyRaw ?? "cumulative" }
        set { payoutFrequencyRaw = newValue }
    }
    
    var premiumAmount: Double {
        get { premiumAmountRaw ?? 0.0 }
        set { premiumAmountRaw = newValue }
    }
    
    var premiumTermYears: Int {
        get { premiumTermYearsRaw ?? 0 }
        set { premiumTermYearsRaw = newValue }
    }
    
    var policyNumber: String {
        get { policyNumberRaw ?? "" }
        set { policyNumberRaw = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    var institutionName: String {
        get { institutionNameRaw ?? "" }
        set { institutionNameRaw = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    init(name: String, currentPrice: Double = 0.0, category: Category? = nil, ticker: String? = "") {
        self.name = name
        self.currentPrice = currentPrice
        self.category = category
        self.tickerRaw = ticker
        self.taxAssetTypeRaw = "equity"
        self.taxCountryRaw = nil
        self.holdingTypeRaw = "investment"
    }
}
