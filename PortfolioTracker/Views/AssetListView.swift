//
//  AssetListView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct AssetListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.name) private var assets: [Asset]
    @Query(sort: \Category.name) private var categories: [Category]
    
    @State private var showAddSheet = false
    @State private var assetToEdit: Asset?
    @State private var searchText = ""

    private var groupedAssets: [AssetSectionData] {
        let filteredAssets = searchText.isEmpty ? assets : assets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        var sections = categories.compactMap { category -> AssetSectionData? in
            let sectionAssets = filteredAssets.filter { $0.category?.persistentModelID == category.persistentModelID }
            guard !sectionAssets.isEmpty else { return nil }
            return AssetSectionData(
                id: "category-\(category.persistentModelID)",
                title: category.name,
                assets: sectionAssets
            )
        }

        let uncategorizedAssets = filteredAssets.filter { $0.category == nil }
        if !uncategorizedAssets.isEmpty {
            sections.append(
                AssetSectionData(
                    id: "uncategorized",
                    title: "Uncategorized",
                    assets: uncategorizedAssets
                )
            )
        }

        return sections
    }
    
    @State private var viewMode = 0 // 0 = Summary (AllAssetsView), 1 = Manage Assets
    
    var body: some View {
        VStack(spacing: 0) {
            if viewMode == 0 {
                AllAssetsView()
            } else {
                List {
                    if groupedAssets.isEmpty {
                        if searchText.isEmpty {
                            ContentUnavailableView(
                                "No Assets",
                                systemImage: "chart.line.uptrend.xyaxis",
                                description: Text("Add an asset to start tracking.")
                            )
                        } else {
                            ContentUnavailableView.search(text: searchText)
                        }
                    } else {
                        ForEach(groupedAssets) { section in
                            Section(section.title) {
                                ForEach(section.assets) { asset in
                                    AssetRow(asset: asset, onEdit: {
                                        assetToEdit = asset
                                    }, onDelete: {
                                        deleteAsset(asset)
                                    })
                                }
                                .onDelete { offsets in
                                    deleteAssets(in: section.assets, offsets: offsets)
                                }
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search Assets")
            }
        }
        .navigationTitle(viewMode == 0 ? "All Assets" : "Manage Assets")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Asset.self) { asset in
            AssetDetailView(asset: asset)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink(destination: AssetMoreToolsView()) {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
            
            ToolbarItem(placement: .principal) {
                Picker("View Mode", selection: $viewMode) {
                    Text("Summary").tag(0)
                    Text("Manage").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            
            ToolbarItem(placement: .primaryAction) {
                if viewMode == 1 {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .disabled(categories.isEmpty)
                } else {
                    Spacer()
                        .frame(width: 24)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AssetFormSheet(asset: nil, categories: categories)
        }
        .sheet(item: $assetToEdit) { asset in
            AssetFormSheet(asset: asset, categories: categories)
        }
    }
    
    private func deleteAssets(in sectionAssets: [Asset], offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sectionAssets[index])
        }
    }
    
    private func deleteAsset(_ asset: Asset) {
        modelContext.delete(asset)
    }
}

struct AssetSectionData: Identifiable {
    let id: String
    let title: String
    let assets: [Asset]
}

// MARK: - Asset Row

struct AssetRow: View {
    let asset: Asset
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            NavigationLink(value: asset) {
                AssetRowContent(asset: asset)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
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

struct AssetRowContent: View {
    let asset: Asset
    
    private var currentValue: Double {
        PortfolioMetrics.currentValue(for: asset)
    }
    
    private var subtitleText: String {
        switch asset.holdingType {
        case .investment:
            let units = PortfolioMetrics.totalUnits(for: asset)
            return "Units: \(units.formatted2) · Value: \(currentValue.formattedComma)"
        case .bankBalance:
            return "Current Balance: \(currentValue.formattedComma)"
        case .fixedDeposit:
            var text = "Principal: \((asset.principalAmount > 0 ? asset.principalAmount : currentValue).formattedComma)"
            if asset.interestRate > 0 {
                text += " · \(asset.interestRate.formatted2)%"
            }
            if asset.payoutFrequency != "cumulative" {
                text += " (\(asset.payoutFrequency.capitalized) Payout)"
            }
            return text
        case .postOffice:
            var text = "Current Value: \(currentValue.formattedComma)"
            if asset.interestRate > 0 {
                text += " · \(asset.interestRate.formatted2)%"
            }
            return text
        case .epf:
            var text = "Accumulated Balance: \(currentValue.formattedComma)"
            if asset.interestRate > 0 {
                text += " · \(asset.interestRate.formatted2)%"
            }
            return text
        case .insuranceAnnuity:
            var text = "Policy Value: \(currentValue.formattedComma)"
            if asset.premiumAmount > 0 {
                text += " · Premium: \(asset.premiumAmount.formattedComma)/yr"
            }
            return text
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(asset.name)
                    .font(.headline)
                
                if !asset.ticker.isEmpty {
                    Text(asset.ticker.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                Text(asset.holdingType.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }
            
            HStack(spacing: 8) {
                Text("Category: \(asset.category?.name ?? "Uncategorized")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                let status = PortfolioMetrics.recencyStatus(for: asset)
                HStack(spacing: 3) {
                    Circle().fill(status.color).frame(width: 5, height: 5)
                    Text("Last Buy: \(PortfolioMetrics.lastInvestedFormattedText(for: asset))")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(status.color)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(status.color.opacity(0.12))
                .clipShape(Capsule())
            }
            
            Text(subtitleText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Asset Form Sheet

struct AssetFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let asset: Asset?
    let categories: [Category]
    let initialCategory: Category?
    
    init(asset: Asset? = nil, categories: [Category], initialCategory: Category? = nil) {
        self.asset = asset
        self.categories = categories
        self.initialCategory = initialCategory
    }
    
    @State private var name: String = ""
    @State private var ticker: String = ""
    @State private var selectedCategory: Category?
    @State private var selectedSubCategory: SubCategory?
    @State private var selectedHoldingType: HoldingType = .investment
    
    // Dynamic fields per holding type
    @State private var currentBalanceStr: String = ""
    @State private var principalAmountStr: String = ""
    @State private var interestRateStr: String = ""
    @State private var hasMaturityDate: Bool = false
    @State private var maturityDate: Date = Date().addingTimeInterval(365 * 86400 * 5)
    @State private var payoutFrequency: String = "cumulative"
    @State private var premiumAmountStr: String = ""
    @State private var premiumTermYearsStr: String = ""
    @State private var policyNumber: String = ""
    @State private var institutionName: String = ""
    @State private var isCompleted: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Investment Classification") {
                    Picker("Investment Type", selection: $selectedHoldingType) {
                        ForEach(HoldingType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Category", selection: $selectedCategory) {
                        Text("Select Category").tag(nil as Category?)
                        ForEach(categories) { category in
                            Text("\(category.name) (\(category.currencyCode))").tag(category as Category?)
                        }
                    }
                    .onChange(of: selectedCategory) { oldValue, newValue in
                        if selectedSubCategory?.category != newValue {
                            selectedSubCategory = nil
                        }
                    }
                }
                
                Section("Basic Information") {
                    let placeholder = namePlaceholder
                    TextField(placeholder, text: $name)
                    
                    if selectedHoldingType == .investment {
                        TextField("Ticker / Symbol (e.g. RELIANCE, AAPL)", text: $ticker)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                        
                        if let category = selectedCategory {
                            Picker("Subcategory", selection: $selectedSubCategory) {
                                Text("Unassigned").tag(nil as SubCategory?)
                                ForEach(category.subCategories.sorted(by: { $0.name.localizedCompare($1.name) == .orderedAscending })) { subCat in
                                    Text(subCat.name).tag(subCat as SubCategory?)
                                }
                            }
                        }
                    } else if selectedHoldingType == .bankBalance || selectedHoldingType == .fixedDeposit || selectedHoldingType == .insuranceAnnuity {
                        TextField("Institution / Bank Name (Optional)", text: $institutionName)
                    }
                }
                
                // Specific Fields per Type
                switch selectedHoldingType {
                case .investment:
                    Section("Investment Note") {
                        Text("Transactions (Buy/Sell) can be added on the asset details page after saving.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                case .bankBalance:
                    Section("Account Balance") {
                        TextField("Current Account Balance", text: $currentBalanceStr)
                            .keyboardType(.decimalPad)
                    }
                    
                case .fixedDeposit:
                    Section("Fixed Deposit / RD Parameters") {
                        TextField("Principal Deposited Amount", text: $principalAmountStr)
                            .keyboardType(.decimalPad)
                        
                        TextField("Interest Rate (% p.a., e.g., 7.5)", text: $interestRateStr)
                            .keyboardType(.decimalPad)
                        
                        Picker("Interest Payout Mode", selection: $payoutFrequency) {
                            Text("Cumulative (Maturity Compounded)").tag("cumulative")
                            Text("Monthly Payout").tag("monthly")
                            Text("Quarterly Payout").tag("quarterly")
                            Text("Annual Payout").tag("annual")
                        }
                        .pickerStyle(.menu)
                        
                        TextField("Current Total Balance / Value", text: $currentBalanceStr)
                            .keyboardType(.decimalPad)
                        
                        Toggle("Set Maturity Date", isOn: $hasMaturityDate)
                        if hasMaturityDate {
                            DatePicker("Maturity Date", selection: $maturityDate, displayedComponents: .date)
                        }
                    }
                    
                case .postOffice:
                    Section("Post Office Scheme Details") {
                        TextField("Deposit / Current Balance Amount", text: $currentBalanceStr)
                            .keyboardType(.decimalPad)
                        
                        TextField("Interest Rate (% p.a., e.g., 7.1)", text: $interestRateStr)
                            .keyboardType(.decimalPad)
                        
                        Picker("Interest Payout Mode", selection: $payoutFrequency) {
                            Text("Cumulative / At Maturity").tag("cumulative")
                            Text("Monthly Income Scheme (MIS)").tag("monthly")
                            Text("Quarterly Payout").tag("quarterly")
                            Text("Annual Payout").tag("annual")
                        }
                        .pickerStyle(.menu)
                        
                        Toggle("Set Maturity Date", isOn: $hasMaturityDate)
                        if hasMaturityDate {
                            DatePicker("Maturity Date", selection: $maturityDate, displayedComponents: .date)
                        }
                    }
                    
                case .epf:
                    Section("EPF / Provident Fund Details") {
                        TextField("Total Accumulated Balance (Employee + Employer)", text: $currentBalanceStr)
                            .keyboardType(.decimalPad)
                        
                        TextField("Interest Rate (% p.a., e.g., 8.25)", text: $interestRateStr)
                            .keyboardType(.decimalPad)
                    }
                    
                case .insuranceAnnuity:
                    Section("Policy & Annuity Details") {
                        TextField("Policy / Account Number (Optional)", text: $policyNumber)
                        
                        TextField("Annual Premium Amount", text: $premiumAmountStr)
                            .keyboardType(.decimalPad)
                        
                        TextField("Payment Term (Years, e.g. 15)", text: $premiumTermYearsStr)
                            .keyboardType(.numberPad)
                        
                        TextField("Current Cash / Surrender Value", text: $currentBalanceStr)
                            .keyboardType(.decimalPad)
                        
                        Toggle("Policy Completed / Matured / Surrendered", isOn: $isCompleted)
                            .tint(AppTheme.accent)
                    }
                }
                
                if asset != nil {
                    Section {
                        Button("Delete Asset", role: .destructive) {
                            deleteAsset()
                        }
                    }
                }
            }
            .navigationTitle(asset == nil ? "Add Asset" : "Edit Asset")
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
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || selectedCategory == nil)
                }
            }
            .onAppear {
                if let asset = asset {
                    name = asset.name
                    ticker = asset.ticker
                    selectedCategory = asset.category
                    selectedSubCategory = asset.subCategory
                    selectedHoldingType = asset.holdingType
                    isCompleted = asset.isCompleted
                    currentBalanceStr = asset.currentPrice > 0 ? "\(asset.currentPrice.formattedPlain)" : ""
                    principalAmountStr = asset.principalAmount > 0 ? "\(asset.principalAmount.formattedPlain)" : ""
                    interestRateStr = asset.interestRate > 0 ? "\(asset.interestRate)" : ""
                    if let mDate = asset.maturityDate {
                        hasMaturityDate = true
                        maturityDate = mDate
                    } else {
                        hasMaturityDate = false
                    }
                    payoutFrequency = asset.payoutFrequency
                    premiumAmountStr = asset.premiumAmount > 0 ? "\(asset.premiumAmount.formattedPlain)" : ""
                    premiumTermYearsStr = asset.premiumTermYears > 0 ? "\(asset.premiumTermYears)" : ""
                    policyNumber = asset.policyNumber
                    institutionName = asset.institutionName
                } else if let initialCategory = initialCategory {
                    selectedCategory = initialCategory
                }
            }
        }
    }
    
    private var namePlaceholder: String {
        switch selectedHoldingType {
        case .investment: return "Asset Name (e.g. Reliance, Apple Inc)"
        case .bankBalance: return "Account Name (e.g. HDFC Savings, ICICI Salary)"
        case .fixedDeposit: return "FD Name (e.g. SBI 1-Yr FD, HDFC Tax Saver)"
        case .postOffice: return "Scheme Name (e.g. PPF Account, NSC V)"
        case .epf: return "EPF Account Name / UAN"
        case .insuranceAnnuity: return "Policy Name (e.g. LIC Jeevan Umang)"
        }
    }
    
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, let category = selectedCategory else { return }
        
        let targetAsset = asset ?? Asset(name: trimmedName, category: category, ticker: ticker)
        targetAsset.name = trimmedName
        targetAsset.ticker = ticker
        targetAsset.category = category
        targetAsset.holdingType = selectedHoldingType
        targetAsset.isCompleted = isCompleted
        targetAsset.subCategory = selectedHoldingType == .investment ? selectedSubCategory : nil
        
        let currentBalance = Double(currentBalanceStr) ?? 0.0
        let principal = Double(principalAmountStr) ?? 0.0
        let interestRate = Double(interestRateStr) ?? 0.0
        let premiumAmount = Double(premiumAmountStr) ?? 0.0
        let premiumTerm = Int(premiumTermYearsStr) ?? 0
        
        targetAsset.interestRate = interestRate
        targetAsset.principalAmount = principal
        targetAsset.maturityDate = hasMaturityDate ? maturityDate : nil
        targetAsset.payoutFrequency = payoutFrequency
        targetAsset.premiumAmount = premiumAmount
        targetAsset.premiumTermYears = premiumTerm
        targetAsset.policyNumber = policyNumber
        targetAsset.institutionName = institutionName
        
        if selectedHoldingType.isNonUnitized {
            if currentBalance > 0 {
                targetAsset.currentPrice = currentBalance
            } else if principal > 0 {
                targetAsset.currentPrice = principal
            }
        }
        
        if asset == nil {
            modelContext.insert(targetAsset)
        }
    }
    
    private func deleteAsset() {
        guard let asset else { return }
        modelContext.delete(asset)
        dismiss()
    }
}

extension Double {
    fileprivate var formattedPlain: String {
        if self.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", self)
        } else {
            return String(format: "%.2f", self)
        }
    }
}
