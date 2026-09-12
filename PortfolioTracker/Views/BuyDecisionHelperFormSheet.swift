//
//  BuyDecisionHelperFormSheet.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct BuyDecisionHelperFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Asset.name) private var allAssets: [Asset]
    
    let helperToEdit: BuyDecisionHelper?
    let preselectedAsset: Asset?
    
    @State private var selectedAssetID: PersistentIdentifier?
    @State private var name: String = ""
    @State private var ticker: String = ""
    @State private var currentPriceString: String = ""
    @State private var currencyCode: String = "USD"
    @State private var notes: String = ""
    
    @State private var strongBuyString: String = ""
    @State private var buyString: String = ""
    @State private var accumulateString: String = ""
    @State private var holdString: String = ""
    @State private var avoidString: String = ""
    
    @State private var validationError: String?
    
    init(helperToEdit: BuyDecisionHelper? = nil, preselectedAsset: Asset? = nil) {
        self.helperToEdit = helperToEdit
        self.preselectedAsset = preselectedAsset
    }
    
    private var isEditing: Bool {
        helperToEdit != nil
    }
    
    private var selectedAsset: Asset? {
        if let id = selectedAssetID {
            return allAssets.first(where: { $0.persistentModelID == id })
        }
        return preselectedAsset
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Entry Target Type (Linked Asset vs Non-Existent Entry)
                Section("Target Asset") {
                    Picker("Link to Portfolio Asset", selection: $selectedAssetID) {
                        Text("None (Standalone / Watchlist Entry)").tag(PersistentIdentifier?.none)
                        ForEach(allAssets) { asset in
                            Text("\(asset.name)\(asset.ticker.isEmpty ? "" : " (\(asset.ticker))")").tag(PersistentIdentifier?.some(asset.persistentModelID))
                        }
                    }
                    
                    if let asset = selectedAsset {
                        HStack {
                            Text("Current Price (CMP)")
                            Spacer()
                            Text("\(asset.category?.currencyCode ?? "USD") \(asset.currentPrice.formattedComma)")
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.accent)
                        }
                    } else {
                        TextField("Asset Name (e.g. NVIDIA)", text: $name)
                        TextField("Ticker Symbol (e.g. NVDA)", text: $ticker)
                            .textInputAutocapitalization(.characters)
                        
                        HStack {
                            Text("Current Market Price")
                            Spacer()
                            TextField("0.00", text: $currentPriceString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                        
                        Picker("Currency", selection: $currencyCode) {
                            Text("USD ($)").tag("USD")
                            Text("INR (₹)").tag("INR")
                            Text("EUR (€)").tag("EUR")
                            Text("GBP (£)").tag("GBP")
                        }
                    }
                }
                
                // Section 2: Decision Rating Target Bands
                Section {
                    HStack {
                        Label("Strong Buy ≤", systemImage: "flame.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                        Spacer()
                        TextField("0.00", text: $strongBuyString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Label("Buy ≤", systemImage: "cart.fill.badge.plus")
                            .foregroundStyle(AppTheme.gain)
                            .font(.subheadline)
                        Spacer()
                        TextField("0.00", text: $buyString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Label("Accumulate ≤", systemImage: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(.blue)
                            .font(.subheadline)
                        Spacer()
                        TextField("0.00", text: $accumulateString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Label("Hold ≤", systemImage: "pause.fill")
                            .foregroundStyle(.orange)
                            .font(.subheadline)
                        Spacer()
                        TextField("0.00", text: $holdString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Label("Avoid / Sell >", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                        Spacer()
                        TextField("Auto ( > Hold)", text: $avoidString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                } header: {
                    Text("Decision Price Thresholds")
                } footer: {
                    Text("Prices equal to or below the upper bound will trigger that decision rating.")
                }
                
                // Section 3: Live Rating Preview
                Section("Live Rating Preview") {
                    let previewCMP = selectedAsset?.currentPrice ?? (Double(currentPriceString) ?? 0.0)
                    let previewRating = computePreviewRating(cmp: previewCMP)
                    
                    HStack {
                        Text("Current Rating")
                            .font(.subheadline)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: previewRating.icon)
                            Text(previewRating.rawValue)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(previewRating.color.opacity(0.15))
                        .foregroundStyle(previewRating.color)
                        .clipShape(Capsule())
                    }
                }
                
                // Section 4: Notes
                Section("Rationale & Notes") {
                    TextField("Add notes, catalyst rationale, or target valuation P/E...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                if let error = validationError {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Decision Helper" : "New Buy Decision Helper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveHelper()
                    }
                }
            }
            .onAppear {
                populateForm()
            }
        }
    }
    
    private func populateForm() {
        if let helper = helperToEdit {
            selectedAssetID = helper.asset?.persistentModelID
            name = helper.name
            ticker = helper.ticker
            currentPriceString = helper.currentPrice > 0 ? String(helper.currentPrice) : ""
            currencyCode = helper.currencyCode
            notes = helper.notes
            
            strongBuyString = helper.strongBuyPrice > 0 ? String(helper.strongBuyPrice) : ""
            buyString = helper.buyPrice > 0 ? String(helper.buyPrice) : ""
            accumulateString = helper.accumulatePrice > 0 ? String(helper.accumulatePrice) : ""
            holdString = helper.holdPrice > 0 ? String(helper.holdPrice) : ""
            avoidString = helper.avoidPrice > 0 ? String(helper.avoidPrice) : ""
        } else if let asset = preselectedAsset {
            selectedAssetID = asset.persistentModelID
            name = asset.name
            ticker = asset.ticker
            currencyCode = asset.category?.currencyCode ?? "USD"
        }
    }
    
    private func computePreviewRating(cmp: Double) -> BuyDecisionRating {
        let sb = Double(strongBuyString) ?? 0.0
        let b = Double(buyString) ?? 0.0
        let acc = Double(accumulateString) ?? 0.0
        let h = Double(holdString) ?? 0.0
        
        guard cmp > 0 else { return .hold }
        if sb > 0 && cmp <= sb { return .strongBuy }
        if b > 0 && cmp <= b { return .buy }
        if acc > 0 && cmp <= acc { return .accumulate }
        if h > 0 && cmp <= h { return .hold }
        return .avoidSell
    }
    
    private func saveHelper() {
        let sb = Double(strongBuyString) ?? 0.0
        let b = Double(buyString) ?? 0.0
        let acc = Double(accumulateString) ?? 0.0
        let h = Double(holdString) ?? 0.0
        let av = Double(avoidString) ?? (h > 0 ? h : 0.0)
        let cmp = Double(currentPriceString) ?? 0.0
        
        if selectedAssetID == nil && name.trimmingCharacters(in: .whitespaces).isEmpty {
            validationError = "Please enter an Asset Name or link to a Portfolio Asset."
            return
        }
        
        let targetAsset = selectedAsset
        
        if let helper = helperToEdit {
            helper.asset = targetAsset
            helper.name = name.trimmingCharacters(in: .whitespaces)
            helper.ticker = ticker.trimmingCharacters(in: .whitespaces).uppercased()
            helper.currentPrice = cmp
            helper.currencyCode = currencyCode
            helper.notes = notes
            helper.strongBuyPrice = sb
            helper.buyPrice = b
            helper.accumulatePrice = acc
            helper.holdPrice = h
            helper.avoidPrice = av
            helper.updatedAt = Date()
        } else {
            let newHelper = BuyDecisionHelper(
                name: name.trimmingCharacters(in: .whitespaces),
                ticker: ticker.trimmingCharacters(in: .whitespaces).uppercased(),
                currentPrice: cmp,
                currencyCode: currencyCode,
                notes: notes,
                strongBuyPrice: sb,
                buyPrice: b,
                accumulatePrice: acc,
                holdPrice: h,
                avoidPrice: av,
                asset: targetAsset
            )
            modelContext.insert(newHelper)
        }
        
        dismiss()
    }
}
