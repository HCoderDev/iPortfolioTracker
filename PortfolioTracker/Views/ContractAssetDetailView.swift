//
//  ContractAssetDetailView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct ContractAssetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let asset: Asset
    
    @Query(sort: \Currency.code) private var currencies: [Currency]
    @Query private var allAssets: [Asset]
    
    @State private var displayInINR = true
    @State private var showAddTransaction = false
    @State private var transactionToEdit: AssetTransaction?
    @State private var selectedTab: ContractTab = .overview
    
    // Pagination state (10 items per page)
    @State private var transactionsPage = 1
    private let itemsPerPage = 10
    
    enum ContractTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case transactions = "Transactions"
        case inflows = "Inflows"
        
        var id: String { rawValue }
    }
    
    private var categoryCurrencyCode: String {
        asset.category?.currencyCode ?? "INR"
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
    
    // Financial Metrics
    private var totalBalance: Double {
        PortfolioMetrics.currentValue(for: asset) * activeRate
    }
    
    private var capitalInvested: Double {
        PortfolioMetrics.investedValue(for: asset) * activeRate
    }
    
    private var totalInterestEarned: Double {
        PortfolioMetrics.totalInterestAccrued(for: asset) * activeRate
    }
    
    private var xirrRate: Double? {
        PortfolioMetrics.xirr(for: asset)
    }
    
    private var lifetimeInvested: Double {
        if isConversionActive {
            return PortfolioMetrics.lifetimeInvestedInINR(for: asset, rate: currentRate)
        } else {
            return PortfolioMetrics.lifetimeInvested(for: asset)
        }
    }
    
    private var lifetimeRetrieved: Double {
        if isConversionActive {
            return PortfolioMetrics.lifetimeRetrievedInINR(for: asset, rate: currentRate)
        } else {
            return PortfolioMetrics.lifetimeRetrieved(for: asset)
        }
    }
    
    private var lifetimeDividend: Double {
        if isConversionActive {
            return PortfolioMetrics.lifetimeDividendInINR(for: asset, rate: currentRate)
        } else {
            return PortfolioMetrics.lifetimeDividend(for: asset)
        }
    }
    
    private var xirrValue: Double? {
        if isConversionActive {
            return PortfolioMetrics.xirrInINR(for: asset, rate: currentRate)
        } else {
            return PortfolioMetrics.xirr(for: asset)
        }
    }
    
    private var totalGainLoss: Double {
        (totalBalance + lifetimeRetrieved) - lifetimeInvested
    }
    
    private var overallGainLossPercentage: Double {
        lifetimeInvested > 0 ? (totalGainLoss / lifetimeInvested) * 100.0 : 0.0
    }
    
    private var daysToMaturityText: String {
        guard let mat = asset.maturityDate else { return "N/A" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: mat).day ?? 0
        if days < 0 { return "Matured" }
        if days >= 365 {
            return "\(days / 365) yr, \(days % 365) days"
        }
        return "\(days) days"
    }
    
    // Category & Portfolio Allocation Percentages
    private var assetValueINR: Double {
        guard let cat = asset.category else { return PortfolioMetrics.currentValue(for: asset) }
        let rate = PortfolioMetrics.currentInrExchangeRate(for: cat, currencies: currencies)
        return PortfolioMetrics.currentValueInINR(for: asset, rate: rate)
    }
    
    private var categoryTotalValueINR: Double {
        guard let cat = asset.category else { return assetValueINR }
        let categoryAssets = allAssets.filter { $0.category?.persistentModelID == cat.persistentModelID }
        let rate = PortfolioMetrics.currentInrExchangeRate(for: cat, currencies: currencies)
        return categoryAssets.reduce(0.0) { sum, a in
            sum + PortfolioMetrics.currentValueInINR(for: a, rate: rate)
        }
    }
    
    private var portfolioTotalNetWorthINR: Double {
        allAssets.reduce(0.0) { sum, a in
            guard let cat = a.category else { return sum + PortfolioMetrics.currentValue(for: a) }
            let rate = PortfolioMetrics.currentInrExchangeRate(for: cat, currencies: currencies)
            return sum + PortfolioMetrics.currentValueInINR(for: a, rate: rate)
        }
    }
    
    private var categoryAllocationPercentage: Double {
        categoryTotalValueINR > 0 ? (assetValueINR / categoryTotalValueINR) * 100.0 : 0.0
    }
    
    private var netWorthAllocationPercentage: Double {
        portfolioTotalNetWorthINR > 0 ? (assetValueINR / portfolioTotalNetWorthINR) * 100.0 : 0.0
    }
    
    // Inception Date
    private var inceptionDateText: String {
        let txs = asset.transactions.filter { $0.config.cashDirection == .outflow }
        guard let firstTx = txs.min(by: { $0.date < $1.date }) else { return "N/A" }
        let days = Calendar.current.dateComponents([.day], from: firstTx.date, to: Date()).day ?? 0
        let dateStr = firstTx.date.formatted(date: .abbreviated, time: .omitted)
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
                // Header Title & Currency Switcher
                headerSection
                
                // Primary Contract Hero Dashboard
                heroMetricsDashboard
                
                // Contract Metadata Banner (Interest Rate, Institution, Policy #, Maturity Date)
                contractMetadataBanner
                
                // Navigation Tabs
                Picker("View", selection: $selectedTab) {
                    ForEach(ContractTab.allCases) { tab in
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
                }
            }
            .padding(.bottom, 30)
        }
        .navigationTitle(asset.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddTransaction = true }) {
                    Label("Add Entry", systemImage: "plus")
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
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(asset.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(asset.holdingType.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                    
                    let isClosed = PortfolioMetrics.isSoldOff(asset)
                    HStack(spacing: 4) {
                        Circle().fill(isClosed ? Color.gray : Color.green).frame(width: 6, height: 6)
                        Text(isClosed ? "COMPLETED" : "ACTIVE POLICY")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isClosed ? Color.gray.opacity(0.15) : Color.green.opacity(0.15))
                    .foregroundStyle(isClosed ? Color.secondary : Color.green)
                    .clipShape(Capsule())
                }
                
                if !asset.institutionName.isEmpty {
                    Text(asset.institutionName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            
            HStack(spacing: 10) {
                Menu {
                    Button {
                        asset.isCompleted.toggle()
                    } label: {
                        Label(
                            asset.isCompleted ? "Mark as Active Policy" : "Mark as Completed / Matured",
                            systemImage: asset.isCompleted ? "arrow.clockwise" : "flag.checkered"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(AppTheme.accent)
                }
                
                if isNonRupeeAsset {
                    Button(action: { displayInINR.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.arrow.right.circle.fill")
                            Text(displayInINR ? "INR (₹)" : "\(categoryCurrencyCode)")
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
        }
        .padding(.horizontal)
    }
    
    private var heroMetricsDashboard: some View {
        VStack(spacing: 12) {
            let isClosed = PortfolioMetrics.isSoldOff(asset)
            
            if isClosed {
                HStack(spacing: 10) {
                    Image(systemName: "flag.checkered.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Policy Completed / Paid Out")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("Current balance is ₹0.00 (Excluded from active net worth). All historical premiums, bonuses, & maturity returns are preserved below.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isClosed ? "Current Active Valuation" : "Current Account Valuation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(currencySymbol)\(formattedVal(totalBalance))")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(isClosed ? .secondary : AppTheme.accent)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("XIRR Return")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let xirr = xirrRate {
                            Text(String(format: "%.2f%%", xirr * 100))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(xirr >= 0 ? AppTheme.gain : AppTheme.loss)
                        } else {
                            Text("N/A")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Divider()
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isClosed ? "Active Invested Capital" : "Capital Invested")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(currencySymbol)\(formattedVal(capitalInvested))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Total Interest / Returns")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("+\(currencySymbol)\(formattedVal(totalInterestEarned))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.gain)
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
            .padding(.horizontal)
        }
    }
    
    private var contractMetadataBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Contract Details")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if asset.interestRate > 0 {
                    metadataItem(title: "Interest Rate", value: String(format: "%.2f%% p.a.", asset.interestRate), icon: "percent")
                }
                
                if let maturity = asset.maturityDate {
                    metadataItem(title: "Maturity Date", value: maturity.formatted(date: .abbreviated, time: .omitted), icon: "calendar")
                    metadataItem(title: "Time to Maturity", value: daysToMaturityText, icon: "hourglass")
                }
                
                if !asset.policyNumber.isEmpty {
                    metadataItem(title: "Account / Policy #", value: asset.policyNumber, icon: "doc.text.fill")
                }
                
                if asset.premiumAmount > 0 {
                    metadataItem(title: "Regular Premium", value: "\(currencySymbol)\(formattedVal(asset.premiumAmount * activeRate))", icon: "arrow.triangle.2.circlepath")
                }
                
                if !asset.payoutFrequency.isEmpty {
                    metadataItem(title: "Payout Mode", value: asset.payoutFrequency.capitalized, icon: "clock.fill")
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.tertiarySystemBackground)))
        .padding(.horizontal)
    }
    
    private func metadataItem(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            Spacer()
        }
    }
    
    // MARK: - Overview Tab Content
    
    private var overviewTabContent: some View {
        VStack(spacing: 16) {
            // Portfolio Allocations
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
            
            // Contract Inception & Recency
            VStack(alignment: .leading, spacing: 12) {
                Text("Contract History & Recency")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last Contribution Date")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(PortfolioMetrics.lastInvestedFormattedText(for: asset))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        
                        let status = PortfolioMetrics.recencyStatus(for: asset)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(status.color)
                                .frame(width: 8, height: 8)
                            Text(status.rawValue)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(status.color)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(status.color.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("First Deposit / Contribution Date")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(inceptionDateText)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                .padding(.horizontal)
            }
            
            // Bulk Schedule Action Button
            HStack(spacing: 12) {
                Button(action: { showAddTransaction = true }) {
                    Label("Bulk Contribution / SIP", systemImage: "arrow.triangle.2.circlepath.circle.fill")
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
            
            // Lifetime Capital Flow Card
            VStack(alignment: .leading, spacing: 12) {
                Text("Lifetime Cash Flow")
                    .font(.headline)
                    .padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lifetime Invested")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(currencySymbol)\(formattedVal(lifetimeInvested))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Text("Total Capital Invested")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lifetime Retrieved")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(currencySymbol)\(formattedVal(lifetimeRetrieved))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.gain)
                        Text("Payouts / Returns")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lifetime Dividends / Interest")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(currencySymbol)\(formattedVal(lifetimeDividend))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                        Text("Payouts Received")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                }
                .padding(.horizontal)
            }
            
            // Overall Performance Card
            VStack(alignment: .leading, spacing: 12) {
                Text("Overall Performance")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Overall Gain / Loss")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(totalGainLoss >= 0 ? "+" : "")\(currencySymbol)\(formattedVal(totalGainLoss)) (\(formattedVal(overallGainLossPercentage))%)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(totalGainLoss >= 0 ? AppTheme.gain : AppTheme.loss)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Overall XIRR")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let xirr = xirrValue {
                                Text(String(format: "%.2f%%", xirr * 100))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(xirr >= 0 ? AppTheme.gain : AppTheme.loss)
                            } else {
                                Text("N/A")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                .padding(.horizontal)
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
                Text("All Contract Entries (\(allOrdered.count))")
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
                Text("No contract transactions found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(pageEntries) { tx in
                    contractTransactionRow(tx)
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
    
    @ViewBuilder
    private func contractTransactionRow(_ tx: AssetTransaction) -> some View {
        let txRate = isConversionActive ? (tx.inrExchangeRate ?? currentRate) : 1.0
        let displayAmount = tx.amount * txRate
        let holdingDays = Calendar.current.dateComponents([.day], from: tx.date, to: Date()).day ?? 0
        
        let durationText: String = {
            if holdingDays >= 365 {
                return "\(holdingDays / 365) yr, \((holdingDays % 365) / 30) mo ago"
            } else if holdingDays >= 30 {
                return "\(holdingDays / 30) mo ago"
            }
            return "\(holdingDays) days ago"
        }()
        
        HStack {
            Image(systemName: tx.config.iconName)
                .font(.title3)
                .foregroundStyle(rowColor(tx.config.cashDirection))
                .frame(width: 38, height: 38)
                .background(Circle().fill(rowColor(tx.config.cashDirection).opacity(0.12)))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.config.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 6) {
                    Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if tx.type == .buy || tx.config.cashDirection == .outflow {
                        Text("• \(durationText)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(cashPrefix(tx.config.cashDirection))\(currencySymbol)\(formattedVal(displayAmount))")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(rowColor(tx.config.cashDirection))
                
                Text(tx.config.cashDirection.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            transactionToEdit = tx
        }
        .contextMenu {
            Button {
                transactionToEdit = tx
            } label: {
                Label("Edit Entry", systemImage: "pencil")
            }
            Button(role: .destructive) {
                modelContext.delete(tx)
            } label: {
                Label("Delete Entry", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(tx)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                transactionToEdit = tx
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
    
    private func rowColor(_ dir: CashDirection) -> Color {
        switch dir {
        case .outflow: return AppTheme.accent
        case .internalAccrual: return .orange
        case .inflow: return AppTheme.gain
        }
    }
    
    private func cashPrefix(_ dir: CashDirection) -> String {
        switch dir {
        case .outflow: return ""
        case .internalAccrual: return "+"
        case .inflow: return ""
        }
    }
    
    private func formattedVal(_ num: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: num)) ?? String(format: "%.2f", num)
    }
}
