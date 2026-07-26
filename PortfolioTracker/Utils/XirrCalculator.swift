//
//  XirrCalculator.swift
//  PortfolioTracker
//

import Foundation

struct CashFlow {
    let amount: Double
    let date: Date
}

struct XirrCalculator {
    private static let maxIterations = 100
    private static let tolerance = 0.00001
    private static let guess = 0.1
    
    /// Calculate XIRR from a list of cash flows using Newton-Raphson method.
    /// Returns the rate as a percentage, or nil if it cannot converge.
    static func calculateXirr(cashFlows: [CashFlow]) -> Double? {
        guard !cashFlows.isEmpty else { return nil }
        
        let sorted = cashFlows.sorted { $0.date < $1.date }
        guard let startDate = sorted.first?.date else { return nil }
        
        let calendar = Calendar.current
        let mapped: [(days: Double, amount: Double)] = sorted.map { cf in
            let days = Double(calendar.dateComponents([.day], from: startDate, to: cf.date).day ?? 0)
            return (days, cf.amount)
        }
        
        var rate = guess
        for _ in 0..<maxIterations {
            let f = calculateNpv(cashFlows: mapped, rate: rate)
            let df = calculateDerivativeNpv(cashFlows: mapped, rate: rate)
            
            guard df != 0.0 else { return nil }
            
            let newRate = rate - f / df
            if abs(newRate - rate) < tolerance {
                return newRate * 100.0
            }
            rate = newRate
        }
        return nil
    }
    
    private static func calculateNpv(cashFlows: [(days: Double, amount: Double)], rate: Double) -> Double {
        var npv = 0.0
        for cf in cashFlows {
            let years = cf.days / 365.0
            npv += cf.amount / pow(1.0 + rate, years)
        }
        return npv
    }
    
    private static func calculateDerivativeNpv(cashFlows: [(days: Double, amount: Double)], rate: Double) -> Double {
        var df = 0.0
        for cf in cashFlows {
            let years = cf.days / 365.0
            if years != 0.0 {
                df -= years * cf.amount / pow(1.0 + rate, years + 1.0)
            }
        }
        return df
    }
}
