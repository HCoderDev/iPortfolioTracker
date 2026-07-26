//
//  BulkCMPImportSheet.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum CMPTargetField: String, CaseIterable, Identifiable {
    case ignore = "Ignore Column"
    case assetName = "Asset Name"
    case ticker = "Ticker / Symbol"
    case category = "Category"
    case currentPrice = "Current Market Price (CMP)"
    
    var id: String { rawValue }
}

struct BulkCMPImportSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Asset.name) private var assets: [Asset]
    
    @State private var isDocumentPickerPresented = false
    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String = ""
    @State private var fileRawGrid: [[String]] = []
    @State private var sheetNames: [String] = []
    @State private var selectedSheetName: String = ""
    @State private var headerRowOffset: Int = 0
    
    @State private var columnMappings: [Int: CMPTargetField] = [:]
    @State private var updatedAssetCount = 0
    @State private var showSuccessAlert = false
    
    struct CMPMatchedItem: Identifiable {
        let id = UUID()
        let asset: Asset
        let oldPrice: Double
        let newPrice: Double
        let priceDiff: Double
        let percentChange: Double
        let isAlreadyMatching: Bool
    }
    
    @State private var matchedItems: [CMPMatchedItem] = []
    
    private var dataRows: [[String]] {
        guard fileRawGrid.count > headerRowOffset else { return [] }
        return Array(fileRawGrid.dropFirst(headerRowOffset))
    }
    
    private var headerRow: [String] {
        dataRows.first ?? []
    }
    
    private var dataContentRows: [[String]] {
        guard dataRows.count > 1 else { return [] }
        return Array(dataRows.dropFirst(1))
    }
    
    private var totalMatchedAssets: Int {
        matchedItems.count
    }
    
    private var totalToBeUpdated: Int {
        matchedItems.filter { !$0.isAlreadyMatching }.count
    }
    
    private var totalAlreadyMatching: Int {
        matchedItems.filter { $0.isAlreadyMatching }.count
    }
    
    private func currencySymbol(for code: String?) -> String {
        guard let code = code?.uppercased() else { return "₹" }
        switch code {
        case "USD": return "$"
        case "INR": return "₹"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        default: return "\(code) "
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 1. File Selection Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("1. Select Updated CMP File (CSV/Excel)")
                                .font(.headline)
                            
                            if selectedFileURL == nil {
                                Button {
                                    isDocumentPickerPresented = true
                                } label: {
                                    HStack {
                                        Image(systemName: "square.and.arrow.down.fill")
                                            .font(.title2)
                                        Text("Browse CMP Update Spreadsheet")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppTheme.accent.opacity(0.1))
                                    .foregroundStyle(AppTheme.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            } else {
                                HStack {
                                    Image(systemName: "tablecells.fill")
                                        .foregroundStyle(AppTheme.accent)
                                    Text(selectedFileName)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    Spacer()
                                    Button("Change") { isDocumentPickerPresented = true }
                                        .font(.caption)
                                        .buttonStyle(.bordered)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        
                        if !sheetNames.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Worksheet").font(.subheadline).fontWeight(.semibold)
                                Picker("Sheet", selection: $selectedSheetName) {
                                    ForEach(sheetNames, id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: selectedSheetName) { _, newSheet in
                                    reloadSheetContent(sheetName: newSheet)
                                }
                            }
                        }
                        
                        if !fileRawGrid.isEmpty {
                            Divider()
                            
                            // 2. Skip Top Rows & Raw Data Preview
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("2. Header Selection (Skip Top Rows)")
                                        .font(.headline)
                                    Spacer()
                                    Stepper("Skip \(headerRowOffset) row(s)", value: $headerRowOffset, in: 0...max(0, fileRawGrid.count - 1))
                                        .labelsHidden()
                                        .onChange(of: headerRowOffset) { _, _ in
                                            autoDetectColumns()
                                            analyzeMatches()
                                        }
                                    Text("Skip \(headerRowOffset)")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                }
                                
                                Text("Tap any row below to set it as table header.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                ScrollView(.horizontal, showsIndicators: true) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(0..<min(12, fileRawGrid.count), id: \.self) { rIdx in
                                            let row = fileRawGrid[rIdx]
                                            let isSkipped = rIdx < headerRowOffset
                                            let isHeader = rIdx == headerRowOffset
                                            
                                            Button {
                                                headerRowOffset = rIdx
                                                autoDetectColumns()
                                                analyzeMatches()
                                            } label: {
                                                HStack(spacing: 8) {
                                                    Text("Row \(rIdx + 1)")
                                                        .font(.caption2)
                                                        .fontWeight(.bold)
                                                        .frame(width: 48, alignment: .leading)
                                                        .foregroundStyle(isSkipped ? Color.gray : (isHeader ? AppTheme.accent : Color.secondary))
                                                    
                                                    Text(isSkipped ? "[ SKIPPED ]" : (isHeader ? "[ HEADER ]" : "[ DATA ]"))
                                                        .font(.caption2)
                                                        .fontWeight(.bold)
                                                        .frame(width: 72, alignment: .leading)
                                                        .foregroundStyle(isSkipped ? Color.gray : (isHeader ? AppTheme.accent : Color.secondary))
                                                    
                                                    ForEach(0..<min(6, row.count), id: \.self) { cIdx in
                                                        let cellVal = row[cIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                                                        Text(cellVal.isEmpty ? "-" : cellVal)
                                                            .font(.caption2)
                                                            .lineLimit(1)
                                                            .frame(width: 90, alignment: .leading)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 4)
                                                            .background(isHeader ? AppTheme.accent.opacity(0.15) : (isSkipped ? Color.gray.opacity(0.1) : Color(.systemGray6)))
                                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                                    }
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        
                        if !headerRow.isEmpty {
                            Divider()
                            
                            // 3. Map Columns
                            VStack(alignment: .leading, spacing: 12) {
                                Text("3. Map CMP Columns")
                                    .font(.headline)
                                
                                ForEach(0..<headerRow.count, id: \.self) { cIdx in
                                    let name = headerRow[cIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                                    HStack {
                                        Text("Col \(cIdx + 1): \(name.isEmpty ? "Unnamed" : name)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Picker("Field", selection: Binding(
                                            get: { columnMappings[cIdx] ?? .ignore },
                                            set: { columnMappings[cIdx] = $0; analyzeMatches() }
                                        )) {
                                            Text("Ignore").tag(CMPTargetField.ignore)
                                            Text("Asset Name").tag(CMPTargetField.assetName)
                                            Text("Ticker / Symbol").tag(CMPTargetField.ticker)
                                            Text("Category").tag(CMPTargetField.category)
                                            Text("Current Market Price (CMP)").tag(CMPTargetField.currentPrice)
                                        }
                                        .pickerStyle(.menu)
                                    }
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            
                            Divider()
                            
                            // 4. Preview & Matches
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("4. CMP Update Preview")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(totalMatchedAssets) Asset(s) Matched")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(AppTheme.accent)
                                }
                                
                                if matchedItems.isEmpty {
                                    Text("No matching assets found in your portfolio for the names/tickers in this file. Please verify column mapping.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    if totalToBeUpdated == 0 && totalMatchedAssets > 0 {
                                        HStack(spacing: 12) {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.title2)
                                                .foregroundStyle(AppTheme.profit)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("All Prices Already Match DB")
                                                    .font(.headline)
                                                    .fontWeight(.bold)
                                                    .foregroundStyle(AppTheme.profit)
                                                Text("All \(totalMatchedAssets) matched assets in your portfolio already have the exact CMP prices specified in this file.")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(AppTheme.profit.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppTheme.profit.opacity(0.3), lineWidth: 1)
                                        )
                                    } else {
                                        HStack(spacing: 12) {
                                            VStack {
                                                Text("\(totalMatchedAssets)").font(.subheadline).fontWeight(.bold)
                                                Text("Matched Assets").font(.caption2).foregroundStyle(.secondary)
                                            }
                                            .frame(maxWidth: .infinity)
                                            
                                            VStack {
                                                Text("\(totalAlreadyMatching)").font(.subheadline).fontWeight(.bold).foregroundStyle(AppTheme.profit)
                                                Text("Unchanged").font(.caption2).foregroundStyle(.secondary)
                                            }
                                            .frame(maxWidth: .infinity)
                                            
                                            VStack {
                                                Text("\(totalToBeUpdated)").font(.subheadline).fontWeight(.bold).foregroundStyle(AppTheme.accent)
                                                Text("To Be Updated").font(.caption2).foregroundStyle(.secondary)
                                            }
                                            .frame(maxWidth: .infinity)
                                        }
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    
                                    LazyVStack(spacing: 8) {
                                        ForEach(matchedItems) { item in
                                            let symbol = currencySymbol(for: item.asset.category?.currencyCode)
                                            
                                            HStack(alignment: .center) {
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(item.asset.name)
                                                        .font(.subheadline)
                                                        .fontWeight(.bold)
                                                    
                                                    HStack(spacing: 6) {
                                                        if let cat = item.asset.category?.name {
                                                            Text(cat)
                                                                .font(.caption2)
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 2)
                                                                .background(AppTheme.accent.opacity(0.12))
                                                                .foregroundStyle(AppTheme.accent)
                                                                .clipShape(Capsule())
                                                        }
                                                        
                                                        Text("Current DB: \(symbol)\(item.oldPrice.formatted2)")
                                                            .font(.caption2)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                if item.isAlreadyMatching {
                                                    Text("Matching (\(symbol)\(item.newPrice.formatted2))")
                                                        .font(.caption2)
                                                        .fontWeight(.bold)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 3)
                                                        .background(AppTheme.profit.opacity(0.15))
                                                        .foregroundStyle(AppTheme.profit)
                                                        .clipShape(Capsule())
                                                } else {
                                                    VStack(alignment: .trailing, spacing: 2) {
                                                        Text("New: \(symbol)\(item.newPrice.formatted2)")
                                                            .font(.caption)
                                                            .fontWeight(.bold)
                                                            .foregroundStyle(AppTheme.accent)
                                                        
                                                        let isPositive = item.priceDiff >= 0
                                                        Text("\(isPositive ? "+" : "")\(item.percentChange.formatted2)%")
                                                            .font(.caption2)
                                                            .fontWeight(.bold)
                                                            .foregroundStyle(isPositive ? AppTheme.profit : AppTheme.loss)
                                                    }
                                                }
                                            }
                                            .padding(10)
                                            .background(Color(.systemBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                if totalToBeUpdated == 0 && totalMatchedAssets > 0 {
                    Button("Prices Already Match — Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    Button {
                        executeUpdate()
                    } label: {
                        Text("Apply & Update CMPs (\(totalToBeUpdated) Asset\(totalToBeUpdated == 1 ? "" : "s"))")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .padding()
                    .disabled(matchedItems.isEmpty || totalToBeUpdated == 0)
                }
            }
            .navigationTitle("Bulk Import Stock & MF CMP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $isDocumentPickerPresented,
                allowedContentTypes: [.commaSeparatedText, .plainText, UTType(filenameExtension: "csv")!, UTType(filenameExtension: "xlsx")!, UTType(filenameExtension: "xls")!],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result: result)
            }
            .alert("Stock & MF CMPs Updated", isPresented: $showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("Updated Current Market Price for \(updatedAssetCount) asset(s) in your portfolio. \(totalAlreadyMatching) asset(s) were already matching and kept unchanged.")
            }
        }
    }
    
    private func handleFileSelection(result: Result<[URL], Error>) {
        if case .success(let urls) = result, let url = urls.first {
            let shouldStop = url.startAccessingSecurityScopedResource()
            defer { if shouldStop { url.stopAccessingSecurityScopedResource() } }
            
            selectedFileURL = url
            selectedFileName = url.lastPathComponent
            
            guard let fileData = try? Data(contentsOf: url) else { return }
            
            let ext = url.pathExtension.lowercased()
            if ext == "xlsx" || ext == "xls" {
                sheetNames = XLSXParser.getSheetNames(data: fileData)
                selectedSheetName = sheetNames.first ?? ""
                fileRawGrid = XLSXParser.parse(data: fileData, sheetName: selectedSheetName)
                
                if fileRawGrid.isEmpty {
                    if let content = String(data: fileData, encoding: .utf8) ?? String(data: fileData, encoding: .ascii) ?? String(data: fileData, encoding: .windowsCP1252) {
                        fileRawGrid = CSVParser.parse(content: content)
                    }
                }
            } else {
                sheetNames = []
                selectedSheetName = ""
                if let content = String(data: fileData, encoding: .utf8) ?? String(data: fileData, encoding: .ascii) ?? String(data: fileData, encoding: .windowsCP1252) {
                    fileRawGrid = CSVParser.parse(content: content)
                }
            }
            
            autoDetectHeaderRow()
            autoDetectColumns()
            analyzeMatches()
        }
    }
    
    private func reloadSheetContent(sheetName: String) {
        guard let url = selectedFileURL else { return }
        let shouldStop = url.startAccessingSecurityScopedResource()
        defer { if shouldStop { url.stopAccessingSecurityScopedResource() } }
        guard let fileData = try? Data(contentsOf: url) else { return }
        fileRawGrid = XLSXParser.parse(data: fileData, sheetName: sheetName)
        autoDetectHeaderRow()
        autoDetectColumns()
        analyzeMatches()
    }
    
    private func autoDetectHeaderRow() {
        if let idx = fileRawGrid.firstIndex(where: { row in
            row.contains(where: { cell in
                let val = cell.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return !val.isEmpty && (
                    val.contains("asset") ||
                    val.contains("stock") ||
                    val.contains("name") ||
                    val.contains("ticker") ||
                    val.contains("cmp") ||
                    val.contains("price") ||
                    val.contains("nav")
                )
            })
        }) {
            headerRowOffset = idx
        } else {
            headerRowOffset = 0
        }
    }
    
    private func autoDetectColumns() {
        columnMappings.removeAll()
        for cIdx in 0..<headerRow.count {
            let h = headerRow[cIdx].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if h.contains("ticker") || h.contains("symbol") || h.contains("code") {
                columnMappings[cIdx] = .ticker
            } else if h.contains("asset") || h.contains("stock") || h.contains("fund") || h.contains("name") {
                columnMappings[cIdx] = .assetName
            } else if h.contains("category") || h.contains("type") {
                columnMappings[cIdx] = .category
            } else if h.contains("cmp") || h.contains("price") || h.contains("nav") || h.contains("ltp") || h.contains("current") || h.contains("rate") {
                columnMappings[cIdx] = .currentPrice
            }
        }
    }
    
    private func analyzeMatches() {
        matchedItems.removeAll()
        
        let nameCol = columnMappings.first(where: { $0.value == .assetName })?.key
        let tickerCol = columnMappings.first(where: { $0.value == .ticker })?.key
        let cmpCol = columnMappings.first(where: { $0.value == .currentPrice })?.key
        
        guard let priceCol = cmpCol else { return }
        var matchedAssetIDs = Set<PersistentIdentifier>()
        
        for rawRow in dataContentRows {
            guard rawRow.indices.contains(priceCol),
                  let newPrice = ImportEngine.parseNumber(rawRow[priceCol]),
                  newPrice >= 0
            else { continue }
            
            let rowName = nameCol.flatMap { rawRow.indices.contains($0) ? rawRow[$0].trimmingCharacters(in: .whitespacesAndNewlines) : nil } ?? ""
            let rowTicker = tickerCol.flatMap { rawRow.indices.contains($0) ? rawRow[$0].trimmingCharacters(in: .whitespacesAndNewlines) : nil } ?? ""
            
            if rowName.isEmpty && rowTicker.isEmpty { continue }
            
            // Find DB asset match
            let matchedAsset = assets.first { dbAsset in
                guard !matchedAssetIDs.contains(dbAsset.persistentModelID) else { return false }
                
                // 1. Ticker match
                if !rowTicker.isEmpty {
                    if dbAsset.name.localizedCaseInsensitiveContains(rowTicker) ||
                       dbAsset.aliases.contains(where: { $0.localizedCaseInsensitiveCompare(rowTicker) == .orderedSame }) {
                        return true
                    }
                }
                
                // 2. Asset Name & Saved Alias Match
                if !rowName.isEmpty {
                    return ImportEngine.isAssetNameMatch(dbAsset, statementName: rowName)
                }
                
                return false
            }
            
            if let targetAsset = matchedAsset {
                matchedAssetIDs.insert(targetAsset.persistentModelID)
                let oldPrice = targetAsset.currentPrice
                let diff = newPrice - oldPrice
                let pct = oldPrice > 0 ? (diff / oldPrice) * 100.0 : 0.0
                let isAlreadyMatching = abs(diff) < 0.0001
                
                matchedItems.append(CMPMatchedItem(
                    asset: targetAsset,
                    oldPrice: oldPrice,
                    newPrice: newPrice,
                    priceDiff: diff,
                    percentChange: pct,
                    isAlreadyMatching: isAlreadyMatching
                ))
            }
        }
    }
    
    private func executeUpdate() {
        var count = 0
        for item in matchedItems {
            guard !item.isAlreadyMatching else { continue }
            item.asset.currentPrice = item.newPrice
            count += 1
        }
        
        do {
            try modelContext.save()
            updatedAssetCount = count
            showSuccessAlert = true
        } catch {
            print("Failed to save CMP updates: \(error)")
        }
    }
}
