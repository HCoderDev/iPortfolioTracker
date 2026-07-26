//
//  CurrencyListView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct CurrencyListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Currency.code) private var currencies: [Currency]
    
    @State private var showAddSheet = false
    @State private var currencyToEdit: Currency?
    
    var body: some View {
        List {
            if currencies.isEmpty {
                ContentUnavailableView(
                    "No Currencies",
                    systemImage: "dollarsign.circle",
                    description: Text("Add a currency to get started.")
                )
            } else {
                ForEach(currencies) { currency in
                    CurrencyRow(currency: currency, onEdit: {
                        currencyToEdit = currency
                    }, onSetDefault: {
                        setDefault(currency)
                    }, onDelete: {
                        deleteCurrency(currency)
                    })
                }
                .onDelete(perform: deleteCurrencies)
            }
        }
        .navigationTitle("Currencies")
        .onAppear {
            PortfolioMetrics.normalizeDefaultCurrencies(currencies)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            CurrencyFormSheet(currency: nil)
        }
        .sheet(item: $currencyToEdit) { currency in
            CurrencyFormSheet(currency: currency)
        }
    }
    
    private func setDefault(_ currency: Currency) {
        currency.isDefault = true
        PortfolioMetrics.normalizeDefaultCurrencies(currencies)
    }
    
    private func deleteCurrencies(offsets: IndexSet) {
        let deletedCurrencyIDs = offsets.map { currencies[$0].persistentModelID }
        for index in offsets {
            modelContext.delete(currencies[index])
        }
        
        let remaining = currencies.filter { !deletedCurrencyIDs.contains($0.persistentModelID) }
        PortfolioMetrics.normalizeDefaultCurrencies(remaining)
    }
    
    private func deleteCurrency(_ currency: Currency) {
        modelContext.delete(currency)
        let remaining = currencies.filter { $0.persistentModelID != currency.persistentModelID }
        PortfolioMetrics.normalizeDefaultCurrencies(remaining)
    }
}

// MARK: - Currency Row

struct CurrencyRow: View {
    let currency: Currency
    let onEdit: () -> Void
    let onSetDefault: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(currency.code)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    if currency.isDefault {
                        Text("DEFAULT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent)
                            .clipShape(Capsule())
                    }
                }
                
                Text("Exchange Rate: \(currency.exchangeRate.formatted2)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if !currency.isDefault {
                Button("Set Default") {
                    onSetDefault()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(AppTheme.accent)
            }
            
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .foregroundStyle(AppTheme.accent)
            }
            .buttonStyle(.plain)
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash.circle.fill")
                    .foregroundStyle(AppTheme.loss)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Currency Form Sheet

struct CurrencyFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Currency.code) private var currencies: [Currency]
    
    let currency: Currency?
    
    @State private var code: String = ""
    @State private var exchangeRate: String = "1.0"
    @State private var isDefault: Bool = false
    private var defaultCurrency: Currency? {
        PortfolioMetrics.defaultCurrency(in: currencies)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Currency Details") {
                    TextField("Currency Code (e.g. INR, USD)", text: $code)
                        .textInputAutocapitalization(.characters)
                    
                    TextField(code.isEmpty ? "Exchange Rate" : "Exchange Rate (1 \(code.uppercased()) = ? \(defaultCurrency?.code ?? "Default"))", text: $exchangeRate)
                        .keyboardType(.decimalPad)
                    
                    Toggle("Set as Default", isOn: $isDefault)
                }
                
                if currency != nil {
                    Section {
                        Button("Delete Currency", role: .destructive) {
                            deleteCurrency()
                        }
                    }
                }
            }
            .navigationTitle(currency == nil ? "Add Currency" : "Edit Currency")
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
                    .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || (Double(exchangeRate) ?? 0) <= 0)
                }
            }
            .onAppear {
                if let currency = currency {
                    code = currency.code
                    exchangeRate = String(currency.exchangeRate)
                    isDefault = currency.isDefault
                }
            }
        }
    }
    
    private func save() {
        guard
            let rate = Double(exchangeRate),
            rate > 0,
            !code.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            return
        }
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let shouldDefault = isDefault || currencies.isEmpty
        
        if let currency = currency {
            currency.code = normalizedCode
            currency.exchangeRate = rate
            currency.isDefault = shouldDefault
            PortfolioMetrics.normalizeDefaultCurrencies(currencies)
        } else {
            let newCurrency = Currency(code: normalizedCode, exchangeRate: rate, isDefault: shouldDefault)
            modelContext.insert(newCurrency)
            PortfolioMetrics.normalizeDefaultCurrencies(currencies + [newCurrency])
        }
    }
    
    private func deleteCurrency() {
        guard let currency else { return }
        modelContext.delete(currency)
        let remaining = currencies.filter { $0.persistentModelID != currency.persistentModelID }
        PortfolioMetrics.normalizeDefaultCurrencies(remaining)
        dismiss()
    }
}
