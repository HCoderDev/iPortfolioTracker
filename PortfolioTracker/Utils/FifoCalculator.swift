//
//  FifoCalculator.swift
//  PortfolioTracker
//
//  Created by Antigravity on 28/05/26.
//

import Foundation
import SwiftData

struct HoldingLot: Identifiable {
    let id = UUID()
    let originalUnits: Double
    let remainingUnits: Double
    let buyPrice: Double
    let date: Date
}

struct FifoResult {
    let realizedProfitLoss: Double
    let lifetimeInvested: Double
    let lifetimeRetrieved: Double
    let holdings: [HoldingLot]
}

struct HoldingLotINR: Identifiable {
    let id = UUID()
    let originalUnits: Double
    let remainingUnits: Double
    let buyPrice: Double // native buy price
    let buyPriceINR: Double // buy price in INR using tx rate
    let date: Date
}

struct FifoResultINR {
    let realizedProfitLoss: Double
    let lifetimeInvested: Double
    let lifetimeRetrieved: Double
    let holdings: [HoldingLotINR]
}

struct TransactionLedgerEntry {
    let type: TransactionType
    let units: Double
    let date: Date
    let createdAt: Date
}

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

enum BuyLotStatus: String, CaseIterable, Identifiable {
    case fullyHeld = "100% Held"
    case partiallySold = "Partially Sold"
    case fullySold = "Sold Out"
    
    var id: String { rawValue }
}

struct MatchedBuyLotInfo: Identifiable {
    let id = UUID()
    let buyTxID: PersistentIdentifier
    let buyDate: Date
    let sellDate: Date
    let unitsTaken: Double
    let buyPrice: Double
    let buyPriceINR: Double
    let sellPrice: Double
    let sellPriceINR: Double
    let realizedGL: Double
    let realizedGLINR: Double
    let holdingDays: Int
    
    var holdingDurationText: String {
        FifoCalculator.formattedHoldingDuration(days: holdingDays)
    }
}

struct TransactionFifoDetail {
    let transactionID: PersistentIdentifier
    let type: TransactionType
    let date: Date
    let units: Double
    let pricePerUnit: Double
    let pricePerUnitINR: Double
    let amount: Double
    let amountINR: Double
    
    // BUY specific fields
    let remainingUnits: Double
    let soldUnits: Double
    let buyStatus: BuyLotStatus?
    let activeHoldingDays: Int?
    let activeHoldingDurationText: String?
    let unrealizedGL: Double?
    let unrealizedGLINR: Double?
    let unrealizedGLPercent: Double?
    let realizedGLForSoldUnits: Double?
    let realizedGLForSoldUnitsINR: Double?
    let realizedGLPercentForSoldUnits: Double?
    let soldHoldingDurationText: String?
    
    // SELL specific fields
    let realizedGLForSellTx: Double?
    let realizedGLForSellTxINR: Double?
    let realizedGLPercentForSellTx: Double?
    let sellHoldingDurationText: String?
    let matchedBuyLots: [MatchedBuyLotInfo]
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
        slabRate: Double,
        ltcgThresholdMonths: Int? = nil
    ) -> (classification: TaxClassification, rate: Double) {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: buyDate, to: valuationDate).day ?? 0
        
        if assetType == .debt {
            return (.slab, slabRate)
        }
        
        let thresholdMonths = ltcgThresholdMonths ?? (country == .us ? 24 : (assetType == .equity ? 12 : 36))
        let thresholdDays = Int(Double(thresholdMonths) * 30.4375)
        
        if days > thresholdDays {
            return (.ltcg, 0.125)
        } else {
            return (.stcg, 0.20)
        }
    }
    
    /// Calculate FIFO tax result for a single asset.
    static func calculateTax(asset: Asset, currencies: [Currency], slabRate: Double = 0.30) -> FifoTaxResult {
        let calendar = Calendar.current
        let customMonths = asset.category?.ltcgMonths
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
                            slabRate: slabRate,
                            ltcgThresholdMonths: customMonths
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
                    let dividendIncome = tx.amount
                    realizedTrades.append(FifoRealizedTrade(
                        sellDate: tx.date,
                        buyDate: tx.date,
                        units: 0.0,
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
        if asset.holdingType.isNonUnitized {
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
                        slabRate: slabRate,
                        ltcgThresholdMonths: customMonths
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
    static func calculate(transactions: [AssetTransaction]) -> FifoResult {
        let sortedTx = orderedTransactions(transactions)
        
        var buyLots: [(originalUnits: Double, remainingUnits: Double, buyPrice: Double, date: Date)] = []
        var realizedPl = 0.0
        
        let lifetimeInvested = transactions.filter { $0.type == .buy }.reduce(0.0) { $0 + $1.amount }
        let lifetimeRetrieved = transactions.filter { $0.type == .sell || $0.type == .dividend }.reduce(0.0) { $0 + $1.amount }
        
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
                let retrieved = tx.amount
                realizedPl += retrieved
            }
        }
        
        let holdings = buyLots
            .filter { $0.remainingUnits > 0.000001 }
            .map { HoldingLot(originalUnits: $0.originalUnits, remainingUnits: $0.remainingUnits, buyPrice: $0.buyPrice, date: $0.date) }
        
        return FifoResult(
            realizedProfitLoss: realizedPl,
            lifetimeInvested: lifetimeInvested,
            lifetimeRetrieved: lifetimeRetrieved,
            holdings: holdings
        )
    }
    
    /// Calculate FIFO-based realized P/L and remaining holding lots in INR terms.
    static func calculateInINR(transactions: [AssetTransaction], categoryExchangeRate: Double) -> FifoResultINR {
        let sortedTx = orderedTransactions(transactions)
        
        var buyLots: [(originalUnits: Double, remainingUnits: Double, buyPrice: Double, buyRate: Double, date: Date)] = []
        var realizedPl = 0.0
        
        let lifetimeInvested = transactions.filter { $0.type == .buy }.reduce(0.0) { sum, tx in
            let rate = tx.inrExchangeRate ?? categoryExchangeRate
            return sum + (tx.amount * rate)
        }
        let lifetimeRetrieved = transactions.filter { $0.type == .sell || $0.type == .dividend }.reduce(0.0) { sum, tx in
            let rate = tx.inrExchangeRate ?? categoryExchangeRate
            return sum + (tx.amount * rate)
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
                let retrieved = tx.amount * txRate
                realizedPl += retrieved
            }
        }
        
        let holdings = buyLots
            .filter { $0.remainingUnits > 0.000001 }
            .map { HoldingLotINR(originalUnits: $0.originalUnits, remainingUnits: $0.remainingUnits, buyPrice: $0.buyPrice, buyPriceINR: $0.buyPrice * $0.buyRate, date: $0.date) }
        
        return FifoResultINR(
            realizedProfitLoss: realizedPl,
            lifetimeInvested: lifetimeInvested,
            lifetimeRetrieved: lifetimeRetrieved,
            holdings: holdings
        )
    }
    
    static func hasSufficientUnits(for transactions: [AssetTransaction]) -> Bool {
        hasSufficientUnits(
            entries: transactions.map {
                TransactionLedgerEntry(
                    type: $0.type,
                    units: $0.units,
                    date: $0.date,
                    createdAt: $0.createdAt
                )
            }
        )
    }
    
    static func hasSufficientUnits(entries: [TransactionLedgerEntry]) -> Bool {
        var runningUnits = 0.0
        
        for transaction in orderedEntries(entries) {
            switch transaction.type {
            case .buy:
                runningUnits += transaction.units
            case .sell:
                guard transaction.units <= runningUnits + 0.000001 else {
                    return false
                }
                runningUnits -= transaction.units
            case .dividend:
                break
            }
        }
        
        return true
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
                realizedProfits[transaction.persistentModelID] = transaction.amount
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
                realizedProfits[transaction.persistentModelID] = transaction.amount * txRate
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
    
    private static func orderedEntries(_ entries: [TransactionLedgerEntry]) -> [TransactionLedgerEntry] {
        entries.sorted {
            if $0.date == $1.date {
                return $0.createdAt < $1.createdAt
            }
            return $0.date < $1.date
        }
    }
    
    // MARK: - Per-Transaction FIFO Breakdown
    
    static func formattedHoldingDuration(days: Int) -> String {
        if days >= 365 {
            let yrs = days / 365
            let mos = (days % 365) / 30
            if mos > 0 { return "\(yrs) yr \(mos) mo" }
            return "\(yrs) yr"
        } else if days >= 30 {
            let mos = days / 30
            let remDays = days % 30
            if remDays > 0 && mos < 3 { return "\(mos) mo \(remDays) d" }
            return "\(mos) mo"
        } else {
            return "\(days) d"
        }
    }
    
    static func detailedFifoBreakdown(
        asset: Asset,
        currencies: [Currency]
    ) -> [PersistentIdentifier: TransactionFifoDetail] {
        let categoryRate = PortfolioMetrics.currentInrExchangeRate(
            for: asset.category ?? Category(name: "Temp", currencyCode: "INR"),
            currencies: currencies
        )
        let sortedTx = orderedTransactions(asset.transactions)
        
        struct InternalBuyLot {
            let txID: PersistentIdentifier
            let buyTx: AssetTransaction
            let buyDate: Date
            let buyPrice: Double
            let buyPriceINR: Double
            let originalUnits: Double
            var remainingUnits: Double
            var soldMatches: [MatchedBuyLotInfo]
        }
        
        var buyLots: [InternalBuyLot] = []
        var sellMatchedLotsMap: [PersistentIdentifier: [MatchedBuyLotInfo]] = [:]
        
        for tx in sortedTx {
            let txRate = tx.inrExchangeRate ?? categoryRate
            switch tx.type {
            case .buy:
                buyLots.append(InternalBuyLot(
                    txID: tx.persistentModelID,
                    buyTx: tx,
                    buyDate: tx.date,
                    buyPrice: tx.pricePerUnit,
                    buyPriceINR: tx.pricePerUnit * txRate,
                    originalUnits: tx.units,
                    remainingUnits: tx.units,
                    soldMatches: []
                ))
            case .sell:
                var unitsToSell = tx.units
                var sellMatches: [MatchedBuyLotInfo] = []
                
                for i in 0..<buyLots.count {
                    if unitsToSell <= 0.000001 { break }
                    
                    let lot = buyLots[i]
                    if lot.remainingUnits > 0.000001 {
                        let unitsTaken = min(unitsToSell, lot.remainingUnits)
                        let daysHeld = max(0, Calendar.current.dateComponents([.day], from: lot.buyDate, to: tx.date).day ?? 0)
                        
                        let sellPrice = tx.pricePerUnit
                        let sellPriceINR = tx.pricePerUnit * txRate
                        
                        let rGL = (sellPrice - lot.buyPrice) * unitsTaken
                        let rGLINR = (sellPriceINR - lot.buyPriceINR) * unitsTaken
                        
                        let match = MatchedBuyLotInfo(
                            buyTxID: lot.txID,
                            buyDate: lot.buyDate,
                            sellDate: tx.date,
                            unitsTaken: unitsTaken,
                            buyPrice: lot.buyPrice,
                            buyPriceINR: lot.buyPriceINR,
                            sellPrice: sellPrice,
                            sellPriceINR: sellPriceINR,
                            realizedGL: rGL,
                            realizedGLINR: rGLINR,
                            holdingDays: daysHeld
                        )
                        
                        sellMatches.append(match)
                        buyLots[i].soldMatches.append(match)
                        buyLots[i].remainingUnits -= unitsTaken
                        unitsToSell -= unitsTaken
                    }
                }
                sellMatchedLotsMap[tx.persistentModelID] = sellMatches
                
            case .dividend:
                break
            }
        }
        
        var result: [PersistentIdentifier: TransactionFifoDetail] = [:]
        let buyLotsMap = Dictionary(uniqueKeysWithValues: buyLots.map { ($0.txID, $0) })
        let currentPrice = asset.currentPrice
        let currentPriceINR = currentPrice * categoryRate
        let today = Date()
        
        for tx in sortedTx {
            let txRate = tx.inrExchangeRate ?? categoryRate
            let priceINR = tx.pricePerUnit * txRate
            let amountINR = tx.amount * txRate
            
            switch tx.type {
            case .buy:
                if let lotState = buyLotsMap[tx.persistentModelID] {
                    let remUnits = max(0, lotState.remainingUnits)
                    let sUnits = max(0, tx.units - remUnits)
                    
                    let status: BuyLotStatus
                    if sUnits <= 0.000001 {
                        status = .fullyHeld
                    } else if remUnits <= 0.000001 {
                        status = .fullySold
                    } else {
                        status = .partiallySold
                    }
                    
                    // Held portion metrics
                    let ageDays = max(0, Calendar.current.dateComponents([.day], from: tx.date, to: today).day ?? 0)
                    let activeDuration = formattedHoldingDuration(days: ageDays)
                    
                    let uGL = remUnits > 0 ? (currentPrice - tx.pricePerUnit) * remUnits : 0.0
                    let uGLINR = remUnits > 0 ? (currentPriceINR - priceINR) * remUnits : 0.0
                    let uGLPct = (remUnits > 0 && tx.pricePerUnit > 0) ? (uGL / (tx.pricePerUnit * remUnits)) * 100.0 : 0.0
                    
                    // Sold portion metrics
                    let rGLSold = lotState.soldMatches.reduce(0.0) { $0 + $1.realizedGL }
                    let rGLSoldINR = lotState.soldMatches.reduce(0.0) { $0 + $1.realizedGLINR }
                    let costOfSold = tx.pricePerUnit * sUnits
                    let rGLSoldPct = (sUnits > 0 && costOfSold > 0) ? (rGLSold / costOfSold) * 100.0 : 0.0
                    
                    let soldHoldingTimeString: String? = {
                        guard !lotState.soldMatches.isEmpty else { return nil }
                        let totalDays = lotState.soldMatches.reduce(0) { $0 + $1.holdingDays }
                        let avgDays = totalDays / lotState.soldMatches.count
                        return "Held \(formattedHoldingDuration(days: avgDays)) before sale"
                    }()
                    
                    result[tx.persistentModelID] = TransactionFifoDetail(
                        transactionID: tx.persistentModelID,
                        type: .buy,
                        date: tx.date,
                        units: tx.units,
                        pricePerUnit: tx.pricePerUnit,
                        pricePerUnitINR: priceINR,
                        amount: tx.amount,
                        amountINR: amountINR,
                        remainingUnits: remUnits,
                        soldUnits: sUnits,
                        buyStatus: status,
                        activeHoldingDays: ageDays,
                        activeHoldingDurationText: activeDuration,
                        unrealizedGL: uGL,
                        unrealizedGLINR: uGLINR,
                        unrealizedGLPercent: uGLPct,
                        realizedGLForSoldUnits: rGLSold,
                        realizedGLForSoldUnitsINR: rGLSoldINR,
                        realizedGLPercentForSoldUnits: rGLSoldPct,
                        soldHoldingDurationText: soldHoldingTimeString,
                        realizedGLForSellTx: nil as Double?,
                        realizedGLForSellTxINR: nil as Double?,
                        realizedGLPercentForSellTx: nil as Double?,
                        sellHoldingDurationText: nil as String?,
                        matchedBuyLots: lotState.soldMatches
                    )
                }
                
            case .sell:
                let matches = sellMatchedLotsMap[tx.persistentModelID] ?? []
                let rGL = matches.reduce(0.0) { $0 + $1.realizedGL }
                let rGLINR = matches.reduce(0.0) { $0 + $1.realizedGLINR }
                
                let costOfMatches = matches.reduce(0.0) { $0 + ($1.buyPrice * $1.unitsTaken) }
                let rGLPct = (costOfMatches > 0) ? (rGL / costOfMatches) * 100.0 : 0.0
                
                let sellHoldingTimeString: String? = {
                    guard !matches.isEmpty else { return nil }
                    let minDays = matches.map { $0.holdingDays }.min() ?? 0
                    let maxDays = matches.map { $0.holdingDays }.max() ?? 0
                    if minDays == maxDays {
                        return "Held \(formattedHoldingDuration(days: minDays))"
                    }
                    return "Held \(formattedHoldingDuration(days: minDays)) – \(formattedHoldingDuration(days: maxDays))"
                }()
                
                result[tx.persistentModelID] = TransactionFifoDetail(
                    transactionID: tx.persistentModelID,
                    type: .sell,
                    date: tx.date,
                    units: tx.units,
                    pricePerUnit: tx.pricePerUnit,
                    pricePerUnitINR: priceINR,
                    amount: tx.amount,
                    amountINR: amountINR,
                    remainingUnits: 0.0,
                    soldUnits: tx.units,
                    buyStatus: nil as BuyLotStatus?,
                    activeHoldingDays: nil as Int?,
                    activeHoldingDurationText: nil as String?,
                    unrealizedGL: nil as Double?,
                    unrealizedGLINR: nil as Double?,
                    unrealizedGLPercent: nil as Double?,
                    realizedGLForSoldUnits: nil as Double?,
                    realizedGLForSoldUnitsINR: nil as Double?,
                    realizedGLPercentForSoldUnits: nil as Double?,
                    soldHoldingDurationText: nil as String?,
                    realizedGLForSellTx: rGL,
                    realizedGLForSellTxINR: rGLINR,
                    realizedGLPercentForSellTx: rGLPct,
                    sellHoldingDurationText: sellHoldingTimeString,
                    matchedBuyLots: matches
                )
                
            case .dividend:
                result[tx.persistentModelID] = TransactionFifoDetail(
                    transactionID: tx.persistentModelID,
                    type: .dividend,
                    date: tx.date,
                    units: 0.0,
                    pricePerUnit: 0.0,
                    pricePerUnitINR: 0.0,
                    amount: tx.amount,
                    amountINR: amountINR,
                    remainingUnits: 0.0,
                    soldUnits: 0.0,
                    buyStatus: nil as BuyLotStatus?,
                    activeHoldingDays: nil as Int?,
                    activeHoldingDurationText: nil as String?,
                    unrealizedGL: nil as Double?,
                    unrealizedGLINR: nil as Double?,
                    unrealizedGLPercent: nil as Double?,
                    realizedGLForSoldUnits: nil as Double?,
                    realizedGLForSoldUnitsINR: nil as Double?,
                    realizedGLPercentForSoldUnits: nil as Double?,
                    soldHoldingDurationText: nil as String?,
                    realizedGLForSellTx: tx.amount,
                    realizedGLForSellTxINR: amountINR,
                    realizedGLPercentForSellTx: 100.0,
                    sellHoldingDurationText: nil as String?,
                    matchedBuyLots: []
                )
            }
        }
        
        return result
    }
}
