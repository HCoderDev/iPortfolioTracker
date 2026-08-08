//
//  PassiveIncomeView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct PassiveIncomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]
    @Query private var transactions: [AssetTransaction]
    @Query(sort: \Currency.code) private var currencies: [Currency]
    @Query(sort: \Asset.name) private var allAssets: [Asset]
    
    enum PeriodType: String, CaseIterable, Identifiable {
        case monthly = "Monthly"
        case yearly = "Yearly"
        case lifetime = "Lifetime"
        var id: String { self.rawValue }
    }
    
    enum IncomeTypeFilter: String, CaseIterable, Identifiable {
        case all = "All Types"
        case dividends = "Dividends"
        case interest = "Interest"
        case benefits = "Coupons & Benefits"
        var id: String { self.rawValue }
    }
    
    @State private var selectedPeriodType: PeriodType = .monthly
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedIncomeFilter: IncomeTypeFilter = .all
    @State private var displayInINR: Bool = true
    @State private var searchText: String = ""
    @State private var expandedCategories: Set<PersistentIdentifier> = []
    @State private var showLogIncomeSheet: Bool = false
    
    // Currency exchange rate converter helper
    private func transactionRate(for tx: AssetTransaction) -> Double {
        guard displayInINR else { return 1.0 }
        guard let cat = tx.asset?.category else { return 1.0 }
        if cat.currencyCode == "INR" { return 1.0 }
        if let txRate = tx.inrExchangeRate { return txRate }
        return PortfolioMetrics.currentInrExchangeRate(for: cat, currencies: currencies)
    }
    
    // Check if a transaction is passive income (dividends, interest, coupons, bonuses, etc.)
    private func isPassiveIncome(_ tx: AssetTransaction) -> Bool {
        if tx.asset?.holdingType.isNonUnitized == true && tx.config.closesAsset {
            // Principal maturity payouts are non-income capital returns
            return false
        }
        if tx.type == .dividend { return true }
        let raw = tx.rawType.uppercased()
        if raw.contains("DIVIDEND") || raw.contains("INTEREST") || raw.contains("COUPON") ||
            raw.contains("BONUS") || raw.contains("SURVIVAL_BENEFIT") || raw.contains("RENT") ||
            raw.contains("ROYALTY") || raw.contains("PAYOUT") {
            return true
        }
        if !tx.config.affectsInvestedAmount && tx.config.affectsProfit &&
            (tx.config.cashDirection == .inflow || tx.config.cashDirection == .internalAccrual) {
            return true
        }
        return false
    }
    
    // Categorize passive income type for filtering
    private func incomeCategoryGroup(for tx: AssetTransaction) -> IncomeTypeFilter {
        let raw = tx.rawType.uppercased()
        if raw.contains("DIVIDEND") || tx.type == .dividend {
            return .dividends
        } else if raw.contains("INTEREST") {
            return .interest
        } else if raw.contains("COUPON") || raw.contains("BONUS") || raw.contains("SURVIVAL_BENEFIT") {
            return .benefits
        }
        return .dividends
    }
    
    // Calculate total income amount for a given transaction in display currency
    private func incomeAmount(for tx: AssetTransaction) -> Double {
        let rawAmount = (tx.units > 0 && tx.type == .dividend && tx.config.isUnitBased) ? (tx.units * tx.pricePerUnit) : tx.amount
        return rawAmount * transactionRate(for: tx)
    }
    
    private var startingYear: Int {
        let incomeTx = transactions.filter { isPassiveIncome($0) }
        let txYears = incomeTx.map { Calendar.current.component(.year, from: $0.date) }
        return txYears.min() ?? Calendar.current.component(.year, from: Date())
    }
    
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    
    var availableYears: [Int] {
        let incomeTx = transactions.filter { isPassiveIncome($0) }
        let txYears = incomeTx.map { Calendar.current.component(.year, from: $0.date) }
        let curr = Calendar.current.component(.year, from: Date())
        var unique = Set(txYears)
        unique.insert(curr)
        return unique.sorted(by: >)
    }
    
    var months: [Int] { Array(1...12) }
    
    func monthName(for number: Int) -> String {
        let formatter = DateFormatter()
        return formatter.monthSymbols[number - 1]
    }
    
    func monthAbbrev(_ month: Int) -> String {
        let formatter = DateFormatter()
        return formatter.shortMonthSymbols[month - 1]
    }
    
    // MARK: - Data Models for Income Flow Matrix
    
    struct FlowItem: Identifiable {
        let id: String
        let name: String
        let totalIncome: Double
        let count: Int
        let dividendAmount: Double
        let interestAmount: Double
        let otherAmount: Double
    }
    
    struct CategoryIncomeFlow: Identifiable {
        let id: PersistentIdentifier
        let category: Category
        let totalIncome: Double
        let count: Int
        let dividendAmount: Double
        let interestAmount: Double
        let otherAmount: Double
        let assetFlows: [FlowItem]
    }
    
    struct YearlyIncomeRow: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let currencyCode: String
        let monthlyIncome: [Int: Double]
        let monthlyCounts: [Int: Int]
        let yearTotal: Double
        let yearCount: Int
        let assetRows: [YearlyAssetIncomeRow]
    }
    
    struct YearlyAssetIncomeRow: Identifiable {
        let id: String
        let name: String
        let monthlyIncome: [Int: Double]
        let monthlyCounts: [Int: Int]
        let yearTotal: Double
        let yearCount: Int
    }
    
    struct LifetimeIncomeRow: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let currencyCode: String
        let yearlyIncome: [Int: Double]
        let yearlyCounts: [Int: Int]
        let overallTotal: Double
        let overallCount: Int
        let assetRows: [LifetimeAssetIncomeRow]
    }
    
    struct LifetimeAssetIncomeRow: Identifiable {
        let id: String
        let name: String
        let yearlyIncome: [Int: Double]
        let yearlyCounts: [Int: Int]
        let overallTotal: Double
        let overallCount: Int
    }
    
    private let headerHeight: CGFloat = 40
    private let categoryRowHeight: CGFloat = 52
    private let assetRowHeight: CGFloat = 44
    private let leftColumnWidth: CGFloat = 130
    private let scrollCellWidth: CGFloat = 75
    
    // Filtered base transactions
    private var baseIncomeTransactions: [AssetTransaction] {
        transactions.filter { tx in
            guard isPassiveIncome(tx) else { return false }
            if selectedIncomeFilter != .all {
                let group = incomeCategoryGroup(for: tx)
                if group != selectedIncomeFilter { return false }
            }
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                let assetMatch = tx.asset?.name.lowercased().contains(query) ?? false
                let catMatch = tx.asset?.category?.name.lowercased().contains(query) ?? false
                let noteMatch = tx.notes?.lowercased().contains(query) ?? false
                let typeMatch = tx.rawType.lowercased().contains(query)
                if !assetMatch && !catMatch && !noteMatch && !typeMatch {
                    return false
                }
            }
            return true
        }
    }
    
    // MARK: - Computed Monthly/Period Data
    
    private var filteredIncomeData: (
        categories: [CategoryIncomeFlow],
        totalIncome: Double,
        totalCount: Int,
        totalDividends: Double,
        totalInterest: Double,
        totalOther: Double,
        topAsset: (name: String, amount: Double)?
    ) {
        let calendar = Calendar.current
        var categoryFlows: [CategoryIncomeFlow] = []
        var totalIncome = 0.0
        var totalCount = 0
        var totalDividends = 0.0
        var totalInterest = 0.0
        var totalOther = 0.0
        var assetTotals: [String: Double] = [:]
        
        let periodTx = baseIncomeTransactions.filter { tx in
            if selectedPeriodType == .lifetime { return true }
            let year = calendar.component(.year, from: tx.date)
            if selectedPeriodType == .yearly {
                return year == selectedYear
            } else {
                let month = calendar.component(.month, from: tx.date)
                return year == selectedYear && month == selectedMonth
            }
        }
        
        for tx in periodTx {
            let amt = incomeAmount(for: tx)
            let assetName = tx.asset?.name ?? "Unknown Asset"
            assetTotals[assetName, default: 0.0] += amt
            totalIncome += amt
            totalCount += 1
            
            let group = incomeCategoryGroup(for: tx)
            switch group {
            case .dividends: totalDividends += amt
            case .interest: totalInterest += amt
            case .benefits, .all: totalOther += amt
            }
        }
        
        for category in categories {
            let catTx = periodTx.filter { $0.asset?.category?.persistentModelID == category.persistentModelID }
            guard !catTx.isEmpty else { continue }
            
            var catTotal = 0.0
            let catCount = catTx.count
            var catDiv = 0.0
            var catInt = 0.0
            var catOth = 0.0
            var assetFlows: [FlowItem] = []
            
            let assetsInCat = Dictionary(grouping: catTx.compactMap { $0.asset }, by: { $0.persistentModelID }).values.compactMap { $0.first }
            for asset in assetsInCat.sorted(by: { $0.name < $1.name }) {
                let aTx = catTx.filter { $0.asset?.persistentModelID == asset.persistentModelID }
                var aTotal = 0.0
                var aDiv = 0.0
                var aInt = 0.0
                var aOth = 0.0
                
                for tx in aTx {
                    let amt = incomeAmount(for: tx)
                    aTotal += amt
                    let group = incomeCategoryGroup(for: tx)
                    switch group {
                    case .dividends: aDiv += amt
                    case .interest: aInt += amt
                    case .benefits, .all: aOth += amt
                    }
                }
                
                assetFlows.append(FlowItem(
                    id: "\(asset.persistentModelID)",
                    name: asset.name,
                    totalIncome: aTotal,
                    count: aTx.count,
                    dividendAmount: aDiv,
                    interestAmount: aInt,
                    otherAmount: aOth
                ))
            }
            
            for tx in catTx {
                let amt = incomeAmount(for: tx)
                catTotal += amt
                let group = incomeCategoryGroup(for: tx)
                switch group {
                case .dividends: catDiv += amt
                case .interest: catInt += amt
                case .benefits, .all: catOth += amt
                }
            }
            
            categoryFlows.append(CategoryIncomeFlow(
                id: category.persistentModelID,
                category: category,
                totalIncome: catTotal,
                count: catCount,
                dividendAmount: catDiv,
                interestAmount: catInt,
                otherAmount: catOth,
                assetFlows: assetFlows.sorted(by: { $0.totalIncome > $1.totalIncome })
            ))
        }
        
        let topAsst = assetTotals.max(by: { $0.value < $1.value }).map { (name: $0.key, amount: $0.value) }
        
        return (
            categoryFlows.sorted(by: { $0.totalIncome > $1.totalIncome }),
            totalIncome,
            totalCount,
            totalDividends,
            totalInterest,
            totalOther,
            topAsst
        )
    }
    
    // MARK: - Computed Yearly Matrix Data
    
    private var yearlyIncomeData: [YearlyIncomeRow] {
        let calendar = Calendar.current
        var rows: [YearlyIncomeRow] = []
        
        let yearTxAll = baseIncomeTransactions.filter { calendar.component(.year, from: $0.date) == selectedYear }
        
        for category in categories {
            var categoryMonthly: [Int: Double] = [:]
            var categoryMonthlyCounts: [Int: Int] = [:]
            var assetRows: [YearlyAssetIncomeRow] = []
            
            let catTx = yearTxAll.filter { $0.asset?.category?.persistentModelID == category.persistentModelID }
            guard !catTx.isEmpty else { continue }
            
            let assetsInCat = Dictionary(grouping: catTx.compactMap { $0.asset }, by: { $0.persistentModelID }).values.compactMap { $0.first }
            for asset in assetsInCat.sorted(by: { $0.name < $1.name }) {
                var assetMonthly: [Int: Double] = [:]
                var assetMonthlyCounts: [Int: Int] = [:]
                let aTx = catTx.filter { $0.asset?.persistentModelID == asset.persistentModelID }
                
                for month in 1...12 {
                    let mTx = aTx.filter { calendar.component(.month, from: $0.date) == month }
                    let amt = mTx.reduce(0.0) { $0 + incomeAmount(for: $1) }
                    assetMonthly[month] = amt
                    assetMonthlyCounts[month] = mTx.count
                }
                
                let assetTotal = assetMonthly.values.reduce(0.0, +)
                let assetCount = assetMonthlyCounts.values.reduce(0, +)
                if assetTotal > 0 || assetCount > 0 {
                    assetRows.append(YearlyAssetIncomeRow(
                        id: "\(asset.persistentModelID)",
                        name: asset.name,
                        monthlyIncome: assetMonthly,
                        monthlyCounts: assetMonthlyCounts,
                        yearTotal: assetTotal,
                        yearCount: assetCount
                    ))
                }
            }
            
            for month in 1...12 {
                let mTx = catTx.filter { calendar.component(.month, from: $0.date) == month }
                let amt = mTx.reduce(0.0) { $0 + incomeAmount(for: $1) }
                categoryMonthly[month] = amt
                categoryMonthlyCounts[month] = mTx.count
            }
            
            let catTotal = categoryMonthly.values.reduce(0.0, +)
            let catCount = categoryMonthlyCounts.values.reduce(0, +)
            if catTotal > 0 || !assetRows.isEmpty {
                rows.append(YearlyIncomeRow(
                    id: category.persistentModelID,
                    name: category.name,
                    currencyCode: category.currencyCode,
                    monthlyIncome: categoryMonthly,
                    monthlyCounts: categoryMonthlyCounts,
                    yearTotal: catTotal,
                    yearCount: catCount,
                    assetRows: assetRows
                ))
            }
        }
        
        return rows
    }
    
    // MARK: - Computed Lifetime Matrix Data
    
    private var lifetimeIncomeData: [LifetimeIncomeRow] {
        let calendar = Calendar.current
        var rows: [LifetimeIncomeRow] = []
        let start = startingYear
        let end = currentYear
        let yearsRange = Array(start...end)
        
        for category in categories {
            var catYearly: [Int: Double] = [:]
            var catYearlyCounts: [Int: Int] = [:]
            var assetRows: [LifetimeAssetIncomeRow] = []
            
            let catTx = baseIncomeTransactions.filter { $0.asset?.category?.persistentModelID == category.persistentModelID }
            guard !catTx.isEmpty else { continue }
            
            let assetsInCat = Dictionary(grouping: catTx.compactMap { $0.asset }, by: { $0.persistentModelID }).values.compactMap { $0.first }
            for asset in assetsInCat.sorted(by: { $0.name < $1.name }) {
                var assetYearly: [Int: Double] = [:]
                var assetYearlyCounts: [Int: Int] = [:]
                let aTx = catTx.filter { $0.asset?.persistentModelID == asset.persistentModelID }
                
                for year in yearsRange {
                    let yTx = aTx.filter { calendar.component(.year, from: $0.date) == year }
                    let amt = yTx.reduce(0.0) { $0 + incomeAmount(for: $1) }
                    assetYearly[year] = amt
                    assetYearlyCounts[year] = yTx.count
                }
                
                let assetTotal = assetYearly.values.reduce(0.0, +)
                let assetCount = assetYearlyCounts.values.reduce(0, +)
                if assetTotal > 0 || assetCount > 0 {
                    assetRows.append(LifetimeAssetIncomeRow(
                        id: "\(asset.persistentModelID)",
                        name: asset.name,
                        yearlyIncome: assetYearly,
                        yearlyCounts: assetYearlyCounts,
                        overallTotal: assetTotal,
                        overallCount: assetCount
                    ))
                }
            }
            
            for year in yearsRange {
                let yTx = catTx.filter { calendar.component(.year, from: $0.date) == year }
                let amt = yTx.reduce(0.0) { $0 + incomeAmount(for: $1) }
                catYearly[year] = amt
                catYearlyCounts[year] = yTx.count
            }
            
            let catTotal = catYearly.values.reduce(0.0, +)
            let catCount = catYearlyCounts.values.reduce(0, +)
            if catTotal > 0 || !assetRows.isEmpty {
                rows.append(LifetimeIncomeRow(
                    id: category.persistentModelID,
                    name: category.name,
                    currencyCode: category.currencyCode,
                    yearlyIncome: catYearly,
                    yearlyCounts: catYearlyCounts,
                    overallTotal: catTotal,
                    overallCount: catCount,
                    assetRows: assetRows
                ))
            }
        }
        
        return rows
    }
    
    // MARK: - Body View
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Header Toolbar & Filters Card
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PASSIVE INCOME DASHBOARD")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(AppTheme.accent)
                            Text("Dividend & Income Insights")
                                .font(.title3.weight(.bold))
                        }
                        Spacer()
                        
                        Button {
                            showLogIncomeSheet = true
                        } label: {
                            Label("Log Income", systemImage: "plus.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(AppTheme.profitGradient)
                                .clipShape(Capsule())
                                .shadow(color: AppTheme.profit.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Divider()
                    
                    // Period Type & Currency Selector
                    HStack(spacing: 12) {
                        Picker("Period Type", selection: $selectedPeriodType) {
                            ForEach(PeriodType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Picker("Currency Display", selection: $displayInINR) {
                            Text("INR (₹)").tag(true)
                            Text("Native").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 160)
                    }
                    
                    // Period Controls & Filters Row
                    HStack(spacing: 12) {
                        if selectedPeriodType != .lifetime {
                            // Year Menu
                            Menu {
                                Picker("Year", selection: $selectedYear) {
                                    ForEach(availableYears, id: \.self) { year in
                                        Text(String(year)).tag(year)
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Year: \(String(selectedYear))")
                                        .font(.system(size: 12, weight: .bold))
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppTheme.accent)
                                .clipShape(Capsule())
                            }
                            
                            // Month Menu
                            if selectedPeriodType == .monthly {
                                Menu {
                                    Picker("Month", selection: $selectedMonth) {
                                        ForEach(months, id: \.self) { month in
                                            Text(monthName(for: month)).tag(month)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(monthName(for: selectedMonth))
                                            .font(.system(size: 12, weight: .bold))
                                        Image(systemName: "chevron.down")
                                            .font(.caption2)
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(AppTheme.accentSecondary)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Income Category Filter Menu
                        Picker("Filter Type", selection: $selectedIncomeFilter) {
                            ForEach(IncomeTypeFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 12, weight: .medium))
                    }
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search asset, category, or note...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .modifier(AppTheme.cardStyle())
                .padding(.horizontal, 20)
                
                let data = filteredIncomeData
                let currencyPrefix = displayInINR ? "₹" : ""
                
                // MARK: - Key Passive Income Insight Cards
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        // Total Passive Income Card
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("TOTAL PASSIVE INCOME")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Image(systemName: "banknote.fill")
                                    .foregroundStyle(AppTheme.profit)
                            }
                            
                            Text("\(currencyPrefix)\(data.totalIncome.formattedComma)")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.profit)
                            
                            Text(selectedPeriodType == .monthly
                                 ? "\(monthName(for: selectedMonth)) \(selectedYear)"
                                 : (selectedPeriodType == .yearly ? "Calendar Year \(selectedYear)" : "Lifetime (\(startingYear) - \(currentYear))"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .modifier(AppTheme.cardStyle())
                        
                        // Income Payout Count & Monthly Rate Card
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("PAYOUTS & RATE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Image(systemName: "arrow.up.right.circle.fill")
                                    .foregroundStyle(AppTheme.accent)
                            }
                            
                            Text("\(data.totalCount) Receipts")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            
                            let monthlyAvg = selectedPeriodType == .monthly ? data.totalIncome : (selectedPeriodType == .yearly ? (data.totalIncome / 12.0) : (data.totalIncome / max(1.0, Double(currentYear - startingYear + 1) * 12.0)))
                            Text("Avg: \(currencyPrefix)\(monthlyAvg.formattedComma)/mo")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppTheme.accent)
                        }
                        .frame(maxWidth: .infinity)
                        .modifier(AppTheme.cardStyle())
                    }
                    
                    // Top Yielding Asset & Breakdown Banner
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TOP PRODUCING ASSET")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            if let top = data.topAsset {
                                Text(top.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .lineLimit(1)
                                Text("\(currencyPrefix)\(top.amount.formattedComma) Payout")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppTheme.profit)
                            } else {
                                Text("No payouts logged")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                        
                        // Breakdown Pill
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("BREAKDOWN BY TYPE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("Dividends: \(currencyPrefix)\(data.totalDividends.formattedCompact)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(AppTheme.profit)
                                    Text("Interest: \(currencyPrefix)\(data.totalInterest.formattedCompact)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .modifier(AppTheme.cardStyle())
                }
                .padding(.horizontal, 20)
                
                // MARK: - Visual Bar Chart Insights
                if selectedPeriodType == .yearly || selectedPeriodType == .lifetime {
                    incomeTrendChartView
                        .padding(.horizontal, 20)
                }
                
                // MARK: - Matrix Grid & Categorized Breakdown
                if selectedPeriodType == .yearly {
                    let yearlyRows = yearlyIncomeData
                    if yearlyRows.isEmpty {
                        ContentUnavailableView(
                            "No Passive Income in \(String(selectedYear))",
                            systemImage: "banknote",
                            description: Text("No dividends or interest transactions recorded for \(String(selectedYear)).")
                        )
                        .padding(.vertical, 30)
                    } else {
                        yearlyIncomeGridView(rows: yearlyRows)
                    }
                } else if selectedPeriodType == .lifetime {
                    let lifetimeRows = lifetimeIncomeData
                    if lifetimeRows.isEmpty {
                        ContentUnavailableView(
                            "No Lifetime Passive Income",
                            systemImage: "banknote",
                            description: Text("No dividends or interest transactions recorded across your portfolio.")
                        )
                        .padding(.vertical, 30)
                    } else {
                        lifetimeIncomeGridView(rows: lifetimeRows)
                    }
                } else {
                    // Monthly Breakdown
                    if data.categories.isEmpty {
                        ContentUnavailableView(
                            "No Income in \(monthName(for: selectedMonth))",
                            systemImage: "banknote",
                            description: Text("No dividend or interest payments were logged for \(monthName(for: selectedMonth)) \(selectedYear).")
                        )
                        .padding(.vertical, 30)
                    } else {
                        monthlyIncomeListView(categories: data.categories)
                    }
                }
                
                // MARK: - Transaction Log Section
                incomeTransactionHistorySection
                    .padding(.horizontal, 20)
                
                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
        .navigationTitle("Passive Income")
        .sheet(isPresented: $showLogIncomeSheet) {
            LogIncomeFormSheet(assets: allAssets, brokers: Array(try! modelContext.fetch(FetchDescriptor<Broker>())))
        }
    }
    
    // MARK: - Bar Chart Trend View
    @ViewBuilder
    private var incomeTrendChartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedPeriodType == .yearly ? "Monthly Passive Income Trend (\(selectedYear))" : "Lifetime Income Growth Trend")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }
            
            let chartData: [(label: String, amount: Double)] = {
                let calendar = Calendar.current
                if selectedPeriodType == .yearly {
                    return (1...12).map { month in
                        let mTx = baseIncomeTransactions.filter {
                            calendar.component(.year, from: $0.date) == selectedYear &&
                            calendar.component(.month, from: $0.date) == month
                        }
                        let total = mTx.reduce(0.0) { $0 + incomeAmount(for: $1) }
                        return (label: monthAbbrev(month), amount: total)
                    }
                } else {
                    let start = startingYear
                    let end = currentYear
                    return (start...end).map { yr in
                        let yTx = baseIncomeTransactions.filter { calendar.component(.year, from: $0.date) == yr }
                        let total = yTx.reduce(0.0) { $0 + incomeAmount(for: $1) }
                        return (label: String(yr), amount: total)
                    }
                }
            }()
            
            let maxVal = max(1.0, chartData.map { $0.amount }.max() ?? 1.0)
            
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(chartData.indices, id: \.self) { idx in
                    let item = chartData[idx]
                    let heightRatio = min(1.0, max(0.05, item.amount / maxVal))
                    
                    VStack(spacing: 4) {
                        if item.amount > 0 {
                            Text(displayInINR ? "₹\(item.amount.formattedCompact)" : item.amount.formattedCompact)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(AppTheme.profit)
                                .lineLimit(1)
                        }
                        
                        GeometryReader { geo in
                            VStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(item.amount > 0 ? AppTheme.profitGradient : LinearGradient(colors: [Color.gray.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                                    .frame(height: max(4, geo.size.height * CGFloat(heightRatio)))
                            }
                        }
                        .frame(height: 90)
                        
                        Text(item.label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 125)
        }
        .modifier(AppTheme.cardStyle())
    }
    
    // MARK: - Monthly List Components
    @ViewBuilder
    private func monthlyCategoryCard(_ catFlow: CategoryIncomeFlow) -> some View {
        VStack(spacing: 0) {
            Button {
                toggleCategory(catFlow.id)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(catFlow.category.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("(\(displayInINR ? "INR ₹" : catFlow.category.currencyCode))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(catFlow.count) Income Payouts")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(displayInINR ? "₹" : "")\(catFlow.totalIncome.formattedComma)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.profit)
                    }
                    
                    Image(systemName: expandedCategories.contains(catFlow.id) ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
                .padding(14)
                .background(Color(.systemGray6))
            }
            .buttonStyle(.plain)
            
            if expandedCategories.contains(catFlow.id) {
                VStack(spacing: 0) {
                    Divider()
                    ForEach(catFlow.assetFlows) { assetFlow in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(assetFlow.name)
                                    .font(.footnote).fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                Text("\(assetFlow.count) Payouts")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            
                            Text("\(displayInINR ? "₹" : "")\(assetFlow.totalIncome.formattedComma)")
                                .font(.caption).fontWeight(.bold)
                                .foregroundStyle(AppTheme.profit)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        Divider()
                    }
                }
                .background(Color(.systemGray6).opacity(0.3))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func monthlyIncomeListView(categories: [CategoryIncomeFlow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category & Asset Breakdown")
                .font(.headline)
                .padding(.horizontal, 20)
            
            ForEach(categories) { catFlow in
                monthlyCategoryCard(catFlow)
            }
        }
    }
    
    // MARK: - Yearly Grid Components
    @ViewBuilder
    private func yearlyLeftColumn(rows: [YearlyIncomeRow]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Category / Asset")
                    .font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(width: leftColumnWidth, height: headerHeight)
            .background(Color(.systemGray5))
            
            Divider()
            
            ForEach(rows) { row in
                HStack {
                    Text(row.name)
                        .font(.caption).fontWeight(.bold).foregroundStyle(AppTheme.accent)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .frame(width: leftColumnWidth, height: categoryRowHeight)
                .background(Color(.systemGray6))
                
                ForEach(row.assetRows) { assetRow in
                    HStack {
                        Text("  \(assetRow.name)")
                            .font(.caption2).foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .frame(width: leftColumnWidth, height: assetRowHeight)
                    .background(Color(.systemBackground))
                }
            }
            
            HStack {
                Text("TOTAL INCOME")
                    .font(.caption2).fontWeight(.black).foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(width: leftColumnWidth, height: categoryRowHeight)
            .background(AppTheme.profit.opacity(0.15))
        }
    }

    @ViewBuilder
    private func yearlyMiddleGrid(rows: [YearlyIncomeRow]) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(months, id: \.self) { month in
                        Text(monthAbbrev(month))
                            .font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
                            .frame(width: scrollCellWidth, height: headerHeight)
                            .background(Color(.systemGray5))
                    }
                    Text("TOTAL")
                        .font(.caption2).fontWeight(.bold).foregroundStyle(AppTheme.profit)
                        .frame(width: scrollCellWidth + 15, height: headerHeight)
                        .background(Color(.systemGray4))
                }
                
                Divider()
                
                ForEach(rows) { row in
                    HStack(spacing: 0) {
                        ForEach(months, id: \.self) { month in
                            let val = row.monthlyIncome[month] ?? 0.0
                            Text(val > 0 ? val.formattedCompact : "-")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(val > 0 ? AppTheme.profit : .secondary.opacity(0.4))
                                .frame(width: scrollCellWidth, height: categoryRowHeight)
                                .background(val > 0 ? AppTheme.profit.opacity(0.1) : Color(.systemGray6))
                        }
                        
                        Text(row.yearTotal.formattedCompact)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.profit)
                            .frame(width: scrollCellWidth + 15, height: categoryRowHeight)
                            .background(AppTheme.profit.opacity(0.18))
                    }
                    
                    ForEach(row.assetRows) { assetRow in
                        HStack(spacing: 0) {
                            ForEach(months, id: \.self) { month in
                                let val = assetRow.monthlyIncome[month] ?? 0.0
                                Text(val > 0 ? val.formattedCompact : "-")
                                    .font(.system(size: 9, weight: val > 0 ? .semibold : .regular))
                                    .foregroundStyle(val > 0 ? Color.primary : Color.secondary.opacity(0.4))
                                    .frame(width: scrollCellWidth, height: assetRowHeight)
                                    .background(val > 0 ? AppTheme.profit.opacity(0.06) : Color(.systemBackground))
                            }
                            
                            Text(assetRow.yearTotal.formattedCompact)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.profit)
                                .frame(width: scrollCellWidth + 15, height: assetRowHeight)
                                .background(AppTheme.profit.opacity(0.1))
                        }
                    }
                }
                
                HStack(spacing: 0) {
                    ForEach(months, id: \.self) { month in
                        let mSum = rows.reduce(0.0) { $0 + ($1.monthlyIncome[month] ?? 0.0) }
                        Text(mSum > 0 ? mSum.formattedCompact : "-")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.profit)
                            .frame(width: scrollCellWidth, height: categoryRowHeight)
                            .background(AppTheme.profit.opacity(0.15))
                    }
                    
                    let yearTotalSum = rows.reduce(0.0) { $0 + $1.yearTotal }
                    Text(yearTotalSum.formattedCompact)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.profit)
                        .frame(width: scrollCellWidth + 15, height: categoryRowHeight)
                        .background(AppTheme.profit.opacity(0.25))
                }
            }
        }
    }

    @ViewBuilder
    private func yearlyIncomeGridView(rows: [YearlyIncomeRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Yearly Income Grid (\(selectedYear))")
                .font(.headline)
                .padding(.horizontal, 20)
            
            HStack(spacing: 0) {
                yearlyLeftColumn(rows: rows)
                Divider()
                yearlyMiddleGrid(rows: rows)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 1))
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Lifetime Grid Components
    @ViewBuilder
    private func lifetimeLeftColumn(rows: [LifetimeIncomeRow]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Category / Asset")
                    .font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(width: leftColumnWidth, height: headerHeight, alignment: .leading)
            .background(Color(.systemGray5))
            
            Divider()
            
            ForEach(rows) { row in
                HStack {
                    Text(row.name)
                        .font(.caption).fontWeight(.bold).foregroundStyle(AppTheme.accent)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .frame(width: leftColumnWidth, height: categoryRowHeight)
                .background(Color(.systemGray6))
                
                ForEach(row.assetRows) { assetRow in
                    HStack {
                        Text("  \(assetRow.name)")
                            .font(.caption2).foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .frame(width: leftColumnWidth, height: assetRowHeight)
                    .background(Color(.systemBackground))
                }
            }
            
            HStack {
                Text("TOTAL LIFETIME")
                    .font(.caption2).fontWeight(.black).foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(width: leftColumnWidth, height: categoryRowHeight)
            .background(AppTheme.profit.opacity(0.15))
        }
    }

    @ViewBuilder
    private func lifetimeMiddleGrid(rows: [LifetimeIncomeRow], yearsRange: [Int]) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(yearsRange, id: \.self) { yr in
                        Text(String(yr))
                            .font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
                            .frame(width: scrollCellWidth, height: headerHeight)
                            .background(Color(.systemGray5))
                    }
                    Text("OVERALL")
                        .font(.caption2).fontWeight(.bold).foregroundStyle(AppTheme.profit)
                        .frame(width: scrollCellWidth + 15, height: headerHeight)
                        .background(Color(.systemGray4))
                }
                
                Divider()
                
                ForEach(rows) { row in
                    HStack(spacing: 0) {
                        ForEach(yearsRange, id: \.self) { yr in
                            let val = row.yearlyIncome[yr] ?? 0.0
                            Text(val > 0 ? val.formattedCompact : "-")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(val > 0 ? AppTheme.profit : Color.secondary.opacity(0.4))
                                .frame(width: scrollCellWidth, height: categoryRowHeight)
                                .background(val > 0 ? AppTheme.profit.opacity(0.1) : Color(.systemGray6))
                        }
                        
                        Text(row.overallTotal.formattedCompact)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.profit)
                            .frame(width: scrollCellWidth + 15, height: categoryRowHeight)
                            .background(AppTheme.profit.opacity(0.18))
                    }
                    
                    ForEach(row.assetRows) { assetRow in
                        HStack(spacing: 0) {
                            ForEach(yearsRange, id: \.self) { yr in
                                let val = assetRow.yearlyIncome[yr] ?? 0.0
                                Text(val > 0 ? val.formattedCompact : "-")
                                    .font(.system(size: 9, weight: val > 0 ? .semibold : .regular))
                                    .foregroundStyle(val > 0 ? Color.primary : Color.secondary.opacity(0.4))
                                    .frame(width: scrollCellWidth, height: assetRowHeight)
                                    .background(val > 0 ? AppTheme.profit.opacity(0.06) : Color(.systemBackground))
                            }
                            
                            Text(assetRow.overallTotal.formattedCompact)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.profit)
                                .frame(width: scrollCellWidth + 15, height: assetRowHeight)
                                .background(AppTheme.profit.opacity(0.1))
                        }
                    }
                }
                
                HStack(spacing: 0) {
                    ForEach(yearsRange, id: \.self) { yr in
                        let ySum = rows.reduce(0.0) { $0 + ($1.yearlyIncome[yr] ?? 0.0) }
                        Text(ySum > 0 ? ySum.formattedCompact : "-")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.profit)
                            .frame(width: scrollCellWidth, height: categoryRowHeight)
                            .background(AppTheme.profit.opacity(0.15))
                    }
                    
                    let overallSum = rows.reduce(0.0) { $0 + $1.overallTotal }
                    Text(overallSum.formattedCompact)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.profit)
                        .frame(width: scrollCellWidth + 15, height: categoryRowHeight)
                        .background(AppTheme.profit.opacity(0.25))
                }
            }
        }
    }

    @ViewBuilder
    private func lifetimeIncomeGridView(rows: [LifetimeIncomeRow]) -> some View {
        let yearsRange = Array(startingYear...currentYear)
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Lifetime Income Grid (\(startingYear) - \(currentYear))")
                .font(.headline)
                .padding(.horizontal, 20)
            
            HStack(spacing: 0) {
                lifetimeLeftColumn(rows: rows)
                Divider()
                lifetimeMiddleGrid(rows: rows, yearsRange: yearsRange)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 1))
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Transaction History List
    @ViewBuilder
    private var incomeTransactionHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Income Transaction Receipts")
                    .font(.headline)
                Spacer()
                Text("\(baseIncomeTransactions.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            let sortedTx = baseIncomeTransactions.sorted(by: { $0.date > $1.date })
            let recentTx = Array(sortedTx.prefix(30))
            
            if recentTx.isEmpty {
                Text("No matching income transactions logged.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 8) {
                    ForEach(recentTx, id: \.persistentModelID) { tx in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(tx.asset?.name ?? "Unknown Asset")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.primary)
                                    
                                    Text(tx.rawType)
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppTheme.profit.opacity(0.15))
                                        .foregroundStyle(AppTheme.profit)
                                        .clipShape(Capsule())
                                }
                                
                                HStack(spacing: 8) {
                                    Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    if let broker = tx.broker {
                                        Text("• \(broker.name)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let notes = tx.notes, !notes.isEmpty {
                                        Text("• \(notes)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                let amt = incomeAmount(for: tx)
                                Text("\(displayInINR ? "₹" : "")\(amt.formattedComma)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(AppTheme.profit)
                                
                                if displayInINR, let cat = tx.asset?.category, cat.currencyCode != "INR" {
                                    Text("\(cat.currencyCode) \(tx.amount.formattedComma)")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.subtleBorder, lineWidth: 1))
                    }
                }
            }
        }
    }
    
    private func toggleCategory(_ id: PersistentIdentifier) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedCategories.contains(id) {
                expandedCategories.remove(id)
            } else {
                expandedCategories.insert(id)
            }
        }
    }
}

// MARK: - Log Income Form Sheet
struct LogIncomeFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let assets: [Asset]
    let brokers: [Broker]
    
    @State private var selectedAsset: Asset?
    @State private var incomeType: String = "DIVIDEND"
    @State private var amountInput: String = ""
    @State private var selectedDate: Date = Date()
    @State private var selectedBroker: Broker?
    @State private var notesInput: String = ""
    
    let incomeTypes = ["DIVIDEND", "INTEREST", "COUPON", "BONUS", "SURVIVAL_BENEFIT"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("ASSET & TYPE") {
                    Picker("Select Asset", selection: $selectedAsset) {
                        Text("Choose an asset...").tag(nil as Asset?)
                        ForEach(assets) { asset in
                            Text("\(asset.name) (\(asset.category?.name ?? "General"))")
                                .tag(asset as Asset?)
                        }
                    }
                    
                    Picker("Income Type", selection: $incomeType) {
                        ForEach(incomeTypes, id: \.self) { type in
                            Text(type.capitalized.replacingOccurrences(of: "_", with: " ")).tag(type)
                        }
                    }
                }
                
                Section("AMOUNT & DATE") {
                    HStack {
                        Text("Payout Amount")
                        Spacer()
                        TextField("0.00", text: $amountInput)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    
                    DatePicker("Date Received", selection: $selectedDate, displayedComponents: .date)
                    
                    if !brokers.isEmpty {
                        Picker("Broker / Account", selection: $selectedBroker) {
                            Text("None").tag(nil as Broker?)
                            ForEach(brokers) { broker in
                                Text(broker.name).tag(broker as Broker?)
                            }
                        }
                    }
                }
                
                Section("NOTES & MEMO") {
                    TextField("e.g. Q3 Dividend Payout or FD Interest", text: $notesInput)
                }
            }
            .navigationTitle("Log Passive Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Income") {
                        saveIncome()
                    }
                    .disabled(selectedAsset == nil || Double(amountInput) == nil || (Double(amountInput) ?? 0) <= 0)
                    .bold()
                }
            }
            .onAppear {
                if selectedAsset == nil {
                    selectedAsset = assets.first
                }
            }
        }
    }
    
    private func saveIncome() {
        guard let asset = selectedAsset, let amount = Double(amountInput), amount > 0 else { return }
        
        let tx = AssetTransaction(
            type: .dividend,
            rawType: incomeType,
            units: 0,
            pricePerUnit: amount,
            date: selectedDate,
            notes: notesInput.isEmpty ? nil : notesInput,
            createdAt: Date(),
            asset: asset,
            broker: selectedBroker
        )
        
        modelContext.insert(tx)
        try? modelContext.save()
        dismiss()
    }
}
