//
//  StockDCFAnalysis.swift
//  PortfolioTracker
//
//  Created by Antigravity on 21/06/26.
//

import Foundation
import SwiftData

@Model
final class StockDCFAnalysis {
    var analysisDate: Date
    var cmp: Double
    var startingFCF: Double
    var growthRate: Double      // e.g. 7.5 for 7.5%
    var discountRate: Double    // e.g. 11.0 for 11.0%
    var terminalGrowth: Double  // e.g. 4.0 for 4.0%
    var shares: Double          // e.g. 405.0 in crores
    
    var asset: Asset?
    
    init(
        cmp: Double = 0.0,
        startingFCF: Double = 0.0,
        growthRate: Double = 0.0,
        discountRate: Double = 0.0,
        terminalGrowth: Double = 0.0,
        shares: Double = 0.0
    ) {
        self.analysisDate = Date()
        self.cmp = cmp
        self.startingFCF = startingFCF
        self.growthRate = growthRate
        self.discountRate = discountRate
        self.terminalGrowth = terminalGrowth
        self.shares = shares
    }
}

// MARK: - DCF Calculations
extension StockDCFAnalysis {
    struct DCFYearRow: Identifiable {
        var id: Int { year }
        let year: Int
        let fcf: Double
        let discountFactor: Double
        let pv: Double
    }
    
    var yearRows: [DCFYearRow] {
        var rows: [DCFYearRow] = []
        var currentFCF = startingFCF
        let g = growthRate / 100.0
        let r = discountRate / 100.0
        
        for yr in 1...10 {
            currentFCF = currentFCF * (1.0 + g)
            let factor = 1.0 / pow(1.0 + r, Double(yr))
            let pv = currentFCF * factor
            rows.append(DCFYearRow(year: yr, fcf: currentFCF, discountFactor: factor, pv: pv))
        }
        return rows
    }
    
    var terminalValue: Double {
        let g = growthRate / 100.0
        let r = discountRate / 100.0
        let dg = terminalGrowth / 100.0
        
        let fcf10 = startingFCF * pow(1.0 + g, 10.0)
        
        guard r > dg else { return 0.0 }
        return (fcf10 * (1.0 + dg)) / (r - dg)
    }
    
    var pvOfTerminalValue: Double {
        let r = discountRate / 100.0
        let factor10 = 1.0 / pow(1.0 + r, 10.0)
        return terminalValue * factor10
    }
    
    var enterpriseValue: Double {
        let sumPVOfFCFs = yearRows.reduce(0.0) { $0 + $1.pv }
        return sumPVOfFCFs + pvOfTerminalValue
    }
    
    var intrinsicValuePerShare: Double {
        guard shares > 0 else { return 0.0 }
        return enterpriseValue / shares
    }
    
    var isUndervalued: Bool {
        cmp < intrinsicValuePerShare
    }
    
    var valuationMarginPercent: Double {
        guard cmp > 0 else { return 0.0 }
        return (intrinsicValuePerShare - cmp) / cmp
    }
}

// MARK: - Indian Currency Formatting Helper
extension Double {
    func formattedIndianRupees(includeDecimal: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_IN")
        if includeDecimal {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        } else {
            formatter.maximumFractionDigits = 0
            formatter.minimumFractionDigits = 0
        }
        return formatter.string(from: NSNumber(value: self)) ?? (includeDecimal ? String(format: "%.2f", self) : String(format: "%.0f", self))
    }
}
