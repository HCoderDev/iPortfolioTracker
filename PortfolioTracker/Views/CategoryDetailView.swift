//
//  CategoryDetailView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Currency.code) private var currencies: [Currency]
    @Query(sort: \Category.name) private var categories: [Category]
    let category: Category
    
    @State private var showDeleteConfirmation = false
    @State private var showSoldOff = false
    @State private var searchText = ""
    @State private var showManageSubCategories = false
    @State private var showAddAssetSheet = false
    @State private var assetToEdit: Asset?
    @State private var showImportSheet = false
    @State private var importMode: ImportMode = .transactions
    
    private var assetsBySubCategory: [(subCategory: SubCategory?, assets: [Asset])] {
        let active = filteredActiveAssets
        var groups: [(subCategory: SubCategory?, assets: [Asset])] = []
        
        let sortedSubs = category.subCategories.sorted(by: { $0.name.localizedCompare($1.name) == .orderedAscending })
        for subCat in sortedSubs {
            let subCatAssets = active.filter { $0.subCategory?.persistentModelID == subCat.persistentModelID }
            if !subCatAssets.isEmpty {
                groups.append((subCategory: subCat, assets: subCatAssets))
            }
        }
        
        let unassignedAssets = active.filter { $0.subCategory == nil }
        if !unassignedAssets.isEmpty {
            groups.append((subCategory: nil, assets: unassignedAssets))
        }
        
        return groups
    }
    
    private var allAssets: [Asset] {
        category.assets
    }
    
    private var activeAssets: [Asset] {
        allAssets.filter { !PortfolioMetrics.isSoldOff($0) }
    }
    
    private var soldOffAssets: [Asset] {
        allAssets.filter { asset in
            PortfolioMetrics.isSoldOff(asset)
        }
    }
    
    private var filteredActiveAssets: [Asset] {
        if searchText.isEmpty { return activeAssets }
        return activeAssets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var filteredSoldOffAssets: [Asset] {
        if searchText.isEmpty { return soldOffAssets }
        return soldOffAssets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var summaryData: (invested: Double, currentValue: Double, unrealizedGL: Double, realizedPL: Double, totalPL: Double, xirr: Double?, lifetimeInvested: Double, lifetimeRetrieved: Double) {
        let isConversionActive = category.currencyCode != "INR" && (category.convertToInr ?? false)
        let rate = PortfolioMetrics.currentInrExchangeRate(for: category, currencies: currencies)
        
        var totalInvested = 0.0
        var totalCurrentValue = 0.0
        var totalRealizedPL = 0.0
        var totalLifetimeInvested = 0.0
        var totalLifetimeRetrieved = 0.0
        var allCashFlows: [CashFlow] = []
        
        for asset in allAssets {
            if isConversionActive {
                let currentValue = PortfolioMetrics.currentValueInINR(for: asset, rate: rate)
                let invested = PortfolioMetrics.investedValueInINR(for: asset, rate: rate)
                let lifoResult = LifoCalculator.calculateInINR(transactions: asset.transactions, categoryExchangeRate: rate)
                
                totalInvested += invested
                totalCurrentValue += currentValue
                totalRealizedPL += lifoResult.realizedProfitLoss
                totalLifetimeInvested += lifoResult.lifetimeInvested
                totalLifetimeRetrieved += lifoResult.lifetimeRetrieved
                
                allCashFlows.append(contentsOf: PortfolioMetrics.cashFlowsInINR(for: asset, rate: rate))
            } else {
                let currentValue = PortfolioMetrics.currentValue(for: asset)
                let invested = PortfolioMetrics.investedValue(for: asset)
                let lifoResult = LifoCalculator.calculate(transactions: asset.transactions)
                
                totalInvested += invested
                totalCurrentValue += currentValue
                totalRealizedPL += lifoResult.realizedProfitLoss
                totalLifetimeInvested += lifoResult.lifetimeInvested
                totalLifetimeRetrieved += lifoResult.lifetimeRetrieved
                
                allCashFlows.append(contentsOf: PortfolioMetrics.cashFlows(for: asset))
            }
        }
        
        let unrealizedGL = totalCurrentValue - totalInvested
        let totalPL = unrealizedGL + totalRealizedPL
        let xirr = XirrCalculator.calculateXirr(cashFlows: allCashFlows)
        return (totalInvested, totalCurrentValue, unrealizedGL, totalRealizedPL, totalPL, xirr, totalLifetimeInvested, totalLifetimeRetrieved)
    }
    
    private var assetAllocation: [PieSlice] {
        let isConversionActive = category.currencyCode != "INR" && (category.convertToInr ?? false)
        let rate = PortfolioMetrics.currentInrExchangeRate(for: category, currencies: currencies)
        
        return activeAssets.compactMap { asset in
            let value = isConversionActive ? PortfolioMetrics.currentValueInINR(for: asset, rate: rate) : PortfolioMetrics.currentValue(for: asset)
            return value > 0 ? PieSlice(label: asset.name, value: value) : nil
        }
    }
    
    private var subCategoryAllocation: [PieSlice] {
        let isConversionActive = category.currencyCode != "INR" && (category.convertToInr ?? false)
        let rate = PortfolioMetrics.currentInrExchangeRate(for: category, currencies: currencies)
        let active = activeAssets
        var subCatValues: [String: Double] = [:]
        
        for asset in active {
            let value = isConversionActive ? PortfolioMetrics.currentValueInINR(for: asset, rate: rate) : PortfolioMetrics.currentValue(for: asset)
            if value > 0 {
                let name = asset.subCategory?.name ?? "Unassigned"
                subCatValues[name, default: 0.0] += value
            }
        }
        
        return subCatValues.map { PieSlice(label: $0.key, value: $0.value) }
            .sorted(by: { $0.value > $1.value })
    }
    
    var body: some View {
        let data = summaryData
        let isConversionActive = category.currencyCode != "INR" && (category.convertToInr ?? false)
        let rate = PortfolioMetrics.currentInrExchangeRate(for: category, currencies: currencies)
        
        let convertBinding = Binding<Bool>(
            get: { category.convertToInr ?? false },
            set: { category.convertToInr = $0 }
        )
        
        let rateBinding = Binding<String>(
            get: {
                if let rateVal = category.lastInrExchangeRate {
                    return String(rateVal)
                }
                let derived = PortfolioMetrics.currentInrExchangeRate(for: category, currencies: currencies)
                return String(derived)
            },
            set: { newValue in
                category.lastInrExchangeRate = Double(newValue)
            }
        )
        
        ScrollView {
            LazyVStack(spacing: 16) {
                // Summary Card
                summaryCard(data: data)
                
                // Convert to INR Card
                if category.currencyCode != "INR" {
                    VStack(spacing: 12) {
                        Toggle(isOn: convertBinding) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.triangle.2.circlepath.currency")
                                    .foregroundStyle(AppTheme.accent)
                                Text("Convert to INR")
                                    .fontWeight(.semibold)
                            }
                        }
                        .tint(AppTheme.accent)
                        
                        if category.convertToInr ?? false {
                            Divider()
                            
                            HStack {
                                Text("Current INR Exchange Rate")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                TextField("Rate", text: rateBinding)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }
                
                // Pie Chart
                if !assetAllocation.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Asset Allocation")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        PieChartView(slices: assetAllocation)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }
                
                // Subcategory Pie Chart
                if !category.subCategories.isEmpty && !subCategoryAllocation.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Subcategory Allocation")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        PieChartView(slices: subCategoryAllocation)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }
                
                if !allAssets.flatMap({ $0.transactions }).isEmpty {
                    TimelineChartView(assets: allAssets, currencyCode: category.currencyCode)
                }
                
                // Assets Header with Sold-Off Toggle
                VStack(spacing: 8) {
                    HStack {
                        Text("Assets (\(activeAssets.count) active\(soldOffAssets.isEmpty ? "" : ", \(soldOffAssets.count) sold"))")
                            .font(.headline)
                        Spacer()
                    }
                    
                    if !soldOffAssets.isEmpty {
                        Toggle("Show Sold-Off Assets", isOn: $showSoldOff)
                            .font(.subheadline)
                            .tint(AppTheme.accent)
                    }
                }
                .padding(.horizontal)
                
                if filteredActiveAssets.isEmpty && (!showSoldOff || filteredSoldOffAssets.isEmpty) {
                    if !searchText.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .padding(.vertical, 32)
                    } else if activeAssets.isEmpty && !showSoldOff {
                        ContentUnavailableView(
                            "No Active Assets",
                            systemImage: "chart.bar",
                            description: Text(soldOffAssets.isEmpty
                                ? "No assets in this category yet."
                                : "All assets have been sold off. Toggle above to view.")
                        )
                        .padding(.vertical, 32)
                    }
                } else {
                    // Active assets grouped by subcategory
                    if category.subCategories.isEmpty {
                        ForEach(filteredActiveAssets) { asset in
                            NavigationLink(value: asset) {
                                CategoryAssetCardView(asset: asset, isConversionActive: isConversionActive, rate: rate, isIndividualEquity: category.isIndividualEquity ?? false, onEdit: {
                                    assetToEdit = asset
                                })
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                            .contextMenu {
                                Button {
                                    assetToEdit = asset
                                } label: {
                                    Label("Edit Asset", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    modelContext.delete(asset)
                                } label: {
                                    Label("Delete Asset", systemImage: "trash")
                                }
                            }
                        }
                    } else {
                        ForEach(assetsBySubCategory, id: \.subCategory?.persistentModelID) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(group.subCategory?.name ?? "Unassigned")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    let groupValue = group.assets.reduce(0.0) { $0 + (isConversionActive ? PortfolioMetrics.currentValueInINR(for: $1, rate: rate) : PortfolioMetrics.currentValue(for: $1)) }
                                    let activeSymbol = isConversionActive ? "₹" : (category.currencyCode == "USD" ? "$" : "")
                                    Text("\(activeSymbol)\(groupValue.formattedComma)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                                
                                ForEach(group.assets) { asset in
                                    NavigationLink(value: asset) {
                                        CategoryAssetCardView(asset: asset, isConversionActive: isConversionActive, rate: rate, isIndividualEquity: category.isIndividualEquity ?? false, onEdit: {
                                            assetToEdit = asset
                                        })
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal)
                                    .contextMenu {
                                        Button {
                                            assetToEdit = asset
                                        } label: {
                                            Label("Edit Asset", systemImage: "pencil")
                                        }
                                        Button(role: .destructive) {
                                            modelContext.delete(asset)
                                        } label: {
                                            Label("Delete Asset", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Sold-off assets (shown conditionally)
                    if showSoldOff && !filteredSoldOffAssets.isEmpty {
                        HStack {
                            Text("Sold-Off Assets")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                        
                        ForEach(filteredSoldOffAssets) { asset in
                            NavigationLink(value: asset) {
                                SoldOffAssetCardView(asset: asset, isConversionActive: isConversionActive, rate: rate, onEdit: {
                                    assetToEdit = asset
                                })
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                            .contextMenu {
                                Button {
                                    assetToEdit = asset
                                } label: {
                                    Label("Edit Asset", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    modelContext.delete(asset)
                                } label: {
                                    Label("Delete Asset", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                
                Spacer(minLength: 32)
            }
            .padding(.vertical)
        }
        .navigationTitle(category.name)
        .searchable(text: $searchText, prompt: "Search Assets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    Menu {
                        Button {
                            importMode = .transactions
                            showImportSheet = true
                        } label: {
                            Label("Import Transactions (Excel/CSV)", systemImage: "doc.badge.plus")
                        }
                        
                        Button {
                            importMode = .dividends
                            showImportSheet = true
                        } label: {
                            Label("Import Dividends (Excel/CSV)", systemImage: "dollarsign.circle")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }

                    Button {
                        showAddAssetSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    
                    Button {
                        showManageSubCategories = true
                    } label: {
                        Image(systemName: "tag.fill")
                    }
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .navigationDestination(for: Asset.self) { asset in
            AssetDetailView(asset: asset)
        }
        .confirmationDialog("Delete Category?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Category", role: .destructive) {
                modelContext.delete(category)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the category and its assets.")
        }
        .sheet(isPresented: $showManageSubCategories) {
            ManageSubCategoriesView(category: category)
        }
        .sheet(isPresented: $showAddAssetSheet) {
            AssetFormSheet(asset: nil, categories: categories, initialCategory: category)
        }
        .sheet(item: $assetToEdit) { asset in
            AssetFormSheet(asset: asset, categories: categories)
        }
        .sheet(isPresented: $showImportSheet) {
            FileImportWizardView(initialCategory: category, initialMode: importMode)
        }
    }
    
    // MARK: - Summary Card
    
    @ViewBuilder
    private func summaryCard(data: (invested: Double, currentValue: Double, unrealizedGL: Double, realizedPL: Double, totalPL: Double, xirr: Double?, lifetimeInvested: Double, lifetimeRetrieved: Double)) -> some View {
        let isConversionActive = category.currencyCode != "INR" && (category.convertToInr ?? false)
        let activeCurrency = isConversionActive ? "INR" : category.currencyCode
        let activeSymbol = activeCurrency == "INR" ? "₹" : (activeCurrency == "USD" ? "$" : "")
        
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text("Currency: \(activeCurrency)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Invested")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(activeSymbol)\(data.invested.formattedComma)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Current Value")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(activeSymbol)\(data.currentValue.formattedComma)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unrealized G/L")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(activeSymbol)\(data.unrealizedGL.formattedComma)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(data.unrealizedGL >= 0 ? AppTheme.profit : AppTheme.loss)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Realized P/L")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(activeSymbol)\(data.realizedPL.formattedComma)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(data.realizedPL >= 0 ? AppTheme.profit : AppTheme.loss)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total P/L")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(activeSymbol)\(data.totalPL.formattedComma)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(data.totalPL >= 0 ? AppTheme.profit : AppTheme.loss)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("XIRR")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(data.xirr != nil ? String(format: "%.2f%%", data.xirr!) : "N/A")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lifetime Invested")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(activeSymbol)\(data.lifetimeInvested.formattedComma)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Lifetime Retrieved")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(activeSymbol)\(data.lifetimeRetrieved.formattedComma)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }
            
            let categoryTxs = allAssets.flatMap { $0.transactions }
            let counts = PortfolioMetrics.transactionCounts(for: categoryTxs)
            
            Divider()
                .background(.white.opacity(0.3))
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trade Activity")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(counts.buyCount) Buy · \(counts.sellCount) Sell · \(counts.dividendCount) Div")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Hold Discipline")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(counts.sellCount == 0 ? "100% BUY (0 Sales)" : String(format: "%.0f%% Buy Discipline", counts.buyPercentage))
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(counts.sellCount == 0 ? AppTheme.profit.opacity(0.3) : Color.orange.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.heroGradient)
        )
        .padding(.horizontal)
    }
}

// MARK: - Category Asset Card (Active)

struct CategoryAssetCardView: View {
    let asset: Asset
    let isConversionActive: Bool
    let rate: Double
    let isIndividualEquity: Bool
    let onEdit: () -> Void
    
    private var lifoResult: LifoResult {
        LifoCalculator.calculate(transactions: asset.transactions)
    }
    
    private var totalUnits: Double {
        PortfolioMetrics.totalUnits(for: asset)
    }
    
    private var invested: Double {
        isConversionActive ? PortfolioMetrics.investedValueInINR(for: asset, rate: rate) : PortfolioMetrics.investedValue(for: asset)
    }
    
    private var currentValue: Double {
        isConversionActive ? PortfolioMetrics.currentValueInINR(for: asset, rate: rate) : PortfolioMetrics.currentValue(for: asset)
    }
    
    private var cmp: Double {
        isConversionActive ? asset.currentPrice * rate : asset.currentPrice
    }
    
    private var gainLoss: Double {
        currentValue - invested
    }
    
    private var currencySymbol: String {
        isConversionActive ? "₹" : (asset.category?.currencyCode == "USD" ? "$" : "")
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(asset.name)
                    .font(.headline)
                Spacer()
                Text("\(currencySymbol)\(currentValue.formattedComma)")
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
                
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }
            
            HStack {
                Text("Units: \(totalUnits.formatted2)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Invested: \(currencySymbol)\(invested.formattedComma)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("CMP: \(currencySymbol)\(cmp.formatted2)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("G/L: \(currencySymbol)\(gainLoss.formattedComma)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(gainLoss >= 0 ? AppTheme.profit : AppTheme.loss)
            }
            
            let txCounts = PortfolioMetrics.transactionCounts(for: asset.transactions)
            HStack {
                Text("Trades: \(txCounts.buyCount) Buy · \(txCounts.sellCount) Sell")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(txCounts.sellCount == 0 ? "100% Held" : String(format: "%.0f%% Buy", txCounts.buyPercentage))
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(txCounts.sellCount == 0 ? AppTheme.profit.opacity(0.15) : Color.orange.opacity(0.15))
                    .foregroundStyle(txCounts.sellCount == 0 ? AppTheme.profit : Color.orange)
                    .clipShape(Capsule())
            }
            
            if isIndividualEquity {
                if let analysis = asset.valueAnalysis {
                    Divider()
                        .padding(.vertical, 4)
                    
                    HStack {
                        // Intrinsic value
                        VStack(alignment: .leading, spacing: 2) {
                            Text("INTRINSIC VALUE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                            let ivConverted = isConversionActive ? analysis.intrinsicValue * rate : analysis.intrinsicValue
                            Text("\(currencySymbol)\(ivConverted.formatted2)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        // Projected CAGR
                        VStack(alignment: .center, spacing: 2) {
                            Text("PROJ. CAGR")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.2f%%", analysis.overallProjectedCAGR * 100.0))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(analysis.overallProjectedCAGR >= 0.15 ? AppTheme.profit : AppTheme.accent)
                        }
                        
                        Spacer()
                        
                        // Undervalued / Overvalued Badge
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(analysis.isUndervalued ? "UNDERVALUED" : "OVERVALUED")
                                .font(.system(size: 8, weight: .black))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background((analysis.isUndervalued ? AppTheme.profit : AppTheme.loss).opacity(0.15))
                                .foregroundStyle(analysis.isUndervalued ? AppTheme.profit : AppTheme.loss)
                                .clipShape(Capsule())
                            
                            let margin = analysis.valuationMarginPercent * 100
                            Text(String(format: "%@%.1f%% Margin", margin >= 0 ? "+" : "", margin))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(margin >= 0 ? AppTheme.profit : AppTheme.loss)
                        }
                    }
                } else {
                    Divider()
                        .padding(.vertical, 4)
                    
                    HStack {
                        Label("No Stock Analysis", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Tap to add")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Sold-Off Asset Card

struct SoldOffAssetCardView: View {
    let asset: Asset
    let isConversionActive: Bool
    let rate: Double
    let onEdit: () -> Void
    
    private var realizedProfitLoss: Double {
        if isConversionActive {
            return LifoCalculator.calculateInINR(transactions: asset.transactions, categoryExchangeRate: rate).realizedProfitLoss
        } else {
            return LifoCalculator.calculate(transactions: asset.transactions).realizedProfitLoss
        }
    }
    
    private var totalBoughtUnits: Double {
        asset.transactions.filter { $0.type == .buy }.reduce(0.0) { $0 + $1.units }
    }
    
    private var totalSoldUnits: Double {
        asset.transactions.filter { $0.type == .sell }.reduce(0.0) { $0 + $1.units }
    }
    
    private var lifetimeInvested: Double {
        isConversionActive ? PortfolioMetrics.lifetimeInvestedInINR(for: asset, rate: rate) : PortfolioMetrics.lifetimeInvested(for: asset)
    }
    
    private var lifetimeRetrieved: Double {
        isConversionActive ? PortfolioMetrics.lifetimeRetrievedInINR(for: asset, rate: rate) : PortfolioMetrics.lifetimeRetrieved(for: asset)
    }
    
    private var currencySymbol: String {
        isConversionActive ? "₹" : (asset.category?.currencyCode == "USD" ? "$" : "")
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(asset.name)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
                
                Text("SOLD")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(AppTheme.warning)
                    )
            }
            
            HStack {
                Text("Bought: \(totalBoughtUnits.formatted2) units")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("Sold: \(totalSoldUnits.formatted2) units")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            HStack {
                Text("Invested: \(currencySymbol)\(lifetimeInvested.formattedComma)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("Retrieved: \(currencySymbol)\(lifetimeRetrieved.formattedComma)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            HStack {
                Spacer()
                Text("Realized P/L: \(currencySymbol)\(realizedProfitLoss.formattedComma)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(realizedProfitLoss >= 0 ? AppTheme.profit : AppTheme.loss)
            }
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(AppTheme.warning.opacity(0.3), lineWidth: 1)
        )
    }
}
