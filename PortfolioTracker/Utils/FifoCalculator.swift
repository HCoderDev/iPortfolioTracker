//
//  FifoCalculator.swift
//  PortfolioTracker
//
//  Created by Antigravity on 28/05/26.
//

import Foundation
import SwiftData

struct FifoHoldingLot: Identifiable {
    let id = UUID()
    let purchaseDate: Date
    let originalUnits: Double
    let remainingUnits: Double
    let buyPrice: Double
    let buyPriceINR: Double
    
    // Tax details
    let taxCategory: TaxClassification
    let taxRate: Double
    let holdingAgeDays: Int
    
    var unrealizedGain: Double {
        (currentPrice - buyPrice) * remainingUnits
    }
    
    var unrealizedGainINR: Double {
        (currentPriceINR - buyPriceINR) * remainingUnits
    }
    
    let currentPrice: Double
    let currentPriceINR: Double
}

enum TaxClassification: String, CaseIterable, Identifiable {
    case stcg = "STCG"
    case ltcg = "LTCG"
    case slab = "Slab Rate (Debt)"
    
    var id: String { self.rawValue }
}

struct FifoRealizedTrade: Identifiable {
    let id = UUID()
    let sellDate: Date
    let buyDate: Date
    let units: Double
    let buyPrice: Double
    let buyPriceINR: Double
    let sellPrice: Double
    let sellPriceINR: Double
    
    let taxCategory: TaxClassification
    let taxRate: Double
    
    var realizedGain: Double {
        (sellPrice - buyPrice) * units
    }
    
    var realizedGainINR: Double {
        (sellPriceINR - buyPriceINR) * units
    }
}

struct FifoTaxResult {
    let activeLots: [FifoHoldingLot]
    let realizedTradesCurrentFY: [FifoRealizedTrade]
    
    // Unrealized Summaries (INR)
    var totalUnrealizedSTCGGains: Double {
        activeLots.filter { $0.taxCategory == .stcg }.reduce(0.0) { $0 + max(0, $1.unrealizedGainINR) }
    }
    
    var totalUnrealizedLTCGGains: Double {
        activeLots.filter { $0.taxCategory == .ltcg }.reduce(0.0) { $0 + max(0, $1.unrealizedGainINR) }
    }
    
    var totalUnrealizedSlabGains: Double {
        activeLots.filter { $0.taxCategory == .slab }.reduce(0.0) { $0 + max(0, $1.unrealizedGainINR) }
    }
    
    var totalUnrealizedTaxSTCG: Double {
        activeLots.filter { $0.taxCategory == .stcg }.reduce(0.0) { $0 + max(0, $1.unrealizedGainINR * $1.taxRate) }
    }
    
    var totalUnrealizedTaxLTCG: Double {
        activeLots.filter { $0.taxCategory == .ltcg }.reduce(0.0) { $0 + max(0, $1.unrealizedGainINR * $1.taxRate) }
    }
    
    var totalUnrealizedTaxSlab: Double {
        activeLots.filter { $0.taxCategory == .slab }.reduce(0.0) { $0 + max(0, $1.unrealizedGainINR * $1.taxRate) }
    }
    
    var totalUnrealizedTax: Double {
        totalUnrealizedTaxSTCG + totalUnrealizedTaxLTCG + totalUnrealizedTaxSlab
    }
    
    // Realized Summaries in Current FY (INR)
    var totalRealizedSTCGGains: Double {
        realizedTradesCurrentFY.filter { $0.taxCategory == .stcg }.reduce(0.0) { $0 + $1.realizedGainINR }
    }
    
    var totalRealizedLTCGGains: Double {
        realizedTradesCurrentFY.filter { $0.taxCategory == .ltcg }.reduce(0.0) { $0 + $1.realizedGainINR }
    }
    
    var totalRealizedSlabGains: Double {
        realizedTradesCurrentFY.filter { $0.taxCategory == .slab }.reduce(0.0) { $0 + $1.realizedGainINR }
    }
    
    var totalRealizedTaxSTCG: Double {
        realizedTradesCurrentFY.filter { $0.taxCategory == .stcg }.reduce(0.0) { $0 + max(0, $1.realizedGainINR * $1.taxRate) }
    }
    
    var totalRealizedTaxLTCG: Double {
        realizedTradesCurrentFY.filter { $0.taxCategory == .ltcg }.reduce(0.0) { $0 + max(0, $1.realizedGainINR * $1.taxRate) }
    }
    
    var totalRealizedTaxSlab: Double {
        realizedTradesCurrentFY.filter { $0.taxCategory == .slab }.reduce(0.0) { $0 + max(0, $1.realizedGainINR * $1.taxRate) }
    }
    
    var totalRealizedTax: Double {
        totalRealizedTaxSTCG + totalRealizedTaxLTCG + totalRealizedTaxSlab
    }
}

struct FifoCalculator {
    
    /// Checks if a date falls within the current Indian Financial Year (starts April 1st).
    static func isInCurrentFinancialYear(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let currentMonth = calendar.component(.month, from: Date())
        
        let fyStartYear = currentMonth >= 4 ? currentYear : currentYear - 1
        
        let components = DateComponents(year: fyStartYear, month: 4, day: 1)
        guard let fyStartDate = calendar.date(from: components) else { return false }
        
        return date >= fyStartDate && date <= Date()
    }
    
    /// Derives the tax classification and tax rate based on country, asset type, and holding duration.
    static func determineTaxClass(
        country: TaxCountry,
        assetType: TaxAssetType,
        buyDate: Date,
        valuationDate: Date,
        slabRate: Double
    ) -> (classification: TaxClassification, rate: Double) {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: buyDate, to: valuationDate).day ?? 0
        
        switch country {
        case .india:
            switch assetType {
            case .equity:
                if days > 365 { // > 1 year
                    return (.ltcg, 0.125) // 12.5% LTCG
                } else {
                    return (.stcg, 0.20) // 20% STCG
                }
            case .debt:
                return (.slab, slabRate) // Taxes at slab rate
            case .other:
                if days > (365 * 3) { // > 3 years
                    return (.ltcg, 0.125) // 12.5% LTCG
                } else {
                    return (.slab, slabRate) // Slab taxed
                }
            }
            
        case .us:
            // US stocks treated as unlisted equities for Indian tax residents
            switch assetType {
            case .equity:
                if days > (365 * 2) { // > 2 years
                    return (.ltcg, 0.125) // 12.5% LTCG
                } else {
                    return (.slab, slabRate) // STCG at Slab rate
                }
            case .debt:
                return (.slab, slabRate) // Debt/Bond funds always taxed at slab
            case .other:
                if days > (365 * 2) { // > 2 years
                    return (.ltcg, 0.125)
                } else {
                    return (.slab, slabRate)
                }
            }
        }
    }
    
    /// Calculate FIFO tax result for a single asset.
    static func calculateTax(asset: Asset, currencies: [Currency], slabRate: Double = 0.30) -> FifoTaxResult {
        let calendar = Calendar.current
        let rate = PortfolioMetrics.currentInrExchangeRate(for: asset.category ?? Category(name: "Temp", currencyCode: "INR"), currencies: currencies)
        
        let sortedTx = asset.transactions.sorted {
            if $0.date == $1.date {
                return $0.createdAt < $1.createdAt
            }
            return $0.date < $1.date
        }
        
        var buyLots: [(originalUnits: Double, remainingUnits: Double, buyPrice: Double, buyRate: Double, date: Date)] = []
        var realizedTrades: [FifoRealizedTrade] = []
        
        for tx in sortedTx {
            let txRate = tx.inrExchangeRate ?? rate
            switch tx.type {
            case .buy:
                buyLots.append((
                    originalUnits: tx.units,
                    remainingUnits: tx.units,
                    buyPrice: tx.pricePerUnit,
                    buyRate: txRate,
                    date: tx.date
                ))
            case .sell:
                var unitsToSell = tx.units
                let sellPrice = tx.pricePerUnit
                
                // FIFO: consume oldest lots first (index 0 upwards)
                for i in 0..<buyLots.count {
                    if unitsToSell <= 0 { break }
                    
                    let lot = buyLots[i]
                    if lot.remainingUnits > 0 {
                        let unitsTaken = min(unitsToSell, lot.remainingUnits)
                        
                        // Determine tax classification at sell date
                        let taxDetails = determineTaxClass(
                            country: asset.taxCountry,
                            assetType: asset.taxAssetType,
                            buyDate: lot.date,
                            valuationDate: tx.date,
                            slabRate: slabRate
                        )
                        
                        let trade = FifoRealizedTrade(
                            sellDate: tx.date,
                            buyDate: lot.date,
                            units: unitsTaken,
                            buyPrice: lot.buyPrice,
                            buyPriceINR: lot.buyPrice * lot.buyRate,
                            sellPrice: sellPrice,
                            sellPriceINR: sellPrice * txRate,
                            taxCategory: taxDetails.classification,
                            taxRate: taxDetails.rate
                        )
                        
                        if isInCurrentFinancialYear(tx.date) {
                            realizedTrades.append(trade)
                        }
                        
                        buyLots[i].remainingUnits -= unitsTaken
                        unitsToSell -= unitsTaken
                    }
                }
            case .dividend:
                // Dividend treated as income, taxed at slab rate
                if isInCurrentFinancialYear(tx.date) {
                    let dividendIncome = tx.units * tx.pricePerUnit
                    realizedTrades.append(FifoRealizedTrade(
                        sellDate: tx.date,
                        buyDate: tx.date,
                        units: 1.0,
                        buyPrice: 0.0,
                        buyPriceINR: 0.0,
                        sellPrice: dividendIncome,
                        sellPriceINR: dividendIncome * txRate,
                        taxCategory: .slab,
                        taxRate: slabRate
                    ))
                }
            }
        }
        
        // Construct Active Lots
        let activeLots: [FifoHoldingLot]
        if asset.holdingType == .bankBalance || asset.holdingType == .fixedDeposit {
            activeLots = []
        } else {
            activeLots = buyLots
                .filter { $0.remainingUnits > 0.000001 }
                .map { lot -> FifoHoldingLot in
                    let taxDetails = determineTaxClass(
                        country: asset.taxCountry,
                        assetType: asset.taxAssetType,
                        buyDate: lot.date,
                        valuationDate: Date(),
                        slabRate: slabRate
                    )
                    
                    let ageDays = calendar.dateComponents([.day], from: lot.date, to: Date()).day ?? 0
                    
                    return FifoHoldingLot(
                        purchaseDate: lot.date,
                        originalUnits: lot.originalUnits,
                        remainingUnits: lot.remainingUnits,
                        buyPrice: lot.buyPrice,
                        buyPriceINR: lot.buyPrice * lot.buyRate,
                        taxCategory: taxDetails.classification,
                        taxRate: taxDetails.rate,
                        holdingAgeDays: ageDays,
                        currentPrice: asset.currentPrice,
                        currentPriceINR: asset.currentPrice * rate
                    )
                }
        }
        
        return FifoTaxResult(
            activeLots: activeLots,
            realizedTradesCurrentFY: realizedTrades
        )
    }
    
    /// Calculate FIFO-based realized P/L and remaining holding lots.
    static func calculate(transactions: [AssetTransaction]) -> LifoResult {
        let sortedTx = orderedTransactions(transactions)
        
        var buyLots: [(originalUnits: Double, remainingUnits: Double, buyPrice: Double, date: Date)] = []
        var realizedPl = 0.0
        
        let lifetimeInvested = transactions.filter { $0.type == .buy }.reduce(0.0) { $0 + ($1.units * $1.pricePerUnit) }
        let lifetimeRetrieved = transactions.filter { $0.type == .sell || $0.type == .dividend }.reduce(0.0) { $0 + ($1.units * $1.pricePerUnit) }
        
        for tx in sortedTx {
            switch tx.type {
            case .buy:
                buyLots.append((
                    originalUnits: tx.units,
                    remainingUnits: tx.units,
                    buyPrice: tx.pricePerUnit,
                    date: tx.date
                ))
            case .sell:
                var unitsToSell = tx.units
                let sellPrice = tx.pricePerUnit
                
                // FIFO: process from the first (oldest) to the last (newest)
                for i in 0..<buyLots.count {
                    if unitsToSell <= 0 { break }
                    
                    let lot = buyLots[i]
                    if lot.remainingUnits > 0 {
                        let unitsTaken = min(unitsToSell, lot.remainingUnits)
                        let invested = lot.buyPrice * unitsTaken
                        let retrieved = sellPrice * unitsTaken
                        let profit = retrieved - invested
                        
                        realizedPl += profit
                        
                        buyLots[i].remainingUnits -= unitsTaken
                        unitsToSell -= unitsTaken
                    }
                }
            case .dividend:
                let retrieved = tx.units * tx.pricePerUnit
                realizedPl += retrieved
            }
        }
        
        let holdings = buyLots
            .filter { $0.remainingUnits > 0.000001 }
            .map { HoldingLot(originalUnits: $0.originalUnits, remainingUnits: $0.remainingUnits, buyPrice: $0.buyPrice, date: $0.date) }
        
        return LifoResult(
            realizedProfitLoss: realizedPl,
            lifetimeInvested: lifetimeInvested,
            lifetimeRetrieved: lifetimeRetrieved,
            holdings: holdings
        )
    }
    
    /// Calculate FIFO-based realized P/L and remaining holding lots in INR terms.
    static func calculateInINR(transactions: [AssetTransaction], categoryExchangeRate: Double) -> LifoResultINR {
        let sortedTx = orderedTransactions(transactions)
        
        var buyLots: [(originalUnits: Double, remainingUnits: Double, buyPrice: Double, buyRate: Double, date: Date)] = []
        var realizedPl = 0.0
        
        let lifetimeInvested = transactions.filter { $0.type == .buy }.reduce(0.0) { sum, tx in
            let rate = tx.inrExchangeRate ?? categoryExchangeRate
            return sum + (tx.units * tx.pricePerUnit * rate)
        }
        let lifetimeRetrieved = transactions.filter { $0.type == .sell || $0.type == .dividend }.reduce(0.0) { sum, tx in
            let rate = tx.inrExchangeRate ?? categoryExchangeRate
            return sum + (tx.units * tx.pricePerUnit * rate)
        }
        
        for tx in sortedTx {
            let txRate = tx.inrExchangeRate ?? categoryExchangeRate
            switch tx.type {
            case .buy:
                buyLots.append((
                    originalUnits: tx.units,
                    remainingUnits: tx.units,
                    buyPrice: tx.pricePerUnit,
                    buyRate: txRate,
                    date: tx.date
                ))
            case .sell:
                var unitsToSell = tx.units
                let sellPrice = tx.pricePerUnit
                
                // FIFO: process from the first (oldest) to the last (newest)
                for i in 0..<buyLots.count {
                    if unitsToSell <= 0 { break }
                    
                    let lot = buyLots[i]
                    if lot.remainingUnits > 0 {
                        let unitsTaken = min(unitsToSell, lot.remainingUnits)
                        let invested = lot.buyPrice * unitsTaken * lot.buyRate
                        let retrieved = sellPrice * unitsTaken * txRate
                        let profit = retrieved - invested
                        
                        realizedPl += profit
                        
                        buyLots[i].remainingUnits -= unitsTaken
                        unitsToSell -= unitsTaken
                    }
                }
            case .dividend:
                let retrieved = tx.units * tx.pricePerUnit * txRate
                realizedPl += retrieved
            }
        }
        
        let holdings = buyLots
            .filter { $0.remainingUnits > 0.000001 }
            .map { HoldingLotINR(originalUnits: $0.originalUnits, remainingUnits: $0.remainingUnits, buyPrice: $0.buyPrice, buyPriceINR: $0.buyPrice * $0.buyRate, date: $0.date) }
        
        return LifoResultINR(
            realizedProfitLoss: realizedPl,
            lifetimeInvested: lifetimeInvested,
            lifetimeRetrieved: lifetimeRetrieved,
            holdings: holdings
        )
    }
    
    static func realizedProfitLossBySellTransaction(transactions: [AssetTransaction]) -> [PersistentIdentifier: Double] {
        let sortedTx = orderedTransactions(transactions)
        var buyLots: [(remainingUnits: Double, buyPrice: Double)] = []
        var realizedProfits: [PersistentIdentifier: Double] = [:]
        
        for transaction in sortedTx {
            switch transaction.type {
            case .buy:
                buyLots.append((remainingUnits: transaction.units, buyPrice: transaction.pricePerUnit))
            case .sell:
                var unitsToSell = transaction.units
                var realizedProfitLoss = 0.0
                
                for i in 0..<buyLots.count {
                    if unitsToSell <= 0 {
                        break
                    }
                    
                    let lot = buyLots[i]
                    guard lot.remainingUnits > 0 else {
                        continue
                    }
                    
                    let unitsTaken = min(unitsToSell, lot.remainingUnits)
                    realizedProfitLoss += (transaction.pricePerUnit - lot.buyPrice) * unitsTaken
                    buyLots[i].remainingUnits -= unitsTaken
                    unitsToSell -= unitsTaken
                }
                
                realizedProfits[transaction.persistentModelID] = realizedProfitLoss
            case .dividend:
                realizedProfits[transaction.persistentModelID] = transaction.units * transaction.pricePerUnit
            }
        }
        
        return realizedProfits
    }
    
    static func realizedProfitLossBySellTransactionInINR(transactions: [AssetTransaction], categoryExchangeRate: Double) -> [PersistentIdentifier: Double] {
        let sortedTx = orderedTransactions(transactions)
        var buyLots: [(remainingUnits: Double, buyPrice: Double, buyRate: Double)] = []
        var realizedProfits: [PersistentIdentifier: Double] = [:]
        
        for transaction in sortedTx {
            let txRate = transaction.inrExchangeRate ?? categoryExchangeRate
            switch transaction.type {
            case .buy:
                buyLots.append((remainingUnits: transaction.units, buyPrice: transaction.pricePerUnit, buyRate: txRate))
            case .sell:
                var unitsToSell = transaction.units
                var realizedProfitLoss = 0.0
                
                for i in 0..<buyLots.count {
                    if unitsToSell <= 0 {
                        break
                    }
                    
                    let lot = buyLots[i]
                    guard lot.remainingUnits > 0 else {
                        continue
                    }
                    
                    let unitsTaken = min(unitsToSell, lot.remainingUnits)
                    let sellAmt = transaction.pricePerUnit * unitsTaken * txRate
                    let buyAmt = lot.buyPrice * unitsTaken * lot.buyRate
                    realizedProfitLoss += (sellAmt - buyAmt)
                    buyLots[i].remainingUnits -= unitsTaken
                    unitsToSell -= unitsTaken
                }
                
                realizedProfits[transaction.persistentModelID] = realizedProfitLoss
            case .dividend:
                realizedProfits[transaction.persistentModelID] = transaction.units * transaction.pricePerUnit * txRate
            }
        }
        
        return realizedProfits
    }
    
    private static func orderedTransactions(_ transactions: [AssetTransaction]) -> [AssetTransaction] {
        transactions.sorted {
            if $0.date == $1.date {
                return $0.createdAt < $1.createdAt
            }
            return $0.date < $1.date
        }
    }
}
