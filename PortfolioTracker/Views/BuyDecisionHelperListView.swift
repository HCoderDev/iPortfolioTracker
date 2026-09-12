//
//  BuyDecisionHelperListView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct BuyDecisionHelperListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BuyDecisionHelper.updatedAt, order: .reverse) private var helpers: [BuyDecisionHelper]
    @Query(sort: \Asset.name) private var assets: [Asset]
    
    @State private var searchText: String = ""
    @State private var selectedFilter: RatingFilter = .all
    @State private var helperToEdit: BuyDecisionHelper?
    @State private var showAddSheet: Bool = false
    
    enum RatingFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case strongBuy = "Strong Buy"
        case buy = "Buy"
        case accumulate = "Accumulate"
        case hold = "Hold"
        case avoid = "Avoid"
        
        var id: String { rawValue }
    }
    
    var filteredHelpers: [BuyDecisionHelper] {
        helpers.filter { helper in
            let matchesSearch = searchText.isEmpty ||
                helper.activeName.localizedCaseInsensitiveContains(searchText) ||
                helper.activeTicker.localizedCaseInsensitiveContains(searchText)
            
            let matchesFilter: Bool = {
                switch selectedFilter {
                case .all: return true
                case .strongBuy: return helper.currentRating == .strongBuy
                case .buy: return helper.currentRating == .buy
                case .accumulate: return helper.currentRating == .accumulate
                case .hold: return helper.currentRating == .hold
                case .avoid: return helper.currentRating == .avoidSell
                }
            }()
            
            return matchesSearch && matchesFilter
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header Banner
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "cart.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Buy Decision Helper & Watchlist")
                                .font(.headline)
                            Text("Set target valuation bands for assets & watchlist items.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(action: { showAddSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Target")
                            }
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(AppTheme.accent)
                            .clipShape(Capsule())
                        }
                    }
                    
                    if !helpers.isEmpty {
                        Divider()
                        
                        // Summary Stats Badges
                        HStack(spacing: 10) {
                            let sbCount = helpers.filter { $0.currentRating == .strongBuy }.count
                            let buyCount = helpers.filter { $0.currentRating == .buy || $0.currentRating == .accumulate }.count
                            let holdCount = helpers.filter { $0.currentRating == .hold || $0.currentRating == .avoidSell }.count
                            
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill").foregroundStyle(.green)
                                Text("\(sbCount) Strong Buy")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.12))
                            .clipShape(Capsule())
                            
                            HStack(spacing: 4) {
                                Image(systemName: "cart.fill").foregroundStyle(AppTheme.gain)
                                Text("\(buyCount) Buy / Acc")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.gain.opacity(0.12))
                            .clipShape(Capsule())
                            
                            HStack(spacing: 4) {
                                Image(systemName: "pause.fill").foregroundStyle(.orange)
                                Text("\(holdCount) Hold / Avoid")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                }
                .modifier(AppTheme.cardStyle())
                .padding(.horizontal)
                
                // Filter Segment
                if !helpers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(RatingFilter.allCases) { filter in
                                Button(action: { selectedFilter = filter }) {
                                    Text(filter.rawValue)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selectedFilter == filter ? AppTheme.accent : Color(.secondarySystemBackground))
                                        .foregroundStyle(selectedFilter == filter ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Content Cards
                if filteredHelpers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cart.badge.questionmark")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(helpers.isEmpty ? "No Buy Decision Helpers Created" : "No Matching Targets Found")
                            .font(.headline)
                        Text(helpers.isEmpty ? "Add decision target bands for your portfolio assets or watchlist entries." : "Try adjusting your search or filter.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                        
                        if helpers.isEmpty {
                            Button("Add First Decision Helper") {
                                showAddSheet = true
                            }
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppTheme.accent)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .padding(.top, 8)
                        }
                    }
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredHelpers) { helper in
                            decisionHelperCard(helper)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .searchable(text: $searchText, prompt: "Search asset or ticker...")
        .navigationTitle("Buy Decision Helper")
        .sheet(isPresented: $showAddSheet) {
            BuyDecisionHelperFormSheet()
        }
        .sheet(item: $helperToEdit) { helper in
            BuyDecisionHelperFormSheet(helperToEdit: helper)
        }
    }
    
    @ViewBuilder
    private func decisionHelperCard(_ helper: BuyDecisionHelper) -> some View {
        let rating = helper.currentRating
        let symbol = helper.currencySymbol
        let cmp = helper.activePrice
        
        VStack(alignment: .leading, spacing: 12) {
            // Header Row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(helper.activeName)
                            .font(.headline)
                        if !helper.activeTicker.isEmpty {
                            Text("(\(helper.activeTicker))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        if helper.asset != nil {
                            Text("Portfolio Asset")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12))
                                .clipShape(Capsule())
                        } else {
                            Text("Watchlist Entry")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        
                        Text("CMP: \(symbol)\(formattedVal(cmp))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Rating Badge
                HStack(spacing: 4) {
                    Image(systemName: rating.icon)
                    Text(rating.rawValue)
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(rating.color.opacity(0.15))
                .foregroundStyle(rating.color)
                .clipShape(Capsule())
            }
            
            Divider()
            
            // Threshold Bands Grid
            VStack(alignment: .leading, spacing: 6) {
                Text("TARGET DECISION BANDS (\(helper.activeCurrencyCode))")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 6) {
                    bandTag(label: "Strong Buy ≤", val: helper.strongBuyPrice, symbol: symbol, active: cmp > 0 && cmp <= helper.strongBuyPrice, color: .green)
                    bandTag(label: "Buy ≤", val: helper.buyPrice, symbol: symbol, active: cmp > helper.strongBuyPrice && cmp <= helper.buyPrice, color: AppTheme.gain)
                    bandTag(label: "Accumulate ≤", val: helper.accumulatePrice, symbol: symbol, active: cmp > helper.buyPrice && cmp <= helper.accumulatePrice, color: .blue)
                    bandTag(label: "Hold ≤", val: helper.holdPrice, symbol: symbol, active: cmp > helper.accumulatePrice && cmp <= helper.holdPrice, color: .orange)
                }
            }
            
            if !helper.notes.isEmpty {
                Text(helper.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(8)
                    .background(Color(.secondarySystemBackground).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .contentShape(Rectangle())
        .onTapGesture {
            helperToEdit = helper
        }
        .contextMenu {
            Button {
                helperToEdit = helper
            } label: {
                Label("Edit Helper", systemImage: "pencil")
            }
            Button(role: .destructive) {
                modelContext.delete(helper)
            } label: {
                Label("Delete Helper", systemImage: "trash")
            }
        }
    }
    
    @ViewBuilder
    private func bandTag(label: String, val: Double, symbol: String, active: Bool, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(active ? color : .secondary)
            Text(val > 0 ? "\(symbol)\(formattedVal(val))" : "N/A")
                .font(.system(size: 10, weight: active ? .bold : .medium, design: .rounded))
                .foregroundStyle(active ? color : .primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(active ? color.opacity(0.18) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(active ? color : Color.gray.opacity(0.2), lineWidth: active ? 1.5 : 0.5))
    }
    
    private func formattedVal(_ num: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: num)) ?? String(format: "%.2f", num)
    }
}
