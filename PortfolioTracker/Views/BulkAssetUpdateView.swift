//
//  BulkAssetUpdateView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CSVExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            text = string
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

struct BulkAssetUpdateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Asset.name) private var assets: [Asset]
    @Query(sort: \Category.name) private var categories: [Category]
    
    @State private var priceInputs: [PersistentIdentifier: String] = [:]
    @State private var searchText = ""
    @State private var showAllAssets = false // Show active by default
    @State private var selectedCategoryIDs: Set<PersistentIdentifier> = [] // empty = All selected
    
    @State private var showImportSheet = false
    @State private var shareExportURL: URL? = nil
    @State private var showShareSheet = false
    
    @State private var showFileExporter = false
    @State private var exportDocument = CSVExportDocument(text: "")
    @State private var exportFileName = "Portfolio_CMP_Export.csv"
    
    private struct CategoryGroup: Identifiable {
        var id: String {
            if let categoryID {
                return "\(categoryID)"
            } else {
                return "uncategorized"
            }
        }
        let categoryID: PersistentIdentifier?
        let title: String
        let currencyCode: String
        let assets: [Asset]
    }
    
    private var categoryFilterSummaryText: String {
        if selectedCategoryIDs.isEmpty || selectedCategoryIDs.count == categories.count {
            return "All Categories (\(categories.count))"
        } else if selectedCategoryIDs.count == 1,
                  let id = selectedCategoryIDs.first,
                  let cat = categories.first(where: { $0.persistentModelID == id }) {
            return cat.name
        } else {
            return "\(selectedCategoryIDs.count) Selected"
        }
    }
    
    private var filteredAssets: [Asset] {
        assets.filter { asset in
            let matchesCategory: Bool
            if selectedCategoryIDs.isEmpty {
                matchesCategory = true
            } else if let catID = asset.category?.persistentModelID {
                matchesCategory = selectedCategoryIDs.contains(catID)
            } else {
                matchesCategory = false
            }
            
            let matchesSearch = searchText.isEmpty || 
                                asset.name.localizedCaseInsensitiveContains(searchText) || 
                                (asset.category?.name.localizedCaseInsensitiveContains(searchText) ?? false)
            
            let totalUnits = PortfolioMetrics.totalUnits(for: asset)
            let isHoldingActive = totalUnits > 0.000001
            let matchesActive = showAllAssets || isHoldingActive
            
            return matchesCategory && matchesSearch && matchesActive
        }
    }
    
    private var groupedAssets: [CategoryGroup] {
        let items = filteredAssets
        var groups: [CategoryGroup] = []
        
        for category in categories {
            if !selectedCategoryIDs.isEmpty && !selectedCategoryIDs.contains(category.persistentModelID) {
                continue
            }
            let catAssets = items.filter { $0.category?.persistentModelID == category.persistentModelID }
            if !catAssets.isEmpty {
                groups.append(CategoryGroup(
                    categoryID: category.persistentModelID,
                    title: category.name,
                    currencyCode: category.currencyCode,
                    assets: catAssets
                ))
            }
        }
        
        if selectedCategoryIDs.isEmpty {
            let uncategorized = items.filter { $0.category == nil }
            if !uncategorized.isEmpty {
                groups.append(CategoryGroup(
                    categoryID: nil,
                    title: "Uncategorized",
                    currencyCode: "USD",
                    assets: uncategorized
                ))
            }
        }
        
        return groups
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
    
    private var hasChanges: Bool {
        for asset in assets {
            if let input = priceInputs[asset.persistentModelID],
               let newPrice = Double(input),
               abs(newPrice - asset.currentPrice) > 0.000001 {
                return true
            }
        }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top controls bar
            VStack(spacing: 12) {
                // Export / Import CMP File Bar
                HStack(spacing: 10) {
                    Button {
                        let csv = generateCMPCSVString()
                        let dateStr = Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")
                        exportFileName = "Portfolio_CMP_Export_\(dateStr).csv"
                        exportDocument = CSVExportDocument(text: csv)
                        showFileExporter = true
                        
                        if let url = generateCMPExportURL() {
                            shareExportURL = url
                        }
                    } label: {
                        Label("Export CMP File", systemImage: "square.and.arrow.up")
                            .font(.caption)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accent)
                    
                    Button {
                        showImportSheet = true
                    } label: {
                        Label("Import CMP File", systemImage: "square.and.arrow.down.fill")
                            .font(.caption)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                }
                
                // Multi-Select Category Filter Bar (Select Equity, MF, etc.; Ignore Banks, FDs)
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                    
                    Text("Categories:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Menu {
                        Button(action: {
                            if selectedCategoryIDs.count == categories.count {
                                selectedCategoryIDs.removeAll()
                            } else {
                                selectedCategoryIDs = Set(categories.map { $0.persistentModelID })
                            }
                        }) {
                            Label(
                                (selectedCategoryIDs.isEmpty || selectedCategoryIDs.count == categories.count) ? "Select All / Reset" : "Select All",
                                systemImage: (selectedCategoryIDs.isEmpty || selectedCategoryIDs.count == categories.count) ? "checkmark.square.fill" : "square"
                            )
                        }
                        
                        Divider()
                        
                        ForEach(categories) { cat in
                            Button(action: {
                                if selectedCategoryIDs.isEmpty {
                                    selectedCategoryIDs = Set(categories.map { $0.persistentModelID })
                                    selectedCategoryIDs.remove(cat.persistentModelID)
                                } else if selectedCategoryIDs.contains(cat.persistentModelID) {
                                    selectedCategoryIDs.remove(cat.persistentModelID)
                                } else {
                                    selectedCategoryIDs.insert(cat.persistentModelID)
                                }
                            }) {
                                let isSelected = selectedCategoryIDs.isEmpty || selectedCategoryIDs.contains(cat.persistentModelID)
                                Label(
                                    cat.name,
                                    systemImage: isSelected ? "checkmark.square.fill" : "square"
                                )
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(categoryFilterSummaryText)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.accent)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.accent)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search active assets or categories...", text: $searchText)
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
                
                // Show all assets toggle
                Toggle(isOn: $showAllAssets) {
                    HStack(spacing: 6) {
                        Image(systemName: showAllAssets ? "eye.fill" : "eye.slash.fill")
                            .foregroundStyle(AppTheme.accent)
                        Text("Show Inactive / Sold-off Assets")
                            .font(.subheadline)
                    }
                }
                .tint(AppTheme.accent)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            .padding(.top, 8)
            .background(Color(.systemBackground))
            
            Divider()
            
            if groupedAssets.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "square.dashed")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(searchText.isEmpty ? "No active assets found" : "No assets match your search")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(searchText.isEmpty ? "Toggle \"Show Inactive Assets\" to view other assets." : "Try adjusting your search criteria.")
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
                        ForEach(groupedAssets) { group in
                            Section {
                                VStack(spacing: 12) {
                                    ForEach(group.assets) { asset in
                                        let totalUnits = PortfolioMetrics.totalUnits(for: asset)
                                        
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack(alignment: .center) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(asset.name)
                                                        .font(.headline)
                                                        .foregroundStyle(.primary)
                                                        .lineLimit(1)
                                                    
                                                    Text("\(totalUnits.formatted2) units")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                
                                                Spacer()
                                                
                                                // Input field with custom styling
                                                HStack(spacing: 6) {
                                                    Text(currencySymbol(for: group.currencyCode))
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(.secondary)
                                                    
                                                    TextField("0.00", text: Binding(
                                                        get: { priceInputs[asset.persistentModelID] ?? "" },
                                                        set: { priceInputs[asset.persistentModelID] = $0 }
                                                    ))
                                                    .keyboardType(.decimalPad)
                                                    .multilineTextAlignment(.trailing)
                                                    .font(.body)
                                                    .fontWeight(.bold)
                                                    .padding(.vertical, 6)
                                                    .padding(.horizontal, 10)
                                                    .background(Color(.systemGray6))
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                                                    )
                                                    .frame(width: 120)
                                                }
                                            }
                                            
                                            // Live Value computation preview
                                            let inputString = priceInputs[asset.persistentModelID] ?? ""
                                            let parsedPrice = Double(inputString) ?? 0.0
                                            let calculatedValue = totalUnits * parsedPrice
                                            let originalValue = totalUnits * asset.currentPrice
                                            let difference = calculatedValue - originalValue
                                            
                                            HStack {
                                                Text("Live Value: ")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Text("\(currencySymbol(for: group.currencyCode))\(calculatedValue.formattedComma)")
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(AppTheme.accent)
                                                
                                                if abs(difference) > 0.001 {
                                                    Spacer()
                                                    
                                                    Text("\(difference >= 0 ? "+" : "")\(currencySymbol(for: group.currencyCode))\(difference.formattedComma)")
                                                        .font(.caption2)
                                                        .fontWeight(.bold)
                                                        .foregroundStyle(difference >= 0 ? AppTheme.profit : AppTheme.loss)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background((difference >= 0 ? AppTheme.profit : AppTheme.loss).opacity(0.12))
                                                        .clipShape(Capsule())
                                                }
                                            }
                                        }
                                        .padding(12)
                                        .background(Color(.systemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                                        .padding(.horizontal)
                                    }
                                }
                                .padding(.vertical, 8)
                            } header: {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.accent)
                                    Text(group.title)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(AppTheme.accent)
                                    Text("(\(group.currencyCode))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray6))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Bulk Price Update")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveAll()
                }
                .disabled(!hasChanges)
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showImportSheet) {
            BulkCMPImportSheet()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareExportURL {
                ShareSheet(items: [url])
            }
        }
        .fileExporter(
            isPresented: $showFileExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: exportFileName
        ) { result in
            switch result {
            case .success(let url):
                print("Successfully exported CMP file to \(url)")
            case .failure(let error):
                print("Failed file export: \(error.localizedDescription)")
            }
        }
        .onAppear {
            initializePriceInputs()
        }
    }
    
    private func generateCMPCSVString() -> String {
        var csv = "Asset Name,Ticker,Category,Currency,Current Price (CMP),Total Units Held\n"
        let activeAssets = assets.filter { asset in
            let matchesCategory: Bool
            if selectedCategoryIDs.isEmpty {
                matchesCategory = true
            } else if let catID = asset.category?.persistentModelID {
                matchesCategory = selectedCategoryIDs.contains(catID)
            } else {
                matchesCategory = false
            }
            let totalUnits = PortfolioMetrics.totalUnits(for: asset)
            return matchesCategory && (showAllAssets || totalUnits > 0.000001)
        }
        
        for asset in activeAssets {
            let cleanName = asset.name.replacingOccurrences(of: "\"", with: "\"\"")
            let name = "\"\(cleanName)\""
            let category = "\"\(asset.category?.name ?? "General")\""
            let currency = "\"\(asset.category?.currencyCode ?? "INR")\""
            let cmp = String(format: "%.2f", asset.currentPrice)
            let units = String(format: "%.4f", PortfolioMetrics.totalUnits(for: asset))
            
            csv += "\(name),,\(category),\(currency),\(cmp),\(units)\n"
        }
        return csv
    }
    
    private func generateCMPExportURL() -> URL? {
        let csv = generateCMPCSVString()
        let dateStr = Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")
        let fileName = "Portfolio_CMP_Export_\(dateStr).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("Failed to generate CMP export file: \(error)")
            return nil
        }
    }


    
    private func initializePriceInputs() {
        for asset in assets {
            priceInputs[asset.persistentModelID] = String(format: "%.2f", asset.currentPrice)
        }
    }
    
    private func saveAll() {
        for asset in assets {
            if let input = priceInputs[asset.persistentModelID],
               let newPrice = Double(input) {
                asset.currentPrice = newPrice
            }
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save context in BulkAssetUpdateView: \(error)")
        }
    }
}
