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
    
    var targetAllocationPercent: Double {
        get { targetAllocation ?? 0.0 }
        set { targetAllocation = newValue }
    }
    
    var isConvertToInr: Bool {
        get { convertToInr ?? true }
        set { convertToInr = newValue }
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
        lastUpdatedDate: Date? = nil
    ) {
        self.name = name
        self.currencyCode = currencyCode
        self.lastInrExchangeRate = lastInrExchangeRate
        self.convertToInr = convertToInr
        self.isIndividualEquity = isIndividualEquity
        self.targetAllocation = targetAllocation
        self.lastUpdatedDate = lastUpdatedDate
    }
}
