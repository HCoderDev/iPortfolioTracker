//
//  TransactionFormView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct TransactionFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Broker.name) private var brokers: [Broker]
    
    let asset: Asset
    
    @State private var transactionType: TransactionType = .buy
    @State private var units: String = ""
    @State private var pricePerUnit: String = ""
    @State private var selectedDate: Date = Date()
    @State private var selectedBroker: Broker?
    @State private var setAsCurrentPrice: Bool = false
    @State private var inrExchangeRate: String = ""
    
    private var unitsValue: Double? {
        transactionType == .dividend ? 1.0 : Double(units)
    }
    
    private var priceValue: Double? {
        Double(pricePerUnit)
    }
    
    private var hasPositiveValues: Bool {
        guard let unitsValue, let priceValue else { return false }
        return unitsValue > 0 && priceValue > 0
    }
    
    private var exceedsAvailableUnits: Bool {
        guard let unitsValue else { return false }
        if transactionType == .dividend { return false }
        let candidate = TransactionLedgerEntry(
            type: transactionType,
            units: unitsValue,
            date: selectedDate,
            createdAt: Date()
        )
        let currentEntries = asset.transactions.map {
            TransactionLedgerEntry(
                type: $0.type,
                units: $0.units,
                date: $0.date,
                createdAt: $0.createdAt
            )
        }
        return !LifoCalculator.hasSufficientUnits(entries: currentEntries + [candidate])
    }
    
    var body: some View {
        Form {
            // BUY / SELL Toggle
            Section {
                Picker("Type", selection: $transactionType) {
                    Text("BUY").tag(TransactionType.buy)
                    Text("SELL").tag(TransactionType.sell)
                    Text("DIVIDEND").tag(TransactionType.dividend)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }
            
            Section("Transaction Details") {
                if transactionType == .dividend {
                    TextField("Dividend Amount", text: $pricePerUnit)
                        .keyboardType(.decimalPad)
                } else {
                    TextField("Units", text: $units)
                        .keyboardType(.decimalPad)
                    
                    TextField("Price per Unit", text: $pricePerUnit)
                        .keyboardType(.decimalPad)
                }
                
                DatePicker("Transaction Date", selection: $selectedDate, displayedComponents: .date)
                
                Picker("Broker", selection: $selectedBroker) {
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
            
            if transactionType != .dividend {
                Section {
                    Toggle("Update asset price to this value", isOn: $setAsCurrentPrice)
                }
            }
            
            if exceedsAvailableUnits {
                Section {
                    Text("Sell units exceed the current holding for this asset.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.loss)
                }
            }
            
            Section {
                Button(action: saveTransaction) {
                    HStack {
                        Spacer()
                        Text("Save Transaction")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isValid ? AppTheme.accent : Color.gray.opacity(0.3))
                )
                .disabled(!isValid)
            }
        }
        .navigationTitle("Add Transaction")
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
    }
    
    private var isValid: Bool {
        hasPositiveValues && !exceedsAvailableUnits
    }
    
    private func saveTransaction() {
        guard let unitsValue, let priceValue else { return }
        
        let rateValue = Double(inrExchangeRate)
        let transaction = AssetTransaction(
            type: transactionType,
            units: unitsValue,
            pricePerUnit: priceValue,
            date: selectedDate,
            asset: asset,
            broker: selectedBroker,
            inrExchangeRate: rateValue
        )
        modelContext.insert(transaction)
        
        if let rateValue {
            asset.category?.lastInrExchangeRate = rateValue
        }
        
        if setAsCurrentPrice {
            asset.currentPrice = priceValue
        }
        
        dismiss()
    }
}

// MARK: - Edit Transaction Sheet

struct EditTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Broker.name) private var brokers: [Broker]
    
    let transaction: AssetTransaction
    
    @State private var transactionType: TransactionType = .buy
    @State private var units: String = ""
    @State private var pricePerUnit: String = ""
    @State private var selectedDate: Date = Date()
    @State private var selectedBroker: Broker?
    @State private var inrExchangeRate: String = ""
    
    private var asset: Asset? {
        transaction.asset
    }
    
    private var isValid: Bool {
        guard
            let priceValue = Double(pricePerUnit),
            priceValue > 0,
            let asset
        else {
            return false
        }
        
        let unitsValue = transactionType == .dividend ? 1.0 : Double(units) ?? 0.0
        guard unitsValue > 0 else { return false }
        
        if transactionType == .dividend { return true }
        
        let updatedTransaction = TransactionLedgerEntry(
            type: transactionType,
            units: unitsValue,
            date: selectedDate,
            createdAt: transaction.createdAt
        )
        let otherTransactions = asset.transactions
            .filter { $0.persistentModelID != transaction.persistentModelID }
            .map {
                TransactionLedgerEntry(
                    type: $0.type,
                    units: $0.units,
                    date: $0.date,
                    createdAt: $0.createdAt
                )
            }
        return LifoCalculator.hasSufficientUnits(entries: otherTransactions + [updatedTransaction])
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $transactionType) {
                        Text("BUY").tag(TransactionType.buy)
                        Text("SELL").tag(TransactionType.sell)
                        Text("DIVIDEND").tag(TransactionType.dividend)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }
                
                Section("Transaction Details") {
                    if transactionType == .dividend {
                        TextField("Dividend Amount", text: $pricePerUnit)
                            .keyboardType(.decimalPad)
                    } else {
                        TextField("Units", text: $units)
                            .keyboardType(.decimalPad)
                        
                        TextField("Price per Unit", text: $pricePerUnit)
                            .keyboardType(.decimalPad)
                    }
                    
                    DatePicker("Transaction Date", selection: $selectedDate, displayedComponents: .date)
                    
                    Picker("Broker", selection: $selectedBroker) {
                        Text("None").tag(nil as Broker?)
                        ForEach(brokers) { broker in
                            Text(broker.name).tag(broker as Broker?)
                        }
                    }
                    
                    if asset?.category?.currencyCode != "INR" {
                        TextField("INR Exchange Rate (1 \(asset?.category?.currencyCode ?? "") = ? INR)", text: $inrExchangeRate)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                transactionType = transaction.type
                units = String(transaction.units)
                pricePerUnit = String(transaction.pricePerUnit)
                selectedDate = transaction.date
                selectedBroker = transaction.broker
                if let rate = transaction.inrExchangeRate {
                    inrExchangeRate = String(rate)
                } else if let rate = transaction.asset?.category?.lastInrExchangeRate {
                    inrExchangeRate = String(rate)
                }
            }
        }
    }
    
    private func save() {
        guard let priceValue = Double(pricePerUnit) else { return }
        let unitsValue = transactionType == .dividend ? 1.0 : Double(units) ?? 0.0
        guard unitsValue > 0 else { return }
        
        transaction.type = transactionType
        transaction.units = unitsValue
        transaction.pricePerUnit = priceValue
        transaction.date = selectedDate
        transaction.broker = selectedBroker
        
        let rateValue = Double(inrExchangeRate)
        transaction.inrExchangeRate = rateValue
        if let rateValue {
            transaction.asset?.category?.lastInrExchangeRate = rateValue
        }
    }
}
