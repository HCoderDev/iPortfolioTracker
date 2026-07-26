//
//  StockSplitMergeView.swift
//  PortfolioTracker
//
//  Created by Antigravity on 18/06/26.
//

import SwiftUI
import SwiftData

struct StockSplitMergeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Asset.name) private var assets: [Asset]
    
    @State private var selectedTab = 0 // 0 = Stock Split, 1 = Asset Merger
    
    // MARK: - Stock Split State
    @State private var selectedSplitAsset: Asset?
    @State private var splitDate = Date()
    @State private var oldSharesString = "1"
    @State private var newSharesString = ""
    @State private var adjustCurrentPrice = true
    @State private var showSplitConfirmation = false
    
    // MARK: - Merger State
    @State private var sourceAsset: Asset?
    @State private var targetAsset: Asset?
    @State private var mergerDate = Date()
    @State private var sourceSharesString = "1"
    @State private var targetSharesString = ""
    @State private var deleteSourceIfEmpty = true
    @State private var showMergerConfirmation = false
    
    // MARK: - Toast State
    @State private var showSuccessToast = false
    @State private var successMessage = ""
    
    // Only show investments for splits and mergers
    private var investmentAssets: [Asset] {
        assets.filter { $0.holdingType == .investment }
    }
    
    private var isFormValid: Bool {
        if selectedTab == 0 {
            guard selectedSplitAsset != nil else { return false }
            guard (Double(oldSharesString) ?? 0.0) > 0 else { return false }
            guard (Double(newSharesString) ?? 0.0) > 0 else { return false }
            return true
        } else {
            guard let src = sourceAsset, let tgt = targetAsset, src.persistentModelID != tgt.persistentModelID else { return false }
            guard (Double(sourceSharesString) ?? 0.0) > 0 else { return false }
            guard (Double(targetSharesString) ?? 0.0) > 0 else { return false }
            return true
        }
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Custom segmented tab bar
                    tabSelector
                        .padding(.top, 8)
                    
                    if selectedTab == 0 {
                        stockSplitFormCard
                        stockSplitPreviewCard
                    } else {
                        assetMergerFormCard
                        assetMergerPreviewCard
                    }
                    
                    actionButton
                        .padding(.top, 10)
                    
                    Spacer(minLength: 40)
                }
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Stock Splits & Mergers")
            .navigationBarTitleDisplayMode(.inline)
            
            // Success Toast
            if showSuccessToast {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.profit)
                            .font(.title2)
                        Text(successMessage)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 24)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.25), radius: 10, y: 5)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showSuccessToast)
        .confirmationDialog("Confirm Stock Split?", isPresented: $showSplitConfirmation, titleVisibility: .visible) {
            Button("Execute Split", role: .none) {
                executeSplit()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let asset = selectedSplitAsset,
               Double(oldSharesString) != nil,
               Double(newSharesString) != nil {
                Text("Are you sure you want to apply a \(newSharesString)-for-\(oldSharesString) split to all \(asset.name) transactions on or before \(splitDate.formatted(date: .abbreviated, time: .omitted))?")
            }
        }
        .confirmationDialog("Confirm Asset Merger?", isPresented: $showMergerConfirmation, titleVisibility: .visible) {
            Button("Execute Merger", role: .none) {
                executeMerger()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let src = sourceAsset,
               let tgt = targetAsset,
               Double(sourceSharesString) != nil,
               Double(targetSharesString) != nil {
                Text("Are you sure you want to merge \(src.name) into \(tgt.name) at a ratio of \(targetSharesString)-for-\(sourceSharesString) for transactions on or before \(mergerDate.formatted(date: .abbreviated, time: .omitted))?")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(0..<2) { index in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                } label: {
                    Text(index == 0 ? "Stock Split" : "Asset Merger")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(selectedTab == index ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedTab == index ? AppTheme.accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
    
    private var stockSplitFormCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Select Stock")
                    .font(.body)
                    .fontWeight(.semibold)
                Spacer()
                Picker("Stock", selection: $selectedSplitAsset) {
                    Text("Select Stock").tag(nil as Asset?)
                    ForEach(investmentAssets) { asset in
                        Text(asset.name).tag(asset as Asset?)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Divider()
            
            DatePicker("Split Date", selection: $splitDate, displayedComponents: .date)
                .font(.body)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Split Ratio")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Old Shares")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        TextField("e.g. 1", text: $oldSharesString)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("New Shares")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        TextField("e.g. 5", text: $newSharesString)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                
                Text("E.g. A 5-for-1 split: Old Shares = 1, New Shares = 5. A 1-for-10 reverse split: Old Shares = 10, New Shares = 1.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            
            Divider()
            
            Toggle(isOn: $adjustCurrentPrice) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Adjust Current Price")
                        .font(.body)
                        .fontWeight(.semibold)
                    Text("Auto-scale the current asset price to match the split ratio.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.accent)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    private var stockSplitPreviewCard: some View {
        Group {
            if let asset = selectedSplitAsset,
               let old = Double(oldSharesString), old > 0,
               let new = Double(newSharesString), new > 0 {
                
                let ratio = new / old
                let affectedTx = asset.transactions.filter { $0.date <= splitDate && $0.type != .dividend }
                let txCount = affectedTx.count
                let currentUnits = PortfolioMetrics.totalUnits(for: affectedTx)
                let postSplitUnits = currentUnits * ratio
                let currency = asset.category?.currencyCode ?? ""
                let currencySym = currencySymbol(for: currency)
                
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "eye.fill")
                            .foregroundStyle(AppTheme.accentSecondary)
                        Text("Split Summary Preview")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    
                    Divider()
                    
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                        GridRow {
                            previewMetric(title: "AFFECTED TRANSACTIONS", value: "\(txCount) txs")
                            previewMetric(title: "SPLIT FACTOR", value: String(format: "%.4g → %.4g (%.3fx)", old, new, ratio))
                        }
                        GridRow {
                            previewMetric(title: "UNITS (BEFORE → AFTER)", value: String(format: "%.4f → %.4f", currentUnits, postSplitUnits))
                            if adjustCurrentPrice {
                                let oldPrice = asset.currentPrice
                                let newPrice = oldPrice / ratio
                                previewMetric(title: "PRICE (BEFORE → AFTER)", value: String(format: "%@%.2f → %@%.2f", currencySym, oldPrice, currencySym, newPrice))
                            } else {
                                previewMetric(title: "PRICE (BEFORE → AFTER)", value: "No adjustment")
                            }
                        }
                    }
                }
                .padding(16)
                .background(AppTheme.cardBackgroundElevated)
                .colorScheme(.dark)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }
    
    private var assetMergerFormCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Source Stock")
                    .font(.body)
                    .fontWeight(.semibold)
                Spacer()
                Picker("Source Stock", selection: $sourceAsset) {
                    Text("Select Source").tag(nil as Asset?)
                    ForEach(investmentAssets) { asset in
                        Text(asset.name).tag(asset as Asset?)
                    }
                }
                .pickerStyle(.menu)
            }
            .onChange(of: sourceAsset) { oldValue, newValue in
                if targetAsset?.persistentModelID == newValue?.persistentModelID {
                    targetAsset = nil
                }
            }
            
            Divider()
            
            HStack {
                Text("Target Stock")
                    .font(.body)
                    .fontWeight(.semibold)
                Spacer()
                Picker("Target Stock", selection: $targetAsset) {
                    Text("Select Target").tag(nil as Asset?)
                    ForEach(investmentAssets.filter { $0.persistentModelID != sourceAsset?.persistentModelID }) { asset in
                        Text(asset.name).tag(asset as Asset?)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Divider()
            
            DatePicker("Merger Date", selection: $mergerDate, displayedComponents: .date)
                .font(.body)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Merger Ratio")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Source Shares")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        TextField("e.g. 1", text: $sourceSharesString)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Target Shares")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        TextField("e.g. 0.5", text: $targetSharesString)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                
                Text("E.g. If you receive 0.5 Target shares for every 1 Source share: Source Shares = 1, Target Shares = 0.5.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            
            Divider()
            
            Toggle(isOn: $deleteSourceIfEmpty) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Delete Source Asset")
                        .font(.body)
                        .fontWeight(.semibold)
                    Text("Delete the source asset if it has no remaining transactions after the merger.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.accent)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    private var assetMergerPreviewCard: some View {
        Group {
            if let src = sourceAsset,
               let tgt = targetAsset,
               let srcShares = Double(sourceSharesString), srcShares > 0,
               let tgtShares = Double(targetSharesString), tgtShares > 0 {
                
                let ratio = tgtShares / srcShares
                let affectedTx = src.transactions.filter { $0.date <= mergerDate }
                let txCount = affectedTx.count
                let sourceUnits = PortfolioMetrics.totalUnits(for: affectedTx)
                let targetUnitsReceived = sourceUnits * ratio
                
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "eye.fill")
                            .foregroundStyle(AppTheme.accentSecondary)
                        Text("Merger Summary Preview")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    
                    Divider()
                    
                    if let srcCurrency = src.category?.currencyCode,
                       let tgtCurrency = tgt.category?.currencyCode,
                       srcCurrency != tgtCurrency {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppTheme.warning)
                                .font(.footnote)
                            Text("Currency Mismatch: Source is \(srcCurrency), Target is \(tgtCurrency). Make sure your merger ratio accounts for the exchange rate difference.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.warning)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.warning.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                        GridRow {
                            previewMetric(title: "TXS TO CONVERT", value: "\(txCount) transactions")
                            previewMetric(title: "MERGER RATIO", value: String(format: "%.4g : %.4g (%.3fx)", srcShares, tgtShares, ratio))
                        }
                        GridRow {
                            previewMetric(title: "SOURCE UNITS TO MERGE", value: String(format: "%.4f %@", sourceUnits, src.name))
                            previewMetric(title: "TARGET UNITS RECEIVED", value: String(format: "%.4f %@", targetUnitsReceived, tgt.name))
                        }
                    }
                }
                .padding(16)
                .background(AppTheme.cardBackgroundElevated)
                .colorScheme(.dark)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }
    
    private var actionButton: some View {
        Button {
            hideKeyboard()
            if selectedTab == 0 {
                showSplitConfirmation = true
            } else {
                showMergerConfirmation = true
            }
        } label: {
            Text(selectedTab == 0 ? "Execute Stock Split" : "Execute Asset Merger")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    isFormValid ? AppTheme.heroGradient : LinearGradient(colors: [Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: isFormValid ? AppTheme.accent.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
        .disabled(!isFormValid)
    }
    
    @ViewBuilder
    private func previewMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Business Logic
    
    private func executeSplit() {
        guard let asset = selectedSplitAsset,
              let old = Double(oldSharesString), old > 0,
              let new = Double(newSharesString), new > 0
        else { return }
        
        let ratio = new / old
        
        // Find transactions on or before split date
        let targetTxs = asset.transactions.filter { $0.date <= splitDate }
        
        for tx in targetTxs {
            if tx.type != .dividend {
                tx.units *= ratio
                tx.pricePerUnit /= ratio
            }
        }
        
        if adjustCurrentPrice {
            asset.currentPrice /= ratio
        }
        
        do {
            try modelContext.save()
            
            // Show toast & Dismiss
            successMessage = "Split applied successfully!"
            showSuccessToast = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } catch {
            print("Failed to save stock split updates: \(error)")
        }
    }
    
    private func executeMerger() {
        guard let src = sourceAsset,
              let tgt = targetAsset,
              let srcShares = Double(sourceSharesString), srcShares > 0,
              let tgtShares = Double(targetSharesString), tgtShares > 0
        else { return }
        
        let ratio = tgtShares / srcShares
        
        // Find transactions of source stock on or before merger date
        let targetTxs = src.transactions.filter { $0.date <= mergerDate }
        
        for tx in targetTxs {
            tx.asset = tgt
            if tx.type != .dividend {
                tx.units *= ratio
                tx.pricePerUnit /= ratio
            }
        }
        
        // Delete source if requested and has no remaining transactions
        if deleteSourceIfEmpty {
            let remainingTxs = src.transactions.filter { $0.date > mergerDate }
            if remainingTxs.isEmpty {
                modelContext.delete(src)
            }
        }
        
        do {
            try modelContext.save()
            
            // Show toast & Dismiss
            successMessage = "Merger applied successfully!"
            showSuccessToast = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } catch {
            print("Failed to save merger updates: \(error)")
        }
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
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
    
    NavigationStack {
        StockSplitMergeView()
            .modelContainer(for: previewModels, inMemory: true)
    }
}
