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
    
    private var totalUnits: Double {
        PortfolioMetrics.totalUnits(for: asset)
    }
    
    private var currentValue: Double {
        PortfolioMetrics.currentValue(for: asset)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(asset.name)
                .font(.headline)
            Text("Category: \(asset.category?.name ?? "Uncategorized")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Units: \(totalUnits.formatted2) · Value: \(currentValue.formattedComma)")
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
    @State private var selectedCategory: Category?
    @State private var selectedSubCategory: SubCategory?
    @State private var selectedHoldingType: HoldingType = .investment
    @State private var initialBalance: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Asset Details") {
                    TextField("Asset Name (e.g. Savings AC, Stocks)", text: $name)
                    
                    Picker("Holding Type", selection: $selectedHoldingType) {
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
                    
                    if selectedHoldingType == .investment {
                        if let category = selectedCategory {
                            Picker("Subcategory", selection: $selectedSubCategory) {
                                Text("Unassigned").tag(nil as SubCategory?)
                                ForEach(category.subCategories.sorted(by: { $0.name.localizedCompare($1.name) == .orderedAscending })) { subCat in
                                    Text(subCat.name).tag(subCat as SubCategory?)
                                }
                            }
                        }
                    } else if asset == nil {
                        let label = selectedHoldingType == .bankBalance ? "Initial Balance" : "Deposit Amount"
                        TextField(label, text: $initialBalance)
                            .keyboardType(.decimalPad)
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
                    selectedCategory = asset.category
                    selectedSubCategory = asset.subCategory
                    selectedHoldingType = asset.holdingType
                } else if let initialCategory = initialCategory {
                    selectedCategory = initialCategory
                }
            }
        }
    }
    
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, let category = selectedCategory else { return }
        
        if let asset = asset {
            asset.name = trimmedName
            asset.category = category
            asset.subCategory = selectedHoldingType == .investment ? selectedSubCategory : nil
            asset.holdingType = selectedHoldingType
        } else {
            let newAsset = Asset(name: trimmedName, category: category)
            newAsset.subCategory = selectedHoldingType == .investment ? selectedSubCategory : nil
            newAsset.holdingType = selectedHoldingType
            if selectedHoldingType != .investment, let balance = Double(initialBalance) {
                newAsset.currentPrice = balance
            }
            modelContext.insert(newAsset)
        }
    }
    
    private func deleteAsset() {
        guard let asset else { return }
        modelContext.delete(asset)
        dismiss()
    }
}
