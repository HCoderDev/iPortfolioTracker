//
//  FICalculator.swift
//  PortfolioTracker
//

import Foundation
import SwiftUI

struct FIMilestone: Identifiable {
    let id = UUID()
    let percentage: Double
    let label: String
    let targetAmount: Double
    let monthsNeeded: Int
    let targetDate: Date
    let ageAtMilestone: Double
    let isAchieved: Bool
}

struct FIProjectionResult {
    let currentNetWorth: Double
    let targetGoal: Double
    let progressPercentage: Double
    let currentAge: Int
    let monthsNeeded: Int
    let yearsNeeded: Double
    let targetDate: Date
    let ageAtFI: Double
    let monthlySIP: Double
    let returnRate: Double
    let inflationRate: Double
    let safeWithdrawalRate: Double
    let annualPassiveIncomeAtFI: Double
    let monthlyPassiveIncomeAtFI: Double
    let milestones: [FIMilestone]
}

enum FICalculator {
    // Default Fallbacks
    static let defaultTargetGoal: Double = 70_000_000.0 // 7 Crore INR
    static let defaultBirthDate: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    static let defaultMonthlySIP: Double = 50_000.0
    static let defaultReturnRate: Double = 12.0
    static let defaultInflationRate: Double = 6.0
    static let defaultSWR: Double = 4.0
    
    static func calculateCurrentAge(from birthDate: Date, asOf currentDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: birthDate, to: currentDate)
        return max(0, components.year ?? 30)
    }
    
    static func projectFI(
        currentNetWorth: Double,
        targetGoal: Double,
        birthDate: Date,
        monthlySIP: Double,
        returnRate: Double,
        inflationRate: Double,
        safeWithdrawalRate: Double = 4.0,
        asOf currentDate: Date = Date()
    ) -> FIProjectionResult {
        let cleanTargetGoal = max(1.0, targetGoal)
        let cleanSIP = max(0.0, monthlySIP)
        let cleanReturnRate = max(0.0, returnRate)
        let progressPct = min(100.0, (currentNetWorth / cleanTargetGoal) * 100.0)
        let currentAgeYears = calculateCurrentAge(from: birthDate, asOf: currentDate)
        
        let monthlyReturnRate = cleanReturnRate > 0 ? pow(1.0 + (cleanReturnRate / 100.0), 1.0 / 12.0) - 1.0 : 0.0
        
        // Calculate months needed to reach full Target Goal
        var balance = currentNetWorth
        var monthsNeeded = 0
        let maxMonths = 1200 // Cap at 100 years
        
        if balance < cleanTargetGoal {
            while balance < cleanTargetGoal && monthsNeeded < maxMonths {
                balance = (balance * (1.0 + monthlyReturnRate)) + cleanSIP
                monthsNeeded += 1
            }
        }
        
        let targetDate = Calendar.current.date(byAdding: .month, value: monthsNeeded, to: currentDate) ?? currentDate
        let exactBirthAgeDouble = Double(currentDate.timeIntervalSince(birthDate)) / (365.25 * 86400.0)
        let ageAtFI = exactBirthAgeDouble + (Double(monthsNeeded) / 12.0)
        let yearsNeeded = Double(monthsNeeded) / 12.0
        
        let annualPassiveIncome = cleanTargetGoal * (safeWithdrawalRate / 100.0)
        let monthlyPassiveIncome = annualPassiveIncome / 12.0
        
        // Calculate Milestones (25%, 50%, 75%, 100%)
        let milestonePcts: [(Double, String)] = [
            (25.0, "25% FI (Quarter FI)"),
            (50.0, "50% FI (Half FI)"),
            (75.0, "75% FI (Three-Quarter FI)"),
            (100.0, "100% FI (Full Freedom)")
        ]
        
        var milestones: [FIMilestone] = []
        
        for (pct, label) in milestonePcts {
            let milestoneGoal = cleanTargetGoal * (pct / 100.0)
            let isAchieved = currentNetWorth >= milestoneGoal
            
            var mBalance = currentNetWorth
            var mMonths = 0
            
            if !isAchieved {
                while mBalance < milestoneGoal && mMonths < maxMonths {
                    mBalance = (mBalance * (1.0 + monthlyReturnRate)) + cleanSIP
                    mMonths += 1
                }
            }
            
            let mDate = Calendar.current.date(byAdding: .month, value: mMonths, to: currentDate) ?? currentDate
            let mAge = exactBirthAgeDouble + (Double(mMonths) / 12.0)
            
            milestones.append(FIMilestone(
                percentage: pct,
                label: label,
                targetAmount: milestoneGoal,
                monthsNeeded: mMonths,
                targetDate: mDate,
                ageAtMilestone: mAge,
                isAchieved: isAchieved
            ))
        }
        
        return FIProjectionResult(
            currentNetWorth: currentNetWorth,
            targetGoal: cleanTargetGoal,
            progressPercentage: progressPct,
            currentAge: currentAgeYears,
            monthsNeeded: monthsNeeded,
            yearsNeeded: yearsNeeded,
            targetDate: targetDate,
            ageAtFI: ageAtFI,
            monthlySIP: cleanSIP,
            returnRate: cleanReturnRate,
            inflationRate: inflationRate,
            safeWithdrawalRate: safeWithdrawalRate,
            annualPassiveIncomeAtFI: annualPassiveIncome,
            monthlyPassiveIncomeAtFI: monthlyPassiveIncome,
            milestones: milestones
        )
    }
}
