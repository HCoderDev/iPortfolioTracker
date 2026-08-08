//
//  ImportDataModels.swift
//  PortfolioTracker
//

import Foundation
import SwiftData

enum ImportMode: String, CaseIterable, Identifiable {
    case transactions = "Transactions"
    case dividends = "Dividends"
    case bulkExchangeRates = "Bulk Exchange Rates"
    
    var id: String { rawValue }
}

enum TargetField: String, CaseIterable, Identifiable {
    case ignore = "Ignore Column"
    case assetName = "Asset Name"
    case transactionType = "Transaction Type"
    case date = "Transaction Date"
    case amount = "Amount / Payment / Contribution"
    case quantity = "Quantity / Units"
    case price = "Price per Unit / Rate"
    case inrExchangeRate = "INR Exchange Rate"
    case ttBuyRate = "TT Buy Rate"
    case ttSellRate = "TT Sell Rate"
    
    var id: String { rawValue }
    
    var shortName: String {
        switch self {
        case .ignore: return "Ignore"
        case .assetName: return "Asset Name"
        case .transactionType: return "Type"
        case .date: return "Date"
        case .amount: return "Amount"
        case .quantity: return "Quantity"
        case .price: return "Price"
        case .inrExchangeRate: return "INR Rate"
        case .ttBuyRate: return "TT Buy Rate"
        case .ttSellRate: return "TT Sell Rate"
        }
    }
}

enum AssetMappingChoice: Hashable, Equatable {
    case existing(Asset)
    case createNew(String)
    case ignore
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .ignore:
            hasher.combine(0)
        case .createNew(let str):
            hasher.combine(1)
            hasher.combine(str)
        case .existing(let asset):
            hasher.combine(2)
            hasher.combine(asset.persistentModelID)
        }
    }
    
    static func == (lhs: AssetMappingChoice, rhs: AssetMappingChoice) -> Bool {
        switch (lhs, rhs) {
        case (.ignore, .ignore):
            return true
        case (.createNew(let a), .createNew(let b)):
            return a == b
        case (.existing(let a), .existing(let b)):
            return a.persistentModelID == b.persistentModelID
        default:
            return false
        }
    }
}

enum DuplicateStatus: Equatable {
    case none
    case exact(AssetTransaction)
    case fuzzy1Day(AssetTransaction, Date)
    case combined(AssetTransaction, String)
    
    var isDuplicate: Bool {
        switch self {
        case .none: return false
        case .exact, .fuzzy1Day, .combined: return true
        }
    }
    
    var label: String {
        switch self {
        case .none:
            return "New"
        case .exact:
            return "Duplicate (Exact)"
        case .fuzzy1Day(_, let matchDate):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "Duplicate (Shifted: \(formatter.string(from: matchDate)))"
        case .combined(_, let details):
            return "Duplicate (Combined DB: \(details))"
        }
    }
    
    static func == (lhs: DuplicateStatus, rhs: DuplicateStatus) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.exact(let a), .exact(let b)):
            return a.persistentModelID == b.persistentModelID
        case (.fuzzy1Day(let a1, let d1), .fuzzy1Day(let a2, let d2)):
            return a1.persistentModelID == a2.persistentModelID && d1 == d2
        case (.combined(let a1, let s1), .combined(let a2, let s2)):
            return a1.persistentModelID == a2.persistentModelID && s1 == s2
        default:
            return false
        }
    }
}

struct ParsedImportRow: Identifiable {
    let id = UUID()
    let rowIndex: Int
    let rawData: [String]
    
    var date: Date?
    var rawAssetName: String?
    var mappedAsset: Asset?
    var newAssetName: String?
    var units: Double?
    var pricePerUnit: Double?
    var txType: TransactionType?
    var rawTxType: String?
    var inrExchangeRate: Double?
    
    var ttBuyRate: Double?
    var ttSellRate: Double?
    
    var duplicateStatus: DuplicateStatus = .none
    var isSelected: Bool = true
    var validationError: String?
    
    var isValid: Bool {
        validationError == nil
    }
}

struct PostImportReport: Identifiable {
    let id = UUID()
    var totalImportedCount: Int = 0
    var buyCount: Int = 0
    var sellCount: Int = 0
    var dividendCount: Int = 0
    var newAssetsCreatedCount: Int = 0
    
    var totalBuyValue: Double = 0.0
    var totalSellValue: Double = 0.0
    var totalDividendValue: Double = 0.0
    var netFlowValue: Double { totalBuyValue - totalSellValue }
    
    var categoryName: String = ""
    var currencyCode: String = "INR"
    var currencySymbol: String = "₹"
    
    var rawTypeCounts: [String: Int] = [:]
    var rawTypeTotals: [String: Double] = [:]
    
    var insertedTransactionIDs: [PersistentIdentifier] = []
    var insertedAssetIDs: [PersistentIdentifier] = []
    
    struct AssetImpact: Identifiable {
        let id = UUID()
        let assetName: String
        var buyUnits: Double = 0.0
        var sellUnits: Double = 0.0
        var buyValue: Double = 0.0
        var sellValue: Double = 0.0
        var buyCount: Int = 0
        var sellCount: Int = 0
        var dividendCount: Int = 0
        var dividendValue: Double = 0.0
        
        var rawTypeCounts: [String: Int] = [:]
        var rawTypeTotals: [String: Double] = [:]
        
        var netUnits: Double { buyUnits - sellUnits }
        var netValue: Double { buyValue - sellValue }
    }
    
    var assetImpacts: [AssetImpact] = []
}
