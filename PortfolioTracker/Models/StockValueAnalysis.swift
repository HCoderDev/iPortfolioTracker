//
//  StockValueAnalysis.swift
//  PortfolioTracker
//
//  Created by Antigravity on 30/05/26.
//

import Foundation
import SwiftData

@Model
final class StockValueAnalysis {
    var analysisDate: Date
    var cmp: Double
    var industry: String
    var epsValuesString: String
    var dpsValuesString: String
    var industryPE: Double
    var intrinsicPE: Double
    var bestCasePE: Double
    var bookValue: Double
    var debtToEquity: Double
    var priceToSales: Double
    var freeCashFlow: Double
    var freeCashFlowRatio: Double
    var consensusGrowthRate: Double
    var consensusDivPayoutRatio: Double
    var investmentPeriod: Int
    
    var asset: Asset?
    
    init(
        cmp: Double = 0.0,
        industry: String = "",
        epsValuesString: String = "",
        dpsValuesString: String = "",
        industryPE: Double = 0.0,
        intrinsicPE: Double = 0.0,
        bestCasePE: Double = 0.0,
        bookValue: Double = 0.0,
        debtToEquity: Double = 0.0,
        priceToSales: Double = 0.0,
        freeCashFlow: Double = 0.0,
        freeCashFlowRatio: Double = 0.0,
        consensusGrowthRate: Double = 0.0,
        consensusDivPayoutRatio: Double = 0.0,
        investmentPeriod: Int = 3
    ) {
        self.analysisDate = Date()
        self.cmp = cmp
        self.industry = industry
        self.epsValuesString = epsValuesString
        self.dpsValuesString = dpsValuesString
        self.industryPE = industryPE
        self.intrinsicPE = intrinsicPE
        self.bestCasePE = bestCasePE
        self.bookValue = bookValue
        self.debtToEquity = debtToEquity
        self.priceToSales = priceToSales
        self.freeCashFlow = freeCashFlow
        self.freeCashFlowRatio = freeCashFlowRatio
        self.consensusGrowthRate = consensusGrowthRate
        self.consensusDivPayoutRatio = consensusDivPayoutRatio
        self.investmentPeriod = investmentPeriod
    }
}

// MARK: - Mathematical Calculations
extension StockValueAnalysis {
    var epsList: [Double] {
        get {
            epsValuesString.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        }
        set {
            epsValuesString = newValue.map { String($0) }.joined(separator: ",")
        }
    }
    
    var dpsList: [Double] {
        get {
            dpsValuesString.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        }
        set {
            dpsValuesString = newValue.map { String($0) }.joined(separator: ",")
        }
    }
    
    // EPS CAGR (growth from oldest EPS to latest EPS)
    var epsGrowthRate: Double {
        let list = epsList
        guard list.count >= 2, let latest = list.first, let oldest = list.last, oldest > 0, latest > 0 else {
            return 0.0
        }
        let years = Double(list.count - 1)
        return pow(latest / oldest, 1.0 / years) - 1.0
    }
    
    // Year-on-Year Growth rates (newest to oldest)
    var yearWiseGrowthRates: [Double] {
        let list = epsList
        guard list.count >= 2 else { return [] }
        var rates: [Double] = []
        for i in 0..<(list.count - 1) {
            let latest = list[i]
            let previous = list[i + 1]
            if previous > 0 {
                rates.append((latest - previous) / previous)
            } else {
                rates.append(0.0)
            }
        }
        return rates
    }
    
    // Current P/E ratio
    var currentPE: Double {
        guard let latestEPS = epsList.first, latestEPS > 0 else { return 0.0 }
        return cmp / latestEPS
    }
    
    // Intrinsic value
    var intrinsicValue: Double {
        guard let latestEPS = epsList.first else { return 0.0 }
        return intrinsicPE * latestEPS
    }
    
    // PEG ratio (Current PE / (epsGrowthRate * 100))
    var pegRatio: Double {
        let growthPercent = epsGrowthRate * 100.0
        guard growthPercent > 0 else { return 0.0 }
        return currentPE / growthPercent
    }
    
    // P/B ratio
    var pbRatio: Double {
        guard bookValue > 0 else { return 0.0 }
        return cmp / bookValue
    }
    
    // ROE
    var roe: Double {
        guard bookValue > 0, let latestEPS = epsList.first else { return 0.0 }
        return latestEPS / bookValue
    }
    
    // Diagnosis: Undervalued vs Overvalued
    var isUndervalued: Bool {
        cmp < intrinsicValue
    }
    
    var valuationMarginPercent: Double {
        guard cmp > 0 else { return 0.0 }
        return (intrinsicValue - cmp) / cmp
    }
    
    // Projected EPS for each year in the period
    var projectedEpsYearWise: [Double] {
        guard let latestEPS = epsList.first else { return [] }
        var list: [Double] = []
        var current = latestEPS
        for _ in 1...investmentPeriod {
            current = current * (1.0 + consensusGrowthRate)
            list.append(current)
        }
        return list
    }
    
    // Projected dividends for each year in the period
    var projectedDividendsYearWise: [Double] {
        let epsProj = projectedEpsYearWise
        return epsProj.map { $0 * consensusDivPayoutRatio }
    }
    
    // Projected Price
    var projectedPrice: Double {
        guard let finalEPS = projectedEpsYearWise.last else { return 0.0 }
        return bestCasePE * finalEPS
    }
    
    // Current capital gains potential (absolute)
    var currentCgPotential: Double {
        intrinsicValue - cmp
    }
    
    // Projected capital gains potential (%)
    var projectedCgPotentialPercent: Double {
        guard cmp > 0 else { return 0.0 }
        return (projectedPrice - cmp) / cmp
    }
    
    // Overall projected capital gains (incorporates projected dividends)
    var overallProjectedCapitalGains: Double {
        let sumDividends = projectedDividendsYearWise.reduce(0.0, +)
        return projectedPrice - cmp + sumDividends
    }
    
    // Overall projected CAGR
    var overallProjectedCAGR: Double {
        guard cmp > 0, investmentPeriod > 0 else { return 0.0 }
        let endValue = cmp + overallProjectedCapitalGains
        guard endValue > 0 else { return 0.0 }
        return pow(endValue / cmp, 1.0 / Double(investmentPeriod)) - 1.0
    }
}
