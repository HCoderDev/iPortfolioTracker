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
    
    var targetAllocationPercent: Double {
        get { targetAllocation ?? 0.0 }
        set { targetAllocation = newValue }
    }
    
    @Relationship(deleteRule: .cascade, inverse: \Asset.category)
    var assets: [Asset] = []
    
    @Relationship(deleteRule: .cascade, inverse: \SubCategory.category)
    var subCategories: [SubCategory] = []
    
    init(
        name: String,
        currencyCode: String,
        lastInrExchangeRate: Double? = nil,
        convertToInr: Bool? = false,
        isIndividualEquity: Bool? = false,
        targetAllocation: Double? = 0.0
    ) {
        self.name = name
        self.currencyCode = currencyCode
        self.lastInrExchangeRate = lastInrExchangeRate
        self.convertToInr = convertToInr
        self.isIndividualEquity = isIndividualEquity
        self.targetAllocation = targetAllocation
    }
}
