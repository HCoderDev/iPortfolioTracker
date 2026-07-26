//
//  BulkExchangeRateUpdateView.swift
//  PortfolioTracker
//
//  Created by Antigravity on 05/07/26.
//

import SwiftUI
import SwiftData

struct BulkExchangeRateUpdateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \AssetTransaction.date, order: .reverse) private var transactions: [AssetTransaction]
    
    @State private var rateInputs: [PersistentIdentifier: String] = [:]
    @State private var searchText = ""
    @State private var showBulkForexImportSheet = false
    
    private struct AssetGroup: Identifiable {
        var id: PersistentIdentifier { assetID }
        let assetID: PersistentIdentifier
        let assetName: String
        let currencyCode: String
        let transactions: [AssetTransaction]
    }
    
    private var foreignTransactions: [AssetTransaction] {
        transactions.filter { tx in
            tx.asset?.category?.currencyCode != "INR" && tx.asset?.category?.currencyCode != nil
        }
    }
    
    private var groupedTransactions: [AssetGroup] {
        let filtered = foreignTransactions.filter { tx in
            searchText.isEmpty || 
            (tx.asset?.name.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (tx.asset?.category?.name.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        
        let grouped = Dictionary(grouping: filtered) { $0.asset }
        var result: [AssetGroup] = []
        
        for (asset, txs) in grouped {
            guard let asset = asset else { continue }
            result.append(AssetGroup(
                assetID: asset.persistentModelID,
                assetName: asset.name,
                currencyCode: asset.category?.currencyCode ?? "USD",
                transactions: txs.sorted { $0.date > $1.date }
            ))
        }
        
        return result.sorted { $0.assetName < $1.assetName }
    }
    
    private func currencySymbol(for code: String) -> String {
        switch code.uppercased() {
        case "USD": return "$"
        case "INR": return "₹"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        default: return "\(code) "
        }
    }
    
    private func txTypeColor(_ type: TransactionType) -> Color {
        switch type {
        case .buy: return AppTheme.profit
        case .sell: return AppTheme.loss
        case .dividend: return AppTheme.warning
        }
    }
    
    private var hasChanges: Bool {
        for tx in foreignTransactions {
            let input = rateInputs[tx.persistentModelID] ?? ""
            let current = tx.inrExchangeRate
            
            if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if current != nil { return true }
            } else if let val = Double(input) {
                if current == nil || abs(current! - val) > 0.000001 {
                    return true
                }
            }
        }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search foreign assets...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            
            Divider()
            
            if groupedTransactions.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "square.dashed")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(searchText.isEmpty ? "No foreign transactions found" : "No match for your search")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(searchText.isEmpty ? "Add foreign stock transactions first." : "Try adjusting your search criteria.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                        ForEach(groupedTransactions) { group in
                            Section {
                                VStack(spacing: 12) {
                                    ForEach(group.transactions) { tx in
                                        HStack(spacing: 8) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(spacing: 6) {
                                                    Text(tx.date.formatted(date: .abbreviated, time: .shortened))
                                                        .font(.subheadline)
                                                        .fontWeight(.medium)
                                                    
                                                    Text(tx.type.rawValue)
                                                        .font(.caption2)
                                                        .fontWeight(.bold)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(txTypeColor(tx.type).opacity(0.12))
                                                        .foregroundStyle(txTypeColor(tx.type))
                                                        .clipShape(Capsule())
                                                }
                                                
                                                Text("\(tx.units.formatted2) units @ \(currencySymbol(for: group.currencyCode))\(tx.pricePerUnit.formatted2)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            VStack(alignment: .trailing, spacing: 2) {
                                                HStack(spacing: 4) {
                                                    Text("₹")
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                    
                                                    TextField("Rate", text: Binding(
                                                        get: { rateInputs[tx.persistentModelID] ?? "" },
                                                        set: { rateInputs[tx.persistentModelID] = $0 }
                                                    ))
                                                    .keyboardType(.decimalPad)
                                                    .multilineTextAlignment(.trailing)
                                                    .font(.subheadline)
                                                    .fontWeight(.bold)
                                                    .padding(.vertical, 6)
                                                    .padding(.horizontal, 8)
                                                    .background(Color(.systemGray6))
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                                    .frame(width: 90)
                                                }
                                                
                                                Text(tx.type == .sell ? "TT Buy" : "TT Sell")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                    .fontWeight(.medium)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(Color(.systemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
                                        .padding(.horizontal)
                                    }
                                }
                                .padding(.vertical, 6)
                            } header: {
                                HStack {
                                    Image(systemName: "globe")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.accent)
                                    Text(group.assetName)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(AppTheme.accent)
                                    Text("(\(group.currencyCode))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Exchange Rates Update")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showBulkForexImportSheet = true
                } label: {
                    Label("Import File", systemImage: "doc.badge.plus")
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveAll()
                }
                .disabled(!hasChanges)
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showBulkForexImportSheet) {
            BulkForexImportSheet()
        }
        .onChange(of: showBulkForexImportSheet) { _, isPresented in
            if !isPresented {
                initializeRateInputs()
            }
        }
        .onAppear {
            initializeRateInputs()
        }
    }
    
    private func initializeRateInputs() {
        for tx in foreignTransactions {
            if let rate = tx.inrExchangeRate {
                rateInputs[tx.persistentModelID] = String(format: "%.2f", rate)
            } else {
                rateInputs[tx.persistentModelID] = ""
            }
        }
    }
    
    private func saveAll() {
        for tx in foreignTransactions {
            if let input = rateInputs[tx.persistentModelID] {
                let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    tx.inrExchangeRate = nil
                } else if let val = Double(trimmed) {
                    tx.inrExchangeRate = val
                }
            }
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save context in BulkExchangeRateUpdateView: \(error)")
        }
    }
}

#Preview {
    let previewModels: [any PersistentModel.Type] = [
        User.self,
        Currency.self,
        Category.self,
        Asset.self,
        Broker.self,
        AssetTransaction.self,
        AssetNote.self,
        SubCategory.self,
        StockValueAnalysis.self,
        AssetReminder.self,
        PortfolioSnapshot.self,
        CategorySnapshot.self,
        AssetSnapshot.self,
    ]
    
    BulkExchangeRateUpdateView()
        .modelContainer(for: previewModels, inMemory: true)
}
