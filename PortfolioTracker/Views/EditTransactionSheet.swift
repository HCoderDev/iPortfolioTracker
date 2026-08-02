//
//  EditTransactionSheet.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct EditTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Broker.name) private var brokers: [Broker]
    
    let transaction: AssetTransaction
    
    @State private var selectedConfig: TransactionTypeConfig
    @State private var amountInput: String = ""
    @State private var unitsInput: String = ""
    @State private var pricePerUnitInput: String = ""
    @State private var notesInput: String = ""
    @State private var selectedDate: Date = Date()
    @State private var selectedBroker: Broker?
    @State private var inrExchangeRate: String = ""
    
    private var asset: Asset? {
        transaction.asset
    }
    
    private var investmentConfig: InvestmentTypeConfig {
        if let asset {
            return TransactionTypeRegistry.shared.config(for: asset.holdingType)
        }
        return TransactionTypeRegistry.shared.config(for: .investment)
    }
    
    private var isUnitized: Bool {
        selectedConfig.isUnitBased
    }
    
    init(transaction: AssetTransaction) {
        self.transaction = transaction
        let cfg = transaction.config
        _selectedConfig = State(initialValue: cfg)
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
    
    private var isValid: Bool {
        guard let amt = parsedAmount, amt > 0 else { return false }
        return true
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Transaction Type") {
                    Picker("Action", selection: $selectedConfig) {
                        ForEach(investmentConfig.allowedTransactions) { cfg in
                            Label(cfg.displayName, systemImage: cfg.iconName).tag(cfg)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Transaction Details") {
                    if isUnitized {
                        TextField("Units", text: $unitsInput)
                            .keyboardType(.decimalPad)
                        
                        TextField("Price per Unit", text: $pricePerUnitInput)
                            .keyboardType(.decimalPad)
                    } else {
                        TextField("Amount", text: $amountInput)
                            .keyboardType(.decimalPad)
                    }
                    
                    DatePicker("Transaction Date", selection: $selectedDate, displayedComponents: .date)
                    
                    TextField("Notes / Remarks", text: $notesInput)
                    
                    Picker("Broker / Account", selection: $selectedBroker) {
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
                selectedConfig = transaction.config
                if isUnitized {
                    unitsInput = String(transaction.units)
                    pricePerUnitInput = String(transaction.pricePerUnit)
                } else {
                    amountInput = String(transaction.amount)
                }
                notesInput = transaction.notes ?? ""
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
        guard let amt = parsedAmount, amt > 0 else { return }
        
        transaction.rawType = selectedConfig.rawType
        if isUnitized {
            transaction.units = Double(unitsInput) ?? 1.0
            transaction.pricePerUnit = Double(pricePerUnitInput) ?? amt
        } else {
            transaction.units = 1.0
            transaction.pricePerUnit = amt
        }
        
        transaction.date = selectedDate
        transaction.notes = notesInput.isEmpty ? nil : notesInput
        transaction.broker = selectedBroker
        
        let rateValue = Double(inrExchangeRate)
        transaction.inrExchangeRate = rateValue
        if let rateValue {
            transaction.asset?.category?.lastInrExchangeRate = rateValue
        }
    }
}
