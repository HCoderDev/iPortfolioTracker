//
//  User.swift
//  PortfolioTracker
//

import Foundation
import SwiftData

@Model
final class User {
    var username: String
    var passwordHash: String
    
    // Tax profile settings (optional for backward compatibility)
    var taxSlabRateRaw: Double? = 0.30
    
    var taxSlabRate: Double {
        get { taxSlabRateRaw ?? 0.30 }
        set { taxSlabRateRaw = newValue }
    }
    
    init(username: String, passwordHash: String = "dummy", taxSlabRate: Double = 0.30) {
        self.username = username
        self.passwordHash = passwordHash
        self.taxSlabRateRaw = taxSlabRate
    }
}
