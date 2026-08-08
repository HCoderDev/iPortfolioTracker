//
//  Category.swift
//  PortfolioTracker
//

import Foundation
import SwiftData

@Model
final class Category {
    var name: String
    var currencyCode: String
    var lastInrExchangeRate: Double?
    var convertToInr: Bool?
    var isIndividualEquity: Bool? = false
    var targetAllocation: Double? = 0.0
    var lastUpdatedDate: Date? = nil
    var ltcgThresholdMonths: Int? = 12
    var passiveTransactionTypesRaw: String? = nil
    
    func allowedPassiveTransactionTypes() -> [(id: String, name: String, icon: String)] {
        var holdingTypes: Set<HoldingType> = Set(assets.map { $0.holdingType })
        if holdingTypes.isEmpty {
            let lowerName = name.lowercased()
            if lowerName.contains("epf") || lowerName.contains("provident") {
                holdingTypes.insert(.epf)
            } else if lowerName.contains("lic") || lowerName.contains("insurance") || lowerName.contains("policy") || lowerName.contains("annuity") {
                holdingTypes.insert(.insuranceAnnuity)
            } else if lowerName.contains("fd") || lowerName.contains("fixed deposit") || lowerName.contains("rd") {
                holdingTypes.insert(.fixedDeposit)
            } else if lowerName.contains("post office") || lowerName.contains("ppf") || lowerName.contains("nsc") {
                holdingTypes.insert(.postOffice)
            } else {
                holdingTypes.insert(.investment)
            }
        }
        
        var result: [(id: String, name: String, icon: String)] = []
        
        for hType in holdingTypes {
            let config = TransactionTypeRegistry.shared.config(for: hType)
            for txConfig in config.allowedTransactions {
                let raw = txConfig.rawType.uppercased()
                if raw == "BUY" || raw == "SELL" || raw == "DEPOSIT" || raw == "WITHDRAWAL" || raw == "CONTRIBUTION" ||
                   raw == "EMPLOYEE_CONTRIBUTION" || raw == "EMPLOYER_CONTRIBUTION" || raw == "MATURITY" || raw == "SURRENDER" || raw == "PREMIUM" {
                    continue
                }
                if txConfig.affectsProfit || raw.contains("DIVIDEND") || raw.contains("INTEREST") || raw.contains("BONUS") || raw.contains("SURVIVAL") || raw.contains("COUPON") || raw.contains("RENT") {
                    if !result.contains(where: { $0.id == raw }) {
                        result.append((id: raw, name: txConfig.displayName, icon: txConfig.iconName))
                    }
                }
            }
        }
        
        let catTx = assets.flatMap { $0.transactions }
        for tx in catTx {
            let raw = tx.rawType.uppercased()
            if raw.contains("EMPLOYER") || raw.contains("EMPLOYEE") || raw.contains("BUY") || raw.contains("SELL") || raw.contains("CONTRIBUTION") || raw.contains("DEPOSIT") || raw.contains("MATURITY") || raw.contains("PREMIUM") {
                continue
            }
            if (raw.contains("DIVIDEND") || raw.contains("INTEREST") || raw.contains("BONUS") || raw.contains("SURVIVAL") || raw.contains("COUPON") || raw.contains("RENT") || raw.contains("ROYALTY")) && !result.contains(where: { $0.id == raw }) {
                result.append((id: raw, name: raw.capitalized, icon: "tag.fill"))
            }
        }
        
        if result.isEmpty {
            result.append((id: "DIVIDEND", name: "Dividend Received", icon: "gift.fill"))
        }
        
        return result
    }
    
    var passiveTransactionTypes: Set<String> {
        get {
            if let raw = passiveTransactionTypesRaw, !raw.isEmpty {
                let array = raw.components(separatedBy: "|||").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
                return Set(array)
            }
            return Set(allowedPassiveTransactionTypes().map { $0.id })
        }
        set {
            passiveTransactionTypesRaw = newValue.joined(separator: "|||")
        }
    }
    
    func isPassiveTransactionType(_ type: String) -> Bool {
        let clean = type.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean.contains("EMPLOYER") || clean.contains("EMPLOYEE") || clean.contains("CONTRIBUTION") ||
           clean == "BUY" || clean == "SELL" || clean == "DEPOSIT" || clean == "WITHDRAWAL" ||
           clean == "MATURITY" || clean == "SURRENDER" || clean == "PREMIUM" {
            return false
        }
        let activeTypes = passiveTransactionTypes
        if activeTypes.contains(clean) { return true }
        return activeTypes.contains(where: { clean.contains($0) })
    }
    
    var targetAllocationPercent: Double {
        get { targetAllocation ?? 0.0 }
        set { targetAllocation = newValue }
    }
    
    var isConvertToInr: Bool {
        get { convertToInr ?? true }
        set { convertToInr = newValue }
    }
    
    var ltcgMonths: Int {
        get {
            if let custom = ltcgThresholdMonths, custom > 0 {
                return custom
            }
            if currencyCode == "USD" || name.localizedCaseInsensitiveContains("US") || name.localizedCaseInsensitiveContains("Foreign") {
                return 24
            }
            return 12
        }
        set {
            ltcgThresholdMonths = newValue
        }
    }
    
    @Relationship(deleteRule: .cascade, inverse: \Asset.category)
    var assets: [Asset] = []
    
    @Relationship(deleteRule: .cascade, inverse: \SubCategory.category)
    var subCategories: [SubCategory] = []
    
    init(
        name: String,
        currencyCode: String,
        lastInrExchangeRate: Double? = nil,
        convertToInr: Bool? = true,
        isIndividualEquity: Bool? = false,
        targetAllocation: Double? = 0.0,
        lastUpdatedDate: Date? = nil,
        ltcgThresholdMonths: Int? = 12
    ) {
        self.name = name
        self.currencyCode = currencyCode
        self.lastInrExchangeRate = lastInrExchangeRate
        self.convertToInr = convertToInr
        self.isIndividualEquity = isIndividualEquity
        self.targetAllocation = targetAllocation
        self.lastUpdatedDate = lastUpdatedDate
        self.ltcgThresholdMonths = ltcgThresholdMonths
    }
}
