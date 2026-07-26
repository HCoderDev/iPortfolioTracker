//
//  PortfolioSnapshot.swift
//  PortfolioTracker
//

import Foundation
import SwiftData

@Model
final class PortfolioSnapshot {
    var date: Date
    var note: String? = ""
    var totalValueINR: Double
    var totalInvestedINR: Double
    
    @Relationship(deleteRule: .cascade, inverse: \CategorySnapshot.portfolioSnapshot)
    var categorySnapshots: [CategorySnapshot] = []
    
    init(date: Date = Date(), note: String? = "", totalValueINR: Double = 0.0, totalInvestedINR: Double = 0.0) {
        self.date = date
        self.note = note
        self.totalValueINR = totalValueINR
        self.totalInvestedINR = totalInvestedINR
    }
}
