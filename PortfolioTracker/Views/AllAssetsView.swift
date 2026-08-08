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
    @State private var selectedViewTab: Int = 0 // 0 = Assets Table, 1 = Investment Recency Matrix
    
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
                    percentOfOverall: 0.0
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
                
                // View Selector (Table vs Recency Matrix)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Picker("View Mode", selection: $selectedViewTab) {
                            Text("Financial Summary").tag(0)
                            Text("Investment Recency Matrix").tag(1)
                        }
                        .pickerStyle(.segmented)
                        
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
                    
                    if selectedViewTab == 0 {
                        if data.groups.isEmpty {
                            ContentUnavailableView(
                                "No Active Assets",
                                systemImage: "chart.bar.fill",
                                description: Text("Asset summary will appear here once you have active holdings.")
                            )
                        } else {
                            AdaptiveAllAssetsTableView(data: data)
                        }
                    } else {
                        CentralRecencyMatrixView(assets: allAssets)
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
}

// MARK: - Adaptive Financial Table View with Last Invested Recency Column
struct AdaptiveAllAssetsTableView: View {
    let data: (totalValueINR: Double, totalInvestedINR: Double, groups: [AllAssetsView.CategorySummaryGroup])
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Fixed Left Column
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
                
                // Scrollable Details
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 0) {
                            Text("INVESTED")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .trailing)
                            
                            Text("CURRENT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .trailing)
                            
                            Text("G/L RETURN")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .trailing)
                            
                            Text("LAST INVESTED")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 120, alignment: .trailing)
                            
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
                                            .frame(width: 100, alignment: .trailing)
                                        
                                        Text("₹\(row.currentValueINR.formattedComma)")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .monospacedDigit()
                                            .foregroundStyle(.primary)
                                            .frame(width: 100, alignment: .trailing)
                                        
                                        HStack {
                                            Spacer()
                                            GainLossBadge(
                                                value: assetGL,
                                                percentage: row.investedINR > 0 ? (assetGL / row.investedINR) * 100.0 : nil,
                                                isCompact: true
                                            )
                                        }
                                        .frame(width: 100, alignment: .trailing)
                                        
                                        // Last Invested Recency Column
                                        HStack(spacing: 4) {
                                            Spacer()
                                            let status = PortfolioMetrics.recencyStatus(for: row.asset)
                                            Circle().fill(status.color).frame(width: 5, height: 5)
                                            Text(PortfolioMetrics.lastInvestedFormattedText(for: row.asset))
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(status.color)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 120, alignment: .trailing)
                                        
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
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 1))
    }
}

// MARK: - Central Asset Investment Recency & Discipline Matrix View
struct CentralRecencyMatrixView: View {
    let assets: [Asset]
    @Query(sort: \Currency.code) private var currencies: [Currency]
    
    enum SortMode: String, CaseIterable, Identifiable {
        case oldestFirst = "Oldest Investment (Dormant)"
        case newestFirst = "Newest Investment"
        case name = "Asset Name"
        var id: String { rawValue }
    }
    
    @State private var selectedStatus: PortfolioMetrics.InvestmentRecencyStatus? = nil
    @State private var sortMode: SortMode = .oldestFirst
    @State private var searchText = ""
    
    var filteredAndSortedAssets: [Asset] {
        let matching = assets.filter { asset in
            if let status = selectedStatus {
                if PortfolioMetrics.recencyStatus(for: asset) != status {
                    return false
                }
            }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                return asset.name.lowercased().contains(q) || (asset.category?.name.lowercased().contains(q) ?? false)
            }
            return true
        }
        
        return matching.sorted { a1, a2 in
            let days1 = PortfolioMetrics.daysSinceLastInvestment(for: a1) ?? Int.max
            let days2 = PortfolioMetrics.daysSinceLastInvestment(for: a2) ?? Int.max
            switch sortMode {
            case .oldestFirst:
                return days1 > days2
            case .newestFirst:
                return days1 < days2
            case .name:
                return a1.name < a2.name
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 14) {
            // Header & Filter Bar
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("INVESTMENT RECENCY & DISCIPLINE MATRIX")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(AppTheme.accent)
                        Text("All Assets Purchase Recency")
                            .font(.headline)
                    }
                    Spacer()
                    
                    Menu {
                        Picker("Sort By", selection: $sortMode) {
                            ForEach(SortMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(sortMode.rawValue)
                                .font(.caption.weight(.bold))
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Filter asset by name or category...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Recency Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            selectedStatus = nil
                        } label: {
                            Text("All (\(assets.count))")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selectedStatus == nil ? AppTheme.accent : Color(.tertiarySystemGroupedBackground))
                                .foregroundStyle(selectedStatus == nil ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        ForEach(PortfolioMetrics.InvestmentRecencyStatus.allCases) { status in
                            let count = assets.filter { PortfolioMetrics.recencyStatus(for: $0) == status }.count
                            Button {
                                selectedStatus = (selectedStatus == status) ? nil : status
                            } label: {
                                HStack(spacing: 4) {
                                    Circle().fill(status.color).frame(width: 6, height: 6)
                                    Text("\(status.shortLabel) (\(count))")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selectedStatus == status ? status.color : Color(.tertiarySystemGroupedBackground))
                                .foregroundStyle(selectedStatus == status ? .white : .primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .modifier(AppTheme.cardStyle())
            
            // Asset Cards Grid
            let list = filteredAndSortedAssets
            if list.isEmpty {
                ContentUnavailableView("No Matching Assets", systemImage: "clock.badge.exclamationmark")
                    .padding(.vertical, 30)
            } else {
                VStack(spacing: 8) {
                    ForEach(list) { asset in
                        NavigationLink(value: asset) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(asset.name)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.primary)
                                        Text("(\(asset.category?.name ?? "General"))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    HStack(spacing: 6) {
                                        Text("Last Buy:")
                                            .font(.caption2).foregroundStyle(.secondary)
                                        Text(PortfolioMetrics.lastInvestedFormattedText(for: asset))
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.primary)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    let status = PortfolioMetrics.recencyStatus(for: asset)
                                    HStack(spacing: 4) {
                                        Circle().fill(status.color).frame(width: 6, height: 6)
                                        Text(status.rawValue)
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(status.color)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(status.color.opacity(0.12))
                                    .clipShape(Capsule())
                                    
                                    if !asset.holdingType.isNonUnitized {
                                        let taxResult = FifoCalculator.calculateTax(asset: asset, currencies: currencies)
                                        let ltcgCount = taxResult.activeLots.filter { $0.taxCategory == .ltcg }.count
                                        let stcgCount = taxResult.activeLots.filter { $0.taxCategory == .stcg || $0.taxCategory == .slab }.count
                                        
                                        HStack(spacing: 4) {
                                            if ltcgCount > 0 {
                                                Text("LTCG: \(ltcgCount) lots")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundStyle(AppTheme.gain)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(AppTheme.gain.opacity(0.12))
                                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                            }
                                            if stcgCount > 0 {
                                                Text("STCG: \(stcgCount) lots")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundStyle(Color.orange)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(Color.orange.opacity(0.12))
                                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray5), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
