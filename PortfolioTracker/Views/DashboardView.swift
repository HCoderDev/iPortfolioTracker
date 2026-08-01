//
//  DashboardView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Asset.name) private var allAssets: [Asset]
    @Query(sort: \Currency.code) private var currencies: [Currency]
    
    @State private var exportDocument: SQLiteDatabaseDocument?
    @State private var isExportingDatabase = false
    @State private var isImportingDatabase = false
    @State private var alertMessage: String?
    @State private var dashboardCurrency: String = "INR"
    
    private var backupFilename: String {
        "PortfolioTrackerBackup-\(Date().formatted(.iso8601.year().month().day()))"
    }
    
    private func convert(_ value: Double, from srcCode: String, to tgtCode: String) -> Double {
        guard
            let srcCurrency = currencies.first(where: { $0.code == srcCode }),
            srcCurrency.exchangeRate != 0,
            let tgtCurrency = currencies.first(where: { $0.code == tgtCode }),
            tgtCurrency.exchangeRate != 0
        else {
            if srcCode == tgtCode {
                return value
            }
            if srcCode == "USD" && tgtCode == "INR" {
                return value * 83.0
            }
            if srcCode == "INR" && tgtCode == "USD" {
                return value / 83.0
            }
            return value
        }
        return (value * srcCurrency.exchangeRate) / tgtCurrency.exchangeRate
    }
    
    private var portfolioData: (totalValue: Double, categoryAllocations: [PieSlice], categoryCards: [CategoryCardData]) {
        var totalValue = 0.0
        var allocations: [PieSlice] = []
        var cards: [CategoryCardData] = []
        
        for category in categories {
            let assetsInCat = allAssets.filter { $0.category?.persistentModelID == category.persistentModelID }
            var catInvested = 0.0
            var catCurrentValue = 0.0
            var catCurrentValueInINR = 0.0
            var assetRows: [AssetRowData] = []
            
            let inrRate = PortfolioMetrics.currentInrExchangeRate(for: category, currencies: currencies)
            

            for asset in assetsInCat {
                let units = PortfolioMetrics.totalUnits(for: asset)
                guard units > 0 else { continue }
                
                let invested = dashboardCurrency == "INR" ? PortfolioMetrics.investedValueInINR(for: asset, rate: inrRate) : PortfolioMetrics.investedValue(for: asset)
                let value = dashboardCurrency == "INR" ? PortfolioMetrics.currentValueInINR(for: asset, rate: inrRate) : PortfolioMetrics.currentValue(for: asset)
                
                let convertedInvested = invested
                let convertedValue = value
                
                catInvested += convertedInvested
                catCurrentValue += convertedValue
                assetRows.append(AssetRowData(asset: asset, value: convertedValue))
                
                catCurrentValueInINR += dashboardCurrency == "INR" ? value : (value * inrRate)
            }
            
            totalValue += catCurrentValueInINR
            
            if catCurrentValueInINR > 0 {
                allocations.append(PieSlice(label: category.name, value: catCurrentValueInINR))
            }
            
            cards.append(CategoryCardData(
                category: category,
                invested: catInvested,
                currentValue: catCurrentValue,
                gainLoss: catCurrentValue - catInvested,
                assets: assetRows
            ))
        }
        
        return (totalValue, allocations, cards)
    }
    
    private var driftedCategories: [String] {
        let targetsSum = categories.reduce(0.0) { $0 + $1.targetAllocationPercent }
        guard abs(targetsSum - 100.0) < 0.01 else { return [] }
        
        let totalVal = portfolioData.totalValue
        guard totalVal > 0 else { return [] }
        
        var drifted: [String] = []
        for category in categories {
            let assetsInCat = allAssets.filter { $0.category?.persistentModelID == category.persistentModelID }
            var catVal = 0.0
            let inrRate = PortfolioMetrics.currentInrExchangeRate(for: category, currencies: currencies)
            for asset in assetsInCat {
                let units = PortfolioMetrics.totalUnits(for: asset)
                guard units > 0 else { continue }
                catVal += PortfolioMetrics.currentValue(for: asset) * inrRate
            }
            
            let actualPercent = (catVal / totalVal) * 100.0
            let targetPercent = category.targetAllocationPercent
            let drift = actualPercent - targetPercent
            if abs(drift) > 5.0 {
                drifted.append(category.name)
            }
        }
        return drifted
    }
    
    @State private var showLayoutSettings = false
    
    var body: some View {
        let data = portfolioData
        
        ScrollView {
            VStack(spacing: 20) {
                // Drift Warning Banner (Apple Caution HIG Banner)
                let driftedCats = driftedCategories
                if !driftedCats.isEmpty {
                    NavigationLink(destination: PortfolioRebalancerView()) {
                        HStack(spacing: 14) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.warning)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Portfolio Allocation Drift Alert")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.primary)
                                Text("Asset allocations drifted by > ±5% in \(driftedCats.joined(separator: ", ")). Click to rebalance.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("Rebalance")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(AppTheme.warning.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.warning.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                
                // Executive Networth Hero Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("TOTAL PORTFOLIO NETWORTH")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chart.pie.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.accent)
                    }
                    
                    Text("₹\(data.totalValue.formattedComma)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(AppTheme.cardStyle())
                
                // Financial Independence Tracker Card
                FICalculationCard(currentNetWorth: data.totalValue)
                
                // Allocation Card (Pie Chart & Category Breakdown)
                if !data.categoryAllocations.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Asset Allocation")
                                    .font(.title3.weight(.bold))
                                Text("Category-wise distribution of investments")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        
                        Divider()
                        
                        PieChartView(slices: data.categoryAllocations)
                            .frame(minHeight: 220)
                    }
                    .modifier(AppTheme.cardStyle())
                }

                
                // Category Performance Section Header
                HStack {
                    Text("Category Performance")
                        .font(.title3.weight(.bold))
                    Spacer()
                }
                .padding(.top, 8)
                
                // Category Dashboard Cards
                ForEach(data.categoryCards) { card in
                    let cardCurrencyCode = dashboardCurrency == "INR" ? "INR" : card.category.currencyCode
                    CategoryDashboardCard(card: card, currencyCode: cardCurrencyCode)
                }
            }
            .padding(20)
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showLayoutSettings = true
                    } label: {
                        Label("Layout & Theme Options", systemImage: "paintbrush")
                    }
                    
                    Divider()
                    
                    Button {
                        do {
                            exportDocument = try appState.exportDatabaseDocument()
                            isExportingDatabase = true
                        } catch {
                            alertMessage = error.localizedDescription
                        }
                    } label: {
                        Label("Export Database Backup", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        isImportingDatabase = true
                    } label: {
                        Label("Import Database Restore", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showLayoutSettings) {
            LayoutAndThemeSettingsSheet()
        }
        .navigationDestination(for: Category.self) { category in

            CategoryDetailView(category: category)
        }
        .navigationDestination(for: Asset.self) { asset in
            AssetDetailView(asset: asset)
        }
        .fileExporter(
            isPresented: $isExportingDatabase,
            document: exportDocument,
            contentType: .sqliteDatabase,
            defaultFilename: backupFilename
        ) { result in
            switch result {
            case .success:
                alertMessage = "Database backup exported successfully."
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $isImportingDatabase,
            allowedContentTypes: UTType.sqliteImportTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    do {
                        try await appState.importDatabase(from: url)
                        await MainActor.run {
                            alertMessage = "Database restored successfully."
                        }
                    } catch {
                        await MainActor.run {
                            alertMessage = error.localizedDescription
                        }
                    }
                }
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
        .alert("Portfolio Database", isPresented: Binding(
            get: { alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    alertMessage = nil
                }
            }
        ), actions: {
            Button("OK") {
                alertMessage = nil
            }
        }, message: {
            Text(alertMessage ?? "")
        })
    }
}

// MARK: - Supporting Data Structs

struct AssetRowData: Identifiable {
    var id: PersistentIdentifier { asset.persistentModelID }
    let asset: Asset
    let value: Double
}

struct CategoryCardData: Identifiable {
    var id: PersistentIdentifier { category.persistentModelID }
    let category: Category
    let invested: Double
    let currentValue: Double
    let gainLoss: Double
    let assets: [AssetRowData]
}

// MARK: - Category Dashboard Card

struct CategoryDashboardCard: View {
    let card: CategoryCardData
    let currencyCode: String
    
    private var currencySymbol: String {
        currencyCode == "INR" ? "₹" : "$"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: card.category) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(card.category.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("\(currencyCode) · \(card.assets.count) active holding\(card.assets.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(currencySymbol)\(card.currentValue.formattedComma)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        
                        GainLossBadge(value: card.gainLoss, percentage: card.invested > 0 ? (card.gainLoss / card.invested) * 100.0 : nil, isCompact: true)
                    }
                }
            }
            .buttonStyle(.plain)
            
            if !card.assets.isEmpty {
                Divider()
                    .padding(.vertical, 2)
                
                VStack(spacing: 8) {
                    ForEach(card.assets) { row in
                        NavigationLink(value: row.asset) {
                            HStack {
                                Text(row.asset.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                                
                                Spacer()

                                
                                Text("\(currencySymbol)\(row.value.formattedComma)")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .padding(.vertical, 3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .modifier(AppTheme.cardStyle())
    }
}

