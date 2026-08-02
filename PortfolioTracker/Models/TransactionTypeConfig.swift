//
//  TransactionTypeConfig.swift
//  PortfolioTracker
//

import Foundation

enum CashDirection: String, Codable, CaseIterable {
    case outflow   // Cash leaves user's pocket into asset (e.g. Deposit, Buy, Premium)
    case inflow    // Cash enters user's pocket from asset (e.g. Withdrawal, Maturity, Dividend)
    case internalAccrual  // No external cash flow across boundary (e.g. Interest credited, Bonus added)
    
    var displayName: String {
        switch self {
        case .outflow: return "Outflow (Invested)"
        case .inflow: return "Inflow (Payout)"
        case .internalAccrual: return "Internal Accrual"
        }
    }
}

struct TransactionTypeConfig: Identifiable, Equatable, Hashable, Codable {
    var id: String
    var rawType: String
    var displayName: String
    var iconName: String
    var cashDirection: CashDirection
    var affectsInvestedAmount: Bool
    var affectsAssetValue: Bool
    var affectsProfit: Bool
    var closesAsset: Bool
    var isUnitBased: Bool
    var notesPrompt: String?
    
    init(
        id: String,
        rawType: String,
        displayName: String,
        iconName: String = "dollarsign.circle",
        cashDirection: CashDirection,
        affectsInvestedAmount: Bool,
        affectsAssetValue: Bool,
        affectsProfit: Bool,
        closesAsset: Bool = false,
        isUnitBased: Bool = false,
        notesPrompt: String? = nil
    ) {
        self.id = id
        self.rawType = rawType
        self.displayName = displayName
        self.iconName = iconName
        self.cashDirection = cashDirection
        self.affectsInvestedAmount = affectsInvestedAmount
        self.affectsAssetValue = affectsAssetValue
        self.affectsProfit = affectsProfit
        self.closesAsset = closesAsset
        self.isUnitBased = isUnitBased
        self.notesPrompt = notesPrompt
    }
}

struct InvestmentTypeConfig {
    let holdingType: HoldingType
    let displayName: String
    let defaultTransactionType: String
    let isUnitized: Bool
    let allowedTransactions: [TransactionTypeConfig]
    
    init(
        holdingType: HoldingType,
        displayName: String,
        defaultTransactionType: String,
        isUnitized: Bool,
        allowedTransactions: [TransactionTypeConfig]
    ) {
        self.holdingType = holdingType
        self.displayName = displayName
        self.defaultTransactionType = defaultTransactionType
        self.isUnitized = isUnitized
        self.allowedTransactions = allowedTransactions
    }
}
