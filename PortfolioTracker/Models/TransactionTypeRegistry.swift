//
//  TransactionTypeRegistry.swift
//  PortfolioTracker
//

import Foundation

final class TransactionTypeRegistry {
    static let shared = TransactionTypeRegistry()
    
    private var configs: [HoldingType: InvestmentTypeConfig] = [:]
    
    private init() {
        registerDefaults()
    }
    
    static func config(for rawType: String, holdingType: HoldingType?) -> TransactionTypeConfig {
        let actualHolding = holdingType ?? .investment
        let investmentConfig = shared.config(for: actualHolding)
        
        if let found = investmentConfig.allowedTransactions.first(where: { $0.rawType.lowercased() == rawType.lowercased() }) {
            return found
        }
        
        // Fallback mapping for standard raw types across any holding
        let cleanType = rawType.uppercased()
        switch cleanType {
        case "BUY", "DEPOSIT", "CONTRIBUTION", "PREMIUM", "PURCHASE", "EMPLOYEE_CONTRIBUTION":
            return TransactionTypeConfig(
                id: "fallback_buy",
                rawType: cleanType,
                displayName: cleanType.capitalized,
                iconName: "plus.circle.fill",
                cashDirection: .outflow,
                affectsInvestedAmount: true,
                affectsAssetValue: true,
                affectsProfit: false,
                closesAsset: false,
                isUnitBased: !actualHolding.isNonUnitized
            )
        case "SELL", "WITHDRAWAL", "REDEMPTION", "SURRENDER", "MATURITY":
            return TransactionTypeConfig(
                id: "fallback_sell",
                rawType: cleanType,
                displayName: cleanType.capitalized,
                iconName: "minus.circle.fill",
                cashDirection: .inflow,
                affectsInvestedAmount: true,
                affectsAssetValue: true,
                affectsProfit: true,
                closesAsset: (cleanType == "MATURITY" || cleanType == "SURRENDER"),
                isUnitBased: !actualHolding.isNonUnitized
            )
        case "DIVIDEND", "INTEREST", "COUPON", "BONUS", "SURVIVAL_BENEFIT":
            return TransactionTypeConfig(
                id: "fallback_dividend",
                rawType: cleanType,
                displayName: cleanType.capitalized,
                iconName: "gift.fill",
                cashDirection: (cleanType == "DIVIDEND" || cleanType == "COUPON" || cleanType == "SURVIVAL_BENEFIT") ? .inflow : .internalAccrual,
                affectsInvestedAmount: false,
                affectsAssetValue: (cleanType == "INTEREST" || cleanType == "BONUS"),
                affectsProfit: true,
                closesAsset: false,
                isUnitBased: false
            )
        default:
            return TransactionTypeConfig(
                id: "fallback_generic",
                rawType: cleanType,
                displayName: cleanType.capitalized,
                iconName: "dollarsign.circle.fill",
                cashDirection: .outflow,
                affectsInvestedAmount: true,
                affectsAssetValue: true,
                affectsProfit: false,
                closesAsset: false,
                isUnitBased: !actualHolding.isNonUnitized
            )
        }
    }
    
    func config(for holdingType: HoldingType) -> InvestmentTypeConfig {
        if let config = configs[holdingType] {
            return config
        }
        return defaultMarketConfig()
    }
    
    func register(holdingType: HoldingType, config: InvestmentTypeConfig) {
        configs[holdingType] = config
    }
    
    private func registerDefaults() {
        // 1. Market Investments (Stocks, Mutual Funds, ETFs, Crypto)
        configs[.investment] = defaultMarketConfig()
        
        // 2. Fixed Deposit / RD
        configs[.fixedDeposit] = InvestmentTypeConfig(
            holdingType: .fixedDeposit,
            displayName: "Fixed Deposit / RD",
            defaultTransactionType: "DEPOSIT",
            isUnitized: false,
            allowedTransactions: [
                TransactionTypeConfig(
                    id: "fd_deposit",
                    rawType: "DEPOSIT",
                    displayName: "Deposit / Installment",
                    iconName: "arrow.down.right.circle.fill",
                    cashDirection: .outflow,
                    affectsInvestedAmount: true,
                    affectsAssetValue: true,
                    affectsProfit: false,
                    closesAsset: false,
                    isUnitBased: false,
                    notesPrompt: "FD Receipt / Account Ref"
                ),
                TransactionTypeConfig(
                    id: "fd_interest_reinvest",
                    rawType: "INTEREST",
                    displayName: "Interest Credited (Reinvested)",
                    iconName: "percent",
                    cashDirection: .internalAccrual,
                    affectsInvestedAmount: false,
                    affectsAssetValue: true,
                    affectsProfit: true,
                    closesAsset: false,
                    isUnitBased: false,
                    notesPrompt: "Compounded interest amount"
                ),
                TransactionTypeConfig(
                    id: "fd_interest_payout",
                    rawType: "INTEREST_PAYOUT",
                    displayName: "Interest Payout (to Bank)",
                    iconName: "banknote.fill",
                    cashDirection: .inflow,
                    affectsInvestedAmount: false,
                    affectsAssetValue: false,
                    affectsProfit: true,
                    closesAsset: false,
                    isUnitBased: false,
                    notesPrompt: "Payout credit ref"
                ),
                TransactionTypeConfig(
                    id: "fd_withdrawal",
                    rawType: "WITHDRAWAL",
                    displayName: "Partial Withdrawal",
                    iconName: "arrow.up.left.circle.fill",
                    cashDirection: .inflow,
                    affectsInvestedAmount: true,
                    affectsAssetValue: true,
                    affectsProfit: false,
                    closesAsset: false,
                    isUnitBased: false,
                    notesPrompt: "Premature partial withdrawal"
                ),
                TransactionTypeConfig(
                    id: "fd_maturity",
                    rawType: "MATURITY",
                    displayName: "FD Maturity / Full Payout",
                    iconName: "flag.checkered.circle.fill",
                    cashDirection: .inflow,
                    affectsInvestedAmount: true,
                    affectsAssetValue: true,
                    affectsProfit: true,
                    closesAsset: true,
                    isUnitBased: false,
                    notesPrompt: "Final payout amount"
                )
            ]
        )
        
        // 3. EPF / Provident Fund
        configs[.epf] = InvestmentTypeConfig(
            holdingType: .epf,
            displayName: "EPF / Provident Fund",
            defaultTransactionType: "EMPLOYEE_CONTRIBUTION",
            isUnitized: false,
            allowedTransactions: [
                TransactionTypeConfig(
                    id: "epf_employee",
                    rawType: "EMPLOYEE_CONTRIBUTION",
                    displayName: "Employee Contribution",
                    iconName: "person.fill.badge.plus",
                    cashDirection: .outflow,
                    affectsInvestedAmount: true,
                    affectsAssetValue: true,
                    affectsProfit: false,
                    closesAsset: false,
                    isUnitBased: false,
                    notesPrompt: "Deducted from salary"
                ),
                TransactionTypeConfig(
                    id: "epf_employer",
                    rawType: "EMPLOYER_CONTRIBUTION",
                    displayName: "Employer Contribution",
                    iconName: "building.2.fill",
                    cashDirection: .internalAccrual,
                    affectsInvestedAmount: true,
                    affectsAssetValue: true,
                    affectsProfit: false,
                    closesAsset: false,
                    isUnitBased: false,
                    notesPrompt: "Employer match contribution"
                ),
                TransactionTypeConfig(
                    id: "epf_interest",
                    rawType: "INTEREST",
                    displayName: "Annual Interest Credited",
                    iconName: "percent",
                    cashDirection: .internalAccrual,
                    affectsInvestedAmount: false,
                    affectsAssetValue: true,
                    affectsProfit: true,
                    closesAsset: false,
                    isUnitBased: false,
                    notesPrompt: "EPFO annual interest rate credit"
                ),
                TransactionTypeConfig(
                    id: "epf_withdrawal",
                    rawType: "WITHDRAWAL",
                    displayName: "EPF Advance / Withdrawal",
                    iconName: "arrow.up.right.circle.fill",
                    cashDirection: .inflow,
                    affectsInvestedAmount: true,
                    affectsAssetValue: true,
                    affectsProfit: false,
                    closesAsset: false,
                    isUnitBased: false,
                    notesPrompt: "Partial claim / advance"
                ),
                TransactionTypeConfig(
                    id: "epf_settlement",
                    rawType: "MATURITY",
                    displayName: "Full EPF Transfer / Settlement",
                    iconName: "checkmark.seal.fill",
                    cashDirection: .inflow,
                    affectsInvestedAmount: true,
                    affectsAssetValue: true,
                    affectsProfit: true,
                    closesAsset: true,
                    isUnitBased: false,
                    notesPrompt: "Final settlement"
                )
            ]
        )
        
        // 4. LIC / Insurance / Annuity
        configs[.insuranceAnnuity] = InvestmentTypeConfig(
            holdingType: .insuranceAnnuity,
            displayName: "LIC / Insurance / Annuity",
            defaultTransactionType: "PREMIUM",
            isUnitized: false,
            allowedTransactions: [
                TransactionTypeConfig(
                    id: "lic_premium",
                    rawType: "PREMIUM",
                    displayName: "Premium Payment",
                    iconName: "doc.text.fill",
                    cashDirection: .outflow,
                    affectsInvestedAmount: true,
                    affectsAssetValue: true,
                    affectsProfit: false,
                    closesAsset: false,
                    isUnitBased: false,
                    notesPrompt: "Policy premium receipt #"
                ),
                TransactionTypeConfig(
                    id: "lic_bonus",
                    rawType: "BONUS",
                    displayName: "Accrued Reversionary Bonus",
                    iconName: "star.fill",
                    cashDirection: .internalAccrual,
                    affectsInvestedAmount: false,
                    affectsAssetValue: true,
                    affectsProfit: true,
                    closesAsset: false,
                    isUnitBased: false,
                    notesPrompt: "Declared annual bonus"
                ),
                TransactionTypeConfig(
                    id: "lic_survival_benefit",
                    rawType: "SURVIVAL_BENEFIT",
                    displayName: "Survival / Money-Back Benefit",
                    iconName: "giftcard.fill",
                    cashDirection: .inflow,
                    affectsInvestedAmount: false,
                    affectsAssetValue: true,
                    affectsProfit: true,
                    closesAsset: false,
                    isUnitBased: false,
                    notesPrompt: "Periodic money-back payout"
                ),
                TransactionTypeConfig(
                    id: "lic_maturity",
                    rawType: "MATURITY",
                    displayName: "Policy Maturity Payout",
                    iconName: "flag.checkered.2.crossed",
                    cashDirection: .inflow,
                    affectsInvestedAmount: true,
                    affectsAssetValue: true,
                    affectsProfit: true,
                    closesAsset: true,
                    isUnitBased: false,
                    notesPrompt: "Sum assured + total bonus"
                ),
                TransactionTypeConfig(
                    id: "lic_surrender",
                    rawType: "SURRENDER",
                    displayName: "Policy Surrender Value",
                    iconName: "xmark.seal.fill",
                    cashDirection: .inflow,
                    affectsInvestedAmount: true,
                    affectsAssetValue: true,
                    affectsProfit: true,
                    closesAsset: true,
                    isUnitBased: false,
                    notesPrompt: "Surrender payout"
                )
            ]
        )
        
        // 5. Post Office Scheme (PPF/NSC/MIS/Sukanya)
        configs[.postOffice] = InvestmentTypeConfig(
            holdingType: .postOffice,
            displayName: "Post Office / PPF / NSC / SSY",
            defaultTransactionType: "CONTRIBUTION",
            isUnitized: false,
            allowedTransactions: [
                TransactionTypeConfig(
                    id: "po_deposit",
                    rawType: "CONTRIBUTION",
                    displayName: "Deposit / Contribution",
                    iconName: "arrow.down.circle.fill",
                    cashDirection: .outflow,
                    affectsInvestedAmount: true,
                    affectsAssetValue: true,
                    affectsProfit: false,
                    closesAsset: false,
                    isUnitBased: false,
                    notesPrompt: "Deposit transaction ref"
                ),
                TransactionTypeConfig(
                    id: "po_interest",
                    rawType: "INTEREST",
                    displayName: "Annual Interest Credited",
                    iconName: "percent",
                    cashDirection: .internalAccrual,
                    affectsInvestedAmount: false,
                    affectsAssetValue: true,
                    affectsProfit: true,
                    closesAsset: false,
                    isUnitBased: false,
                    notesPrompt: "Fiscal year interest"
                ),
                TransactionTypeConfig(
                    id: "po_withdrawal",
                    rawType: "WITHDRAWAL",
                    displayName: "Partial Withdrawal",
                    iconName: "arrow.up.circle.fill",
                    cashDirection: .inflow,
                    affectsInvestedAmount: true,
                    affectsAssetValue: true,
                    affectsProfit: false,
                    closesAsset: false,
                    isUnitBased: false,
                    notesPrompt: "Eligible withdrawal"
                ),
                TransactionTypeConfig(
                    id: "po_maturity",
                    rawType: "MATURITY",
                    displayName: "Scheme Maturity / Full Closure",
                    iconName: "flag.fill",
                    cashDirection: .inflow,
                    affectsInvestedAmount: true,
                    affectsAssetValue: true,
                    affectsProfit: true,
                    closesAsset: true,
                    isUnitBased: false,
                    notesPrompt: "Final payout amount"
                )
            ]
        )
        
        // 6. Bank Balance
        configs[.bankBalance] = InvestmentTypeConfig(
            holdingType: .bankBalance,
            displayName: "Bank Account Balance",
            defaultTransactionType: "DEPOSIT",
            isUnitized: false,
            allowedTransactions: [
                TransactionTypeConfig(
                    id: "bank_deposit",
                    rawType: "DEPOSIT",
                    displayName: "Money Added / Savings",
                    iconName: "plus.circle.fill",
                    cashDirection: .outflow,
                    affectsInvestedAmount: true,
                    affectsAssetValue: true,
                    affectsProfit: false,
                    closesAsset: false,
                    isUnitBased: false
                ),
                TransactionTypeConfig(
                    id: "bank_interest",
                    rawType: "INTEREST",
                    displayName: "Savings Interest Credited",
                    iconName: "percent",
                    cashDirection: .internalAccrual,
                    affectsInvestedAmount: false,
                    affectsAssetValue: true,
                    affectsProfit: true,
                    closesAsset: false,
                    isUnitBased: false
                ),
                TransactionTypeConfig(
                    id: "bank_withdrawal",
                    rawType: "WITHDRAWAL",
                    displayName: "Money Withdrawn / Spent",
                    iconName: "minus.circle.fill",
                    cashDirection: .inflow,
                    affectsInvestedAmount: true,
                    affectsAssetValue: true,
                    affectsProfit: false,
                    closesAsset: false,
                    isUnitBased: false
                )
            ]
        )
    }
    
    private func defaultMarketConfig() -> InvestmentTypeConfig {
        InvestmentTypeConfig(
            holdingType: .investment,
            displayName: "Stocks / Mutual Funds",
            defaultTransactionType: "BUY",
            isUnitized: true,
            allowedTransactions: [
                TransactionTypeConfig(
                    id: "market_buy",
                    rawType: "BUY",
                    displayName: "Buy Units",
                    iconName: "cart.badge.plus",
                    cashDirection: .outflow,
                    affectsInvestedAmount: true,
                    affectsAssetValue: true,
                    affectsProfit: false,
                    closesAsset: false,
                    isUnitBased: true,
                    notesPrompt: "Order # / Strategy"
                ),
                TransactionTypeConfig(
                    id: "market_sell",
                    rawType: "SELL",
                    displayName: "Sell Units",
                    iconName: "cart.badge.minus",
                    cashDirection: .inflow,
                    affectsInvestedAmount: true,
                    affectsAssetValue: true,
                    affectsProfit: true,
                    closesAsset: false,
                    isUnitBased: true,
                    notesPrompt: "Sell Order #"
                ),
                TransactionTypeConfig(
                    id: "market_dividend",
                    rawType: "DIVIDEND",
                    displayName: "Dividend Received",
                    iconName: "gift.fill",
                    cashDirection: .inflow,
                    affectsInvestedAmount: false,
                    affectsAssetValue: false,
                    affectsProfit: true,
                    closesAsset: false,
                    isUnitBased: false,
                    notesPrompt: "Dividend Per Share or Total Payout"
                )
            ]
        )
    }
}
