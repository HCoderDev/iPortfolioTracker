//
//  ImportEngine.swift
//  PortfolioTracker
//

import Foundation
import SwiftData

struct ImportEngine {
    
    // MARK: - Date Parser
    
    private static let dateFormats: [String] = [
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd",
        "dd/MM/yyyy HH:mm:ss",
        "dd/MM/yyyy",
        "MM/dd/yyyy",
        "dd-MM-yyyy",
        "dd-MMM-yyyy",
        "dd MMM yyyy",
        "yyyy/MM/dd",
        "yyyy.MM.dd",
        "d-MMM-yy",
        "d-MMM-yyyy",
        "dd-MMM-yy",
        "dd/MM/yy",
        "MM/dd/yy",
        "dd-MM-yy",
        "d/M/yyyy",
        "d/M/yy",
        "d-M-yyyy",
        "d-M-yy",
        "d MMM yyyy",
        "d MMM yy",
        "MMM dd, yyyy",
        "MMM d, yyyy",
        "dd-MMM-yy HH:mm:ss",
        "yyyy/MM/dd HH:mm:ss",
        "yyyyMMdd"
    ]
    
    private static let formatters: [DateFormatter] = {
        dateFormats.map { fmt in
            let df = DateFormatter()
            df.dateFormat = fmt
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone.current
            return df
        }
    }()
    
    private static let isoFormatter = ISO8601DateFormatter()
    
    static func parseDate(_ input: String) -> Date? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters.subtracting(CharacterSet(charactersIn: "-/."))))
        guard !trimmed.isEmpty else { return nil }
        
        // 1. Try Excel numeric date serial format (e.g. 45234 or 45234.5)
        if let doubleVal = Double(trimmed), doubleVal > 30000 && doubleVal < 80000 {
            // Excel epoch starts 1900-01-01 (with 1900 leap year bug: 25569 offset)
            let unixTimestamp = (doubleVal - 25569.0) * 86400.0
            return Date(timeIntervalSince1970: unixTimestamp)
        }
        
        // 2. Try ISO8601
        if let isoDate = isoFormatter.date(from: trimmed) {
            return isoDate
        }
        
        // 3. Try standard DateFormatters
        for df in formatters {
            if let date = df.date(from: trimmed) {
                return date
            }
        }
        
        return nil
    }
    
    // MARK: - Number Parser
    
    static func parseNumber(_ input: String) -> Double? {
        let cleaned = input.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned)
    }
    
    // MARK: - Transaction Type Inference
    
    static func inferRawTxType(_ raw: String, holdingType: HoldingType) -> String? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return nil }
        
        switch holdingType {
        case .epf:
            if cleaned.contains("employee") || cleaned.contains("ee") || cleaned.contains("pf contribution") || cleaned.contains("member") || cleaned.contains("emp contribution") {
                return "EMPLOYEE_CONTRIBUTION"
            } else if cleaned.contains("employer") || cleaned.contains("er") || cleaned.contains("company match") || cleaned.contains("company") || cleaned.contains("matching") {
                return "EMPLOYER_CONTRIBUTION"
            } else if cleaned.contains("interest") || cleaned.contains("int") {
                return "INTEREST"
            } else if cleaned.contains("withdraw") || cleaned.contains("advance") || cleaned.contains("claim") {
                return "WITHDRAWAL"
            } else if cleaned.contains("settlement") || cleaned.contains("transfer") || cleaned.contains("maturity") {
                return "MATURITY"
            }
            
        case .fixedDeposit:
            if cleaned.contains("principal") || cleaned.contains("deposit") || cleaned.contains("installment") || cleaned.contains("opening") {
                return "DEPOSIT"
            } else if cleaned.contains("payout") || cleaned.contains("credit to bank") {
                return "INTEREST_PAYOUT"
            } else if cleaned.contains("interest") || cleaned.contains("int") || cleaned.contains("compounding") {
                return "INTEREST"
            } else if cleaned.contains("withdraw") || cleaned.contains("premature") || cleaned.contains("partial") {
                return "WITHDRAWAL"
            } else if cleaned.contains("maturity") || cleaned.contains("closure") || cleaned.contains("full payout") {
                return "MATURITY"
            }
            
        case .insuranceAnnuity:
            if cleaned.contains("premium") || cleaned.contains("policy premium") || cleaned.contains("payment") {
                return "PREMIUM"
            } else if cleaned.contains("bonus") || cleaned.contains("reversionary") {
                return "BONUS"
            } else if cleaned.contains("survival") || cleaned.contains("money back") || cleaned.contains("periodic") {
                return "SURVIVAL_BENEFIT"
            } else if cleaned.contains("surrender") || cleaned.contains("cancellation") {
                return "SURRENDER"
            } else if cleaned.contains("maturity") || cleaned.contains("claim") {
                return "MATURITY"
            }
            
        case .postOffice:
            if cleaned.contains("deposit") || cleaned.contains("contribution") || cleaned.contains("ppf") || cleaned.contains("ssy") {
                return "CONTRIBUTION"
            } else if cleaned.contains("interest") || cleaned.contains("int") {
                return "INTEREST"
            } else if cleaned.contains("withdraw") || cleaned.contains("partial") {
                return "WITHDRAWAL"
            } else if cleaned.contains("maturity") || cleaned.contains("closure") {
                return "MATURITY"
            }
            
        case .bankBalance:
            if cleaned.contains("deposit") || cleaned.contains("add") || cleaned.contains("credit") || cleaned.contains("cr") || cleaned.contains("savings") {
                return "DEPOSIT"
            } else if cleaned.contains("interest") || cleaned.contains("int") {
                return "INTEREST"
            } else if cleaned.contains("withdraw") || cleaned.contains("debit") || cleaned.contains("dr") || cleaned.contains("spent") {
                return "WITHDRAWAL"
            }
            
        case .investment:
            if cleaned == "buy" || cleaned == "bought" || cleaned == "b" || cleaned.contains("purchase") || cleaned == "cr" || cleaned == "credit" {
                return "BUY"
            } else if cleaned == "sell" || cleaned == "sold" || cleaned == "s" || cleaned.contains("sale") || cleaned == "dr" || cleaned == "debit" {
                return "SELL"
            } else if cleaned == "dividend" || cleaned == "div" || cleaned == "divd" || cleaned.contains("payout") || cleaned == "yield" {
                return "DIVIDEND"
            }
        }
        
        // Fallback checks across any holding type
        if cleaned.contains("employee") { return "EMPLOYEE_CONTRIBUTION" }
        if cleaned.contains("employer") { return "EMPLOYER_CONTRIBUTION" }
        if cleaned.contains("premium") { return "PREMIUM" }
        if cleaned.contains("principal") || cleaned.contains("deposit") { return "DEPOSIT" }
        if cleaned.contains("interest") { return "INTEREST" }
        if cleaned.contains("bonus") { return "BONUS" }
        if cleaned.contains("maturity") { return "MATURITY" }
        if cleaned.contains("withdraw") { return "WITHDRAWAL" }
        if cleaned.contains("buy") || cleaned.contains("bought") { return "BUY" }
        if cleaned.contains("sell") || cleaned.contains("sold") { return "SELL" }
        if cleaned.contains("dividend") { return "DIVIDEND" }
        
        return nil
    }
    
    static func inferTxType(_ raw: String) -> TransactionType? {
        guard let rawType = inferRawTxType(raw, holdingType: .investment) else { return nil }
        return TransactionType(rawValue: rawType)
    }
    
    // MARK: - Asset Name Fuzzy & Brand Match Helper
    
    private static let brandKeywords: Set<String> = [
        "axis", "quant", "sbi", "hdfc", "uti", "icici", "nippon", "parag", "parikh",
        "kotak", "tata", "motilal", "oswal", "aditya", "birla", "bandhan", "groww",
        "zerodha", "dsp", "mirae", "canara", "robeco", "franklin", "sundaram",
        "invesco", "edelweiss", "navi", "union", "baroda", "pgim", "hsbc", "whiteoak",
        "samco", "mahindra", "manulife", "mcred", "vivriti", "nmdc", "pnb", "gail",
        "iifl", "nifty", "bse", "nse", "realty", "gold", "silver"
    ]
    
    static func normalizeNameWords(_ name: String) -> Set<String> {
        let lower = name.lowercased()
        let cleaned = lower.reduce("") { result, char in
            if char.isLetter || char.isNumber {
                return result + String(char)
            } else {
                return result + " "
            }
        }
        return Set(cleaned.split(separator: " ").map(String.init))
    }
    
    static func isAssetNameMatch(_ asset: Asset, statementName: String) -> Bool {
        // 1. Check primary name match
        if isAssetNameMatch(asset.name, statementName) {
            return true
        }
        
        // 2. Check saved aliases for this asset (exact, normalized, or fuzzy alias match)
        for alias in asset.aliases {
            if isAssetNameMatch(alias, statementName) {
                return true
            }
        }
        
        return false
    }
    
    static func isAssetNameMatch(_ name1: String, _ name2: String) -> Bool {
        let trimmed1 = name1.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed2 = name2.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed1.localizedCaseInsensitiveCompare(trimmed2) == .orderedSame {
            return true
        }
        
        let words1 = normalizeNameWords(name1)
        let words2 = normalizeNameWords(name2)
        
        if words1.isEmpty || words2.isEmpty { return false }
        if words1 == words2 { return true }
        
        // Brand collision check: If both names contain distinct brand/AMC words, NEVER match!
        let brands1 = words1.intersection(brandKeywords)
        let brands2 = words2.intersection(brandKeywords)
        if !brands1.isEmpty && !brands2.isEmpty && brands1.intersection(brands2).isEmpty {
            return false
        }
        
        let ignoreWords: Set<String> = ["direct", "growth", "plan", "fund", "of", "etf", "ltd", "limited", "inc", "corp", "corporation", "class", "shares", "co", "company"]
        let filtered1 = words1.subtracting(ignoreWords)
        let filtered2 = words2.subtracting(ignoreWords)
        
        if !filtered1.isEmpty && !filtered2.isEmpty {
            if filtered1 == filtered2 { return true }
            let common = filtered1.intersection(filtered2)
            let minCount = min(filtered1.count, filtered2.count)
            if common.count >= minCount {
                return true
            }
        }
        
        let cleanStr1 = words1.sorted().joined()
        let cleanStr2 = words2.sorted().joined()
        if !cleanStr1.isEmpty && !cleanStr2.isEmpty && (cleanStr1.contains(cleanStr2) || cleanStr2.contains(cleanStr1)) {
            return true
        }
        
        return false
    }
    
    // MARK: - Duplicate Detection Engine
    
    // MARK: - Robust Multi-Pass Duplicate Detection Engine
    
    static func detectDuplicates(
        rows: [ParsedImportRow],
        existingTransactions: [AssetTransaction],
        brokerFilter: Broker?
    ) -> [ParsedImportRow] {
        var updatedRows = rows
        let calendar = Calendar.current
        var usedDBTxIDs = Set<PersistentIdentifier>()
        
        // Helper: Filter candidate DB transactions for a given import row by Asset and Type
        func candidateDBTxs(for row: ParsedImportRow) -> [AssetTransaction] {
            guard let rowTxType = row.txType else { return [] }
            let rowAssetName = row.mappedAsset?.name ?? row.newAssetName ?? row.rawAssetName ?? ""
            guard !rowAssetName.isEmpty else { return [] }
            
            return existingTransactions.filter { tx in
                guard !usedDBTxIDs.contains(tx.persistentModelID) else { return false }
                guard let txAsset = tx.asset else { return false }
                
                // Asset Match
                let assetMatch: Bool
                if let mapped = row.mappedAsset {
                    assetMatch = (txAsset.persistentModelID == mapped.persistentModelID) || isAssetNameMatch(txAsset, statementName: rowAssetName)
                } else {
                    assetMatch = isAssetNameMatch(txAsset, statementName: rowAssetName)
                }
                
                guard assetMatch else { return false }
                
                // Transaction Type Match
                return tx.type == rowTxType
            }
        }
        
        // PASS 1: Exact 1-to-1 Match (Same Date, Same Units/Value)
        for i in 0..<updatedRows.count {
            var row = updatedRows[i]
            guard row.isValid, let rowDate = row.date, let rowUnits = row.units, let rowPrice = row.pricePerUnit else { continue }
            let rowCash = rowUnits * rowPrice
            
            let candidates = candidateDBTxs(for: row)
            if let exactMatch = candidates.first(where: { tx in
                guard calendar.isDate(tx.date, inSameDayAs: rowDate) else { return false }
                let unitsMatch = abs(tx.units - rowUnits) < 0.001
                let valueMatch = abs((tx.units * tx.pricePerUnit) - rowCash) < 2.0
                return unitsMatch || valueMatch
            }) {
                row.duplicateStatus = .exact(exactMatch)
                row.isSelected = false
                usedDBTxIDs.insert(exactMatch.persistentModelID)
                updatedRows[i] = row
            }
        }
        
        // PASS 2: Date-Shifted 1-to-1 Match (Within 5 days, e.g. T+2/weekend settlement shift)
        for i in 0..<updatedRows.count {
            var row = updatedRows[i]
            guard row.duplicateStatus == .none, row.isValid, let rowDate = row.date, let rowUnits = row.units, let rowPrice = row.pricePerUnit else { continue }
            let rowCash = rowUnits * rowPrice
            
            let candidates = candidateDBTxs(for: row)
            if let shiftedMatch = candidates.first(where: { tx in
                let dayDiff = abs(calendar.dateComponents([.day], from: tx.date, to: rowDate).day ?? 99)
                guard dayDiff <= 5 else { return false }
                let unitsMatch = abs(tx.units - rowUnits) < 0.001
                let valueMatch = abs((tx.units * tx.pricePerUnit) - rowCash) < 2.0
                return unitsMatch || valueMatch
            }) {
                row.duplicateStatus = .fuzzy1Day(shiftedMatch, shiftedMatch.date)
                row.isSelected = false
                usedDBTxIDs.insert(shiftedMatch.persistentModelID)
                updatedRows[i] = row
            }
        }
        
        // PASS 3: Multiple Import Rows Combined into Single DB Transaction
        let unmatchedIndices = updatedRows.indices.filter { updatedRows[$0].duplicateStatus == .none && updatedRows[$0].isValid && updatedRows[$0].date != nil && updatedRows[$0].units != nil }
        let unusedDBTxs = existingTransactions.filter { !usedDBTxIDs.contains($0.persistentModelID) && $0.asset != nil }
        
        for dbTx in unusedDBTxs {
            guard let dbAsset = dbTx.asset else { continue }
            let dbCash = dbTx.units * dbTx.pricePerUnit
            
            let candidateRowIndices = unmatchedIndices.filter { idx in
                let row = updatedRows[idx]
                guard row.duplicateStatus == .none, let rowTxType = row.txType, rowTxType == dbTx.type, let rowDate = row.date else { return false }
                let rowAssetName = row.mappedAsset?.name ?? row.newAssetName ?? row.rawAssetName ?? ""
                guard isAssetNameMatch(dbAsset, statementName: rowAssetName) else { return false }
                let dayDiff = abs(calendar.dateComponents([.day], from: dbTx.date, to: rowDate).day ?? 99)
                return dayDiff <= 5
            }
            
            if candidateRowIndices.count >= 2 {
                var foundCombination: [Int]? = nil
                for r in 2...min(4, candidateRowIndices.count) {
                    func findCombo(start: Int, current: [Int], currentUnits: Double, currentCash: Double) {
                        if foundCombination != nil { return }
                        if current.count == r {
                            let unitsMatch = abs(currentUnits - dbTx.units) < 0.01
                            let valMatch = abs(currentCash - dbCash) < 2.0
                            if unitsMatch || valMatch {
                                foundCombination = current
                            }
                            return
                        }
                        for k in start..<candidateRowIndices.count {
                            let rIdx = candidateRowIndices[k]
                            let rUnits = updatedRows[rIdx].units ?? 0
                            let rPrice = updatedRows[rIdx].pricePerUnit ?? 0
                            findCombo(
                                start: k + 1,
                                current: current + [rIdx],
                                currentUnits: currentUnits + rUnits,
                                currentCash: currentCash + (rUnits * rPrice)
                            )
                        }
                    }
                    findCombo(start: 0, current: [], currentUnits: 0.0, currentCash: 0.0)
                    if foundCombination != nil { break }
                }
                
                if let combo = foundCombination {
                    let unitsStr = String(format: "%.2f", dbTx.units)
                    for rIdx in combo {
                        updatedRows[rIdx].duplicateStatus = .combined(dbTx, "\(unitsStr) units")
                        updatedRows[rIdx].isSelected = false
                    }
                    usedDBTxIDs.insert(dbTx.persistentModelID)
                }
            }
        }
        
        // PASS 4: Mark all remaining unmatched rows as New (isSelected = true)
        for i in 0..<updatedRows.count {
            if updatedRows[i].duplicateStatus == .none {
                updatedRows[i].isSelected = true
            }
        }
        
        return updatedRows
    }
    
    // MARK: - TT Buy / TT Sell Exchange Rate Assignment
    
    static func resolveExchangeRate(
        txType: TransactionType,
        inrRateCol: Double?,
        ttBuyRateCol: Double?,
        ttSellRateCol: Double?,
        categoryFallbackRate: Double?
    ) -> Double? {
        if txType == .sell {
            // Sell uses TT Buy rate
            return ttBuyRateCol ?? inrRateCol ?? categoryFallbackRate
        } else if txType == .buy {
            // Buy uses TT Sell rate
            return ttSellRateCol ?? inrRateCol ?? categoryFallbackRate
        } else if txType == .dividend {
            // Dividend uses TT Buy rate
            return ttBuyRateCol ?? inrRateCol ?? categoryFallbackRate
        }
        return inrRateCol ?? categoryFallbackRate
    }
}
