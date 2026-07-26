//
//  LifoCalculator.swift
//  PortfolioTracker
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

struct LifoResult {
    let realizedProfitLoss: Double
    let lifetimeInvested: Double
    let lifetimeRetrieved: Double
    let holdings: [HoldingLot]
}

struct RealizedSellProfit {
    let transactionID: PersistentIdentifier
    let realizedProfitLoss: Double
}

struct HoldingLotINR: Identifiable {
    let id = UUID()
    let originalUnits: Double
    let remainingUnits: Double
    let buyPrice: Double // native buy price
    let buyPriceINR: Double // buy price in INR using tx rate
    let date: Date
}

struct LifoResultINR {
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

struct LifoCalculator {
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
                
                // LIFO: process from the last (most recent) to the first
                for i in stride(from: buyLots.count - 1, through: 0, by: -1) {
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
    
    /// Calculate LIFO-based realized P/L and remaining holding lots in INR terms.
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
                
                // LIFO: process from the last (most recent) to the first
                for i in stride(from: buyLots.count - 1, through: 0, by: -1) {
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
                
                for i in stride(from: buyLots.count - 1, through: 0, by: -1) {
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
                
                for i in stride(from: buyLots.count - 1, through: 0, by: -1) {
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
    
    private static func orderedEntries(_ entries: [TransactionLedgerEntry]) -> [TransactionLedgerEntry] {
        entries.sorted {
            if $0.date == $1.date {
                return $0.createdAt < $1.createdAt
            }
            return $0.date < $1.date
        }
    }
}
