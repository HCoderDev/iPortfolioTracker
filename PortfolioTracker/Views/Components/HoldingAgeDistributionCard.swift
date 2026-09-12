//
//  HoldingAgeDistributionCard.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

enum HoldingAgeBucket: String, CaseIterable, Identifiable {
    case under1Y = "< 1 year"
    case y1To2 = "1–2 years"
    case y2To3 = "2–3 years"
    case y3To4 = "3–4 years"
    case y4To5 = "4–5 years"
    case y5To7 = "5–7 years"
    case y7To10 = "7–10 years"
    case over10Y = "10+ years"
    
    var id: String { rawValue }
    
    var shortLabel: String {
        switch self {
        case .under1Y: return "<1Y"
        case .y1To2: return "1–2Y"
        case .y2To3: return "2–3Y"
        case .y3To4: return "3–4Y"
        case .y4To5: return "4–5Y"
        case .y5To7: return "5–7Y"
        case .y7To10: return "7–10Y"
        case .over10Y: return "10Y+"
        }
    }
    
    var themeColor: Color {
        switch self {
        case .under1Y: return Color(hex: "FF453A") // Short-term red/orange
        case .y1To2: return Color(hex: "FF9F0A") // Orange
        case .y2To3: return Color(hex: "FFD60A") // Yellow
        case .y3To4: return Color(hex: "64D2FF") // Light Blue
        case .y4To5: return Color(hex: "0A84FF") // Blue
        case .y5To7: return Color(hex: "5E5CE6") // Indigo/Purple
        case .y7To10: return Color(hex: "BF5AF2") // Purple
        case .over10Y: return Color(hex: "30D158") // Emerald Green (Compounded)
        }
    }
    
    static func bucket(forDays days: Int) -> HoldingAgeBucket {
        let years = Double(days) / 365.25
        if years < 1.0 { return .under1Y }
        else if years < 2.0 { return .y1To2 }
        else if years < 3.0 { return .y2To3 }
        else if years < 4.0 { return .y3To4 }
        else if years < 5.0 { return .y4To5 }
        else if years < 7.0 { return .y5To7 }
        else if years < 10.0 { return .y7To10 }
        else { return .over10Y }
    }
}

struct BucketStat: Identifiable {
    let bucket: HoldingAgeBucket
    let units: Double
    let value: Double
    let percentage: Double
    
    var id: String { bucket.id }
}

struct HoldingAgeDistributionCard: View {
    let assets: [Asset]
    let title: String
    let currencyCode: String
    let displayInINR: Bool
    let currentRate: Double
    
    @Query(sort: \Currency.code) private var currencies: [Currency]
    
    init(assets: [Asset], title: String = "Holding Age Distribution", currencyCode: String = "INR", displayInINR: Bool = true, currentRate: Double = 1.0) {
        // Only include unitized assets (Indian Mutual Funds, Indian Stocks, US Stocks)
        self.assets = assets.filter { !$0.holdingType.isNonUnitized }
        self.title = title
        self.currencyCode = currencyCode
        self.displayInINR = displayInINR
        self.currentRate = currentRate
    }
    
    init(asset: Asset, displayInINR: Bool = true, currentRate: Double = 1.0) {
        if asset.holdingType.isNonUnitized {
            self.assets = []
        } else {
            self.assets = [asset]
        }
        self.title = "Holding Age Distribution"
        self.currencyCode = asset.category?.currencyCode ?? "INR"
        self.displayInINR = displayInINR
        self.currentRate = currentRate
    }
    
    // MARK: - Calculated Data
    
    private var currencySymbol: String {
        if displayInINR || currencyCode == "INR" {
            return "₹"
        } else if currencyCode == "USD" {
            return "$"
        } else {
            return "\(currencyCode) "
        }
    }
    
    private var activeRate: Double {
        (currencyCode != "INR" && displayInINR) ? currentRate : 1.0
    }
    
    private var bucketStats: [BucketStat] {
        var bucketUnitsMap: [HoldingAgeBucket: Double] = [:]
        var bucketValueMap: [HoldingAgeBucket: Double] = [:]
        
        for bucket in HoldingAgeBucket.allCases {
            bucketUnitsMap[bucket] = 0.0
            bucketValueMap[bucket] = 0.0
        }
        
        for asset in assets {
            let taxResult = FifoCalculator.calculateTax(asset: asset, currencies: currencies, slabRate: 0.30)
            for lot in taxResult.activeLots {
                let bucket = HoldingAgeBucket.bucket(forDays: lot.holdingAgeDays)
                let lotUnits = lot.remainingUnits
                let valLocal = lotUnits * lot.currentPrice
                let lotVal = valLocal * activeRate
                
                bucketUnitsMap[bucket, default: 0.0] += lotUnits
                bucketValueMap[bucket, default: 0.0] += lotVal
            }
        }
        
        let totalVal = bucketValueMap.values.reduce(0.0, +)
        let totalUn = bucketUnitsMap.values.reduce(0.0, +)
        
        return HoldingAgeBucket.allCases.map { bucket in
            let u = bucketUnitsMap[bucket] ?? 0.0
            let v = bucketValueMap[bucket] ?? 0.0
            let pct = totalVal > 0 ? (v / totalVal) * 100.0 : (totalUn > 0 ? (u / totalUn) * 100.0 : 0.0)
            return BucketStat(bucket: bucket, units: u, value: v, percentage: pct)
        }
    }
    
    private var totalValue: Double {
        bucketStats.reduce(0.0) { $0 + $1.value }
    }
    
    private var totalUnits: Double {
        bucketStats.reduce(0.0) { $0 + $1.units }
    }
    
    // Featured Long-Term Holding Stats (5+ Years)
    private var longTermBuckets: [HoldingAgeBucket] {
        [.y5To7, .y7To10, .over10Y]
    }
    
    private var longTermValue: Double {
        bucketStats.filter { longTermBuckets.contains($0.bucket) }.reduce(0.0) { $0 + $1.value }
    }
    
    private var longTermUnits: Double {
        bucketStats.filter { longTermBuckets.contains($0.bucket) }.reduce(0.0) { $0 + $1.units }
    }
    
    private var longTermPercentage: Double {
        totalValue > 0 ? (longTermValue / totalValue) * 100.0 : (totalUnits > 0 ? (longTermUnits / totalUnits) * 100.0 : 0.0)
    }
    
    private var longTermCaptionText: String {
        if longTermPercentage >= 50.0 {
            return "🏆 \(String(format: "%.0f%%", longTermPercentage)) of your holding is 5+ years old! Exceptional long-term discipline."
        } else if longTermPercentage > 0.0 {
            return "🌱 \(String(format: "%.0f%%", longTermPercentage)) is held for over 5 years. Patient holding lets compounding work its magic."
        } else {
            return "⏳ Hold your units for the long term (3–5+ years) to maximize compounding and tax efficiency."
        }
    }
    
    private func formatUnitsText(_ units: Double) -> String {
        if units == 0 { return "0" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = units.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return formatter.string(from: NSNumber(value: units)) ?? String(format: "%.0f", units)
    }
    
    private func formatCurrencyText(_ value: Double) -> String {
        let activeCode = (displayInINR || currencyCode == "INR") ? "INR" : currencyCode
        let compact = value.formattedCompactChart(currencyCode: activeCode)
        return "\(currencySymbol)\(compact)"
    }
    
    var body: some View {
        if assets.isEmpty || totalUnits <= 0 {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 16) {
                // Card Header & Portfolio Summary
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text(formatCurrencyText(totalValue))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Text("\(formatUnitsText(totalUnits)) units")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                
                // Featured Holding Age Section (5+ Years highlight)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Holding Age")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("5+ Years")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            
                            Text(formatCurrencyText(longTermValue))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.accent)
                        }
                        
                        Spacer()
                        
                        Text(String(format: "%.0f%%", longTermPercentage))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(longTermPercentage > 0 ? AppTheme.profit : .secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Text(longTermCaptionText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                // Visual Timeline Segmented Progress Bar
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(bucketStats) { stat in
                                if stat.percentage > 0 {
                                    Rectangle()
                                        .fill(stat.bucket.themeColor)
                                        .frame(width: max(3, geo.size.width * CGFloat(stat.percentage / 100.0)))
                                }
                            }
                        }
                    }
                    .frame(height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    
                    // Timeline Age Labels below progress bar
                    HStack(spacing: 0) {
                        ForEach(HoldingAgeBucket.allCases) { bucket in
                            Text(bucket.shortLabel)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.vertical, 4)
                
                Divider()
                
                // Age Distribution List Breakdown
                VStack(alignment: .leading, spacing: 10) {
                    Text("Age Distribution")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    VStack(spacing: 8) {
                        ForEach(bucketStats) { stat in
                            HStack {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(stat.bucket.themeColor)
                                        .frame(width: 8, height: 8)
                                    Text(stat.bucket.rawValue)
                                        .font(.subheadline)
                                        .foregroundStyle(stat.units > 0 ? .primary : .secondary)
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 8) {
                                    if stat.value > 0 {
                                        Text("(\(String(format: "%.1f%%", stat.percentage)))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Text(formatUnitsText(stat.units))
                                        .font(.subheadline.monospacedDigit())
                                        .fontWeight(stat.units > 0 ? .bold : .regular)
                                        .foregroundStyle(stat.units > 0 ? .primary : .secondary)
                                }
                            }
                            
                            if stat.bucket != bucketStats.last?.bucket {
                                Divider().opacity(0.4)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
