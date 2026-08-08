//
//  PortfolioMetrics.swift
//  PortfolioTracker
//

import Foundation
import SwiftData
import SwiftUI

enum PortfolioMetrics {
    static func defaultCurrency(in currencies: [Currency]) -> Currency? {
        currencies.first(where: \.isDefault) ?? currencies.first
    }
    
    static func normalizeDefaultCurrencies(_ currencies: [Currency]) {
        guard !currencies.isEmpty else { return }
        
        if let defaultCurrency = currencies.first(where: \.isDefault) {
            for currency in currencies where currency.persistentModelID != defaultCurrency.persistentModelID {
                currency.isDefault = false
            }
        } else {
            currencies[0].isDefault = true
            for currency in currencies.dropFirst() {
                currency.isDefault = false
            }
        }
    }
    
    static func orderedTransactions(_ transactions: [AssetTransaction]) -> [AssetTransaction] {
        transactions.sorted {
            if $0.date == $1.date {
                return $0.createdAt < $1.createdAt
            }
            return $0.date < $1.date
        }
    }
    
    static func reverseOrderedTransactions(_ transactions: [AssetTransaction]) -> [AssetTransaction] {
        Array(orderedTransactions(transactions).reversed())
    }
    
    static func totalUnits(for transactions: [AssetTransaction]) -> Double {
        let total = transactions.reduce(0.0) { partialResult, transaction in
            if transaction.type == .dividend || transaction.rawType.uppercased().contains("DIVIDEND") || !transaction.config.isUnitBased {
                return partialResult
            }
            switch transaction.type {
            case .buy: return partialResult + transaction.units
            case .sell: return partialResult - transaction.units
            case .dividend: return partialResult
            }
        }
        return abs(total) < 0.000001 ? 0.0 : total
    }
    
    static func totalUnits(for asset: Asset) -> Double {
        if asset.holdingType.isNonUnitized {
            return 1.0
        }
        return totalUnits(for: asset.transactions)
    }

    static func isSoldOff(_ asset: Asset) -> Bool {
        if asset.isCompleted {
            return true
        }
        if asset.holdingType.isNonUnitized {
            return asset.transactions.contains(where: { $0.config.closesAsset })
        }
        let remainingUnits = totalUnits(for: asset)
        return abs(remainingUnits) <= 0.000001 && asset.transactions.contains(where: { $0.type == .buy })
    }
    
    static func totalInterestAccrued(for asset: Asset) -> Double {
        asset.transactions.filter { $0.config.affectsProfit }.reduce(0.0) { $0 + $1.amount }
    }
    
    static func investedValue(for asset: Asset) -> Double {
        if isSoldOff(asset) {
            return 0.0
        }
        if asset.holdingType.isNonUnitized {
            let txInvested = asset.transactions.reduce(0.0) { sum, tx in
                let cfg = tx.config
                guard cfg.affectsInvestedAmount else { return sum }
                if cfg.cashDirection == .outflow {
                    return sum + tx.amount
                } else if cfg.cashDirection == .inflow {
                    return sum - tx.amount
                }
                return sum
            }
            
            if txInvested > 0 {
                return txInvested
            }
            if asset.principalAmount > 0 {
                return asset.principalAmount
            }
            if asset.premiumAmount > 0 {
                return asset.premiumAmount
            }
            let totalProfit = totalInterestAccrued(for: asset)
            return max(0, asset.currentPrice - totalProfit)
        }
        return FifoCalculator.calculate(transactions: asset.transactions).holdings.reduce(0.0) { partialResult, lot in
            partialResult + (lot.remainingUnits * lot.buyPrice)
        }
    }
    
    static func lifetimeInvested(for asset: Asset) -> Double {
        if asset.holdingType.isNonUnitized {
            let sumOutflows = asset.transactions.filter { $0.config.affectsInvestedAmount && $0.config.cashDirection == .outflow }.reduce(0.0) { $0 + $1.amount }
            if sumOutflows > 0 { return sumOutflows }
            if asset.principalAmount > 0 { return asset.principalAmount }
            if asset.premiumAmount > 0 { return asset.premiumAmount }
            return investedValue(for: asset)
        }
        return FifoCalculator.calculate(transactions: asset.transactions).lifetimeInvested
    }
    
    static func lifetimeRetrieved(for asset: Asset) -> Double {
        if asset.holdingType.isNonUnitized {
            return asset.transactions.filter { $0.config.cashDirection == .inflow }.reduce(0.0) { $0 + $1.amount }
        }
        return FifoCalculator.calculate(transactions: asset.transactions).lifetimeRetrieved
    }
    
    static func currentValue(for asset: Asset) -> Double {
        if isSoldOff(asset) {
            return 0.0
        }
        if asset.holdingType.isNonUnitized {
            let txBalance = asset.transactions.reduce(0.0) { sum, tx in
                let cfg = tx.config
                guard cfg.affectsAssetValue else { return sum }
                if cfg.cashDirection == .outflow || cfg.cashDirection == .internalAccrual {
                    return sum + tx.amount
                } else if cfg.cashDirection == .inflow {
                    return sum - tx.amount
                }
                return sum
            }
            if txBalance > 0 {
                return max(txBalance, asset.currentPrice)
            }
            return asset.currentPrice
        }
        return totalUnits(for: asset) * asset.currentPrice
    }
    
    static func unrealizedGainLoss(for asset: Asset) -> Double {
        currentValue(for: asset) - investedValue(for: asset)
    }
    
    static func lifetimeDividend(for asset: Asset) -> Double {
        asset.transactions.filter { $0.type == .dividend || $0.rawType.uppercased().contains("DIVIDEND") }.reduce(0.0) { $0 + $1.amount }
    }
    
    static func cashFlows(for asset: Asset, valuationDate: Date = Date()) -> [CashFlow] {
        let transactions = orderedTransactions(asset.transactions)
        var cashFlows: [CashFlow] = []
        
        for tx in transactions {
            let cfg = tx.config
            let amount = tx.amount
            let uRaw = tx.rawType.uppercased()
            if cfg.cashDirection == .outflow {
                cashFlows.append(CashFlow(amount: -amount, date: tx.date))
            } else if cfg.cashDirection == .inflow || cfg.cashDirection == .internalAccrual || tx.type == .dividend || uRaw.contains("DIVIDEND") || uRaw.contains("INTEREST") || uRaw.contains("COUPON") {
                cashFlows.append(CashFlow(amount: amount, date: tx.date))
            }
        }
        
        let currVal = currentValue(for: asset)
        if currVal > 0 && !isSoldOff(asset) {
            cashFlows.append(CashFlow(amount: currVal, date: valuationDate))
        }
        
        return cashFlows
    }
    
    static func xirr(for asset: Asset, valuationDate: Date = Date()) -> Double? {
        XirrCalculator.calculateXirr(cashFlows: cashFlows(for: asset, valuationDate: valuationDate))
    }
    
    static func holdingDurationText(for asset: Asset, asOf date: Date = Date()) -> String {
        let txs = asset.transactions.filter { $0.config.cashDirection == .outflow }
        guard let firstTx = txs.min(by: { $0.date < $1.date }), currentValue(for: asset) > 0 else {
            return "N/A"
        }
        
        let days = Calendar.current.dateComponents([.day], from: firstTx.date, to: date).day ?? 0
        
        if days >= 365 {
            return "\(days / 365) yr, \(days % 365) d"
        }
        
        if days >= 30 {
            return "\(days / 30) mo, \(days % 30) d"
        }
        
        return "\(days) d"
    }
    
    static func normalizedValue(
        _ value: Double,
        currencyCode: String,
        defaultCurrency: Currency?,
        currencies: [Currency]
    ) -> Double {
        guard
            let defaultCurrency,
            defaultCurrency.exchangeRate != 0,
            let sourceCurrency = currencies.first(where: { $0.code == currencyCode }),
            sourceCurrency.exchangeRate != 0
        else {
            return value
        }
        
        return (value * sourceCurrency.exchangeRate) / defaultCurrency.exchangeRate
    }
    
    static func currentInrExchangeRate(for category: Category, currencies: [Currency]) -> Double {
        if category.currencyCode == "INR" {
            return 1.0
        }
        if let lastRate = category.lastInrExchangeRate {
            return lastRate
        }
        guard
            let inrCurrency = currencies.first(where: { $0.code == "INR" }),
            let catCurrency = currencies.first(where: { $0.code == category.currencyCode }),
            catCurrency.exchangeRate != 0
        else {
            if category.currencyCode == "USD" {
                return 83.0
            }
            return 1.0
        }
        return catCurrency.exchangeRate / inrCurrency.exchangeRate
    }
    
    static func investedValueInINR(for asset: Asset, rate: Double) -> Double {
        if asset.holdingType.isNonUnitized {
            let invLocal = investedValue(for: asset)
            return invLocal * rate
        }
        return FifoCalculator.calculateInINR(transactions: asset.transactions, categoryExchangeRate: rate).holdings.reduce(0.0) { partialResult, lot in
            partialResult + lot.remainingUnits * lot.buyPriceINR
        }
    }
    
    static func lifetimeInvestedInINR(for asset: Asset, rate: Double) -> Double {
        if asset.holdingType.isNonUnitized {
            return lifetimeInvested(for: asset) * rate
        }
        return FifoCalculator.calculateInINR(transactions: asset.transactions, categoryExchangeRate: rate).lifetimeInvested
    }
    
    static func lifetimeRetrievedInINR(for asset: Asset, rate: Double) -> Double {
        if asset.holdingType.isNonUnitized {
            return lifetimeRetrieved(for: asset) * rate
        }
        return FifoCalculator.calculateInINR(transactions: asset.transactions, categoryExchangeRate: rate).lifetimeRetrieved
    }
    
    static func currentValueInINR(for asset: Asset, rate: Double) -> Double {
        if asset.holdingType.isNonUnitized {
            return currentValue(for: asset) * rate
        }
        return totalUnits(for: asset) * asset.currentPrice * rate
    }
    
    static func unrealizedGainLossInINR(for asset: Asset, rate: Double) -> Double {
        currentValueInINR(for: asset, rate: rate) - investedValueInINR(for: asset, rate: rate)
    }
    
    static func lifetimeDividendInINR(for asset: Asset, rate: Double) -> Double {
        asset.transactions.filter { $0.type == .dividend || $0.rawType.uppercased().contains("DIVIDEND") }.reduce(0.0) { sum, tx in
            let txRate = tx.inrExchangeRate ?? rate
            return sum + (tx.amount * txRate)
        }
    }
    
    static func cashFlowsInINR(for asset: Asset, rate: Double, valuationDate: Date = Date()) -> [CashFlow] {
        let transactions = orderedTransactions(asset.transactions)
        var cashFlows: [CashFlow] = []
        
        for tx in transactions {
            let cfg = tx.config
            let txRate = tx.inrExchangeRate ?? rate
            let amountINR = tx.amount * txRate
            let uRaw = tx.rawType.uppercased()
            
            if cfg.cashDirection == .outflow {
                cashFlows.append(CashFlow(amount: -amountINR, date: tx.date))
            } else if cfg.cashDirection == .inflow || cfg.cashDirection == .internalAccrual || tx.type == .dividend || uRaw.contains("DIVIDEND") || uRaw.contains("INTEREST") || uRaw.contains("COUPON") {
                cashFlows.append(CashFlow(amount: amountINR, date: tx.date))
            }
        }
        
        let currValINR = currentValueInINR(for: asset, rate: rate)
        if currValINR > 0 && !isSoldOff(asset) {
            cashFlows.append(CashFlow(amount: currValINR, date: valuationDate))
        }
        
        return cashFlows
    }
    
    static func xirrInINR(for asset: Asset, rate: Double, valuationDate: Date = Date()) -> Double? {
        XirrCalculator.calculateXirr(cashFlows: cashFlowsInINR(for: asset, rate: rate, valuationDate: valuationDate))
    }
    
    // MARK: - Transaction Count Helpers
    
    struct TransactionCounts {
        let buyCount: Int
        let sellCount: Int
        let dividendCount: Int
        let totalCount: Int
        
        var buyPercentage: Double {
            let total = buyCount + sellCount
            return total > 0 ? (Double(buyCount) / Double(total)) * 100.0 : 100.0
        }
        
        var disciplineRatioText: String {
            if buyCount + sellCount == 0 { return "No Trades" }
            if sellCount == 0 { return "100% Buy / Contribution" }
            return String(format: "%.0f%% Inflow / %.0f%% Outflow", buyPercentage, 100.0 - buyPercentage)
        }
    }
    
    static func transactionCounts(
        for transactions: [AssetTransaction],
        year: Int? = nil,
        month: Int? = nil
    ) -> TransactionCounts {
        let calendar = Calendar.current
        let filtered = transactions.filter { tx in
            if let y = year {
                let txYear = calendar.component(.year, from: tx.date)
                if txYear != y { return false }
            }
            if let m = month {
                let txMonth = calendar.component(.month, from: tx.date)
                if txMonth != m { return false }
            }
            return true
        }
        
        var buy = 0
        var sell = 0
        var div = 0
        
        for tx in filtered {
            if tx.type == .dividend || tx.rawType.uppercased().contains("DIVIDEND") {
                div += 1
            } else if tx.config.cashDirection == .outflow {
                buy += 1
            } else if tx.config.cashDirection == .inflow {
                sell += 1
            } else {
                div += 1
            }
        }
        
        return TransactionCounts(buyCount: buy, sellCount: sell, dividendCount: div, totalCount: buy + sell + div)
    }
    
    // MARK: - Investment Recency Helpers
    
    enum InvestmentRecencyStatus: String, CaseIterable, Identifiable {
        case active = "Active (<= 30d)"
        case moderate = "Moderate (30-90d)"
        case dormant = "Dormant (> 90d)"
        case never = "Never Invested"
        
        var id: String { rawValue }
        
        var shortLabel: String {
            switch self {
            case .active: return "<= 30d"
            case .moderate: return "30-90d"
            case .dormant: return "> 90d"
            case .never: return "Never"
            }
        }
        
        var color: Color {
            switch self {
            case .active: return .green
            case .moderate: return .orange
            case .dormant: return .red
            case .never: return .gray
            }
        }
    }
    
    static func lastInvestedTransaction(for asset: Asset) -> AssetTransaction? {
        asset.transactions
            .filter { $0.type == .buy || $0.config.cashDirection == .outflow }
            .max(by: { $0.date < $1.date })
    }
    
    static func daysSinceLastInvestment(for asset: Asset) -> Int? {
        guard let lastTx = lastInvestedTransaction(for: asset) else { return nil }
        return Calendar.current.dateComponents([.day], from: lastTx.date, to: Date()).day
    }
    
    static func lastInvestedFormattedText(for asset: Asset) -> String {
        guard let lastTx = lastInvestedTransaction(for: asset), let days = daysSinceLastInvestment(for: asset) else {
            return "Never Invested"
        }
        let dateStr = lastTx.date.formatted(date: .abbreviated, time: .omitted)
        if days == 0 {
            return "Today (\(dateStr))"
        } else if days == 1 {
            return "Yesterday (\(dateStr))"
        } else if days < 30 {
            return "\(days) days ago (\(dateStr))"
        } else if days < 365 {
            let months = days / 30
            let remDays = days % 30
            if remDays > 0 && months < 3 {
                return "\(months) mo \(remDays)d ago (\(dateStr))"
            }
            return "\(months) mo ago (\(dateStr))"
        } else {
            let yrs = days / 365
            let mos = (days % 365) / 30
            if mos > 0 {
                return "\(yrs) yr \(mos) mo ago (\(dateStr))"
            }
            return "\(yrs) yr ago (\(dateStr))"
        }
    }
    
    static func recencyStatus(for asset: Asset) -> InvestmentRecencyStatus {
        guard let days = daysSinceLastInvestment(for: asset) else { return .never }
        if days <= 30 { return .active }
        if days <= 90 { return .moderate }
        return .dormant
    }
    
    // MARK: - Tax Classification Helpers
    
    struct TaxBadgeInfo {
        let classification: TaxClassification
        let label: String
        let fullLabel: String
        let isLTCG: Bool
        let daysHeld: Int
    }
    
    static func taxBadgeInfo(for tx: AssetTransaction, asset: Asset) -> TaxBadgeInfo? {
        guard tx.type == .buy || tx.config.cashDirection == .outflow else { return nil }
        let days = Calendar.current.dateComponents([.day], from: tx.date, to: Date()).day ?? 0
        let thresholdMonths = asset.category?.ltcgMonths ?? ((asset.taxCountry == .us) ? 24 : 12)
        
        let taxDetails = FifoCalculator.determineTaxClass(
            country: asset.taxCountry,
            assetType: asset.taxAssetType,
            buyDate: tx.date,
            valuationDate: Date(),
            slabRate: 0.30,
            ltcgThresholdMonths: thresholdMonths
        )
        
        let isLTCG = (taxDetails.classification == .ltcg)
        let yrText = (thresholdMonths % 12 == 0) ? "\(thresholdMonths / 12)yr" : "\(thresholdMonths)mo"
        let label = isLTCG ? "LTCG" : (taxDetails.classification == .stcg ? "STCG" : "Slab")
        let fullLabel = isLTCG ? "LTCG (>\(yrText))" : (taxDetails.classification == .stcg ? "STCG (<\(yrText))" : "Slab Rate")
        
        return TaxBadgeInfo(
            classification: taxDetails.classification,
            label: label,
            fullLabel: fullLabel,
            isLTCG: isLTCG,
            daysHeld: days
        )
    }
}
