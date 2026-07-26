//
//  PortfolioRebalancerView.swift
//  PortfolioTracker
//
//  Created by Antigravity on 21/06/26.
//

import SwiftUI
import SwiftData

struct PortfolioRebalancerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Asset.name) private var allAssets: [Asset]
    @Query(sort: \Currency.code) private var currencies: [Currency]
    
    @State private var showTargetAllocationSheet = false
    
    // MARK: - Computations
    
    private var categoryValues: [PersistentIdentifier: Double] {
        var dict: [PersistentIdentifier: Double] = [:]
        for category in categories {
            let assetsInCat = allAssets.filter { $0.category?.persistentModelID == category.persistentModelID }
            var sumVal = 0.0
            let rate = PortfolioMetrics.currentInrExchangeRate(for: category, currencies: currencies)
            for asset in assetsInCat {
                let units = PortfolioMetrics.totalUnits(for: asset)
                guard units > 0 else { continue }
                sumVal += PortfolioMetrics.currentValue(for: asset) * rate
            }
            dict[category.persistentModelID] = sumVal
        }
        return dict
    }
    
    private var totalPortfolioValue: Double {
        categoryValues.values.reduce(0.0, +)
    }
    
    private var totalTargetsSum: Double {
        categories.reduce(0.0) { $0 + $1.targetAllocationPercent }
    }
    
    private var isTargetSetupValid: Bool {
        abs(totalTargetsSum - 100.0) < 0.01
    }
    
    // MARK: - Rebalance Trade Models
    
    struct RebalanceTrade: Identifiable {
        var id: PersistentIdentifier { categoryID }
        let categoryID: PersistentIdentifier
        let categoryName: String
        let action: TradeAction
        let amount: Double
    }
    
    enum TradeAction {
        case buy
        case sell
        case hold
        
        var displayName: String {
            switch self {
            case .buy: return "BUY"
            case .sell: return "SELL"
            case .hold: return "HOLD"
            }
        }
        
        var color: Color {
            switch self {
            case .buy: return AppTheme.profit
            case .sell: return AppTheme.loss
            case .hold: return .secondary
            }
        }
    }
    
    private var calculatedTrades: [RebalanceTrade] {
        guard isTargetSetupValid else { return [] }
        
        let totalVal = totalPortfolioValue
        var trades: [RebalanceTrade] = []
        for cat in categories {
            let currentVal = categoryValues[cat.persistentModelID] ?? 0.0
            let targetVal = totalVal * (cat.targetAllocationPercent / 100.0)
            let diff = targetVal - currentVal
            
            if diff > 1.0 {
                trades.append(RebalanceTrade(categoryID: cat.persistentModelID, categoryName: cat.name, action: .buy, amount: diff))
            } else if diff < -1.0 {
                trades.append(RebalanceTrade(categoryID: cat.persistentModelID, categoryName: cat.name, action: .sell, amount: abs(diff)))
            } else {
                trades.append(RebalanceTrade(categoryID: cat.persistentModelID, categoryName: cat.name, action: .hold, amount: 0.0))
            }
        }
        return trades
    }
    
    // MARK: - View Helpers
    
    private func driftColor(_ drift: Double) -> Color {
        let absDrift = abs(drift)
        if absDrift <= 1.5 {
            return AppTheme.profit
        } else if absDrift <= 5.0 {
            return AppTheme.warning
        } else {
            return AppTheme.loss
        }
    }
    
    private func actualFillColor(_ drift: Double) -> Color {
        let absDrift = abs(drift)
        if absDrift <= 1.5 {
            return AppTheme.profit
        } else if drift > 0 {
            return AppTheme.loss
        } else {
            return AppTheme.warning
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !isTargetSetupValid {
                    // Warning sheet prompt
                    unconfiguredTargetsCard
                } else {

                    
                    // Portfolio Allocation & Drift Visuals Section
                    driftAnalysisSection
                    
                    // Recommended Trades Section
                    recommendedTradesSection
                }
                
                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Portfolio Rebalancer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showTargetAllocationSheet = true
                } label: {
                    Label("Edit Targets", systemImage: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $showTargetAllocationSheet) {
            TargetAllocationConfigSheet()
        }
    }
    
    // MARK: - Subviews
    
    private var unconfiguredTargetsCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "slider.horizontal.3")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.accent)
                .padding(.top, 12)
            
            Text("Set Allocation Goals")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Define your desired asset allocation targets (summing to 100%) to enable drift metrics and the rebalancing calculator.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showTargetAllocationSheet = true
            } label: {
                Text("Configure Target Allocations")
                    .fontWeight(.bold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .padding(.bottom, 12)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
        .padding(.top, 10)
    }
    

    
    private var driftAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PORTFOLIO DRIFT ANALYSIS")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 20) {
                let totalVal = totalPortfolioValue
                
                ForEach(categories) { category in
                    let catVal = categoryValues[category.persistentModelID] ?? 0.0
                    let actualPercent = totalVal > 0 ? (catVal / totalVal) * 100.0 : 0.0
                    let targetPercent = category.targetAllocationPercent
                    let drift = actualPercent - targetPercent
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(category.name)
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Spacer()
                            Text(String(format: "%.1f%% Act vs. %.0f%% Tgt", actualPercent, targetPercent))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%@%.1f%% Drift", drift >= 0 ? "+" : "", drift))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(driftColor(drift))
                        }
                        
                        // Target vs Actual bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.12))
                                    .frame(height: 8)
                                
                                // Target indicator line
                                Rectangle()
                                    .fill(Color.secondary)
                                    .frame(width: 2, height: 16)
                                    .offset(x: geo.size.width * CGFloat(targetPercent / 100.0))
                                
                                // Actual value fill
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(actualFillColor(drift))
                                    .frame(width: geo.size.width * CGFloat(max(0.01, min(100.0, actualPercent)) / 100.0), height: 8)
                            }
                        }
                        .frame(height: 16)
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
    
    private var recommendedTradesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("RECOMMENDED REBALANCING TRADES")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                let trades = calculatedTrades
                let activeTrades = trades.filter { $0.action != .hold }
                
                if activeTrades.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(AppTheme.profit)
                        Text("Portfolio is Balanced")
                            .font(.headline)
                        Text("No rebalancing trades needed to maintain target allocations.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(0..<trades.count, id: \.self) { index in
                        let trade = trades[index]
                        if index > 0 {
                            Divider()
                        }
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trade.categoryName)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 12) {
                                Text(trade.action.displayName)
                                    .font(.caption2)
                                    .fontWeight(.black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(trade.action.color.opacity(0.12))
                                    .foregroundStyle(trade.action.color)
                                    .clipShape(Capsule())
                                
                                if trade.action != .hold {
                                    Text("₹\(trade.amount.formattedComma)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(trade.action == .buy ? AppTheme.profit : AppTheme.loss)
                                } else {
                                    Text("—")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
}
