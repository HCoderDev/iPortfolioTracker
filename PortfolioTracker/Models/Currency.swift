//
//  Currency.swift
//  PortfolioTracker
//

import Foundation
import SwiftData

@Model
final class Currency {
    var code: String
    var exchangeRate: Double
    var isDefault: Bool
    
    init(code: String, exchangeRate: Double = 1.0, isDefault: Bool = false) {
        self.code = code
        self.exchangeRate = exchangeRate
        self.isDefault = isDefault
    }
}
