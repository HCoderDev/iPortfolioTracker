//
//  MarketAssetDetailView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct MarketAssetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let asset: Asset
    
    @Query(sort: \Currency.code) private var currencies: [Currency]
    @Query private var allAssets: [Asset]
    
    @State private var displayInINR = true
    @State private var showUpdatePriceAlert = false
    @State private var priceInput = ""
    @State private var showAddTransaction = false
    @State private var transactionToEdit: AssetTransaction?
    
    // Valuation Sheet Triggers
    @State private var showValueAnalysisForm = false
    @State private var showValueAnalysisDetail = false
    @State private var showDCFAnalysisForm = false
    
    // Navigation Tab
    @State private var selectedTab: MarketTab = .overview
    
    // Pagination State (10 items per page)
    @State private var transactionsPage = 1
    private let itemsPerPage = 10
    
    enum MarketTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case transactions = "Transactions"
        case inflows = "Inflows"
        case valuation = "Valuation"
        
        var id: String { rawValue }
    }
    
    private var categoryCurrencyCode: String {
        asset.category?.currencyCode ?? "USD"
    }
    
    private var isNonRupeeAsset: Bool {
        categoryCurrencyCode != "INR"
    }
    
    private var currentRate: Double {
        guard let category = asset.category else { return 1.0 }
        return PortfolioMetrics.currentInrExchangeRate(for: category, currencies: currencies)
    }
    
    private var isConversionActive: Bool {
        asset.category?.currencyCode != "INR" && displayInINR
    }
    
    private var currencySymbol: String {
        if isNonRupeeAsset {
            return displayInINR ? "₹" : (categoryCurrencyCode == "USD" ? "$" : "\(categoryCurrencyCode) ")
        }
        return "₹"
    }
    
    private var activeRate: Double {
        isConversionActive ? currentRate : 1.0
    }
    
    // MARK: - Metric Calculations
    
    private var totalUnits: Double {
        PortfolioMetrics.totalUnits(for: asset)
    }
    
    private var currentValue: Double {
        let valLocal = totalUnits * asset.currentPrice
        return valLocal * activeRate
    }
    
    private var investedValue: Double {
        if isConversionActive {
            return PortfolioMetrics.investedValueInINR(for: asset, rate: currentRate)
        } else {
            return PortfolioMetrics.investedValue(for: asset)
        }
    }
    
    private var unrealizedPnl: Double {
        currentValue - investedValue
    }
    
    private var unrealizedPnlPercentage: Double {
        investedValue > 0 ? (unrealizedPnl / investedValue) * 100.0 : 0.0
    }
    
    private var avgBuyPrice: Double {
        totalUnits > 0 ? (investedValue / totalUnits) : 0.0
    }
    
    private var xirrValue: Double? {
        if isConversionActive {
            return PortfolioMetrics.xirrInINR(for: asset, rate: currentRate)
        } else {
            return PortfolioMetrics.xirr(for: asset)
        }
    }
    
    // Category & Portfolio Allocation Percentages
    private var categoryTotalValue: Double {
        guard let cat = asset.category else { return currentValue }
        let categoryAssets = allAssets.filter { $0.category?.persistentModelID == cat.persistentModelID }
        return categoryAssets.reduce(0.0) { sum, a in
            sum + (PortfolioMetrics.currentValue(for: a) * (isConversionActive ? currentRate : 1.0))
        }
    }
    
    private var portfolioTotalNetWorth: Double {
        allAssets.reduce(0.0) { sum, a in
            let catRate = a.category != nil ? PortfolioMetrics.currentInrExchangeRate(for: a.category!, currencies: currencies) : 1.0
            let rate = isConversionActive ? catRate : 1.0
            return sum + (PortfolioMetrics.currentValue(for: a) * rate)
        }
    }
    
    private var categoryAllocationPercentage: Double {
        categoryTotalValue > 0 ? (currentValue / categoryTotalValue) * 100.0 : 0.0
    }
    
    private var netWorthAllocationPercentage: Double {
        portfolioTotalNetWorth > 0 ? (currentValue / portfolioTotalNetWorth) * 100.0 : 0.0
    }
    
    // Trade Discipline
    private var transactionCounts: PortfolioMetrics.TransactionCounts {
        PortfolioMetrics.transactionCounts(for: asset.transactions)
    }
    
    // Inception Date
    private var inceptionDateText: String {
        let buys = asset.transactions.filter { $0.config.cashDirection == .outflow }
        guard let firstBuy = buys.min(by: { $0.date < $1.date }) else { return "N/A" }
        let days = Calendar.current.dateComponents([.day], from: firstBuy.date, to: Date()).day ?? 0
        let dateStr = firstBuy.date.formatted(date: .abbreviated, time: .omitted)
        if days >= 365 {
            return "\(dateStr) (\(days / 365) yr, \((days % 365) / 30) mo ago)"
        } else if days >= 30 {
            return "\(dateStr) (\(days / 30) mo ago)"
        }
        return "\(dateStr) (\(days) days ago)"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header & Currency Switcher
                headerSection
                
                // Primary Market Metrics Hero Cards
                heroCardsSection
                
                // Navigation Tabs
                Picker("View", selection: $selectedTab) {
                    ForEach(MarketTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Tab Content
                switch selectedTab {
                case .overview:
                    overviewTabContent
                case .transactions:
                    transactionsTabContent
                case .inflows:
                    AssetInflowsView(asset: asset, displayInINR: displayInINR, currentRate: currentRate)
                case .valuation:
                    valuationTabContent
                }
            }
            .padding(.bottom, 30)
        }
        .navigationTitle(asset.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddTransaction = true }) {
                    Label("Add Transaction", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddTransaction) {
            NavigationStack {
                TransactionFormView(asset: asset)
            }
        }
        .sheet(item: $transactionToEdit) { tx in
            EditTransactionSheet(transaction: tx)
        }
        .sheet(isPresented: $showValueAnalysisForm) {
            StockValueAnalysisFormSheet(asset: asset)
        }
        .sheet(isPresented: $showDCFAnalysisForm) {
            StockDCFAnalysisFormSheet(asset: asset)
        }
        .sheet(isPresented: $showValueAnalysisDetail) {
            if let analysis = asset.valueAnalysis {
                StockValueAnalysisDetailSheet(analysis: analysis)
            }
        }
        .alert("Update Current Price", isPresented: $showUpdatePriceAlert) {
            TextField("Price in \(categoryCurrencyCode)", text: $priceInput)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { }
            Button("Update") {
                if let val = Double(priceInput), val >= 0 {
                    asset.currentPrice = val
                }
            }
        } message: {
            Text("Enter current price in \(categoryCurrencyCode) for \(asset.name)")
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(asset.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        if !asset.ticker.isEmpty {
                            Text(asset.ticker)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    Text(asset.category?.name ?? "Market Investment")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                if isNonRupeeAsset {
                    Button(action: { displayInINR.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.arrow.right.circle.fill")
                            Text(displayInINR ? "INR (₹)" : "\(categoryCurrencyCode) (\(currencySymbol.trimmingCharacters(in: .whitespaces)))")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var heroCardsSection: some View {
        VStack(spacing: 12) {
            // Main Valuation Card
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Valuation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(currencySymbol)\(formattedVal(currentValue))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Unrealized P&L")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: unrealizedPnl >= 0 ? "arrow.up.right" : "arrow.down.right")
                            Text("\(unrealizedPnl >= 0 ? "+" : "")\(currencySymbol)\(formattedVal(unrealizedPnl)) (\(formattedVal(unrealizedPnlPercentage))%)")
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(unrealizedPnl >= 0 ? AppTheme.gain : AppTheme.loss)
                    }
                }
                
                Divider()
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cost Basis")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(currencySymbol)\(formattedVal(investedValue))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Units Held")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formattedVal(totalUnits))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Avg Price")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(currencySymbol)\(formattedVal(avgBuyPrice))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
            .padding(.horizontal)
            
            // Secondary Quick Stats
            HStack(spacing: 12) {
                Button(action: {
                    priceInput = String(asset.currentPrice)
                    showUpdatePriceAlert = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current Price")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(currencySymbol)\(formattedVal(asset.currentPrice * activeRate))")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.accent)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemBackground)))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("XIRR (CAGR)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let rate = xirrValue {
                        Text(String(format: "%.2f%%", rate * 100))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(rate >= 0 ? AppTheme.gain : AppTheme.loss)
                    } else {
                        Text("N/A")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemBackground)))
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Overview Tab Content
    
    private var overviewTabContent: some View {
        VStack(spacing: 16) {
            // Category & Net Worth Allocation Breakdown Cards
            VStack(alignment: .leading, spacing: 12) {
                Text("Portfolio Allocations")
                    .font(.headline)
                    .padding(.horizontal)
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Category Share")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", categoryAllocationPercentage))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.accent)
                        Text("of \(asset.category?.name ?? "Category")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Net Worth Share")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", netWorthAllocationPercentage))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        Text("of Total Portfolio")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                }
                .padding(.horizontal)
            }
            
            // Trading Activity & Inception
            VStack(alignment: .leading, spacing: 12) {
                Text("Investment History & Activity")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("First Investment Date")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(inceptionDateText)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Trading Activity")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(transactionCounts.buyCount) Buys / \(transactionCounts.sellCount) Sells")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    if transactionCounts.totalCount > 0 {
                        ProgressView(value: transactionCounts.buyPercentage, total: 100)
                            .tint(AppTheme.accent)
                            .background(AppTheme.gain)
                            .clipShape(Capsule())
                        
                        Text(transactionCounts.disciplineRatioText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                .padding(.horizontal)
            }
            
            // Action Buttons & Preview
            HStack(spacing: 12) {
                Button(action: { showAddTransaction = true }) {
                    Label("Add Trade", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal)
            
            // Recent Transactions List Preview
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent Activity")
                        .font(.headline)
                    Spacer()
                    Button("View All") { selectedTab = .transactions }
                        .font(.caption)
                }
                .padding(.horizontal)
                
                let recent = Array(PortfolioMetrics.reverseOrderedTransactions(asset.transactions).prefix(5))
                if recent.isEmpty {
                    Text("No transactions recorded yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                } else {
                    ForEach(recent) { tx in
                        transactionRow(tx)
                    }
                }
            }
        }
    }
    
    // MARK: - Transactions Tab Content (Paginated 10 per page)
    
    private var transactionsTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            let allOrdered = PortfolioMetrics.reverseOrderedTransactions(asset.transactions)
            let totalPages = max(1, Int(ceil(Double(allOrdered.count) / Double(itemsPerPage))))
            let currentPage = min(max(1, transactionsPage), totalPages)
            
            let startIndex = (currentPage - 1) * itemsPerPage
            let endIndex = min(startIndex + itemsPerPage, allOrdered.count)
            let pageEntries = allOrdered.isEmpty ? [] : Array(allOrdered[startIndex..<endIndex])
            
            HStack {
                Text("All Transactions (\(allOrdered.count))")
                    .font(.headline)
                Spacer()
                if totalPages > 1 {
                    Text("Page \(currentPage) of \(totalPages)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            
            if pageEntries.isEmpty {
                Text("No transactions found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(pageEntries) { tx in
                    transactionRow(tx, showDetailedMetrics: true)
                }
                
                // Pagination Navigation Controls
                if totalPages > 1 {
                    HStack {
                        Button(action: {
                            if transactionsPage > 1 { transactionsPage -= 1 }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Previous")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                        .disabled(transactionsPage <= 1)
                        
                        Spacer()
                        
                        Button(action: {
                            if transactionsPage < totalPages { transactionsPage += 1 }
                        }) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                        .disabled(transactionsPage >= totalPages)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Valuation Tab Content
    
    private var valuationTabContent: some View {
        VStack(spacing: 16) {
            Text("Valuation & Intrinsic Analysis")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            // 1. Stock Value Analysis Worksheet Option / Saved Analysis Card
            if let valAnalysis = asset.valueAnalysis {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stock Value Analysis")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Intrinsic Value: \(currencySymbol)\(formattedVal(valAnalysis.intrinsicValue * activeRate))")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Margin of Safety")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            let marginPct = valAnalysis.valuationMarginPercent * 100.0
                            Text(String(format: "%.1f%%", marginPct))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(marginPct >= 0 ? AppTheme.gain : AppTheme.loss)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Button("View Analysis Details") {
                            showValueAnalysisDetail = true
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Edit Sheet") {
                            showValueAnalysisForm = true
                        }
                        .font(.caption)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                .padding(.horizontal)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Stock Value Analysis Worksheet")
                                .font(.headline)
                            Text("Analyze P/E multiples, EPS, Graham number, & margin of safety.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button(action: { showValueAnalysisForm = true }) {
                        Text("Perform Stock Value Analysis")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.top, 4)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                .padding(.horizontal)
            }
            
            // 2. DCF Intrinsic Value Worksheet Option / Saved DCF Card
            if let dcf = asset.dcfAnalysis {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DCF Valuation Model")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Intrinsic Price: \(currencySymbol)\(formattedVal(dcf.intrinsicValuePerShare * activeRate))")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Margin of Safety")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            let dcfMarginPct = dcf.valuationMarginPercent * 100.0
                            Text(String(format: "%.1f%%", dcfMarginPct))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(dcfMarginPct >= 0 ? AppTheme.gain : AppTheme.loss)
                        }
                    }
                    
                    Divider()
                    
                    Button("Edit DCF Valuation") {
                        showDCFAnalysisForm = true
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                .padding(.horizontal)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "dollarsign.arrow.circlepath")
                            .font(.title2)
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DCF Intrinsic Valuation Model")
                                .font(.headline)
                            Text("Project 10-year Free Cash Flows and calculate intrinsic share price.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button(action: { showDCFAnalysisForm = true }) {
                        Text("Perform DCF Valuation")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.top, 4)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Row Helper for Transactions
    
    @ViewBuilder
    private func transactionRow(_ tx: AssetTransaction, showDetailedMetrics: Bool = false) -> some View {
        let txRate = isConversionActive ? (tx.inrExchangeRate ?? currentRate) : 1.0
        let unitPriceDisplay = tx.pricePerUnit * txRate
        let amountDisplay = tx.amount * txRate
        let holdingDays = Calendar.current.dateComponents([.day], from: tx.date, to: Date()).day ?? 0
        
        let holdingDurationText: String = {
            if holdingDays >= 365 {
                return "\(holdingDays / 365) yr, \((holdingDays % 365) / 30) mo"
            } else if holdingDays >= 30 {
                return "\(holdingDays / 30) mo, \(holdingDays % 30) d"
            }
            return "\(holdingDays) days"
        }()
        
        // Per-Transaction P/L calculation for unit-based buy transactions
        let txPnlInfo: (pnl: Double, percentage: Double)? = {
            guard tx.config.isUnitBased else { return nil }
            if tx.config.rawType == "BUY" {
                let currentValForTx = tx.units * asset.currentPrice * txRate
                let pnl = currentValForTx - amountDisplay
                let pct = amountDisplay > 0 ? (pnl / amountDisplay) * 100.0 : 0.0
                return (pnl, pct)
            } else if tx.config.rawType == "DIVIDEND" {
                return (amountDisplay, 100.0)
            }
            return nil
        }()
        
        HStack {
            Image(systemName: tx.config.iconName)
                .font(.title3)
                .foregroundStyle(tx.config.cashDirection == .outflow ? AppTheme.accent : AppTheme.gain)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.gray.opacity(0.12)))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.config.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("• Held \(holdingDurationText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(currencySymbol)\(formattedVal(amountDisplay))")
                    .font(.callout)
                    .fontWeight(.semibold)
                
                if tx.config.isUnitBased {
                    Text("\(formattedVal(tx.units)) units @ \(currencySymbol)\(formattedVal(unitPriceDisplay))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                if showDetailedMetrics, let info = txPnlInfo {
                    HStack(spacing: 2) {
                        Text("P/L:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(info.pnl >= 0 ? "+" : "")\(currencySymbol)\(formattedVal(info.pnl)) (\(formattedVal(info.percentage))%)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(info.pnl >= 0 ? AppTheme.gain : AppTheme.loss)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            transactionToEdit = tx
        }
    }
    
    private func formattedVal(_ num: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: num)) ?? String(format: "%.2f", num)
    }
}
