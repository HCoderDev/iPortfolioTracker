//
//  AssetInflowsView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct AssetInflowsView: View {
    let asset: Asset
    let displayInINR: Bool
    let currentRate: Double
    
    @State private var selectedPeriod: InflowPeriodType = .monthly
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    
    enum InflowPeriodType: String, CaseIterable, Identifiable {
        case monthly = "Monthly"
        case yearly = "Yearly"
        case lifetime = "Lifetime"
        var id: String { rawValue }
    }
    
    private var availableYears: [Int] {
        let txYears = asset.transactions.map { Calendar.current.component(.year, from: $0.date) }
        let currentYear = Calendar.current.component(.year, from: Date())
        var uniqueYears = Set(txYears)
        uniqueYears.insert(currentYear)
        return uniqueYears.sorted(by: >)
    }
    
    private var months: [Int] {
        Array(1...12)
    }
    
    private func monthName(for number: Int) -> String {
        let formatter = DateFormatter()
        return formatter.monthSymbols[number - 1]
    }
    
    private var currencySymbol: String {
        if asset.category?.currencyCode != "INR" {
            return displayInINR ? "₹" : (asset.category?.currencyCode == "USD" ? "$" : "")
        }
        return "₹"
    }
    
    private var isConversionActive: Bool {
        asset.category?.currencyCode != "INR" && displayInINR
    }
    
    private var periodTransactions: [AssetTransaction] {
        let calendar = Calendar.current
        return asset.transactions.filter { tx in
            let year = calendar.component(.year, from: tx.date)
            if selectedPeriod == .lifetime {
                return true
            } else if selectedPeriod == .yearly {
                return year == selectedYear
            } else {
                let month = calendar.component(.month, from: tx.date)
                return year == selectedYear && month == selectedMonth
            }
        }.sorted(by: { $0.date > $1.date })
    }
    
    private var periodSummary: (invested: Double, withdrawn: Double, netFlow: Double) {
        var invested = 0.0
        var withdrawn = 0.0
        
        for tx in periodTransactions {
            let cfg = tx.config
            let rate = isConversionActive ? (tx.inrExchangeRate ?? currentRate) : 1.0
            let amount = tx.amount * rate
            
            if cfg.cashDirection == .outflow {
                invested += amount
            } else if cfg.cashDirection == .inflow {
                withdrawn += amount
            }
        }
        
        return (invested, withdrawn, invested - withdrawn)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Period Selector
            Picker("Period", selection: $selectedPeriod) {
                ForEach(InflowPeriodType.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // Year and Month Pickers if needed
            if selectedPeriod == .monthly || selectedPeriod == .yearly {
                HStack(spacing: 12) {
                    if selectedPeriod == .monthly {
                        Picker("Month", selection: $selectedMonth) {
                            ForEach(months, id: \.self) { m in
                                Text(monthName(for: m)).tag(m)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Picker("Year", selection: $selectedYear) {
                        ForEach(availableYears, id: \.self) { y in
                            Text(String(y)).tag(y)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal)
            }
            
            // Inflows / Outflows Summary Card
            VStack(spacing: 12) {
                let summary = periodSummary
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Capital Injected (Outflows)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(currencySymbol)\(formattedVal(summary.invested))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.accent)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Payouts / Returns (Inflows)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(currencySymbol)\(formattedVal(summary.withdrawn))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.gain)
                    }
                }
                
                Divider()
                
                HStack {
                    Text("Net Cash Flow")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(summary.netFlow >= 0 ? "+" : "")\(currencySymbol)\(formattedVal(summary.netFlow))")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(summary.netFlow >= 0 ? AppTheme.accent : AppTheme.loss)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
            .padding(.horizontal)
            
            // Transaction List for Selected Period
            VStack(alignment: .leading, spacing: 12) {
                Text("Period Transactions (\(periodTransactions.count))")
                    .font(.headline)
                    .padding(.horizontal)
                
                if periodTransactions.isEmpty {
                    Text("No transactions found for the selected period.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    ForEach(periodTransactions) { tx in
                        let rate = isConversionActive ? (tx.inrExchangeRate ?? currentRate) : 1.0
                        let displayAmount = tx.amount * rate
                        
                        HStack {
                            Image(systemName: tx.config.iconName)
                                .font(.title3)
                                .foregroundStyle(tx.config.cashDirection == .outflow ? AppTheme.accent : AppTheme.gain)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.gray.opacity(0.12)))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tx.config.displayName)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(currencySymbol)\(formattedVal(displayAmount))")
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                Text(tx.config.cashDirection.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
    
    private func formattedVal(_ num: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: num)) ?? String(format: "%.2f", num)
    }
}
