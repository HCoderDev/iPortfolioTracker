//
//  TransactionFormView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

enum TransactionFormMode: String, CaseIterable, Identifiable {
    case single = "Single Entry"
    case sip = "SIP / Bulk Schedule"
    
    var id: String { rawValue }
}

enum SIPFrequency: String, CaseIterable, Identifiable {
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case biweekly = "Bi-Weekly"
    case weekly = "Weekly"
    
    var id: String { rawValue }
}

struct GeneratedSIPItem: Identifiable, Equatable {
    let id = UUID()
    var date: Date
    var amount: Double
    var units: Double
    var pricePerUnit: Double
}

struct TransactionFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Broker.name) private var brokers: [Broker]
    
    let asset: Asset
    
    // Mode
    @State private var formMode: TransactionFormMode = .single
    
    // Configured Transactions for this asset
    private var investmentConfig: InvestmentTypeConfig {
        TransactionTypeRegistry.shared.config(for: asset.holdingType)
    }
    
    // Single Transaction State
    @State private var selectedConfig: TransactionTypeConfig
    @State private var amountInput: String = ""
    @State private var unitsInput: String = ""
    @State private var pricePerUnitInput: String = ""
    @State private var notesInput: String = ""
    @State private var selectedDate: Date = Date()
    @State private var selectedBroker: Broker?
    @State private var setAsCurrentPrice: Bool = false
    @State private var inrExchangeRate: String = ""
    
    // SIP State
    @State private var sipConfig: TransactionTypeConfig
    @State private var sipFrequency: SIPFrequency = .monthly
    @State private var sipDayOfMonth: Int = 5
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var sipAmountInput: String = ""
    @State private var sipUnitsInput: String = ""
    @State private var sipPricePerUnitInput: String = ""
    @State private var generatedEntries: [GeneratedSIPItem] = []
    
    init(asset: Asset) {
        self.asset = asset
        let config = TransactionTypeRegistry.shared.config(for: asset.holdingType)
        let initialConfig = config.allowedTransactions.first ?? TransactionTypeRegistry.config(for: "BUY", holdingType: asset.holdingType)
        _selectedConfig = State(initialValue: initialConfig)
        _sipConfig = State(initialValue: initialConfig)
    }
    
    private var isUnitized: Bool {
        selectedConfig.isUnitBased
    }
    
    private var parsedAmount: Double? {
        if isUnitized {
            guard let u = Double(unitsInput), u > 0, let p = Double(pricePerUnitInput), p > 0 else { return nil }
            return u * p
        } else {
            guard let a = Double(amountInput), a > 0 else { return nil }
            return a
        }
    }
    
    private var parsedUnits: Double {
        if isUnitized {
            return Double(unitsInput) ?? 1.0
        }
        return 1.0
    }
    
    private var parsedPricePerUnit: Double {
        if isUnitized {
            return Double(pricePerUnitInput) ?? 0.0
        }
        return Double(amountInput) ?? 0.0
    }
    
    private var isSingleValid: Bool {
        guard let amount = parsedAmount, amount > 0 else { return false }
        return true
    }
    
    var body: some View {
        Form {
            // Mode Selector
            Section {
                Picker("Entry Mode", selection: $formMode) {
                    ForEach(TransactionFormMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }
            
            if formMode == .single {
                singleTransactionFormContent
            } else {
                sipFormContent
            }
        }
        .navigationTitle(formMode == .single ? "Add Transaction" : "\(asset.holdingType.isNonUnitized ? "Bulk Contribution" : "Bulk SIP")")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear {
            if let rate = asset.category?.lastInrExchangeRate {
                inrExchangeRate = String(rate)
            }
        }
        .onChange(of: sipConfig) { _, _ in generateSIPEntries() }
        .onChange(of: sipFrequency) { _, _ in generateSIPEntries() }
        .onChange(of: sipDayOfMonth) { _, _ in generateSIPEntries() }
        .onChange(of: startDate) { _, _ in generateSIPEntries() }
        .onChange(of: endDate) { _, _ in generateSIPEntries() }
        .onChange(of: sipAmountInput) { _, _ in generateSIPEntries() }
        .onChange(of: sipUnitsInput) { _, _ in generateSIPEntries() }
        .onChange(of: sipPricePerUnitInput) { _, _ in generateSIPEntries() }
    }
    
    // MARK: - Single Form Content
    
    @ViewBuilder
    private var singleTransactionFormContent: some View {
        // Transaction Type Selector
        Section("Transaction Type") {
            Picker("Action", selection: $selectedConfig) {
                ForEach(investmentConfig.allowedTransactions) { cfg in
                    Label(cfg.displayName, systemImage: cfg.iconName).tag(cfg)
                }
            }
            .pickerStyle(.menu)
            
            // Cash Flow Impact Badge
            HStack(spacing: 8) {
                Image(systemName: selectedConfig.iconName)
                    .foregroundStyle(cashColor(selectedConfig.cashDirection))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedConfig.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(impactDescription(selectedConfig))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        
        Section("Transaction Details") {
            if isUnitized {
                TextField("Units / Quantity", text: $unitsInput)
                    .keyboardType(.decimalPad)
                
                TextField("Price per Unit", text: $pricePerUnitInput)
                    .keyboardType(.decimalPad)
                
                if let amt = parsedAmount {
                    HStack {
                        Text("Total Amount")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formattedCurrency(amt))
                            .fontWeight(.semibold)
                    }
                }
            } else {
                TextField("Amount (\(asset.category?.currencyCode ?? "INR"))", text: $amountInput)
                    .keyboardType(.decimalPad)
            }
            
            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
            
            TextField(selectedConfig.notesPrompt ?? "Notes / Remarks (Optional)", text: $notesInput)
            
            Picker("Broker / Account", selection: $selectedBroker) {
                Text("None").tag(nil as Broker?)
                ForEach(brokers) { broker in
                    Text(broker.name).tag(broker as Broker?)
                }
            }
            
            if asset.category?.currencyCode != "INR" {
                TextField("INR Exchange Rate (1 \(asset.category?.currencyCode ?? "") = ? INR)", text: $inrExchangeRate)
                    .keyboardType(.decimalPad)
            }
        }
        
        if isUnitized {
            Section {
                Toggle("Update asset price to this unit price", isOn: $setAsCurrentPrice)
            }
        }
        
        Section {
            Button(action: saveSingleTransaction) {
                HStack {
                    Spacer()
                    Text("Save \(selectedConfig.displayName)")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSingleValid ? AppTheme.accent : Color.gray.opacity(0.3))
            )
            .disabled(!isSingleValid)
        }
    }
    
    // MARK: - SIP Content
    
    @ViewBuilder
    private var sipFormContent: some View {
        Section("Bulk Schedule Setup") {
            Picker("Transaction Type", selection: $sipConfig) {
                ForEach(investmentConfig.allowedTransactions.filter { $0.cashDirection == .outflow || $0.cashDirection == .internalAccrual }) { cfg in
                    Text(cfg.displayName).tag(cfg)
                }
            }
            
            Picker("Frequency", selection: $sipFrequency) {
                ForEach(SIPFrequency.allCases) { freq in
                    Text(freq.rawValue).tag(freq)
                }
            }
            
            if sipFrequency == .monthly || sipFrequency == .quarterly {
                Picker("Day of the Month", selection: $sipDayOfMonth) {
                    ForEach(1...31, id: \.self) { day in
                        Text("\(day)\(daySuffix(for: day))").tag(day)
                    }
                }
            }
            
            DatePicker("Start Period", selection: $startDate, displayedComponents: .date)
            DatePicker("End Period", selection: $endDate, displayedComponents: .date)
            
            if sipConfig.isUnitBased {
                TextField("Units per Buy", text: $sipUnitsInput)
                    .keyboardType(.decimalPad)
                
                TextField("Price per Unit", text: $sipPricePerUnitInput)
                    .keyboardType(.decimalPad)
            } else {
                TextField("Installment Amount per Contribution", text: $sipAmountInput)
                    .keyboardType(.decimalPad)
            }
            
            Picker("Broker / Account", selection: $selectedBroker) {
                Text("None").tag(nil as Broker?)
                ForEach(brokers) { broker in
                    Text(broker.name).tag(broker as Broker?)
                }
            }
            
            if asset.category?.currencyCode != "INR" {
                TextField("INR Exchange Rate (1 \(asset.category?.currencyCode ?? "") = ? INR)", text: $inrExchangeRate)
                    .keyboardType(.decimalPad)
            }
        }
        
        if !generatedEntries.isEmpty {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total Installments: \(generatedEntries.count)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if sipConfig.isUnitBased {
                            Text("Total Units: \(formattedNumber(sipTotalUnits))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Total Value")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formattedCurrency(sipTotalValue))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Schedule Summary")
            }
            
            Section {
                ForEach(generatedEntries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.body)
                                .fontWeight(.medium)
                            if sipConfig.isUnitBased {
                                Text("\(formattedNumber(entry.units)) units @ \(formattedCurrency(entry.pricePerUnit))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(formattedCurrency(entry.amount))
                            .font(.callout)
                            .fontWeight(.semibold)
                    }
                }
                .onDelete(perform: deleteSIPEntries)
            } header: {
                HStack {
                    Text("Generated Schedule (\(generatedEntries.count))")
                    Spacer()
                    Button("Reset") {
                        generateSIPEntries()
                    }
                    .font(.caption)
                }
            }
        }
        
        Section {
            Button(action: saveSIPTransactions) {
                HStack {
                    Spacer()
                    Text("Save \(generatedEntries.count) Schedule Transactions")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: 10)
                    .fill(!generatedEntries.isEmpty ? AppTheme.accent : Color.gray.opacity(0.3))
            )
            .disabled(generatedEntries.isEmpty)
        }
    }
    
    // MARK: - Logic & Calculations
    
    private var sipTotalUnits: Double {
        generatedEntries.reduce(0) { $0 + $1.units }
    }
    
    private var sipTotalValue: Double {
        generatedEntries.reduce(0) { $0 + $1.amount }
    }
    
    private func deleteSIPEntries(at offsets: IndexSet) {
        generatedEntries.remove(atOffsets: offsets)
    }
    
    private func generateSIPEntries() {
        let isUnit = sipConfig.isUnitBased
        var unitVal = 1.0
        var priceVal = 0.0
        var amountVal = 0.0
        
        if isUnit {
            guard let u = Double(sipUnitsInput), u > 0,
                  let p = Double(sipPricePerUnitInput), p > 0,
                  startDate <= endDate else {
                generatedEntries = []
                return
            }
            unitVal = u
            priceVal = p
            amountVal = u * p
        } else {
            guard let a = Double(sipAmountInput), a > 0,
                  startDate <= endDate else {
                generatedEntries = []
                return
            }
            amountVal = a
            unitVal = 1.0
            priceVal = a
        }
        
        let calendar = Calendar.current
        var entries: [GeneratedSIPItem] = []
        
        switch sipFrequency {
        case .monthly, .quarterly:
            let stepMonths = (sipFrequency == .monthly) ? 1 : 3
            var currentComponent = calendar.dateComponents([.year, .month], from: startDate)
            
            let startOfDay = calendar.startOfDay(for: startDate)
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
            
            while let currentBase = calendar.date(from: currentComponent) {
                let range = calendar.range(of: .day, in: .month, for: currentBase)
                let maxDays = range?.count ?? 28
                let targetDay = min(sipDayOfMonth, maxDays)
                
                var targetComponents = currentComponent
                targetComponents.day = targetDay
                
                if let entryDate = calendar.date(from: targetComponents) {
                    if entryDate >= startOfDay && entryDate <= endOfDay {
                        entries.append(GeneratedSIPItem(date: entryDate, amount: amountVal, units: unitVal, pricePerUnit: priceVal))
                    }
                }
                
                guard let nextMonthDate = calendar.date(byAdding: .month, value: stepMonths, to: currentBase) else { break }
                currentComponent = calendar.dateComponents([.year, .month], from: nextMonthDate)
                
                if let nextDateCheck = calendar.date(from: currentComponent), nextDateCheck > endOfDay {
                    break
                }
            }
            
        case .biweekly, .weekly:
            let stepDays = (sipFrequency == .weekly) ? 7 : 14
            var currentDate = calendar.startOfDay(for: startDate)
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
            
            while currentDate <= endOfDay {
                entries.append(GeneratedSIPItem(date: currentDate, amount: amountVal, units: unitVal, pricePerUnit: priceVal))
                guard let nextDate = calendar.date(byAdding: .day, value: stepDays, to: currentDate) else { break }
                currentDate = nextDate
            }
        }
        
        generatedEntries = entries
    }
    
    private func saveSingleTransaction() {
        guard let amount = parsedAmount, amount > 0 else { return }
        
        let rateValue = Double(inrExchangeRate)
        let transaction = AssetTransaction(
            rawType: selectedConfig.rawType,
            units: parsedUnits,
            pricePerUnit: parsedPricePerUnit,
            date: selectedDate,
            notes: notesInput.isEmpty ? nil : notesInput,
            asset: asset,
            broker: selectedBroker,
            inrExchangeRate: rateValue
        )
        modelContext.insert(transaction)
        
        if let rateValue {
            asset.category?.lastInrExchangeRate = rateValue
        }
        
        if setAsCurrentPrice && isUnitized {
            asset.currentPrice = parsedPricePerUnit
        }
        
        dismiss()
    }
    
    private func saveSIPTransactions() {
        guard !generatedEntries.isEmpty else { return }
        let rateValue = Double(inrExchangeRate)
        let sortedEntries = generatedEntries.sorted(by: { $0.date < $1.date })
        
        for entry in sortedEntries {
            let transaction = AssetTransaction(
                rawType: sipConfig.rawType,
                units: entry.units,
                pricePerUnit: entry.pricePerUnit,
                date: entry.date,
                notes: "\(sipFrequency.rawValue) Schedule",
                asset: asset,
                broker: selectedBroker,
                inrExchangeRate: rateValue
            )
            modelContext.insert(transaction)
        }
        
        if let rateValue {
            asset.category?.lastInrExchangeRate = rateValue
        }
        
        if setAsCurrentPrice, sipConfig.isUnitBased, let latestPrice = sortedEntries.last?.pricePerUnit {
            asset.currentPrice = latestPrice
        }
        
        dismiss()
    }
    
    private func cashColor(_ dir: CashDirection) -> Color {
        switch dir {
        case .outflow: return AppTheme.accent
        case .internalAccrual: return .orange
        case .inflow: return AppTheme.gain
        }
    }
    
    private func impactDescription(_ cfg: TransactionTypeConfig) -> String {
        var parts: [String] = []
        if cfg.affectsInvestedAmount {
            parts.append(cfg.cashDirection == .outflow ? "+Invested Capital" : "-Invested Capital")
        }
        if cfg.affectsAssetValue {
            parts.append(cfg.cashDirection == .inflow ? "-Account Value" : "+Account Value")
        }
        if cfg.affectsProfit {
            parts.append("+Profit / Return")
        }
        if cfg.closesAsset {
            parts.append("Closes Holding")
        }
        return parts.joined(separator: " • ")
    }
    
    private func daySuffix(for day: Int) -> String {
        switch day {
        case 1, 21, 31: return "st"
        case 2, 22: return "nd"
        case 3, 23: return "rd"
        default: return "th"
        }
    }
    
    private func formattedNumber(_ val: Double) -> String {
        if val.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", val)
        } else {
            return String(format: "%.4f", val)
        }
    }
    
    private func formattedCurrency(_ val: Double) -> String {
        let code = asset.category?.currencyCode ?? "INR"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: val)) ?? "\(code) \(val)"
    }
}
