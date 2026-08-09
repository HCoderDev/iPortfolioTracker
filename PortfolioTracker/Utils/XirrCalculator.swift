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
    private static let tolerance = 0.0000001 // 1e-7 for high accuracy matching Excel/Groww
    private static let guesses: [Double] = [0.1, 0.05, -0.05, 0.2, -0.2, 0.5, -0.5, 1.0, -0.8]
    
    /// Calculate XIRR from a list of cash flows using Newton-Raphson method with multi-start guesses.
    /// Returns the rate as a percentage, or nil if it cannot converge.
    static func calculateXirr(cashFlows: [CashFlow]) -> Double? {
        guard !cashFlows.isEmpty else { return nil }
        
        let sorted = cashFlows.sorted { $0.date < $1.date }
        guard let firstDate = sorted.first?.date else { return nil }
        
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: firstDate)
        
        let mapped: [(days: Double, amount: Double)] = sorted.map { cf in
            let cfDate = calendar.startOfDay(for: cf.date)
            let days = Double(calendar.dateComponents([.day], from: startDate, to: cfDate).day ?? 0)
            return (days, cf.amount)
        }
        
        // Ensure cash flows contain at least one positive and one negative amount
        let hasPositive = mapped.contains { $0.amount > 0 }
        let hasNegative = mapped.contains { $0.amount < 0 }
        guard hasPositive && hasNegative else { return nil }
        
        for initialGuess in guesses {
            if let result = solveXirr(cashFlows: mapped, guess: initialGuess) {
                return result * 100.0
            }
        }
        
        return nil
    }
    
    private static func solveXirr(cashFlows: [(days: Double, amount: Double)], guess: Double) -> Double? {
        var rate = guess
        
        for _ in 0..<maxIterations {
            guard 1.0 + rate > 0.0001 else { return nil }
            
            let f = calculateNpv(cashFlows: cashFlows, rate: rate)
            let df = calculateDerivativeNpv(cashFlows: cashFlows, rate: rate)
            
            guard df != 0.0 && !df.isNaN && !f.isNaN else { return nil }
            
            var newRate = rate - f / df
            
            // Keep rate within realistic bounds during iteration
            if newRate <= -0.9999 {
                newRate = -0.99
            }
            
            if abs(newRate - rate) < tolerance {
                return newRate
            }
            
            rate = newRate
        }
        
        return nil
    }
    
    private static func calculateNpv(cashFlows: [(days: Double, amount: Double)], rate: Double) -> Double {
        guard 1.0 + rate > 0.0001 else { return Double.nan }
        var npv = 0.0
        for cf in cashFlows {
            let years = cf.days / 365.0
            npv += cf.amount / pow(1.0 + rate, years)
        }
        return npv
    }
    
    private static func calculateDerivativeNpv(cashFlows: [(days: Double, amount: Double)], rate: Double) -> Double {
        guard 1.0 + rate > 0.0001 else { return Double.nan }
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
