//
//  PortfolioMetrics.swift
//  PortfolioTracker
//

import Foundation
import SwiftData

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
            switch transaction.type {
            case .buy: return partialResult + transaction.units
            case .sell: return partialResult - transaction.units
            case .dividend: return partialResult
            }
        }
        return abs(total) < 0.000001 ? 0.0 : total
    }
    
    static func totalUnits(for asset: Asset) -> Double {
        if asset.holdingType == .bankBalance || asset.holdingType == .fixedDeposit {
            return 1.0
        }
        return totalUnits(for: asset.transactions)
    }

    static func isSoldOff(_ asset: Asset) -> Bool {
        let remainingUnits = totalUnits(for: asset)
        return abs(remainingUnits) <= 0.000001 && asset.transactions.contains(where: { $0.type == .buy })
    }
    
    static func investedValue(for asset: Asset) -> Double {
        if asset.holdingType == .bankBalance || asset.holdingType == .fixedDeposit {
            let totalInterest = asset.transactions.filter { $0.type == .dividend }.reduce(0.0) { $0 + $1.pricePerUnit }
            return max(0, asset.currentPrice - totalInterest)
        }
        return FifoCalculator.calculate(transactions: asset.transactions).holdings.reduce(0.0) { partialResult, lot in
            partialResult + (lot.remainingUnits * lot.buyPrice)
        }
    }
    
    static func lifetimeInvested(for asset: Asset) -> Double {
        FifoCalculator.calculate(transactions: asset.transactions).lifetimeInvested
    }
    
    static func lifetimeRetrieved(for asset: Asset) -> Double {
        FifoCalculator.calculate(transactions: asset.transactions).lifetimeRetrieved
    }
    
    static func currentValue(for asset: Asset) -> Double {
        if asset.holdingType == .bankBalance || asset.holdingType == .fixedDeposit {
            return asset.currentPrice
        }
        return totalUnits(for: asset) * asset.currentPrice
    }
    
    static func unrealizedGainLoss(for asset: Asset) -> Double {
        currentValue(for: asset) - investedValue(for: asset)
    }
    
    static func cashFlows(for asset: Asset, valuationDate: Date = Date()) -> [CashFlow] {
        let transactions = orderedTransactions(asset.transactions)
        var cashFlows = transactions.map { transaction in
            let amount = transaction.units * transaction.pricePerUnit
            let signedAmount = transaction.type == .buy ? -amount : amount
            return CashFlow(amount: signedAmount, date: transaction.date)
        }
        
        let units = totalUnits(for: transactions)
        if units > 0 {
            cashFlows.append(CashFlow(amount: currentValue(for: asset), date: valuationDate))
        }
        
        return cashFlows
    }
    
    static func xirr(for asset: Asset, valuationDate: Date = Date()) -> Double? {
        XirrCalculator.calculateXirr(cashFlows: cashFlows(for: asset, valuationDate: valuationDate))
    }
    
    static func holdingDurationText(for asset: Asset, asOf date: Date = Date()) -> String {
        let buys = asset.transactions.filter { $0.type == .buy }
        guard let firstBuy = buys.min(by: { $0.date < $1.date }), totalUnits(for: asset) > 0 else {
            return "N/A"
        }
        
        let days = Calendar.current.dateComponents([.day], from: firstBuy.date, to: date).day ?? 0
        
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
        // Try to derive from currencies in the database
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
        if asset.holdingType == .bankBalance || asset.holdingType == .fixedDeposit {
            let totalInterest = asset.transactions.filter { $0.type == .dividend }.reduce(0.0) { sum, tx in
                let txRate = tx.inrExchangeRate ?? rate
                return sum + (tx.pricePerUnit * txRate)
            }
            let currentValueInINR = asset.currentPrice * rate
            return max(0, currentValueInINR - totalInterest)
        }
        return FifoCalculator.calculateInINR(transactions: asset.transactions, categoryExchangeRate: rate).holdings.reduce(0.0) { partialResult, lot in
            partialResult + lot.remainingUnits * lot.buyPriceINR
        }
    }
    
    static func lifetimeInvestedInINR(for asset: Asset, rate: Double) -> Double {
        FifoCalculator.calculateInINR(transactions: asset.transactions, categoryExchangeRate: rate).lifetimeInvested
    }
    
    static func lifetimeRetrievedInINR(for asset: Asset, rate: Double) -> Double {
        FifoCalculator.calculateInINR(transactions: asset.transactions, categoryExchangeRate: rate).lifetimeRetrieved
    }
    
    static func currentValueInINR(for asset: Asset, rate: Double) -> Double {
        if asset.holdingType == .bankBalance || asset.holdingType == .fixedDeposit {
            return asset.currentPrice * rate
        }
        return totalUnits(for: asset) * asset.currentPrice * rate
    }
    
    static func unrealizedGainLossInINR(for asset: Asset, rate: Double) -> Double {
        currentValueInINR(for: asset, rate: rate) - investedValueInINR(for: asset, rate: rate)
    }
    
    static func cashFlowsInINR(for asset: Asset, rate: Double, valuationDate: Date = Date()) -> [CashFlow] {
        let transactions = orderedTransactions(asset.transactions)
        var cashFlows = transactions.map { transaction in
            let amount = transaction.units * transaction.pricePerUnit
            let txRate = transaction.inrExchangeRate ?? rate
            let amountINR = amount * txRate
            let signedAmount = transaction.type == .buy ? -amountINR : amountINR
            return CashFlow(amount: signedAmount, date: transaction.date)
        }
        
        let units = totalUnits(for: transactions)
        if units > 0 {
            cashFlows.append(CashFlow(amount: currentValueInINR(for: asset, rate: rate), date: valuationDate))
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
            if sellCount == 0 { return "100% Buy (No Sales)" }
            return String(format: "%.0f%% Buy / %.0f%% Sell", buyPercentage, 100.0 - buyPercentage)
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
            switch tx.type {
            case .buy: buy += 1
            case .sell: sell += 1
            case .dividend: div += 1
            }
        }
        
        return TransactionCounts(buyCount: buy, sellCount: sell, dividendCount: div, totalCount: buy + sell + div)
    }
}
