//
//  AllAssetsView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct AllAssetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Asset.name) private var allAssets: [Asset]
    @Query(sort: \Currency.code) private var currencies: [Currency]
    
    @State private var showImportWizard = false
    
    struct AssetSummaryRow: Identifiable {
        let id: PersistentIdentifier
        let asset: Asset
        let categoryName: String
        let investedINR: Double
        let currentValueINR: Double
        let percentOfOverall: Double
    }
    
    struct CategorySummaryGroup: Identifiable {
        let id: PersistentIdentifier
        let category: Category
        let totalInvestedINR: Double
        let totalCurrentValueINR: Double
        let percentOfOverall: Double
        let assetRows: [AssetSummaryRow]
    }
    
    private var consolidatedData: (totalValueINR: Double, totalInvestedINR: Double, groups: [CategorySummaryGroup]) {
        var overallCurrentValueINR = 0.0
        var overallInvestedINR = 0.0
        
        // 1. Calculate values for all assets and overall totals
        var tempGroups: [(category: Category, invested: Double, current: Double, assets: [AssetSummaryRow])] = []
        
        for category in categories {
            let assetsInCat = allAssets.filter { $0.category?.persistentModelID == category.persistentModelID }
            let rate = PortfolioMetrics.currentInrExchangeRate(for: category, currencies: currencies)
            
            var catInvestedINR = 0.0
            var catCurrentValueINR = 0.0
            var assetRows: [AssetSummaryRow] = []
            
            for asset in assetsInCat {
                let units = PortfolioMetrics.totalUnits(for: asset)
                guard units > 0 else { continue }
                
                let investedINR = PortfolioMetrics.investedValueInINR(for: asset, rate: rate)
                let currentValueINR = PortfolioMetrics.currentValueInINR(for: asset, rate: rate)
                
                catInvestedINR += investedINR
                catCurrentValueINR += currentValueINR
                
                assetRows.append(AssetSummaryRow(
                    id: asset.persistentModelID,
                    asset: asset,
                    categoryName: category.name,
                    investedINR: investedINR,
                    currentValueINR: currentValueINR,
                    percentOfOverall: 0.0 // Computed in next step
                ))
            }
            
            if !assetRows.isEmpty {
                overallCurrentValueINR += catCurrentValueINR
                overallInvestedINR += catInvestedINR
                
                tempGroups.append((
                    category: category,
                    invested: catInvestedINR,
                    current: catCurrentValueINR,
                    assets: assetRows
                ))
            }
        }
        
        // 2. Map groups with computed percentage allocations
        let groups = tempGroups.map { item -> CategorySummaryGroup in
            let catPct = overallCurrentValueINR > 0 ? (item.current / overallCurrentValueINR) * 100 : 0.0
            let mappedAssets = item.assets.map { assetRow -> AssetSummaryRow in
                let assetPct = overallCurrentValueINR > 0 ? (assetRow.currentValueINR / overallCurrentValueINR) * 100 : 0.0
                return AssetSummaryRow(
                    id: assetRow.id,
                    asset: assetRow.asset,
                    categoryName: assetRow.categoryName,
                    investedINR: assetRow.investedINR,
                    currentValueINR: assetRow.currentValueINR,
                    percentOfOverall: assetPct
                )
            }.sorted(by: { $0.currentValueINR > $1.currentValueINR })
            
            return CategorySummaryGroup(
                id: item.category.persistentModelID,
                category: item.category,
                totalInvestedINR: item.invested,
                totalCurrentValueINR: item.current,
                percentOfOverall: catPct,
                assetRows: mappedAssets
            )
        }.sorted(by: { $0.totalCurrentValueINR > $1.totalCurrentValueINR })
        
        return (overallCurrentValueINR, overallInvestedINR, groups)
    }
    
    var body: some View {
        let data = consolidatedData
        let totalGL = data.totalValueINR - data.totalInvestedINR
        
        ScrollView {
            VStack(spacing: 20) {
                // Consolidated Networth KPI Card
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CONSOLIDATED NETWORTH")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        Text("₹\(data.totalValueINR.formattedComma)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("INVESTED: ₹\(data.totalInvestedINR.formattedComma)")
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        
                        GainLossBadge(
                            value: totalGL,
                            percentage: data.totalInvestedINR > 0 ? (totalGL / data.totalInvestedINR) * 100.0 : nil,
                            isCompact: false
                        )
                    }
                }
                .modifier(AppTheme.cardStyle())
                
                // Asset Allocation Numbers Table
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Assets Breakdown")
                                .font(.title3.weight(.bold))
                            Text("Real-time valuation across all categories (INR)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        
                        Button {
                            showImportWizard = true
                        } label: {
                            Label("Import Data", systemImage: "square.and.arrow.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                    }
                    
                    if data.groups.isEmpty {
                        ContentUnavailableView(
                            "No Active Assets",
                            systemImage: "chart.bar.fill",
                            description: Text("Asset summary will appear here once you have active holdings.")
                        )
                    } else {
                        AdaptiveAllAssetsTableView(data: data)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("All Assets")
        .sheet(isPresented: $showImportWizard) {
            FileImportWizardView()
        }
    }
}// MARK: - Adaptive Financial Table View (Portrait Sticky Asset Name vs Landscape 100% Full Width)
struct AdaptiveAllAssetsTableView: View {
    let data: (totalValueINR: Double, totalInvestedINR: Double, groups: [AllAssetsView.CategorySummaryGroup])
    @State private var containerWidth: CGFloat = 0
    
    var body: some View {
        let isNarrowPortrait = containerWidth > 0 && containerWidth < 600
        
        VStack(spacing: 0) {
            if isNarrowPortrait {
                // PORTRAIT MODE: Fixed Sticky Left Asset Name + Scrollable Financial Metrics
                HStack(spacing: 0) {
                    // 1. Fixed Left Asset Name Column
                    VStack(alignment: .leading, spacing: 0) {
                        Text("ASSET NAME")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(height: 38, alignment: .leading)
                            .padding(.horizontal, 12)
                        
                        Divider()
                        
                        ForEach(data.groups) { group in
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.accent)
                                Text(group.category.name)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(AppTheme.accent)
                                    .lineLimit(1)
                            }
                            .frame(height: 34, alignment: .leading)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.accent.opacity(0.06))
                            
                            Divider()
                            
                            ForEach(group.assetRows) { row in
                                NavigationLink(value: row.asset) {
                                    Text(row.asset.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .frame(height: 42, alignment: .leading)
                                        .padding(.horizontal, 12)
                                }
                                .buttonStyle(.plain)
                                
                                Divider()
                            }
                        }
                    }
                    .frame(width: 145)
                    .background(Color(.secondarySystemGroupedBackground))
                    
                    Divider()
                    
                    // 2. Horizontally Scrollable Financial Details
                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 0) {
                                Text("INVESTED")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 105, alignment: .trailing)
                                
                                Text("CURRENT")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 105, alignment: .trailing)
                                
                                Text("G/L RETURN")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 105, alignment: .trailing)
                                
                                Text("ALLOC")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .trailing)
                                    .padding(.trailing, 12)
                            }
                            .frame(height: 38)
                            .background(Color.primary.opacity(0.04))
                            
                            Divider()
                            
                            ForEach(data.groups) { group in
                                HStack(spacing: 0) {
                                    Spacer()
                                    Text("₹\(group.totalCurrentValueINR.formattedComma)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(.primary)
                                    Text(" (\(group.percentOfOverall.formatted2)%)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.trailing, 12)
                                .frame(height: 34)
                                .background(AppTheme.accent.opacity(0.06))
                                
                                Divider()
                                
                                ForEach(group.assetRows) { row in
                                    let assetGL = row.currentValueINR - row.investedINR
                                    
                                    NavigationLink(value: row.asset) {
                                        HStack(spacing: 0) {
                                            Text("₹\(row.investedINR.formattedComma)")
                                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                                .monospacedDigit()
                                                .foregroundStyle(.secondary)
                                                .frame(width: 105, alignment: .trailing)
                                            
                                            Text("₹\(row.currentValueINR.formattedComma)")
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .monospacedDigit()
                                                .foregroundStyle(.primary)
                                                .frame(width: 105, alignment: .trailing)
                                            
                                            HStack {
                                                Spacer()
                                                GainLossBadge(
                                                    value: assetGL,
                                                    percentage: row.investedINR > 0 ? (assetGL / row.investedINR) * 100.0 : nil,
                                                    isCompact: true
                                                )
                                            }
                                            .frame(width: 105, alignment: .trailing)
                                            
                                            Text("\(row.percentOfOverall.formatted2)%")
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .monospacedDigit()
                                                .foregroundStyle(.secondary)
                                                .frame(width: 60, alignment: .trailing)
                                                .padding(.trailing, 12)
                                        }
                                        .frame(height: 42)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Divider()
                                }
                            }
                        }
                    }
                }
            } else {
                // LANDSCAPE MODE: 100% Full Width Table with Flexible Asset Name Column
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("ASSET NAME")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
                        
                        Text("INVESTED")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .trailing)
                        
                        Text("CURRENT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .trailing)
                        
                        Text("G/L RETURN")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .trailing)
                        
                        Text("ALLOC")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 65, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.04))
                    
                    Divider()
                    
                    ForEach(data.groups) { group in
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.accent)
                            
                            Text(group.category.name)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppTheme.accent)
                            
                            Spacer()
                            
                            Text("₹\(group.totalCurrentValueINR.formattedComma)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                            
                            Text("(\(group.percentOfOverall.formatted2)%)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppTheme.accent.opacity(0.06))
                        
                        Divider()
                        
                        ForEach(group.assetRows) { row in
                            let assetGL = row.currentValueINR - row.investedINR
                            
                            NavigationLink(value: row.asset) {
                                HStack(spacing: 0) {
                                    Text(row.asset.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
                                    
                                    Text("₹\(row.investedINR.formattedComma)")
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                        .frame(width: 110, alignment: .trailing)
                                    
                                    Text("₹\(row.currentValueINR.formattedComma)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(.primary)
                                        .frame(width: 110, alignment: .trailing)
                                    
                                    HStack {
                                        Spacer()
                                        GainLossBadge(
                                            value: assetGL,
                                            percentage: row.investedINR > 0 ? (assetGL / row.investedINR) * 100.0 : nil,
                                            isCompact: true
                                        )
                                    }
                                    .frame(width: 110, alignment: .trailing)
                                    
                                    Text("\(row.percentOfOverall.formatted2)%")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                        .frame(width: 65, alignment: .trailing)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.onAppear {
                    containerWidth = geo.size.width
                }
                .onChange(of: geo.size.width) { _, newWidth in
                    containerWidth = newWidth
                }
            }
        )
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.subtleBorder, lineWidth: 1)
        )
    }
}





