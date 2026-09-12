//
//  PortfolioFlowsView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct PortfolioFlowsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]
    @Query private var transactions: [AssetTransaction]
    @Query(sort: \Currency.code) private var currencies: [Currency]
    
    enum PeriodType: String, CaseIterable, Identifiable {
        case monthly = "Monthly"
        case yearly = "Yearly"
        case lifetime = "Lifetime"
        var id: String { self.rawValue }
    }
    
    @State private var selectedPeriodType: PeriodType = .monthly
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var displayInINR: Bool = true
    
    private func transactionRate(for tx: AssetTransaction) -> Double {
        guard displayInINR else { return 1.0 }
        guard let cat = tx.asset?.category else { return 1.0 }
        if cat.currencyCode == "INR" { return 1.0 }
        if let txRate = tx.inrExchangeRate { return txRate }
        return PortfolioMetrics.currentInrExchangeRate(for: cat, currencies: currencies)
    }
    
    private var startingYear: Int {
        let txYears = transactions
            .filter { $0.asset?.holdingType.isNonUnitized == false }
            .map { Calendar.current.component(.year, from: $0.date) }
        return txYears.min() ?? Calendar.current.component(.year, from: Date())
    }
    
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    
    // Set of category IDs that are expanded
    @State private var expandedCategories: Set<PersistentIdentifier> = []
    
    // Available years based on transactions, fallback to recent years
    var availableYears: [Int] {
        let txYears = transactions
            .filter { $0.asset?.holdingType.isNonUnitized == false }
            .map { Calendar.current.component(.year, from: $0.date) }
        let currentYear = Calendar.current.component(.year, from: Date())
        var uniqueYears = Set(txYears)
        uniqueYears.insert(currentYear)
        return uniqueYears.sorted(by: >)
    }
    
    var months: [Int] {
        Array(1...12)
    }
    
    func monthName(for number: Int) -> String {
        let formatter = DateFormatter()
        return formatter.monthSymbols[number - 1]
    }
    
    // Structure to hold flows & trade count data
    struct FlowItem: Identifiable {
        let id: String
        let name: String
        let invested: Double
        let withdrawn: Double
        let netFlow: Double
        let buyCount: Int
        let sellCount: Int
        let divCount: Int
    }
    
    struct CategoryFlow: Identifiable {
        let id: PersistentIdentifier
        let category: Category
        let invested: Double
        let withdrawn: Double
        let netFlow: Double
        let buyCount: Int
        let sellCount: Int
        let divCount: Int
        let assetFlows: [FlowItem]
    }
    
    struct YearlyFlowRow: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let currencyCode: String
        let monthlyInflows: [Int: Double]
        let monthlyTradeCounts: [Int: (buy: Int, sell: Int)]
        let yearTotal: Double
        let yearBuyCount: Int
        let yearSellCount: Int
        let assetRows: [YearlyAssetFlowRow]
    }
    
    struct YearlyAssetFlowRow: Identifiable {
        let id: String
        let name: String
        let monthlyInflows: [Int: Double]
        let monthlyTradeCounts: [Int: (buy: Int, sell: Int)]
        let yearTotal: Double
        let yearBuyCount: Int
        let yearSellCount: Int
    }
    
    struct LifetimeFlowRow: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let currencyCode: String
        let yearlyNetFlows: [Int: Double]
        let yearlyTradeCounts: [Int: (buy: Int, sell: Int)]
        let overallNetFlow: Double
        let overallBuyCount: Int
        let overallSellCount: Int
        let assetRows: [LifetimeAssetFlowRow]
    }
    
    struct LifetimeAssetFlowRow: Identifiable {
        let id: String
        let name: String
        let yearlyNetFlows: [Int: Double]
        let yearlyTradeCounts: [Int: (buy: Int, sell: Int)]
        let overallNetFlow: Double
        let overallBuyCount: Int
        let overallSellCount: Int
    }
    
    private let headerHeight: CGFloat = 40
    private let categoryRowHeight: CGFloat = 52
    private let assetRowHeight: CGFloat = 44
    private let leftColumnWidth: CGFloat = 110
    private let rightColumnWidth: CGFloat = 85
    private let scrollCellWidth: CGFloat = 65
    
    private func monthAbbrev(_ month: Int) -> String {
        let formatter = DateFormatter()
        return formatter.shortMonthSymbols[month - 1]
    }
    
    private var lifetimeFlowsData: [LifetimeFlowRow] {
        let calendar = Calendar.current
        var rows: [LifetimeFlowRow] = []
        let start = startingYear
        let end = currentYear
        let yearsRange = Array(start...end)
        
        for category in categories {
            var categoryYearlyNet: [Int: Double] = [:]
            var categoryYearlyCounts: [Int: (buy: Int, sell: Int)] = [:]
            var assetRows: [LifetimeAssetFlowRow] = []
            
            let categoryTx = transactions.filter { tx in
                tx.asset?.category?.persistentModelID == category.persistentModelID &&
                tx.asset?.holdingType.isNonUnitized == false
            }
            
            let assetsInCat = Dictionary(grouping: categoryTx.compactMap { $0.asset }, by: { $0.persistentModelID }).values.compactMap { $0.first }
            for asset in assetsInCat.sorted(by: { $0.name < $1.name }) {
                var assetYearlyNet: [Int: Double] = [:]
                var assetYearlyCounts: [Int: (buy: Int, sell: Int)] = [:]
                let assetTx = categoryTx.filter { $0.asset?.persistentModelID == asset.persistentModelID }
                
                var assetTotalBuyCount = 0
                var assetTotalSellCount = 0
                
                for year in yearsRange {
                    let yearTx = assetTx.filter { calendar.component(.year, from: $0.date) == year }
                    var invested = 0.0
                    var withdrawn = 0.0
                    var buyCount = 0
                    var sellCount = 0
                    
                    for tx in yearTx {
                        let amount = tx.units * tx.pricePerUnit * transactionRate(for: tx)
                        if tx.type == TransactionType.buy {
                            invested += amount
                            buyCount += 1
                        } else if tx.type == TransactionType.sell {
                            withdrawn += amount
                            sellCount += 1
                        }
                    }
                    assetYearlyNet[year] = invested - withdrawn
                    assetYearlyCounts[year] = (buyCount, sellCount)
                    assetTotalBuyCount += buyCount
                    assetTotalSellCount += sellCount
                }
                
                let assetOverallNet = assetTx.reduce(0.0) { sum, tx in
                    let amount = tx.units * tx.pricePerUnit * transactionRate(for: tx)
                    if tx.type == .buy { return sum + amount }
                    else if tx.type == .sell { return sum - amount }
                    return sum
                }
                
                if assetOverallNet != 0 || (assetTotalBuyCount + assetTotalSellCount) > 0 {
                    assetRows.append(LifetimeAssetFlowRow(
                        id: "\(asset.persistentModelID)",
                        name: asset.name,
                        yearlyNetFlows: assetYearlyNet,
                        yearlyTradeCounts: assetYearlyCounts,
                        overallNetFlow: assetOverallNet,
                        overallBuyCount: assetTotalBuyCount,
                        overallSellCount: assetTotalSellCount
                    ))
                }
            }
            
            var catTotalBuyCount = 0
            var catTotalSellCount = 0
            
            for year in yearsRange {
                let yearTx = categoryTx.filter { calendar.component(.year, from: $0.date) == year }
                var invested = 0.0
                var withdrawn = 0.0
                var buyCount = 0
                var sellCount = 0
                
                for tx in yearTx {
                    let amount = tx.units * tx.pricePerUnit * transactionRate(for: tx)
                    if tx.type == .buy {
                        invested += amount
                        buyCount += 1
                    } else if tx.type == .sell {
                        withdrawn += amount
                        sellCount += 1
                    }
                }
                categoryYearlyNet[year] = invested - withdrawn
                categoryYearlyCounts[year] = (buyCount, sellCount)
                catTotalBuyCount += buyCount
                catTotalSellCount += sellCount
            }
            
            let categoryOverallNet = categoryTx.reduce(0.0) { sum, tx in
                let amount = tx.units * tx.pricePerUnit * transactionRate(for: tx)
                if tx.type == .buy { return sum + amount }
                else if tx.type == .sell { return sum - amount }
                return sum
            }
            
            if categoryOverallNet != 0 || !assetRows.isEmpty || (catTotalBuyCount + catTotalSellCount) > 0 {
                rows.append(LifetimeFlowRow(
                    id: category.persistentModelID,
                    name: category.name,
                    currencyCode: category.currencyCode,
                    yearlyNetFlows: categoryYearlyNet,
                    yearlyTradeCounts: categoryYearlyCounts,
                    overallNetFlow: categoryOverallNet,
                    overallBuyCount: catTotalBuyCount,
                    overallSellCount: catTotalSellCount,
                    assetRows: assetRows
                ))
            }
        }
        
        return rows
    }
    
    private var yearlyFlowsData: [YearlyFlowRow] {
        let calendar = Calendar.current
        var rows: [YearlyFlowRow] = []
        
        for category in categories {
            var categoryMonthly: [Int: Double] = [:]
            var categoryMonthlyCounts: [Int: (buy: Int, sell: Int)] = [:]
            var assetRows: [YearlyAssetFlowRow] = []
            
            let yearTx = transactions.filter { tx in
                calendar.component(.year, from: tx.date) == selectedYear &&
                tx.asset?.category?.persistentModelID == category.persistentModelID &&
                tx.asset?.holdingType.isNonUnitized == false
            }
            
            let assetsInCat = Dictionary(grouping: yearTx.compactMap { $0.asset }, by: { $0.persistentModelID }).values.compactMap { $0.first }
            for asset in assetsInCat.sorted(by: { $0.name < $1.name }) {
                var assetMonthly: [Int: Double] = [:]
                var assetMonthlyCounts: [Int: (buy: Int, sell: Int)] = [:]
                let assetTx = yearTx.filter { $0.asset?.persistentModelID == asset.persistentModelID }
                
                var assetYearBuy = 0
                var assetYearSell = 0
                
                for month in 1...12 {
                    let monthBuys = assetTx.filter { calendar.component(.month, from: $0.date) == month && $0.type == .buy }
                    let monthSells = assetTx.filter { calendar.component(.month, from: $0.date) == month && $0.type == .sell }
                    
                    let amount = monthBuys.reduce(0.0) { $0 + ($1.units * $1.pricePerUnit * transactionRate(for: $1)) }
                    assetMonthly[month] = amount
                    assetMonthlyCounts[month] = (monthBuys.count, monthSells.count)
                    
                    assetYearBuy += monthBuys.count
                    assetYearSell += monthSells.count
                }
                
                let assetTotal = assetMonthly.values.reduce(0.0, +)
                if assetTotal > 0 || (assetYearBuy + assetYearSell) > 0 {
                    assetRows.append(YearlyAssetFlowRow(
                        id: "\(asset.persistentModelID)",
                        name: asset.name,
                        monthlyInflows: assetMonthly,
                        monthlyTradeCounts: assetMonthlyCounts,
                        yearTotal: assetTotal,
                        yearBuyCount: assetYearBuy,
                        yearSellCount: assetYearSell
                    ))
                }
            }
            
            var catYearBuy = 0
            var catYearSell = 0
            
            for month in 1...12 {
                let monthBuys = yearTx.filter { calendar.component(.month, from: $0.date) == month && $0.type == .buy }
                let monthSells = yearTx.filter { calendar.component(.month, from: $0.date) == month && $0.type == .sell }
                
                let amount = monthBuys.reduce(0.0) { $0 + ($1.units * $1.pricePerUnit * transactionRate(for: $1)) }
                categoryMonthly[month] = amount
                categoryMonthlyCounts[month] = (monthBuys.count, monthSells.count)
                
                catYearBuy += monthBuys.count
                catYearSell += monthSells.count
            }
            
            let categoryTotal = categoryMonthly.values.reduce(0.0, +)
            if categoryTotal > 0 || !assetRows.isEmpty || (catYearBuy + catYearSell) > 0 {
                rows.append(YearlyFlowRow(
                    id: category.persistentModelID,
                    name: category.name,
                    currencyCode: category.currencyCode,
                    monthlyInflows: categoryMonthly,
                    monthlyTradeCounts: categoryMonthlyCounts,
                    yearTotal: categoryTotal,
                    yearBuyCount: catYearBuy,
                    yearSellCount: catYearSell,
                    assetRows: assetRows
                ))
            }
        }
        
        return rows
    }
    
    // Computed flows & trade counts based on selections
    private var flowsData: (categories: [CategoryFlow], totalInvested: Double, totalWithdrawn: Double, totalNetFlow: Double, totalBuyCount: Int, totalSellCount: Int, totalDivCount: Int) {
        var categoryFlows: [CategoryFlow] = []
        var totalInvested = 0.0
        var totalWithdrawn = 0.0
        var totalBuyCount = 0
        var totalSellCount = 0
        var totalDivCount = 0
        
        let calendar = Calendar.current
        
        // Filter transactions for chosen period
        let filteredTransactions = transactions.filter { tx in
            if tx.asset?.holdingType.isNonUnitized == true {
                return false
            }
            if selectedPeriodType == .lifetime {
                return true
            }
            let year = calendar.component(.year, from: tx.date)
            if selectedPeriodType == .yearly {
                return year == selectedYear
            } else {
                let month = calendar.component(.month, from: tx.date)
                return year == selectedYear && month == selectedMonth
            }
        }
        
        for category in categories {
            var categoryInvested = 0.0
            var categoryWithdrawn = 0.0
            var categoryBuy = 0
            var categorySell = 0
            var categoryDiv = 0
            var assetFlows: [FlowItem] = []
            
            let categoryTx = filteredTransactions.filter { $0.asset?.category?.persistentModelID == category.persistentModelID }
            let assetsInCat = Dictionary(grouping: categoryTx.compactMap { $0.asset }, by: { $0.persistentModelID }).values.compactMap { $0.first }
            
            for asset in assetsInCat.sorted(by: { $0.name < $1.name }) {
                let assetTx = categoryTx.filter { $0.asset?.persistentModelID == asset.persistentModelID }
                
                var assetInvested = 0.0
                var assetWithdrawn = 0.0
                var assetBuy = 0
                var assetSell = 0
                var assetDiv = 0
                
                for tx in assetTx {
                    let amount = tx.units * tx.pricePerUnit * transactionRate(for: tx)
                    switch tx.type {
                    case .buy:
                        assetInvested += amount
                        assetBuy += 1
                    case .sell:
                        assetWithdrawn += amount
                        assetSell += 1
                    case .dividend:
                        assetDiv += 1
                    }
                }
                
                if assetInvested > 0 || assetWithdrawn > 0 || (assetBuy + assetSell) > 0 {
                    assetFlows.append(FlowItem(
                        id: "\(asset.persistentModelID)",
                        name: asset.name,
                        invested: assetInvested,
                        withdrawn: assetWithdrawn,
                        netFlow: assetInvested - assetWithdrawn,
                        buyCount: assetBuy,
                        sellCount: assetSell,
                        divCount: assetDiv
                    ))
                }
            }
            
            for tx in categoryTx {
                let amount = tx.units * tx.pricePerUnit * transactionRate(for: tx)
                switch tx.type {
                case .buy:
                    categoryInvested += amount
                    categoryBuy += 1
                case .sell:
                    categoryWithdrawn += amount
                    categorySell += 1
                case .dividend:
                    categoryDiv += 1
                }
            }
            
            if categoryInvested > 0 || categoryWithdrawn > 0 || !assetFlows.isEmpty || (categoryBuy + categorySell) > 0 {
                categoryFlows.append(CategoryFlow(
                    id: category.persistentModelID,
                    category: category,
                    invested: categoryInvested,
                    withdrawn: categoryWithdrawn,
                    netFlow: categoryInvested - categoryWithdrawn,
                    buyCount: categoryBuy,
                    sellCount: categorySell,
                    divCount: categoryDiv,
                    assetFlows: assetFlows
                ))
                
                totalInvested += categoryInvested
                totalWithdrawn += categoryWithdrawn
                totalBuyCount += categoryBuy
                totalSellCount += categorySell
                totalDivCount += categoryDiv
            }
        }
        
        return (categoryFlows, totalInvested, totalWithdrawn, totalInvested - totalWithdrawn, totalBuyCount, totalSellCount, totalDivCount)
    }
    
    @State private var showCopiedToast: Bool = false
    
    private func generateLLMPromptText() -> String {
        let periodName: String = {
            switch selectedPeriodType {
            case .monthly: return "\(monthName(for: selectedMonth)) \(selectedYear)"
            case .yearly: return "Year \(selectedYear)"
            case .lifetime: return "Lifetime (\(startingYear) - \(currentYear))"
            }
        }()
        
        let currencySymbol = displayInINR ? "₹" : ""
        let data = flowsData
        
        var prompt = """
        # Portfolio Investment Inflows & Cash Flow Analysis Request
        
        **Period**: \(periodName)
        **Display Currency**: \(displayInINR ? "INR (₹)" : "Native Asset Currency")
        
        ## 1. Summary Overview
        - **Total Capital Invested**: \(currencySymbol)\(data.totalInvested.formattedComma)
        - **Total Capital Withdrawn**: \(currencySymbol)\(data.totalWithdrawn.formattedComma)
        - **Net Cash Flow**: \(currencySymbol)\(data.totalNetFlow.formattedComma)
        - **Total Trade Activity**: \(data.totalBuyCount) BUYs, \(data.totalSellCount) SELLs, \(data.totalDivCount) Dividend Entries
        
        ## 2. Category & Asset Inflow Breakdown
        """
        
        if selectedPeriodType == .monthly {
            for catFlow in data.categories {
                prompt += "\n\n### Category: \(catFlow.category.name)"
                prompt += "\n- Net Category Inflow: \(currencySymbol)\(catFlow.netFlow.formattedComma) (\(catFlow.buyCount) B, \(catFlow.sellCount) S, \(catFlow.divCount) D)"
                for assetFlow in catFlow.assetFlows {
                    prompt += "\n  • \(assetFlow.name): Net \(currencySymbol)\(assetFlow.netFlow.formattedComma) (Invested \(currencySymbol)\(assetFlow.invested.formattedComma), Withdrawn \(currencySymbol)\(assetFlow.withdrawn.formattedComma)) [\(assetFlow.buyCount)B / \(assetFlow.sellCount)S]"
                }
            }
        } else if selectedPeriodType == .yearly {
            let yearlyRows = yearlyFlowsData
            for row in yearlyRows {
                prompt += "\n\n### Category: \(row.name)"
                prompt += "\n- Annual Total Net Flow: \(currencySymbol)\(row.yearTotal.formattedComma) (\(row.yearBuyCount) B, \(row.yearSellCount) S)"
                for aRow in row.assetRows {
                    prompt += "\n  • \(aRow.name): Net \(currencySymbol)\(aRow.yearTotal.formattedComma) [\(aRow.yearBuyCount)B / \(aRow.yearSellCount)S]"
                }
            }
        } else {
            let lifetimeRows = lifetimeFlowsData
            for row in lifetimeRows {
                prompt += "\n\n### Category: \(row.name)"
                prompt += "\n- Lifetime Net Capital Deployed: \(currencySymbol)\(row.overallNetFlow.formattedComma) (\(row.overallBuyCount) B, \(row.overallSellCount) S)"
                for aRow in row.assetRows {
                    prompt += "\n  • \(aRow.name): Net \(currencySymbol)\(aRow.overallNetFlow.formattedComma) [\(aRow.overallBuyCount)B / \(aRow.overallSellCount)S]"
                }
            }
        }
        
        prompt += """
        
        ---
        ## 3. Request for AI Portfolio Feedback
        Based on the cash flow and investment inflow data above:
        1. **Dollar Cost Averaging & Capital Deployment Discipline**: Evaluate if my capital deployment pacing and DCA consistency are effective.
        2. **Category & Asset Concentration**: Identify any potential over-concentration risks or erratic buying/selling behavior.
        3. **3 Actionable Portfolio Recommendations**: Provide 3 high-value, actionable feedback points to optimize future capital allocation.
        """
        
        return prompt
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                    // Period Selector Card
                    VStack(spacing: 12) {
                        HStack {
                            Text("CURRENCY DISPLAY")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        
                        Picker("Currency Display", selection: $displayInINR) {
                            Text("INR (₹) Default").tag(true)
                            Text("Native Currency").tag(false)
                        }
                        .pickerStyle(.segmented)
                        
                        Divider()
                        
                        Picker("Period Type", selection: $selectedPeriodType) {
                            ForEach(PeriodType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        if selectedPeriodType != .lifetime {
                            HStack(spacing: 12) {
                                // Year Selector
                                Menu {
                                    Picker("Year", selection: $selectedYear) {
                                        ForEach(availableYears, id: \.self) { year in
                                            Text(String(year)).tag(year)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text("Year: \(String(selectedYear))")
                                            .font(.system(size: 13, weight: .semibold))
                                        Image(systemName: "chevron.down")
                                            .font(.caption2)
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(AppTheme.accent)
                                    .clipShape(Capsule())
                                }
                                
                                // Month Selector (if monthly)
                                if selectedPeriodType == .monthly {
                                    Menu {
                                        Picker("Month", selection: $selectedMonth) {
                                            ForEach(months, id: \.self) { month in
                                                Text(monthName(for: month)).tag(month)
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(monthName(for: selectedMonth))
                                                .font(.system(size: 13, weight: .semibold))
                                            Image(systemName: "chevron.down")
                                                .font(.caption2)
                                        }
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(AppTheme.accentSecondary)
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .modifier(AppTheme.cardStyle())
                    .padding(.horizontal, 20)
                    
                    let data = flowsData
                    let currencyPrefix = displayInINR ? "₹" : ""
                    
                    // Comprehensive Combined Summary Card (Amounts + Trade Activity)
                    VStack(spacing: 14) {
                        HStack {
                            Text(selectedPeriodType == .monthly
                                 ? "Summary & Activity for \(monthName(for: selectedMonth)) \(selectedYear)"
                                 : (selectedPeriodType == .yearly
                                    ? "Summary & Activity for \(selectedYear)"
                                    : "Lifetime Summary (\(startingYear) - \(currentYear))"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                let promptText = generateLLMPromptText()
                                UIPasteboard.general.string = promptText
                                withAnimation {
                                    showCopiedToast = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                    withAnimation {
                                        showCopiedToast = false
                                    }
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.doc.fill")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("Copy LLM Prompt")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(AppTheme.accent)
                                .clipShape(Capsule())
                            }
                        }
                    
                    // Cash Flow Amounts Row
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Invested")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(currencyPrefix)\(data.totalInvested.formattedComma)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Total Withdrawn")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(currencyPrefix)\(data.totalWithdrawn.formattedComma)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    HStack {
                        Text("Net Portfolio Flow")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        GainLossBadge(value: data.totalNetFlow, percentage: nil, isCompact: false)
                    }
                    
                    Divider()
                    
                    // Trade Activity & Hold Discipline Row
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Trade Transactions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(data.totalBuyCount) BUY · \(data.totalSellCount) SELL · \(data.totalDivCount) DIV")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Hold Discipline")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            let totalTrades = data.totalBuyCount + data.totalSellCount
                            let buyPct = totalTrades > 0 ? (Double(data.totalBuyCount) / Double(totalTrades)) * 100.0 : 100.0
                            Text(data.totalSellCount == 0
                                 ? "100% BUY (0 Sales)"
                                 : "\(buyPct.formatted2)% BUY (\(data.totalSellCount) Sales)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(buyPct >= 70 ? AppTheme.profit : AppTheme.warning)
                        }
                    }
                }
                .modifier(AppTheme.cardStyle())
                .padding(.horizontal, 20)


                
                // Flows & Trade Activity Breakdown

                if selectedPeriodType == .yearly {
                    let yearlyRows = yearlyFlowsData
                    if yearlyRows.isEmpty {
                        ContentUnavailableView(
                            "No Activity",
                            systemImage: "arrow.up.arrow.down.circle",
                            description: Text("No transactions logged in \(String(selectedYear)).")
                        )
                        .padding(.vertical, 40)
                    } else {
                        yearlyInflowGridView(rows: yearlyRows)
                    }
                } else if selectedPeriodType == .lifetime {
                    let lifetimeRows = lifetimeFlowsData
                    if lifetimeRows.isEmpty {
                        ContentUnavailableView(
                            "No Lifetime Activity",
                            systemImage: "arrow.up.arrow.down.circle",
                            description: Text("No lifetime transactions logged.")
                        )
                        .padding(.vertical, 40)
                    } else {
                        lifetimeInflowGridView(rows: lifetimeRows)
                    }
                } else {
                    if data.categories.isEmpty {
                        ContentUnavailableView(
                            "No Activity",
                            systemImage: "arrow.up.arrow.down.circle",
                            description: Text("No investments, withdrawals, or trades logged in this period.")
                        )
                        .padding(.vertical, 40)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Breakdown by Category & Asset")
                                .font(.headline)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            ForEach(data.categories) { catFlow in
                                VStack(spacing: 0) {
                                    // Category Header Table Row
                                    Button {
                                        toggleCategory(catFlow.id)
                                    } label: {
                                        VStack(spacing: 8) {
                                            HStack {
                                                Text(catFlow.category.name)
                                                    .font(.headline)
                                                    .foregroundStyle(.primary)
                                                Text("(\(displayInINR ? "INR ₹" : catFlow.category.currencyCode))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Spacer()
                                                
                                                // Trade count badge on category row
                                                Text("\(catFlow.buyCount)B / \(catFlow.sellCount)S")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(catFlow.sellCount == 0 ? AppTheme.profit.opacity(0.12) : Color.orange.opacity(0.12))
                                                    .foregroundStyle(catFlow.sellCount == 0 ? AppTheme.profit : Color.orange)
                                                    .clipShape(Capsule())
                                                
                                                Image(systemName: expandedCategories.contains(catFlow.id) ? "chevron.up" : "chevron.down")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            
                                            // 3-Column Amount & Trade Table
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("Invested")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                    Text(catFlow.invested.formattedComma)
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(.primary)
                                                    Text("\(catFlow.buyCount) Buy Txs")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundStyle(AppTheme.profit)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                
                                                VStack(alignment: .center, spacing: 2) {
                                                    Text("Withdrawn")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                    Text(catFlow.withdrawn.formattedComma)
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(.primary)
                                                    Text("\(catFlow.sellCount) Sell Txs")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundStyle(catFlow.sellCount == 0 ? .secondary : AppTheme.loss)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .center)
                                                
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text("Net Flow")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                    Text(abs(catFlow.netFlow).formattedComma)
                                                        .font(.subheadline)
                                                        .fontWeight(.bold)
                                                        .foregroundStyle(catFlow.netFlow == 0 ? .primary : (catFlow.netFlow > 0 ? AppTheme.profit : AppTheme.loss))
                                                    Text("\(catFlow.divCount) Div Txs")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundStyle(AppTheme.warning)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                            }
                                        }
                                        .padding(16)
                                        .background(Color(.systemGray6))
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Collapsible Asset Table
                                    if expandedCategories.contains(catFlow.id) {
                                        VStack(spacing: 0) {
                                            Divider()
                                            
                                            HStack {
                                                Text("Asset Name")
                                                    .font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                Text("Invested (Buys)")
                                                    .font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
                                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                                Text("Withdrawn (Sells)")
                                                    .font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
                                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                                Text("Net Flow")
                                                    .font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
                                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                            }
                                            .padding(.horizontal, 16).padding(.vertical, 8)
                                            .background(Color(.systemGray6).opacity(0.5))
                                            
                                            ForEach(catFlow.assetFlows) { assetFlow in
                                                Divider()
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(assetFlow.name)
                                                            .font(.footnote).fontWeight(.semibold).foregroundStyle(.primary)
                                                            .lineLimit(1)
                                                    }
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    
                                                    VStack(alignment: .trailing, spacing: 2) {
                                                        Text(assetFlow.invested > 0 ? assetFlow.invested.formattedComma : "-")
                                                            .font(.caption).foregroundStyle(.secondary)
                                                        Text("\(assetFlow.buyCount)B")
                                                            .font(.system(size: 9, weight: .bold)).foregroundStyle(AppTheme.profit)
                                                    }
                                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                                    
                                                    VStack(alignment: .trailing, spacing: 2) {
                                                        Text(assetFlow.withdrawn > 0 ? assetFlow.withdrawn.formattedComma : "-")
                                                            .font(.caption).foregroundStyle(.secondary)
                                                        Text("\(assetFlow.sellCount)S")
                                                            .font(.system(size: 9, weight: .bold)).foregroundStyle(assetFlow.sellCount == 0 ? .secondary : AppTheme.loss)
                                                    }
                                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                                    
                                                    VStack(alignment: .trailing, spacing: 2) {
                                                        Text(abs(assetFlow.netFlow).formattedComma)
                                                            .font(.caption).fontWeight(.bold)
                                                            .foregroundStyle(assetFlow.netFlow == 0 ? .secondary : (assetFlow.netFlow > 0 ? AppTheme.profit : AppTheme.loss))
                                                    }
                                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                                }
                                                .padding(.horizontal, 16).padding(.vertical, 10)
                                            }
                                        }
                                        .background(Color(.systemGray6).opacity(0.3))
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(.systemGray5), lineWidth: 1)
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Copied LLM Prompt to Clipboard!")
                        .font(.system(size: 13, weight: .bold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationTitle("Flows & Trade Activity")
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
    
    // MARK: - Yearly Grid Components
    @ViewBuilder
    private func yearlyLeftColumn(rows: [YearlyFlowRow]) -> some View {
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
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
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
                }
            }
        }
    }

    @ViewBuilder
    private func yearlyMiddleGrid(rows: [YearlyFlowRow]) -> some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(months, id: \.self) { month in
                        Text(monthAbbrev(month))
                            .font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
                            .frame(width: scrollCellWidth, height: headerHeight)
                            .background(Color(.systemGray5))
                    }
                }
                
                Divider()
                
                ForEach(rows) { row in
                    HStack(spacing: 0) {
                        ForEach(months, id: \.self) { month in
                            let val = row.monthlyInflows[month] ?? 0.0
                            let counts = row.monthlyTradeCounts[month] ?? (0, 0)
                            
                            VStack(spacing: 1) {
                                Text(val > 0 ? val.formattedCompact : "-")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(val > 0 ? Color.primary : Color.gray)
                                
                                if counts.buy > 0 || counts.sell > 0 {
                                    Text("\(counts.buy)B/\(counts.sell)S")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundStyle(counts.sell == 0 ? AppTheme.profit : AppTheme.loss)
                                }
                            }
                            .frame(width: scrollCellWidth, height: categoryRowHeight)
                            .background(Color(.systemGray6))
                        }
                    }
                    
                    ForEach(row.assetRows) { assetRow in
                        HStack(spacing: 0) {
                            ForEach(months, id: \.self) { month in
                                let val = assetRow.monthlyInflows[month] ?? 0.0
                                let counts = assetRow.monthlyTradeCounts[month] ?? (0, 0)
                                
                                VStack(spacing: 1) {
                                    Text(val > 0 ? val.formattedCompact : "-")
                                        .font(.system(size: 10))
                                        .foregroundStyle(val > 0 ? Color.primary : Color.gray)
                                    
                                    if counts.buy > 0 || counts.sell > 0 {
                                        Text("\(counts.buy)B/\(counts.sell)S")
                                            .font(.system(size: 8, weight: .semibold))
                                            .foregroundStyle(counts.sell == 0 ? AppTheme.profit : AppTheme.loss)
                                    }
                                }
                                .frame(width: scrollCellWidth, height: assetRowHeight)
                                .background(Color(.systemBackground))
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func yearlyRightColumn(rows: [YearlyFlowRow]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Year Total")
                    .font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
                Spacer()
            }
            .frame(width: rightColumnWidth, height: headerHeight)
            .background(Color(.systemGray5))
            
            Divider()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        VStack(spacing: 1) {
                            Text(row.yearTotal.formattedCompact)
                                .font(.caption).fontWeight(.bold).foregroundStyle(AppTheme.accent)
                            Text("\(row.yearBuyCount)B/\(row.yearSellCount)S")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(row.yearSellCount == 0 ? AppTheme.profit : Color.orange)
                        }
                        .frame(width: rightColumnWidth, height: categoryRowHeight)
                        .background(Color(.systemGray6))
                        
                        ForEach(row.assetRows) { assetRow in
                            VStack(spacing: 1) {
                                Text(assetRow.yearTotal.formattedCompact)
                                    .font(.caption).fontWeight(.semibold).foregroundStyle(.primary)
                                Text("\(assetRow.yearBuyCount)B/\(assetRow.yearSellCount)S")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(assetRow.yearSellCount == 0 ? AppTheme.profit : Color.orange)
                            }
                            .frame(width: rightColumnWidth, height: assetRowHeight)
                            .background(Color(.systemBackground))
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func yearlyInflowGridView(rows: [YearlyFlowRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Breakdown by Category & Asset (Inflows & Trades)")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)
            
            HStack(spacing: 0) {
                yearlyLeftColumn(rows: rows)
                Divider()
                yearlyMiddleGrid(rows: rows)
                Divider()
                yearlyRightColumn(rows: rows)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray4), lineWidth: 1))
            .padding(.horizontal)
        }
    }

    // MARK: - Lifetime Grid Components
    @ViewBuilder
    private func lifetimeLeftColumn(rows: [LifetimeFlowRow]) -> some View {
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
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
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
                }
            }
        }
    }

    @ViewBuilder
    private func lifetimeMiddleGrid(rows: [LifetimeFlowRow], yearsRange: [Int]) -> some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(yearsRange, id: \.self) { year in
                        Text(String(year))
                            .font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
                            .frame(width: scrollCellWidth, height: headerHeight)
                            .background(Color(.systemGray5))
                    }
                }
                
                Divider()
                
                ForEach(rows) { row in
                    HStack(spacing: 0) {
                        ForEach(yearsRange, id: \.self) { year in
                            let val = row.yearlyNetFlows[year] ?? 0.0
                            let counts = row.yearlyTradeCounts[year] ?? (0, 0)
                            
                            VStack(spacing: 1) {
                                Text(val != 0 ? val.formattedCompact : "-")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(val == 0 ? Color.gray : (val > 0 ? AppTheme.profit : AppTheme.loss))
                                
                                if counts.buy > 0 || counts.sell > 0 {
                                    Text("\(counts.buy)B/\(counts.sell)S")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundStyle(counts.sell == 0 ? AppTheme.profit : AppTheme.loss)
                                }
                            }
                            .frame(width: scrollCellWidth, height: categoryRowHeight)
                            .background(Color(.systemGray6))
                        }
                    }
                    
                    ForEach(row.assetRows) { assetRow in
                        HStack(spacing: 0) {
                            ForEach(yearsRange, id: \.self) { year in
                                let val = assetRow.yearlyNetFlows[year] ?? 0.0
                                let counts = assetRow.yearlyTradeCounts[year] ?? (0, 0)
                                
                                VStack(spacing: 1) {
                                    Text(val != 0 ? val.formattedCompact : "-")
                                        .font(.system(size: 10))
                                        .foregroundStyle(val == 0 ? Color.gray : (val > 0 ? AppTheme.profit : AppTheme.loss))
                                    
                                    if counts.buy > 0 || counts.sell > 0 {
                                        Text("\(counts.buy)B/\(counts.sell)S")
                                            .font(.system(size: 8, weight: .semibold))
                                            .foregroundStyle(counts.sell == 0 ? AppTheme.profit : AppTheme.loss)
                                    }
                                }
                                .frame(width: scrollCellWidth, height: assetRowHeight)
                                .background(Color(.systemBackground))
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func lifetimeRightColumn(rows: [LifetimeFlowRow]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Overall Net")
                    .font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
                Spacer()
            }
            .frame(width: rightColumnWidth, height: headerHeight)
            .background(Color(.systemGray5))
            
            Divider()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        VStack(spacing: 1) {
                            Text(row.overallNetFlow.formattedCompact)
                                .font(.caption).fontWeight(.bold)
                                .foregroundStyle(row.overallNetFlow >= 0 ? AppTheme.profit : AppTheme.loss)
                            Text("\(row.overallBuyCount)B/\(row.overallSellCount)S")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(row.overallSellCount == 0 ? AppTheme.profit : Color.orange)
                        }
                        .frame(width: rightColumnWidth, height: categoryRowHeight)
                        .background(Color(.systemGray6))
                        
                        ForEach(row.assetRows) { assetRow in
                            VStack(spacing: 1) {
                                Text(assetRow.overallNetFlow.formattedCompact)
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundStyle(assetRow.overallNetFlow >= 0 ? AppTheme.profit : AppTheme.loss)
                                Text("\(assetRow.overallBuyCount)B/\(assetRow.overallSellCount)S")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(assetRow.overallSellCount == 0 ? AppTheme.profit : Color.orange)
                            }
                            .frame(width: rightColumnWidth, height: assetRowHeight)
                            .background(Color(.systemBackground))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func lifetimeInflowGridView(rows: [LifetimeFlowRow]) -> some View {
        let start = startingYear
        let end = currentYear
        let yearsRange = Array(start...end)
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Lifetime Net Flows & Trade Activity (Decade View)")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)
            
            HStack(spacing: 0) {
                lifetimeLeftColumn(rows: rows)
                Divider()
                lifetimeMiddleGrid(rows: rows, yearsRange: yearsRange)
                Divider()
                lifetimeRightColumn(rows: rows)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray4), lineWidth: 1))
            .padding(.horizontal)
        }
    }
}
