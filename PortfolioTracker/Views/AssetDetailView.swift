//
//  AssetDetailView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct AssetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let asset: Asset
    @Query(sort: \Currency.code) private var currencies: [Currency]
    @State private var displayInINR = true
    
    @State private var showUpdatePriceAlert = false
    @State private var priceInput = ""
    @State private var showAddTransaction = false
    @State private var showAddNote = false
    @State private var showAddReminder = false
    @State private var transactionToEdit: AssetTransaction?
    @State private var noteToEdit: AssetNote?
    @State private var reminderToEdit: AssetReminder?
    @State private var showDeleteConfirmation = false
    @State private var showTaxOverrideSheet = false
    
    enum AccountingMethod: String, CaseIterable, Identifiable {
        case lifo = "LIFO"
        case fifo = "FIFO"
        var id: String { self.rawValue }
    }
    @State private var holdingsMethod: AccountingMethod = .lifo
    @State private var showValueAnalysisForm = false
    @State private var showValueAnalysisDetail = false
    @State private var showDCFAnalysisForm = false
    
    @State private var holdingsPage = 1
    @State private var transactionsPage = 1
    private let itemsPerPage = 10
    
    enum ViewTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case inflows = "Inflows"
        var id: String { self.rawValue }
    }
    
    enum InflowPeriodType: String, CaseIterable, Identifiable {
        case monthly = "Monthly"
        case yearly = "Yearly"
        case lifetime = "Lifetime"
        var id: String { self.rawValue }
    }
    
    @State private var selectedViewTab: ViewTab = .overview
    @State private var selectedInflowPeriod: InflowPeriodType = .monthly
    @State private var selectedInflowYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedInflowMonth: Int = Calendar.current.component(.month, from: Date())
    
    private var availableInflowYears: [Int] {
        let txYears = asset.transactions.map { Calendar.current.component(.year, from: $0.date) }
        let currentYear = Calendar.current.component(.year, from: Date())
        var uniqueYears = Set(txYears)
        uniqueYears.insert(currentYear)
        return uniqueYears.sorted(by: >)
    }
    
    private var months: [Int] {
        Array(1...12)
    }
    
    private func monthName(for number: Int) -> String {
        let formatter = DateFormatter()
        return formatter.monthSymbols[number - 1]
    }
    
    private func monthAbbrev(_ month: Int) -> String {
        let formatter = DateFormatter()
        return formatter.shortMonthSymbols[month - 1]
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
        isConversionActive ? "₹" : (asset.category?.currencyCode == "USD" ? "$" : "")
    }
    
    struct HoldingLotDisplayItem: Identifiable {
        let id: UUID
        let originalUnits: Double
        let remainingUnits: Double
        let buyPrice: Double
        let date: Date
    }
    
    private var displayHoldings: [HoldingLotDisplayItem] {
        if holdingsMethod == .lifo {
            if isConversionActive {
                let res = LifoCalculator.calculateInINR(transactions: asset.transactions, categoryExchangeRate: currentRate)
                return res.holdings.map { HoldingLotDisplayItem(id: $0.id, originalUnits: $0.originalUnits, remainingUnits: $0.remainingUnits, buyPrice: $0.buyPriceINR, date: $0.date) }
            } else {
                let res = LifoCalculator.calculate(transactions: asset.transactions)
                return res.holdings.map { HoldingLotDisplayItem(id: $0.id, originalUnits: $0.originalUnits, remainingUnits: $0.remainingUnits, buyPrice: $0.buyPrice, date: $0.date) }
            }
        } else {
            if isConversionActive {
                let res = FifoCalculator.calculateInINR(transactions: asset.transactions, categoryExchangeRate: currentRate)
                return res.holdings.map { HoldingLotDisplayItem(id: $0.id, originalUnits: $0.originalUnits, remainingUnits: $0.remainingUnits, buyPrice: $0.buyPriceINR, date: $0.date) }
            } else {
                let res = FifoCalculator.calculate(transactions: asset.transactions)
                return res.holdings.map { HoldingLotDisplayItem(id: $0.id, originalUnits: $0.originalUnits, remainingUnits: $0.remainingUnits, buyPrice: $0.buyPrice, date: $0.date) }
            }
        }
    }
    
    private var periodInflowsSummary: (invested: Double, withdrawn: Double, netFlow: Double) {
        let calendar = Calendar.current
        let filtered = asset.transactions.filter { tx in
            let year = calendar.component(.year, from: tx.date)
            if selectedInflowPeriod == .lifetime {
                return true
            } else if selectedInflowPeriod == .yearly {
                return year == selectedInflowYear
            } else {
                let month = calendar.component(.month, from: tx.date)
                return year == selectedInflowYear && month == selectedInflowMonth
            }
        }
        
        var invested = 0.0
        var withdrawn = 0.0
        for tx in filtered {
            let txRate = isConversionActive ? (tx.inrExchangeRate ?? currentRate) : 1.0
            let amount = tx.units * tx.pricePerUnit * txRate
            if tx.type == .buy {
                invested += amount
            } else if tx.type == .sell {
                withdrawn += amount
            }
        }
        return (invested, withdrawn, invested - withdrawn)
    }
    
    private var yearlyGridData: [Int: Double] {
        let calendar = Calendar.current
        var monthly: [Int: Double] = [:]
        let yearTx = asset.transactions.filter { calendar.component(.year, from: $0.date) == selectedInflowYear }
        
        for month in 1...12 {
            let monthTx = yearTx.filter { calendar.component(.month, from: $0.date) == month && $0.type == .buy }
            let amount = monthTx.reduce(0.0) { sum, tx in
                let txRate = isConversionActive ? (tx.inrExchangeRate ?? currentRate) : 1.0
                return sum + (tx.units * tx.pricePerUnit * txRate)
            }
            monthly[month] = amount
        }
        return monthly
    }
    
    private var yearlyGridTotal: Double {
        yearlyGridData.values.reduce(0.0, +)
    }
    
    private var startingInflowYear: Int {
        let txYears = asset.transactions.map { Calendar.current.component(.year, from: $0.date) }
        return txYears.min() ?? Calendar.current.component(.year, from: Date())
    }
    
    private var lifetimeGridData: [Int: Double] {
        let calendar = Calendar.current
        var yearly: [Int: Double] = [:]
        let start = startingInflowYear
        let end = Calendar.current.component(.year, from: Date())
        let yearsRange = Array(start...end)
        
        for year in yearsRange {
            let yearTx = asset.transactions.filter { calendar.component(.year, from: $0.date) == year }
            var invested = 0.0
            var withdrawn = 0.0
            for tx in yearTx {
                let txRate = isConversionActive ? (tx.inrExchangeRate ?? currentRate) : 1.0
                let amount = tx.units * tx.pricePerUnit * txRate
                if tx.type == .buy {
                    invested += amount
                } else if tx.type == .sell {
                    withdrawn += amount
                }
            }
            yearly[year] = invested - withdrawn
        }
        return yearly
    }
    
    private var lifetimeGridTotal: Double {
        asset.transactions.reduce(0.0) { sum, tx in
            let txRate = isConversionActive ? (tx.inrExchangeRate ?? currentRate) : 1.0
            let amount = tx.units * tx.pricePerUnit * txRate
            if tx.type == .buy {
                return sum + amount
            } else if tx.type == .sell {
                return sum - amount
            }
            return sum
        }
    }
    
    private var lifoResult: LifoResult {
        LifoCalculator.calculate(transactions: asset.transactions)
    }
    
    private var totalUnits: Double {
        PortfolioMetrics.totalUnits(for: asset)
    }
    
    private var totalInvested: Double {
        PortfolioMetrics.investedValue(for: asset)
    }
    
    private var lifetimeInvested: Double {
        PortfolioMetrics.lifetimeInvested(for: asset)
    }
    
    private var lifetimeRetrieved: Double {
        PortfolioMetrics.lifetimeRetrieved(for: asset)
    }
    
    private var averageBuyPrice: Double {
        totalUnits > 0 ? totalInvested / totalUnits : 0.0
    }
    
    private var currentValue: Double {
        PortfolioMetrics.currentValue(for: asset)
    }
    
    private var unrealizedGainLoss: Double {
        PortfolioMetrics.unrealizedGainLoss(for: asset)
    }
    
    private var xirr: Double? {
        PortfolioMetrics.xirr(for: asset)
    }
    
    private var holdingDurationText: String {
        PortfolioMetrics.holdingDurationText(for: asset)
    }
    
    private var sortedTransactions: [AssetTransaction] {
        Array(PortfolioMetrics.reverseOrderedTransactions(asset.transactions))
    }
    
    private var realizedSellProfitByTransaction: [PersistentIdentifier: Double] {
        LifoCalculator.realizedProfitLossBySellTransaction(transactions: asset.transactions)
    }
    
    private var sortedNotes: [AssetNote] {
        asset.notes.sorted {
            if $0.date == $1.date {
                return $0.createdAt > $1.createdAt
            }
            return $0.date > $1.date
        }
    }
    
    private var fifoResult: LifoResult {
        FifoCalculator.calculate(transactions: asset.transactions)
    }
    
    private var activeAverageBuyPriceLIFO: Double {
        totalUnits > 0 ? activeTotalInvestedLIFO / totalUnits : 0.0
    }
    
    private var activeAverageBuyPriceFIFO: Double {
        totalUnits > 0 ? activeTotalInvestedFIFO / totalUnits : 0.0
    }
    
    private var activeTotalInvestedLIFO: Double {
        isConversionActive 
            ? PortfolioMetrics.investedValueInINR(for: asset, rate: currentRate)
            : totalInvested
    }
    
    private var activeTotalInvestedFIFO: Double {
        if asset.holdingType == .bankBalance || asset.holdingType == .fixedDeposit {
            return activeTotalInvestedLIFO
        }
        if isConversionActive {
            let res = FifoCalculator.calculateInINR(transactions: asset.transactions, categoryExchangeRate: currentRate)
            return res.holdings.reduce(0.0) { $0 + $1.remainingUnits * $1.buyPriceINR }
        } else {
            let res = FifoCalculator.calculate(transactions: asset.transactions)
            return res.holdings.reduce(0.0) { $0 + $1.remainingUnits * $1.buyPrice }
        }
    }
    
    private var activeCurrentValue: Double {
        isConversionActive
            ? PortfolioMetrics.currentValueInINR(for: asset, rate: currentRate)
            : currentValue
    }
    
    private var activeUnrealizedGainLossLIFO: Double {
        activeCurrentValue - activeTotalInvestedLIFO
    }
    
    private var activeUnrealizedGainLossFIFO: Double {
        activeCurrentValue - activeTotalInvestedFIFO
    }
    
    private var activeRealizedProfitLossLIFO: Double {
        if isConversionActive {
            return LifoCalculator.calculateInINR(transactions: asset.transactions, categoryExchangeRate: currentRate).realizedProfitLoss
        } else {
            return lifoResult.realizedProfitLoss
        }
    }
    
    private var activeRealizedProfitLossFIFO: Double {
        if isConversionActive {
            return FifoCalculator.calculateInINR(transactions: asset.transactions, categoryExchangeRate: currentRate).realizedProfitLoss
        } else {
            return fifoResult.realizedProfitLoss
        }
    }
    
    private var activeLifetimeInvestedLIFO: Double {
        isConversionActive
            ? PortfolioMetrics.lifetimeInvestedInINR(for: asset, rate: currentRate)
            : lifetimeInvested
    }
    
    private var activeLifetimeInvestedFIFO: Double {
        if isConversionActive {
            return FifoCalculator.calculateInINR(transactions: asset.transactions, categoryExchangeRate: currentRate).lifetimeInvested
        } else {
            return fifoResult.lifetimeInvested
        }
    }
    
    private var activeLifetimeRetrievedLIFO: Double {
        isConversionActive
            ? PortfolioMetrics.lifetimeRetrievedInINR(for: asset, rate: currentRate)
            : lifetimeRetrieved
    }
    
    private var activeLifetimeRetrievedFIFO: Double {
        if isConversionActive {
            return FifoCalculator.calculateInINR(transactions: asset.transactions, categoryExchangeRate: currentRate).lifetimeRetrieved
        } else {
            return fifoResult.lifetimeRetrieved
        }
    }
    
    private var activeXirr: Double? {
        isConversionActive
            ? PortfolioMetrics.xirrInINR(for: asset, rate: currentRate)
            : xirr
    }
    
    private var activeRealizedSellProfitByTransactionLIFO: [PersistentIdentifier: Double] {
        if isConversionActive {
            return LifoCalculator.realizedProfitLossBySellTransactionInINR(transactions: asset.transactions, categoryExchangeRate: currentRate)
        } else {
            return realizedSellProfitByTransaction
        }
    }
    
    private var activeRealizedSellProfitByTransactionFIFO: [PersistentIdentifier: Double] {
        if isConversionActive {
            return FifoCalculator.realizedProfitLossBySellTransactionInINR(transactions: asset.transactions, categoryExchangeRate: currentRate)
        } else {
            return FifoCalculator.realizedProfitLossBySellTransaction(transactions: asset.transactions)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if asset.holdingType != .bankBalance && asset.holdingType != .fixedDeposit {
                Picker("View Mode", selection: $selectedViewTab) {
                    ForEach(ViewTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .padding(.top, 4)
            }
            
            if isNonRupeeAsset {
                Picker("Currency Display", selection: $displayInINR) {
                    Text(categoryCurrencyCode).tag(false)
                    Text("Rupees (INR)").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    if selectedViewTab == .overview || asset.holdingType == .bankBalance || asset.holdingType == .fixedDeposit {
                        // Summary Card
                        summaryCard
                        
                        // Tax Settings Section
                        taxSettingsSection
                        
                        // Value Analysis Section (Stocks only if category is Individual Equity)
                        if asset.taxAssetType == .equity && asset.holdingType == .investment && (asset.category?.isIndividualEquity ?? false) {
                            stockValueAnalysisSection
                            stockDCFAnalysisSection
                        }
                        
                        // Holdings Section
                        if asset.holdingType == .investment, !lifoResult.holdings.isEmpty {
                            holdingsSection
                        }
                        
                        // Notes Section
                        notesSection
                        
                        // Reminders Section
                        remindersSection
                        
                        // Transactions Section
                        transactionsSection
                    } else {
                        // Inflows Analysis Section
                        assetInflowAnalysisSection
                    }
                    
                    Spacer(minLength: 80)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(asset.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showAddTransaction = true
                    } label: {
                        Label("Add Transaction", systemImage: "arrow.left.arrow.right.circle")
                    }
                    
                    Button {
                        showAddNote = true
                    } label: {
                        Label("Add Note", systemImage: "note.text.badge.plus")
                    }
                    
                    Button {
                        showAddReminder = true
                    } label: {
                        Label("Add Reminder", systemImage: "calendar.badge.clock")
                    }
                    
                    if let csvURL = generateCSVURL(for: asset) {
                        ShareLink(item: csvURL, preview: SharePreview("\(asset.name) Transactions CSV", image: Image(systemName: "doc.text"))) {
                            Label("Export Transactions CSV", systemImage: "square.and.arrow.up")
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .sheet(isPresented: $showAddTransaction) {
            NavigationStack {
                TransactionFormView(asset: asset)
            }
        }
        .sheet(isPresented: $showAddNote) {
            NavigationStack {
                AssetNoteFormView(asset: asset)
            }
        }
        .sheet(item: $transactionToEdit) { tx in
            EditTransactionSheet(transaction: tx)
        }
        .sheet(item: $noteToEdit) { note in
            EditAssetNoteSheet(note: note)
        }
        .sheet(isPresented: $showAddReminder) {
            AssetReminderFormSheet(reminder: nil, defaultAsset: asset)
        }
        .sheet(item: $reminderToEdit) { reminder in
            AssetReminderFormSheet(reminder: reminder, defaultAsset: asset)
        }
        .sheet(isPresented: $showTaxOverrideSheet) {
            AssetTaxOverrideSheet(asset: asset)
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
        .alert(asset.holdingType == .investment ? "Update Current Price" : "Update Current Balance", isPresented: $showUpdatePriceAlert) {
            TextField("Price", text: $priceInput)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) {}
            Button("Update") {
                if let newPrice = Double(priceInput) {
                    asset.currentPrice = newPrice
                }
            }
        }
        .confirmationDialog("Delete Asset?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Asset", role: .destructive) {
                modelContext.delete(asset)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the asset, its transactions, and its notes.")
        }
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Asset Overview")
                        .font(.title3.weight(.bold))
                    Text("Performance & valuation summary")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                Button {
                    priceInput = String(asset.currentPrice)
                    showUpdatePriceAlert = true
                } label: {
                    Label("Update Price", systemImage: "pencil.line")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.accent)
            }
            
            Divider()
            
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    if asset.holdingType == .investment {
                        Text("Total Units: \(totalUnits.formatted2)")
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                        Text("Avg Price (LIFO): \(currencySymbol)\(activeAverageBuyPriceLIFO.formatted2)")
                            .font(.system(size: 13, weight: .regular))
                            .monospacedDigit()
                        Text("Avg Price (FIFO): \(currencySymbol)\(activeAverageBuyPriceFIFO.formatted2)")
                            .font(.system(size: 13, weight: .regular))
                            .monospacedDigit()
                    } else {
                        Text("Principal Deposit: \(currencySymbol)\(activeAverageBuyPriceLIFO.formatted2)")
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                    }
                }
                
                Spacer()
                
                if asset.holdingType == .investment {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Holding Duration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(holdingDurationText)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                // Header row
                HStack {
                    Text("Metric")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("LIFO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .trailing)
                    Text("FIFO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .trailing)
                }
                
                Divider()
                
                // Invested Value
                HStack {
                    Text("Invested Value")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(currencySymbol)\(activeTotalInvestedLIFO.formattedComma)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 100, alignment: .trailing)
                    Text("\(currencySymbol)\(activeTotalInvestedFIFO.formattedComma)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 100, alignment: .trailing)
                }
                
                // Current Value
                HStack {
                    Text("Current Market Value")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(currencySymbol)\(activeCurrentValue.formattedComma)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 200 + 8, alignment: .trailing)
                }
                
                // Unrealized G/L
                HStack {
                    Text("Unrealized G/L")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    GainLossBadge(value: activeUnrealizedGainLossLIFO, percentage: activeTotalInvestedLIFO > 0 ? (activeUnrealizedGainLossLIFO / activeTotalInvestedLIFO) * 100.0 : nil, isCompact: true)
                        .frame(width: 100, alignment: .trailing)
                    
                    GainLossBadge(value: activeUnrealizedGainLossFIFO, percentage: activeTotalInvestedFIFO > 0 ? (activeUnrealizedGainLossFIFO / activeTotalInvestedFIFO) * 100.0 : nil, isCompact: true)
                        .frame(width: 100, alignment: .trailing)
                }
                
                // Realized P/L
                HStack {
                    Text("Realized Profit/Loss")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(currencySymbol)\(activeRealizedProfitLossLIFO.formattedComma)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(activeRealizedProfitLossLIFO >= 0 ? AppTheme.profit : AppTheme.loss)
                        .frame(width: 100, alignment: .trailing)
                    Text("\(currencySymbol)\(activeRealizedProfitLossFIFO.formattedComma)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(activeRealizedProfitLossFIFO >= 0 ? AppTheme.profit : AppTheme.loss)
                        .frame(width: 100, alignment: .trailing)
                }
                
                // Lifetime Invested
                HStack {
                    Text("Lifetime Invested")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(currencySymbol)\(activeLifetimeInvestedLIFO.formattedComma)")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 100, alignment: .trailing)
                    Text("\(currencySymbol)\(activeLifetimeInvestedFIFO.formattedComma)")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 100, alignment: .trailing)
                }

                
                // Lifetime Retrieved
                HStack {
                    Text("Lifetime Retrieved")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(currencySymbol)\(activeLifetimeRetrievedLIFO.formattedComma)")
                        .font(.subheadline)
                        .frame(width: 90, alignment: .trailing)
                    Text("\(currencySymbol)\(activeLifetimeRetrievedFIFO.formattedComma)")
                        .font(.subheadline)
                        .frame(width: 90, alignment: .trailing)
                }
                
                // XIRR
                HStack {
                    Text("XIRR")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(activeXirr != nil ? String(format: "%.2f%%", activeXirr!) : "N/A")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .frame(width: 180 + 8, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    // MARK: - Tax Configuration Section
    
    private var taxSettingsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Tax Classification")
                    .font(.headline)
                Spacer()
                Button {
                    showTaxOverrideSheet = true
                } label: {
                    Label("Configure", systemImage: "slider.horizontal.3")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.accent)
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ruleset Country")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(asset.taxCountry.rawValue)
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Instrument Type")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(asset.taxAssetType.displayName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    // MARK: - Holdings Section
    
    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current Holdings")
                    .font(.headline)
                Spacer()
                Picker("Holdings Method", selection: $holdingsMethod) {
                    ForEach(AccountingMethod.allCases) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            .padding(.horizontal)
            
            let allHoldings = displayHoldings
            let startIndex = (holdingsPage - 1) * itemsPerPage
            let endIndex = min(startIndex + itemsPerPage, allHoldings.count)
            let paginatedHoldings = (startIndex < allHoldings.count) ? Array(allHoldings[startIndex..<endIndex]) : []
 
            ForEach(paginatedHoldings) { lot in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(lot.remainingUnits.formatted2) units · \(Calendar.current.dateComponents([.day], from: lot.date, to: Date()).day ?? 0)d @ \(currencySymbol)\(lot.buyPrice.formatted2)")
                            .font(.caption)
                    }
                    Spacer()
                    let lotGainLoss = lot.remainingUnits * ((isConversionActive ? asset.currentPrice * currentRate : asset.currentPrice) - lot.buyPrice)
                    Text("G/L: \(currencySymbol)\(lotGainLoss.formatted2)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(lotGainLoss >= 0 ? AppTheme.profit : AppTheme.loss)
                }
                .padding(10)
                .background(Color(.systemGray6).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
            }
            
            if allHoldings.count > itemsPerPage {
                PaginationView(currentPage: $holdingsPage, totalItems: allHoldings.count, pageSize: itemsPerPage)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Transactions Section
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Notes")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showAddNote = true
                } label: {
                    Label("Add Note", systemImage: "note.text.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.warning)
            }
            .padding(.horizontal)
            
            if sortedNotes.isEmpty {
                Text("No notes yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(sortedNotes) { note in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(note.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(note.date, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(note.noteDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 10) {
                            Button {
                                noteToEdit = note
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                modelContext.delete(note)
                            } label: {
                                Image(systemName: "trash.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(AppTheme.loss)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
        }
    }
       private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Transactions")
                    .font(.headline)
                
                Spacer()
                
                if let csvURL = generateCSVURL(for: asset) {
                    ShareLink(item: csvURL, preview: SharePreview("\(asset.name) Transactions CSV", image: Image(systemName: "doc.text"))) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accent)
                }
            }
            .padding(.horizontal)
            
            if sortedTransactions.isEmpty {
                Text("No transactions yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                let startIndex = (transactionsPage - 1) * itemsPerPage
                let endIndex = min(startIndex + itemsPerPage, sortedTransactions.count)
                let paginatedTransactions = (startIndex < sortedTransactions.count) ? Array(sortedTransactions[startIndex..<endIndex]) : []
 
                ForEach(paginatedTransactions) { tx in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.type.rawValue)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(tx.type == .sell ? AppTheme.loss : AppTheme.accent)
                            Text(tx.date, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let broker = tx.broker {
                                Text(broker.name)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            if tx.type == .sell {
                                HStack(spacing: 8) {
                                    if let realizedProfitLIFO = activeRealizedSellProfitByTransactionLIFO[tx.persistentModelID] {
                                        Text("LIFO: \(currencySymbol)\(realizedProfitLIFO.formattedComma)")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundStyle(realizedProfitLIFO >= 0 ? AppTheme.profit : AppTheme.loss)
                                    }
                                    Text("·")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    if let realizedProfitFIFO = activeRealizedSellProfitByTransactionFIFO[tx.persistentModelID] {
                                        Text("FIFO: \(currencySymbol)\(realizedProfitFIFO.formattedComma)")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundStyle(realizedProfitFIFO >= 0 ? AppTheme.profit : AppTheme.loss)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        let txPrice = tx.pricePerUnit * (isConversionActive ? (tx.inrExchangeRate ?? currentRate) : 1.0)
                        if tx.type == .dividend {
                            Text("\(currencySymbol)\(txPrice.formattedComma)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        } else {
                            Text("\(tx.units.formatted2) @ \(currencySymbol)\(txPrice.formatted2)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        // Edit
                        Button {
                            transactionToEdit = tx
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.body)
                                .foregroundStyle(AppTheme.accent)
                        }
                        .buttonStyle(.plain)
                        
                        // Delete
                        Button {
                            modelContext.delete(tx)
                        } label: {
                            Image(systemName: "trash.circle.fill")
                                .font(.body)
                                .foregroundStyle(AppTheme.loss)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                
                if sortedTransactions.count > itemsPerPage {
                    PaginationView(currentPage: $transactionsPage, totalItems: sortedTransactions.count, pageSize: itemsPerPage)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    private var periodTradeCounts: PortfolioMetrics.TransactionCounts {
        let calendar = Calendar.current
        let filtered = asset.transactions.filter { tx in
            let year = calendar.component(.year, from: tx.date)
            if selectedInflowPeriod == .lifetime {
                return true
            } else if selectedInflowPeriod == .yearly {
                return year == selectedInflowYear
            } else {
                let month = calendar.component(.month, from: tx.date)
                return year == selectedInflowYear && month == selectedInflowMonth
            }
        }
        return PortfolioMetrics.transactionCounts(for: filtered)
    }

    // MARK: - Asset Inflow Subviews
    @ViewBuilder
    private var assetInflowAnalysisSection: some View {
        VStack(spacing: 16) {
            // Period selector
            VStack(spacing: 12) {
                Picker("Period Type", selection: $selectedInflowPeriod) {
                    ForEach(InflowPeriodType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                
                if selectedInflowPeriod != .lifetime {
                    HStack(spacing: 12) {
                        Menu {
                            Picker("Year", selection: $selectedInflowYear) {
                                ForEach(availableInflowYears, id: \.self) { year in
                                    Text(String(year)).tag(year)
                                }
                            }
                        } label: {
                            HStack {
                                Text("Year: \(String(selectedInflowYear))")
                                    .fontWeight(.semibold)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.accent)
                            .clipShape(Capsule())
                        }
                        
                        if selectedInflowPeriod == .monthly {
                            Menu {
                                Picker("Month", selection: $selectedInflowMonth) {
                                    ForEach(months, id: \.self) { month in
                                        Text(monthName(for: month)).tag(month)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(monthName(for: selectedInflowMonth))
                                        .fontWeight(.semibold)
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(AppTheme.accentSecondary)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            
            let summary = periodInflowsSummary
            let counts = periodTradeCounts
            
            // Flow & Trade Activity Card
            VStack(spacing: 14) {
                Text(selectedInflowPeriod == .monthly
                     ? "Inflows & Activity: \(monthName(for: selectedInflowMonth)) \(selectedInflowYear)"
                     : (selectedInflowPeriod == .yearly
                        ? "Inflows & Activity: \(selectedInflowYear)"
                        : "Lifetime Inflows & Activity"))
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Invested")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        Text("\(currencySymbol)\(summary.invested.formattedComma)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Withdrawn")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        Text("\(currencySymbol)\(summary.withdrawn.formattedComma)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
                
                Divider().background(.white.opacity(0.3))
                
                // Trade Counts & Hold Discipline
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trade Counts")
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
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.heroGradient))
            .padding(.horizontal)
            
            if selectedInflowPeriod == .yearly {
                yearlyInflowGridBlock
            } else if selectedInflowPeriod == .lifetime {
                lifetimeInflowGridBlock
            }
        }
    }

    @ViewBuilder
    private var yearlyInflowGridBlock: some View {
        let monthly = yearlyGridData
        let total = yearlyGridTotal
        let displayCurrencyName = isConversionActive ? "INR" : categoryCurrencyCode
        let calendar = Calendar.current
        let yearTx = asset.transactions.filter { calendar.component(.year, from: $0.date) == selectedInflowYear }
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly Inflows & Trades (\(String(selectedInflowYear))) in \(displayCurrencyName)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            HStack(spacing: 0) {
                // Scrollable Monthly cells
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 12) {
                        ForEach(1...12, id: \.self) { month in
                            let monthBuys = yearTx.filter { calendar.component(.month, from: $0.date) == month && $0.type == .buy }.count
                            let monthSells = yearTx.filter { calendar.component(.month, from: $0.date) == month && $0.type == .sell }.count
                            let val = monthly[month] ?? 0.0
                            
                            VStack(spacing: 2) {
                                Text(monthAbbrev(month))
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                
                                Text(abs(val).formattedCompact)
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(val == 0 ? .primary : (val > 0 ? AppTheme.profit : AppTheme.loss))
                                
                                if monthBuys > 0 || monthSells > 0 {
                                    Text("\(monthBuys)B/\(monthSells)S")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(monthSells == 0 ? AppTheme.profit : AppTheme.loss)
                                }
                            }
                            .frame(width: 60)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Divider()
                
                // Fixed Year Total
                VStack(spacing: 2) {
                    Text("Total")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    
                    Text(abs(total).formattedCompact)
                        .font(.footnote)
                        .fontWeight(.bold)
                        .foregroundStyle(total == 0 ? .primary : (total > 0 ? AppTheme.profit : AppTheme.loss))
                    
                    let totalBuys = yearTx.filter { $0.type == .buy }.count
                    let totalSells = yearTx.filter { $0.type == .sell }.count
                    Text("\(totalBuys)B/\(totalSells)S")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(totalSells == 0 ? AppTheme.profit : Color.orange)
                }
                .frame(width: 75)
                .padding(.vertical, 8)
                .background(Color(.systemGray6).opacity(0.4))
            }
            .background(Color(.systemGray6).opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var lifetimeInflowGridBlock: some View {
        let yearly = lifetimeGridData
        let total = lifetimeGridTotal
        let start = startingInflowYear
        let end = Calendar.current.component(.year, from: Date())
        let yearsRange = Array(start...end)
        let displayCurrencyName = isConversionActive ? "INR" : categoryCurrencyCode
        let calendar = Calendar.current
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Yearly Net Flows & Trades in \(displayCurrencyName)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            HStack(spacing: 0) {
                // Scrollable Yearly cells
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 12) {
                        ForEach(yearsRange, id: \.self) { year in
                            let yearTx = asset.transactions.filter { calendar.component(.year, from: $0.date) == year }
                            let yearBuys = yearTx.filter { $0.type == .buy }.count
                            let yearSells = yearTx.filter { $0.type == .sell }.count
                            let val = yearly[year] ?? 0.0
                            
                            VStack(spacing: 2) {
                                Text(String(year))
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                
                                Text(abs(val).formattedCompact)
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(val == 0 ? .primary : (val > 0 ? AppTheme.profit : AppTheme.loss))
                                
                                if yearBuys > 0 || yearSells > 0 {
                                    Text("\(yearBuys)B/\(yearSells)S")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(yearSells == 0 ? AppTheme.profit : AppTheme.loss)
                                }
                            }
                            .frame(width: 60)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Divider()
                
                // Fixed Lifetime Total
                VStack(spacing: 2) {
                    Text("Total")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    
                    Text(abs(total).formattedCompact)
                        .font(.footnote)
                        .fontWeight(.bold)
                        .foregroundStyle(total == 0 ? .primary : (total > 0 ? AppTheme.profit : AppTheme.loss))
                    
                    let overallBuys = asset.transactions.filter { $0.type == .buy }.count
                    let overallSells = asset.transactions.filter { $0.type == .sell }.count
                    Text("\(overallBuys)B/\(overallSells)S")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(overallSells == 0 ? AppTheme.profit : Color.orange)
                }
                .frame(width: 75)
                .padding(.vertical, 8)
                .background(Color(.systemGray6).opacity(0.4))
            }
            .background(Color(.systemGray6).opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }
    
    // MARK: - Stock Value Analysis Section
    
    @ViewBuilder
    private var stockValueAnalysisSection: some View {
        if let analysis = asset.valueAnalysis {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Stock Value Analysis")
                        .font(.headline)
                    Spacer()
                    Button {
                        showValueAnalysisDetail = true
                    } label: {
                        Text("View Details")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                }
                .padding(.horizontal)
                
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(analysis.industry.uppercased())
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.accent)
                        }
                        Spacer()
                        Text(timeAgo(for: analysis.analysisDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("INTRINSIC VALUE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(String(format: "₹ %.2f", analysis.intrinsicValue))
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Text(analysis.isUndervalued ? "UNDERVALUED" : "OVERVALUED")
                                .font(.caption2)
                                .fontWeight(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background((analysis.isUndervalued ? AppTheme.profit : AppTheme.loss).opacity(0.15))
                                .foregroundStyle(analysis.isUndervalued ? AppTheme.profit : AppTheme.loss)
                                .clipShape(Capsule())
                            
                            let margin = analysis.valuationMarginPercent * 100
                            Text(String(format: "%@%.1f%% Margin", margin >= 0 ? "+" : "", margin))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(margin >= 0 ? AppTheme.profit : AppTheme.loss)
                        }
                    }
                    
                    Divider()
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PROJECTED CAGR")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.2f%%", analysis.overallProjectedCAGR * 100.0))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(analysis.overallProjectedCAGR >= 0.15 ? AppTheme.profit : AppTheme.accent)
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PEG RATIO")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.2f", analysis.pegRatio))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(analysis.pegRatio < 1.0 && analysis.pegRatio > 0 ? AppTheme.profit : .primary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("ROE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.2f%%", analysis.roe * 100.0))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(analysis.roe >= 0.15 ? AppTheme.profit : .primary)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Button {
                            showValueAnalysisForm = true
                        } label: {
                            Label("Edit Worksheet", systemImage: "pencil")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.accent)
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            deleteAnalysis(analysis)
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.loss)
                    }
                }
                .padding(16)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Stock Value Analysis")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(AppTheme.accent)
                        .padding(.top, 8)
                    
                    Text("Analyze Stock Valuation")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("Calculate intrinsic value, PEG, margins of safety, and multi-year CAGR forecasts to determine if this stock is undervalued or overvalued.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    Button {
                        showValueAnalysisForm = true
                    } label: {
                        Text("Perform Value Analysis")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }
    
    private func timeAgo(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func deleteAnalysis(_ analysis: StockValueAnalysis) {
        asset.valueAnalysis = nil
        modelContext.delete(analysis)
        try? modelContext.save()
    }
    
    private func deleteDCFAnalysis(_ dcf: StockDCFAnalysis) {
        asset.dcfAnalysis = nil
        modelContext.delete(dcf)
        try? modelContext.save()
    }
    
    @ViewBuilder
    private var stockDCFAnalysisSection: some View {
        if let dcf = asset.dcfAnalysis {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Stock DCF Analysis")
                        .font(.headline)
                    Spacer()
                    Button {
                        showDCFAnalysisForm = true
                    } label: {
                        Text("View Worksheet")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                }
                .padding(.horizontal)
                
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DISCOUNTED CASH FLOW MODEL")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.accentSecondary)
                        }
                        Spacer()
                        Text(timeAgo(for: dcf.analysisDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("INTRINSIC VALUE/SHARE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(String(format: "₹ %.2f", dcf.intrinsicValuePerShare))
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Text(dcf.isUndervalued ? "UNDERVALUED" : "OVERVALUED")
                                .font(.caption2)
                                .fontWeight(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background((dcf.isUndervalued ? AppTheme.profit : AppTheme.loss).opacity(0.15))
                                .foregroundStyle(dcf.isUndervalued ? AppTheme.profit : AppTheme.loss)
                                .clipShape(Capsule())
                            
                            let margin = dcf.valuationMarginPercent * 100
                            Text(String(format: "%@%.1f%% Margin", margin >= 0 ? "+" : "", margin))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(margin >= 0 ? AppTheme.profit : AppTheme.loss)
                        }
                    }
                    
                    Divider()
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("STARTING FCF")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text("₹\(dcf.startingFCF.formattedIndianRupees()) Cr")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("GROWTH / DISCOUNT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f%% / %.1f%%", dcf.growthRate, dcf.discountRate))
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("ENTERPRISE VALUE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text("₹\(dcf.enterpriseValue.formattedIndianRupees()) Cr")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.accentSecondary)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Button {
                            showDCFAnalysisForm = true
                        } label: {
                            Label("Edit Worksheet", systemImage: "pencil")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.accentSecondary)
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            deleteDCFAnalysis(dcf)
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.loss)
                    }
                }
                .padding(16)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Stock DCF Analysis")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    Image(systemName: "indianrupeesign.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(AppTheme.accentSecondary)
                        .padding(.top, 8)
                    
                    Text("Perform Discounted Cash Flow Analysis")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("Determine if this stock is undervalued or overvalued by calculating the present value of projected future free cash flows.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    Button {
                        showDCFAnalysisForm = true
                    } label: {
                        Text("Perform DCF Analysis")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentSecondary)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }
    

    
    private var sortedReminders: [AssetReminder] {
        asset.reminders.sorted { $0.eventDate < $1.eventDate }
    }
    
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Reminders & Events")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showAddReminder = true
                } label: {
                    Label("Add Event", systemImage: "calendar.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.accent)
            }
            .padding(.horizontal)
            
            if sortedReminders.isEmpty {
                Text("No reminders set.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(sortedReminders) { reminder in
                    let isOverdue = !reminder.isCompleted && reminder.eventDate < Date()
                    
                    HStack(alignment: .top, spacing: 12) {
                        // Checkbox button to toggle completion
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                reminder.isCompleted.toggle()
                                try? modelContext.save()
                            }
                        } label: {
                            Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(reminder.isCompleted ? AppTheme.profit : (isOverdue ? AppTheme.loss : .secondary))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .center, spacing: 6) {
                                Text(reminder.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .strikethrough(reminder.isCompleted)
                                    .foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                                
                                if isOverdue {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.loss)
                                }
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                Text(reminder.eventDate, style: .date)
                                    .font(.caption2)
                                Text("at")
                                    .font(.system(size: 9))
                                Text(reminder.eventDate, style: .time)
                                    .font(.caption2)
                            }
                            .foregroundStyle(reminder.isCompleted ? .secondary : (isOverdue ? AppTheme.loss : .secondary))
                            
                            if !reminder.notes.isEmpty {
                                Text(reminder.notes)
                                    .font(.caption)
                                    .foregroundStyle(reminder.isCompleted ? .tertiary : .secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 2)
                            }
                        }
                        
                        Spacer()
                        
                        // Edit & Delete Buttons
                        HStack(spacing: 12) {
                            Button {
                                reminderToEdit = reminder
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                withAnimation {
                                    modelContext.delete(reminder)
                                    try? modelContext.save()
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.loss)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 2)
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private func generateCSVURL(for asset: Asset) -> URL? {
        let safeName = asset.name.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "_")
        let fileName = "\(safeName)_transactions.csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        var csvContent = "Asset Name,Category,Currency,Transaction Type,Date,Units,Price Per Unit,Total Amount (Native),INR Exchange Rate,Total Amount (INR)\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let sortedTx = asset.transactions.sorted {
            if $0.date == $1.date {
                return $0.createdAt < $1.createdAt
            }
            return $0.date < $1.date
        }
        
        let catName = asset.category?.name ?? ""
        let currencyCode = asset.category?.currencyCode ?? "USD"
        
        for tx in sortedTx {
            let txRate = tx.inrExchangeRate ?? currentRate
            let amountNative = tx.units * tx.pricePerUnit
            let amountINR = amountNative * txRate
            
            let line = "\"\(asset.name)\",\"\(catName)\",\"\(currencyCode)\",\"\(tx.type.rawValue)\",\"\(dateFormatter.string(from: tx.date))\",\(tx.units.formatted2),\(tx.pricePerUnit.formatted2),\(amountNative.formatted2),\(txRate.formatted2),\(amountINR.formatted2)\n"
            csvContent.append(line)
        }
        
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Failed to write CSV file: \(error)")
            return nil
        }
    }
}
