//
//  FICalculationCard.swift
//  PortfolioTracker
//

import SwiftUI

struct FICalculationCard: View {
    let currentNetWorth: Double
    
    @AppStorage("fiTargetGoal") private var targetGoal: Double = FICalculator.defaultTargetGoal
    @AppStorage("fiBirthDateTimeInterval") private var birthDateTimeInterval: Double = FICalculator.defaultBirthDate.timeIntervalSince1970
    @AppStorage("fiMonthlySIP") private var monthlySIP: Double = FICalculator.defaultMonthlySIP
    @AppStorage("fiReturnRate") private var returnRate: Double = FICalculator.defaultReturnRate
    @AppStorage("fiInflationRate") private var inflationRate: Double = FICalculator.defaultInflationRate
    @AppStorage("fiSafeWithdrawalRate") private var safeWithdrawalRate: Double = FICalculator.defaultSWR
    
    @State private var showSettingsSheet = false
    @State private var isExpandedMilestones = false
    
    private var projection: FIProjectionResult {
        let birthDate = Date(timeIntervalSince1970: birthDateTimeInterval)
        return FICalculator.projectFI(
            currentNetWorth: currentNetWorth,
            targetGoal: targetGoal,
            birthDate: birthDate,
            monthlySIP: monthlySIP,
            returnRate: returnRate,
            inflationRate: inflationRate,
            safeWithdrawalRate: safeWithdrawalRate
        )
    }
    
    private var formattedTargetGoal: String {
        let inCr = projection.targetGoal / 10_000_000.0
        if inCr >= 1.0 {
            return String(format: "₹%.2f Cr", inCr)
        } else {
            let inLakh = projection.targetGoal / 100_000.0
            return String(format: "₹%.2f Lakh", inLakh)
        }
    }
    
    private var formattedNetWorth: String {
        let inCr = currentNetWorth / 10_000_000.0
        if inCr >= 1.0 {
            return String(format: "₹%.2f Cr", inCr)
        } else {
            let inLakh = currentNetWorth / 100_000.0
            return String(format: "₹%.2f Lakh", inLakh)
        }
    }
    
    private func formatTargetDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
    
    var body: some View {
        let result = projection
        
        VStack(alignment: .leading, spacing: 16) {
            // Header Row
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.title3)
                        .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FINANCIAL INDEPENDENCE (FI)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text("Freedom Projection & Goal Tracker")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }
                
                Spacer()
                
                Button {
                    showSettingsSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape.fill")
                            .font(.caption)
                        Text("Edit Target")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.accent.opacity(0.12))
                    .foregroundStyle(AppTheme.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Goal Progress Bar & Metrics
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Target: \(formattedTargetGoal)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text("\(result.progressPercentage.formatted1)% Achieved")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                }
                
                // Animated Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.tertiarySystemFill))
                            .frame(height: 10)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.accent, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(result.progressPercentage / 100.0))), height: 10)
                    }
                }
                .frame(height: 10)
                
                HStack {
                    Text("Current: ₹\(currentNetWorth.formattedComma)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    let remaining = max(0, result.targetGoal - currentNetWorth)
                    Text("Remaining: ₹\(remaining.formattedComma)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Primary FI Achievement Time Highlight Card
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TIME TO FI")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    if result.monthsNeeded == 0 {
                        Text("ACHIEVED! 🎉")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.gain)
                    } else {
                        let yrs = result.monthsNeeded / 12
                        let mos = result.monthsNeeded % 12
                        Text("\(yrs) yrs \(mos) mos")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .frame(height: 36)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("TARGET FI DATE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    Text(formatTargetDate(result.targetDate))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .frame(height: 36)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("AGE AT FI")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    Text(String(format: "%.1f yrs", result.ageAtFI))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(AppTheme.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Statistics Grid (4 Key Stats)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                FIStatTile(
                    title: "Monthly SIP",
                    value: "₹\(result.monthlySIP.formattedComma)",
                    subtitle: "Current Contribution",
                    icon: "arrow.up.forward.square.fill"
                )
                
                FIStatTile(
                    title: "Assumed Return",
                    value: "\(result.returnRate.formatted1)% p.a.",
                    subtitle: "CAGR Growth Rate",
                    icon: "chart.line.uptrend.xyaxis"
                )
                
                FIStatTile(
                    title: "Passive Income (4% SWR)",
                    value: "₹\((result.annualPassiveIncomeAtFI / 100_000).formatted1) Lakh/yr",
                    subtitle: "₹\((result.monthlyPassiveIncomeAtFI).formattedComma)/mo",
                    icon: "indianrupeesign.circle.fill"
                )
                
                FIStatTile(
                    title: "Current Age",
                    value: "\(result.currentAge) Years",
                    subtitle: "Date of Birth Setting",
                    icon: "person.fill"
                )
            }
            
            // Milestone Breakdown Accordion / Toggle
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut) {
                        isExpandedMilestones.toggle()
                    }
                } label: {
                    HStack {
                        Text("Milestone Roadmap")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(isExpandedMilestones ? "Hide Details" : "Show Details")
                            .font(.caption)
                            .foregroundStyle(AppTheme.accent)
                        Image(systemName: isExpandedMilestones ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .buttonStyle(.plain)
                
                if isExpandedMilestones {
                    VStack(spacing: 8) {
                        ForEach(result.milestones) { milestone in
                            HStack {
                                Image(systemName: milestone.isAchieved ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(milestone.isAchieved ? AppTheme.gain : .secondary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(milestone.label)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Goal: ₹\(milestone.targetAmount.formattedComma)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    if milestone.isAchieved {
                                        Text("Achieved")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(AppTheme.gain)
                                    } else {
                                        Text(formatTargetDate(milestone.targetDate))
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(AppTheme.accent)
                                        Text(String(format: "Age %.1f", milestone.ageAtMilestone))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(10)
                            .background(milestone.isAchieved ? AppTheme.gain.opacity(0.06) : Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .modifier(AppTheme.cardStyle())
        .sheet(isPresented: $showSettingsSheet) {
            FISettingsSheet()
        }
    }
}

// MARK: - Supporting FI Tile

struct FIStatTile: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 32, height: 32)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
