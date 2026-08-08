//
//  BulkForexImportSheet.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BulkForexImportSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \AssetTransaction.date, order: .reverse) private var transactions: [AssetTransaction]
    
    @State private var isDocumentPickerPresented = false
    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String = ""
    @State private var fileRawGrid: [[String]] = []
    @State private var sheetNames: [String] = []
    @State private var selectedSheetName: String = ""
    @State private var headerRowOffset: Int = 0
    @State private var selectedCurrencyCode: String = "ALL"
    
    @State private var columnMappings: [Int: TargetField] = [:]
    @State private var updatedTxCount = 0
    @State private var showSuccessAlert = false
    
    private struct ForexMatchedTx: Identifiable {
        let id = UUID()
        let tx: AssetTransaction
        let resolvedRate: Double?
        let isAlreadyMatching: Bool
    }
    
    private struct ForexMatchedRow: Identifiable {
        let id = UUID()
        let date: Date
        let ttBuyRate: Double?
        let ttSellRate: Double?
        let inrRate: Double?
        let matchedTxs: [ForexMatchedTx]
        
        var toBeUpdatedCount: Int {
            matchedTxs.filter { !$0.isAlreadyMatching && $0.resolvedRate != nil }.count
        }
        
        var alreadyMatchingCount: Int {
            matchedTxs.filter { $0.isAlreadyMatching }.count
        }
    }
    
    @State private var matchedRows: [ForexMatchedRow] = []
    
    private var availableForeignCurrencies: [String] {
        let currencies = transactions.compactMap { tx -> String? in
            guard let code = tx.asset?.category?.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() else { return nil }
            return code != "INR" ? code : nil
        }
        return Array(Set(currencies)).sorted()
    }
    
    private var foreignTransactions: [AssetTransaction] {
        transactions.filter { tx in
            guard let catCurrency = tx.asset?.category?.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() else { return false }
            guard catCurrency != "INR" else { return false }
            if selectedCurrencyCode != "ALL" {
                return catCurrency == selectedCurrencyCode.uppercased()
            }
            return true
        }
    }
    
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
    
    private var totalMatchingTxs: Int {
        matchedRows.reduce(0) { $0 + $1.matchedTxs.count }
    }
    
    private var totalToBeUpdatedTxs: Int {
        matchedRows.reduce(0) { $0 + $1.toBeUpdatedCount }
    }
    
    private var totalAlreadyMatchingTxs: Int {
        matchedRows.reduce(0) { $0 + $1.alreadyMatchingCount }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 1. File selection card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("1. Select Exchange Rates File (CSV/Excel)")
                                .font(.headline)
                            
                            if selectedFileURL == nil {
                                Button {
                                    isDocumentPickerPresented = true
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                            .font(.title2)
                                        Text("Browse TT Buy / TT Sell Rates File")
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
                        
                        // Currency Target Selector
                        if !availableForeignCurrencies.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Target Currency")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Picker("Target Currency", selection: $selectedCurrencyCode) {
                                    Text("All (\(availableForeignCurrencies.joined(separator: ", ")))").tag("ALL")
                                    ForEach(availableForeignCurrencies, id: \.self) { code in
                                        Text("\(code) Transactions Only").tag(code)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: selectedCurrencyCode) { _, _ in
                                    analyzeMatches()
                                }
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
                                
                                Text("Tap any row below to mark it as your table header row.")
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
                            
                            // 3. Column mapping
                            VStack(alignment: .leading, spacing: 12) {
                                Text("3. Map Rate Columns")
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
                                            Text("Ignore").tag(TargetField.ignore)
                                            Text("Date").tag(TargetField.date)
                                            Text("TT Buy Rate").tag(TargetField.ttBuyRate)
                                            Text("TT Sell Rate").tag(TargetField.ttSellRate)
                                            Text("INR Rate").tag(TargetField.inrExchangeRate)
                                        }
                                        .pickerStyle(.menu)
                                    }
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            
                            Divider()
                            
                            // 4. Preview of matched transactions to update
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("4. Rate Matches Preview")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(matchedRows.count) Date(s) | \(totalMatchingTxs) Tx(s)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(AppTheme.accent)
                                }
                                
                                if matchedRows.isEmpty {
                                    Text("No matching \(selectedCurrencyCode == "ALL" ? "foreign" : selectedCurrencyCode) transactions found in DB for the dates in this file. Please verify Date column mapping and raw grid header selection.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    if totalToBeUpdatedTxs == 0 && totalMatchingTxs > 0 {
                                        HStack(spacing: 12) {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.title2)
                                                .foregroundStyle(AppTheme.profit)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("All Rates Already Match DB")
                                                    .font(.headline)
                                                    .fontWeight(.bold)
                                                    .foregroundStyle(AppTheme.profit)
                                                Text("All \(totalMatchingTxs) matching \(selectedCurrencyCode == "ALL" ? "foreign" : selectedCurrencyCode) transactions already have the exact exchange rates specified in this file.")
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
                                                Text("\(totalMatchingTxs)").font(.subheadline).fontWeight(.bold)
                                                Text("Matched DB Txs").font(.caption2).foregroundStyle(.secondary)
                                            }
                                            .frame(maxWidth: .infinity)
                                            
                                            VStack {
                                                Text("\(totalAlreadyMatchingTxs)").font(.subheadline).fontWeight(.bold).foregroundStyle(AppTheme.profit)
                                                Text("Already Matching").font(.caption2).foregroundStyle(.secondary)
                                            }
                                            .frame(maxWidth: .infinity)
                                            
                                            VStack {
                                                Text("\(totalToBeUpdatedTxs)").font(.subheadline).fontWeight(.bold).foregroundStyle(AppTheme.accent)
                                                Text("To Be Updated").font(.caption2).foregroundStyle(.secondary)
                                            }
                                            .frame(maxWidth: .infinity)
                                        }
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    
                                    LazyVStack(spacing: 8) {
                                        ForEach(matchedRows) { row in
                                            VStack(alignment: .leading, spacing: 6) {
                                                HStack {
                                                    Text(row.date.formatted(date: .abbreviated, time: .omitted))
                                                        .font(.subheadline)
                                                        .fontWeight(.bold)
                                                    Spacer()
                                                    Text("\(row.matchedTxs.count) tx(s)")
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(AppTheme.accent)
                                                }
                                                
                                                HStack(spacing: 12) {
                                                    if let buy = row.ttBuyRate {
                                                        Text("TT Buy (Sell/Div): ₹\(buy.formatted2)")
                                                            .font(.caption2)
                                                            .fontWeight(.medium)
                                                            .foregroundStyle(AppTheme.profit)
                                                    }
                                                    if let sell = row.ttSellRate {
                                                        Text("TT Sell (Buy): ₹\(sell.formatted2)")
                                                            .font(.caption2)
                                                            .fontWeight(.medium)
                                                            .foregroundStyle(AppTheme.loss)
                                                    }
                                                    if let inr = row.inrRate {
                                                        Text("INR Rate: ₹\(inr.formatted2)")
                                                            .font(.caption2)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }
                                                
                                                Divider().padding(.vertical, 2)
                                                
                                                ForEach(row.matchedTxs) { item in
                                                    HStack {
                                                        if item.tx.config.isUnitBased {
                                                            Text("• \(item.tx.asset?.name ?? "Asset") (\(item.tx.type.rawValue)): \(item.tx.units.formatted2) units")
                                                                .font(.caption2)
                                                                .foregroundStyle(.primary)
                                                        } else {
                                                            Text("• \(item.tx.asset?.name ?? "Asset") (\(item.tx.type.rawValue)): \(item.tx.amount.formatted2)")
                                                                .font(.caption2)
                                                                .foregroundStyle(.primary)
                                                        }
                                                        Spacer()
                                                        if item.isAlreadyMatching, let rate = item.resolvedRate {
                                                            Text("Already Matching (₹\(rate.formatted2))")
                                                                .font(.caption2)
                                                                .fontWeight(.bold)
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 2)
                                                                .background(AppTheme.profit.opacity(0.15))
                                                                .foregroundStyle(AppTheme.profit)
                                                                .clipShape(Capsule())
                                                        } else if let rate = item.resolvedRate {
                                                            Text("New Rate: ₹\(rate.formatted2)")
                                                                .font(.caption2)
                                                                .fontWeight(.bold)
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 2)
                                                                .background(AppTheme.accent.opacity(0.15))
                                                                .foregroundStyle(AppTheme.accent)
                                                                .clipShape(Capsule())
                                                        }
                                                    }
                                                }
                                            }
                                            .padding(10)
                                            .background(Color(.systemBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
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
                
                if totalToBeUpdatedTxs == 0 && totalMatchingTxs > 0 {
                    Button("Rates Already Match — Done") {
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
                        Text("Apply & Update Exchange Rates (\(totalToBeUpdatedTxs) Tx\(totalToBeUpdatedTxs == 1 ? "" : "s"))")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .padding()
                    .disabled(matchedRows.isEmpty || totalToBeUpdatedTxs == 0)
                }
            }
            .navigationTitle("Bulk Import Forex Rates")
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
            .alert("Forex Rates Updated", isPresented: $showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("Updated exchange rates for \(updatedTxCount) transaction(s). \(totalAlreadyMatchingTxs) transaction(s) were already matching and kept unchanged.")
            }
        }
    }
    
    private func handleFileSelection(result: Result<[URL], Error>) {
        if case .success(let urls) = result, let url = urls.first {
            let shouldStop = url.startAccessingSecurityScopedResource()
            defer { if shouldStop { url.stopAccessingSecurityScopedResource() } }
            
            selectedFileURL = url
            selectedFileName = url.lastPathComponent
            
            guard let fileData = try? Data(contentsOf: url) else {
                print("Failed to read file data from URL: \(url)")
                return
            }
            
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
                    val.contains("date") ||
                    val.contains("tt buy") ||
                    val.contains("tt sell") ||
                    val.contains("buy rate") ||
                    val.contains("sell rate") ||
                    val.contains("rate") ||
                    val.contains("inr") ||
                    val.contains("currency")
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
            if h.contains("date") {
                columnMappings[cIdx] = .date
            } else if h.contains("tt buy") || h.contains("buy rate") {
                columnMappings[cIdx] = .ttBuyRate
            } else if h.contains("tt sell") || h.contains("sell rate") {
                columnMappings[cIdx] = .ttSellRate
            } else if h.contains("rate") || h.contains("inr") || h.contains("exchange") {
                columnMappings[cIdx] = .inrExchangeRate
            }
        }
    }
    
    private func analyzeMatches() {
        matchedRows.removeAll()
        
        let dateCol = columnMappings.first(where: { $0.value == .date })?.key
        let ttBuyCol = columnMappings.first(where: { $0.value == .ttBuyRate })?.key
        let ttSellCol = columnMappings.first(where: { $0.value == .ttSellRate })?.key
        let inrCol = columnMappings.first(where: { $0.value == .inrExchangeRate })?.key
        
        guard let dCol = dateCol else { return }
        let calendar = Calendar.current
        
        for rawRow in dataContentRows {
            guard rawRow.indices.contains(dCol),
                  let date = ImportEngine.parseDate(rawRow[dCol])
            else { continue }
            
            let ttBuyVal = ttBuyCol.flatMap { rawRow.indices.contains($0) ? ImportEngine.parseNumber(rawRow[$0]) : nil }
            let ttSellVal = ttSellCol.flatMap { rawRow.indices.contains($0) ? ImportEngine.parseNumber(rawRow[$0]) : nil }
            let inrVal = inrCol.flatMap { rawRow.indices.contains($0) ? ImportEngine.parseNumber(rawRow[$0]) : nil }
            
            if ttBuyVal == nil && ttSellVal == nil && inrVal == nil { continue }
            
            let dbTxs = foreignTransactions.filter { calendar.isDate($0.date, inSameDayAs: date) }
            
            if !dbTxs.isEmpty {
                var rowMatchedTxs: [ForexMatchedTx] = []
                for tx in dbTxs {
                    let resolved = ImportEngine.resolveExchangeRate(
                        txType: tx.type,
                        inrRateCol: inrVal,
                        ttBuyRateCol: ttBuyVal,
                        ttSellRateCol: ttSellVal,
                        categoryFallbackRate: tx.asset?.category?.lastInrExchangeRate
                    )
                    
                    let alreadyMatch: Bool
                    if let resolved = resolved, let existing = tx.inrExchangeRate {
                        alreadyMatch = abs(existing - resolved) < 0.0001
                    } else {
                        alreadyMatch = false
                    }
                    
                    rowMatchedTxs.append(ForexMatchedTx(
                        tx: tx,
                        resolvedRate: resolved,
                        isAlreadyMatching: alreadyMatch
                    ))
                }
                
                matchedRows.append(ForexMatchedRow(
                    date: date,
                    ttBuyRate: ttBuyVal,
                    ttSellRate: ttSellVal,
                    inrRate: inrVal,
                    matchedTxs: rowMatchedTxs
                ))
            }
        }
    }
    
    private func executeUpdate() {
        var count = 0
        for row in matchedRows {
            for item in row.matchedTxs {
                guard !item.isAlreadyMatching, let rate = item.resolvedRate else { continue }
                item.tx.inrExchangeRate = rate
                item.tx.asset?.category?.lastInrExchangeRate = rate
                count += 1
            }
        }
        
        do {
            try modelContext.save()
            updatedTxCount = count
            showSuccessAlert = true
        } catch {
            print("Failed to save forex rate update: \(error)")
        }
    }
}
