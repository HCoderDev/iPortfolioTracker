//
//  FileImportWizardView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct FileImportWizardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Asset.name) private var assets: [Asset]
    @Query(sort: \Broker.name) private var brokers: [Broker]
    @Query(sort: \AssetTransaction.date, order: .reverse) private var existingTransactions: [AssetTransaction]
    
    let initialCategory: Category?
    let initialAsset: Asset?
    let initialMode: ImportMode
    
    // Step state
    @State private var currentStep: Int = 1
    
    // File state
    @State private var isDocumentPickerPresented = false
    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String = ""
    @State private var fileRawGrid: [[String]] = []
    @State private var sheetNames: [String] = []
    @State private var selectedSheetName: String = ""
    
    // Config state
    @State private var selectedBroker: Broker?
    @State private var selectedCategory: Category?
    @State private var headerRowOffset: Int = 0 // Number of rows to skip before header
    
    // Mappings
    @State private var columnMappings: [Int: TargetField] = [:]
    @State private var txTypeMappings: [String: TransactionType?] = [:] // rawString -> mappedType
    @State private var assetMappings: [String: AssetMappingChoice] = [:] // rawAssetName -> choice
    @State private var aliasSavedFeedback: [String: String] = [:] // fileAssetName -> feedback message
    
    // Parsed rows for review
    @State private var parsedRows: [ParsedImportRow] = []
    
    // Alerts & UI state
    @State private var errorMessage: String?
    @State private var isImporting = false
    @State private var postImportReport: PostImportReport?
    
    init(initialCategory: Category? = nil, initialAsset: Asset? = nil, initialMode: ImportMode = .transactions) {
        self.initialCategory = initialCategory
        self.initialAsset = initialAsset
        self.initialMode = initialMode
        _selectedCategory = State(initialValue: initialCategory)
    }
    
    private var dataRows: [[String]] {
        guard fileRawGrid.count > headerRowOffset else { return [] }
        return Array(fileRawGrid.dropFirst(headerRowOffset))
    }
    
    private var headerRow: [String] {
        if let first = dataRows.first {
            return first
        }
        return []
    }
    
    private var dataContentRows: [[String]] {
        guard dataRows.count > 1 else { return [] }
        return Array(dataRows.dropFirst(1))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step Progress Indicator
                stepIndicatorHeader
                
                Divider()
                
                // Step Content
                ScrollView {
                    VStack(spacing: 20) {
                        switch currentStep {
                        case 1:
                            step1FileAndConfig
                        case 2:
                            step2ColumnAndTypeMapping
                        case 3:
                            step3AssetMapping
                        case 4:
                            step4PreviewAndDuplicates
                        default:
                            EmptyView()
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Navigation Buttons
                bottomBar
            }
            .navigationTitle("File Import Wizard")
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
            .sheet(item: $postImportReport) { report in
                ImportResultSummarySheet(
                    report: report,
                    onDismiss: { dismiss() },
                    onUndo: { undoImport(report: report) }
                )
            }
            .onAppear {
                if selectedCategory == nil, let cat = categories.first {
                    selectedCategory = cat
                }
            }
        }
    }
    
    // MARK: - Step Progress Header
    
    private var stepIndicatorHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                stepBadge(number: 1, title: "Select File")
                lineDivider(active: currentStep >= 2)
                stepBadge(number: 2, title: "Columns")
                lineDivider(active: currentStep >= 3)
                stepBadge(number: 3, title: "Assets")
                lineDivider(active: currentStep >= 4)
                stepBadge(number: 4, title: "Review")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }
    
    private func stepBadge(number: Int, title: String) -> some View {
        let isActive = currentStep == number
        let isDone = currentStep > number
        
        return HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isDone ? AppTheme.profit : (isActive ? AppTheme.accent : Color.gray.opacity(0.2)))
                    .frame(width: 22, height: 22)
                
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isActive ? .white : .secondary)
                }
            }
            
            Text(title)
                .font(.system(size: 12, weight: isActive ? .bold : .medium))
                .foregroundStyle(isActive ? .primary : .secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isActive ? AppTheme.accent.opacity(0.12) : Color.clear)
        )
    }
    
    private func lineDivider(active: Bool) -> some View {
        Rectangle()
            .fill(active ? AppTheme.accent : Color.gray.opacity(0.2))
            .frame(height: 2)
            .frame(width: 16)
    }



    
    // MARK: - STEP 1: File & Sheet Selection
    
    private var step1FileAndConfig: some View {
        VStack(alignment: .leading, spacing: 16) {
            step1FileSection
            if !sheetNames.isEmpty {
                step1SheetSection
            }
            step1CategoryAndBrokerSection
            step1HeaderOffsetSection
            if !fileRawGrid.isEmpty {
                step1PreviewSection
            }
        }
    }
    
    private var step1FileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("1. Select Excel or CSV File")
                .font(.headline)
            
            if selectedFileURL == nil {
                Button {
                    isDocumentPickerPresented = true
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                            .font(.title2)
                        Text("Browse Excel / CSV File")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accent.opacity(0.1))
                    .foregroundStyle(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(AppTheme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    )
                }
            } else {
                HStack {
                    Image(systemName: selectedFileName.hasSuffix(".csv") ? "doc.text.fill" : "tablecells.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.accent)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedFileName)
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("\(fileRawGrid.count) total row(s) read")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Change") {
                        isDocumentPickerPresented = true
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var step1SheetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Excel Worksheet")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Picker("Sheet", selection: $selectedSheetName) {
                ForEach(sheetNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .pickerStyle(.menu)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onChange(of: selectedSheetName) { _, newSheet in
                reloadSheetContent(sheetName: newSheet)
            }
        }
    }
    
    private var step1CategoryAndBrokerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("2. Target Category & Broker")
                .font(.headline)
            
            Picker("Target Category", selection: $selectedCategory) {
                Text("Select Category...").tag(nil as Category?)
                ForEach(categories) { cat in
                    Text("\(cat.name) (\(cat.currencyCode))").tag(cat as Category?)
                }
            }
            .pickerStyle(.menu)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Picker("Broker Statement Source", selection: $selectedBroker) {
                Text("None / Unspecified").tag(nil as Broker?)
                ForEach(brokers) { broker in
                    Text(broker.name).tag(broker as Broker?)
                }
            }
            .pickerStyle(.menu)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var step1HeaderOffsetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("3. Skip Header / Title Rows")
                    .font(.headline)
                Spacer()
                Stepper("Skip \(headerRowOffset) row(s)", value: $headerRowOffset, in: 0...max(0, fileRawGrid.count - 1))
                    .labelsHidden()
                Text("Skip \(headerRowOffset)")
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            
            Text("Adjust if your file has title rows or metadata before the actual column headers table.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func previewRowView(idx: Int, row: [String]) -> some View {
        let isIgnored = idx < headerRowOffset
        let isHeader = idx == headerRowOffset
        let rowTitle = isIgnored ? "[ SKIPPED ]" : (isHeader ? "[ HEADER ROW ]" : "")
        
        return HStack(spacing: 8) {
            Text("Row \(idx + 1)")
                .font(.caption2)
                .fontWeight(.bold)
                .frame(width: 50, alignment: .leading)
                .foregroundStyle(isIgnored ? Color.gray : (isHeader ? AppTheme.accent : Color.secondary))
            
            if !rowTitle.isEmpty {
                Text(rowTitle)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(isIgnored ? Color.gray : (isHeader ? AppTheme.accent : Color.secondary))
            }
            
            ForEach(0..<min(8, row.count), id: \.self) { cIdx in
                let cellValue = row[cIdx]
                Text(cellValue.isEmpty ? "-" : cellValue)
                    .font(.caption2)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(isIgnored ? Color.gray.opacity(0.1) : (isHeader ? AppTheme.accent.opacity(0.1) : Color(.systemGray6)))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }
    
    private var step1PreviewSection: some View {
        let sampleRows = Array(fileRawGrid.prefix(50))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("File Preview (Top 50 Rows)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(fileRawGrid.count) total rows in file")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<sampleRows.count, id: \.self) { idx in
                        previewRowView(idx: idx, row: sampleRows[idx])
                    }
                }
            }
            .frame(maxHeight: 280)
            .padding(8)
            .background(Color(.systemGray6).opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    
    // MARK: - STEP 2: Column & Transaction Type Mapping
    
    private var step2ColumnAndTypeMapping: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Map File Columns to Transaction Fields")
                    .font(.headline)
                Text("Select which field corresponds to each column in your imported statement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Column Mapping list
            VStack(spacing: 12) {
                ForEach(0..<headerRow.count, id: \.self) { colIdx in
                    let colHeader = headerRow[colIdx]
                    let sampleVal = dataContentRows.first.flatMap { $0.indices.contains(colIdx) ? $0[colIdx] : nil } ?? ""
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Col \(colIdx + 1): \(colHeader.isEmpty ? "Unnamed" : colHeader)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            if !sampleVal.isEmpty {
                                Text("Sample: \(sampleVal)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Picker("Field", selection: Binding(
                            get: { columnMappings[colIdx] ?? .ignore },
                            set: { newValue in
                                columnMappings[colIdx] = newValue
                                updateTxTypeMappingsIfNeeded()
                            }
                        )) {
                            ForEach(TargetField.allCases) { field in
                                Text(field.rawValue).tag(field)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
                }
            }
            
            // Transaction Type Custom Value Mapping section
            if hasTxTypeColumnMapped {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Transaction Type Value Mapping")
                            .font(.headline)
                        Text("Verify or map raw values in your file to BUY, SELL, or DIVIDEND.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    let uniqueRawTypes = extractUniqueTxTypeValues()
                    
                    VStack(spacing: 8) {
                        ForEach(uniqueRawTypes, id: \.self) { rawVal in
                            HStack {
                                Text("\"\(rawVal)\"")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                Picker("Map to", selection: Binding(
                                    get: { txTypeMappings[rawVal] ?? nil },
                                    set: { txTypeMappings[rawVal] = $0 }
                                )) {
                                    Text("Ignore / Skip").tag(nil as TransactionType?)
                                    Text("BUY").tag(TransactionType.buy as TransactionType?)
                                    Text("SELL").tag(TransactionType.sell as TransactionType?)
                                    Text("DIVIDEND").tag(TransactionType.dividend as TransactionType?)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 220)
                            }
                            .padding(10)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .onAppear {
            autoDetectColumnMappings()
            updateTxTypeMappingsIfNeeded()
        }
    }
    
    private var hasTxTypeColumnMapped: Bool {
        columnMappings.values.contains(.transactionType)
    }
    
    private func extractUniqueTxTypeValues() -> [String] {
        guard let colIdx = columnMappings.first(where: { $0.value == .transactionType })?.key else { return [] }
        var uniqueSet = Set<String>()
        for row in dataContentRows {
            if row.indices.contains(colIdx) {
                let val = row[colIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                if !val.isEmpty {
                    uniqueSet.insert(val)
                }
            }
        }
        return Array(uniqueSet).sorted()
    }
    
    private func updateTxTypeMappingsIfNeeded() {
        let rawTypes = extractUniqueTxTypeValues()
        for raw in rawTypes {
            if txTypeMappings[raw] == nil {
                txTypeMappings[raw] = ImportEngine.inferTxType(raw)
            }
        }
    }
    
    // MARK: - STEP 3: Asset Name Mapping
    
    private var step3AssetMapping: some View {
        VStack(alignment: .leading, spacing: 20) {
            if hasAssetNameColumnMapped {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Map Asset Names in File to Database Assets")
                        .font(.headline)
                    Text("Select existing assets in your portfolio or choose to create new ones automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                let uniqueAssetNames = extractUniqueAssetNames()
                
                VStack(spacing: 12) {
                    ForEach(uniqueAssetNames, id: \.self) { fileAssetName in
                        let currentChoice = assetMappings[fileAssetName] ?? .createNew(fileAssetName)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fileAssetName)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    Text("In statement")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Picker("Map to Asset", selection: Binding(
                                    get: { currentChoice },
                                    set: { assetMappings[fileAssetName] = $0 }
                                )) {
                                    Text("+ Create New Asset \"\(fileAssetName)\"").tag(AssetMappingChoice.createNew(fileAssetName))
                                    Divider()
                                    ForEach(availableAssetsForCategory) { dbAsset in
                                        Text("Existing: \(dbAsset.name)").tag(AssetMappingChoice.existing(dbAsset))
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            // Alias & Rename Action Buttons
                            if case .existing(let dbAsset) = currentChoice {
                                Divider()
                                HStack(spacing: 10) {
                                    if let feedback = aliasSavedFeedback[fileAssetName] {
                                        Label(feedback, systemImage: "checkmark.circle.fill")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(AppTheme.profit)
                                    } else {
                                        Button {
                                            dbAsset.addAlias(fileAssetName)
                                            try? modelContext.save()
                                            withAnimation {
                                                aliasSavedFeedback[fileAssetName] = "Saved alias for future auto-match"
                                            }
                                        } label: {
                                            Label("Save as Alias", systemImage: "bookmark.fill")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(AppTheme.accent)
                                        
                                        Button {
                                            dbAsset.name = fileAssetName
                                            try? modelContext.save()
                                            withAnimation {
                                                aliasSavedFeedback[fileAssetName] = "Renamed DB asset to match"
                                            }
                                        } label: {
                                            Label("Rename Asset in DB", systemImage: "pencil")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.orange)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("No Asset Name Column Mapped")
                        .font(.headline)
                    Text("Since your file does not contain an Asset Name column, select a single asset to assign all imported transactions to:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Picker("Target Asset", selection: Binding(
                        get: { initialAsset ?? availableAssetsForCategory.first },
                        set: { _ in }
                    )) {
                        ForEach(availableAssetsForCategory) { dbAsset in
                            Text(dbAsset.name).tag(dbAsset as Asset?)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .onAppear {
            initializeAssetMappings()
        }
    }
    
    private var hasAssetNameColumnMapped: Bool {
        columnMappings.values.contains(.assetName)
    }
    
    private var availableAssetsForCategory: [Asset] {
        guard let cat = selectedCategory else { return assets }
        return assets.filter { $0.category?.persistentModelID == cat.persistentModelID }
    }
    
    private func extractUniqueAssetNames() -> [String] {
        guard let colIdx = columnMappings.first(where: { $0.value == .assetName })?.key else { return [] }
        var uniqueSet = Set<String>()
        for row in dataContentRows {
            if row.indices.contains(colIdx) {
                let val = row[colIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                if !val.isEmpty {
                    uniqueSet.insert(val)
                }
            }
        }
        return Array(uniqueSet).sorted()
    }
    
    private func initializeAssetMappings() {
        let names = extractUniqueAssetNames()
        for name in names {
            if assetMappings[name] == nil {
                // Auto-match exact or fuzzy name against DB assets
                if let match = availableAssetsForCategory.first(where: { ImportEngine.isAssetNameMatch($0.name, name) }) {
                    assetMappings[name] = .existing(match)
                } else if let fallbackMatch = assets.first(where: { ImportEngine.isAssetNameMatch($0.name, name) }) {
                    assetMappings[name] = .existing(fallbackMatch)
                } else {
                    assetMappings[name] = .createNew(name)
                }
            }
        }
    }
    
    // MARK: - STEP 4: Review & Duplicate Resolution
    
    private var step4PreviewAndDuplicates: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Summary Cards
            let newCount = parsedRows.filter { $0.duplicateStatus == .none && $0.isValid }.count
            let exactCount = parsedRows.filter { if case .exact = $0.duplicateStatus { return true }; if case .fuzzy1Day = $0.duplicateStatus { return true }; return false }.count
            let combinedCount = parsedRows.filter { if case .combined = $0.duplicateStatus { return true }; return false }.count
            
            if newCount == 0 && !parsedRows.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.profit)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All Transactions Already Imported")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.profit)
                        Text("Every transaction in this file matches records in your database up to date. No new transactions will be added.")
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
            }
            
            HStack(spacing: 12) {
                summaryBadge(title: "New Rows", count: newCount, color: AppTheme.profit)
                summaryBadge(title: "Exact / Shifted", count: exactCount, color: AppTheme.warning)
                summaryBadge(title: "Combined Dups", count: combinedCount, color: Color.purple)
            }
            
            // Selection Controls
            HStack {
                Button("Select All New") {
                    for i in 0..<parsedRows.count {
                        if parsedRows[i].duplicateStatus == .none {
                            parsedRows[i].isSelected = true
                        }
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                
                Button("Deselect All Duplicates") {
                    for i in 0..<parsedRows.count {
                        if parsedRows[i].duplicateStatus.isDuplicate {
                            parsedRows[i].isSelected = false
                        }
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                
                Spacer()
                
                let selectedTotal = parsedRows.filter { $0.isSelected }.count
                Text("\(selectedTotal) / \(parsedRows.count) selected")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.accent)
            }
            
            Divider()
            
            // Parsed Rows List
            LazyVStack(spacing: 10) {
                ForEach($parsedRows) { $row in
                    HStack(spacing: 12) {
                        Toggle("", isOn: $row.isSelected)
                            .labelsHidden()
                            .tint(AppTheme.accent)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                if let date = row.date {
                                    Text(date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                } else {
                                    Text("Invalid Date")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.loss)
                                }
                                
                                if let type = row.txType {
                                    Text(type.rawValue)
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(txTypeColor(type).opacity(0.12))
                                        .foregroundStyle(txTypeColor(type))
                                        .clipShape(Capsule())
                                }
                                
                                Spacer()
                                
                                statusBadge(for: row.duplicateStatus)
                            }
                            
                            HStack {
                                let assetName = row.mappedAsset?.name ?? row.newAssetName ?? row.rawAssetName ?? "Default Asset"
                                Text(assetName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                if let units = row.units, let price = row.pricePerUnit {
                                    Text("\(units.formatted2) units @ \(price.formatted2)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            if let rate = row.inrExchangeRate, selectedCategory?.currencyCode != "INR" {
                                Text("INR Rate: ₹\(rate.formatted2)")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.accent)
                            }
                            
                            if let err = row.validationError {
                                Text("Error: \(err)")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.loss)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(row.duplicateStatus.isDuplicate ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private func summaryBadge(title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    @ViewBuilder
    private func statusBadge(for status: DuplicateStatus) -> some View {
        switch status {
        case .none:
            Text("NEW")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AppTheme.profit.opacity(0.15))
                .foregroundStyle(AppTheme.profit)
                .clipShape(Capsule())
        case .exact:
            Text("EXACT DUP")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AppTheme.warning.opacity(0.15))
                .foregroundStyle(AppTheme.warning)
                .clipShape(Capsule())
        case .fuzzy1Day(_, let date):
            Text("SHIFTED DUP (\(date.formatted(date: .numeric, time: .omitted)))")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.15))
                .foregroundStyle(Color.orange)
                .clipShape(Capsule())
        case .combined(_, let details):
            Text("COMBINED DUP (\(details))")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.15))
                .foregroundStyle(Color.purple)
                .clipShape(Capsule())
        }
    }
    
    private func txTypeColor(_ type: TransactionType) -> Color {
        switch type {
        case .buy: return AppTheme.profit
        case .sell: return AppTheme.loss
        case .dividend: return AppTheme.warning
        }
    }
    
    // MARK: - Bottom Bar Navigation
    
    private var bottomBar: some View {
        HStack {
            if currentStep > 1 {
                Button("Back") {
                    currentStep -= 1
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            if currentStep < 4 {
                Button("Next Step") {
                    advanceToNextStep()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .disabled(selectedFileURL == nil || dataContentRows.isEmpty)
            } else {
                let selectedRows = parsedRows.filter({ $0.isSelected && $0.isValid })
                if selectedRows.isEmpty {
                    Button("Nothing to Import — Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                } else {
                    Button {
                        executeFinalImport()
                    } label: {
                        if isImporting {
                            ProgressView()
                        } else {
                            Text("Confirm & Import (\(selectedRows.count))")
                                .fontWeight(.bold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.profit)
                    .disabled(isImporting)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Logic & Actions
    
    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let shouldStop = url.startAccessingSecurityScopedResource()
            defer { if shouldStop { url.stopAccessingSecurityScopedResource() } }
            
            selectedFileURL = url
            selectedFileName = url.lastPathComponent
            
            if url.pathExtension.lowercased() == "xlsx" || url.pathExtension.lowercased() == "xls" {
                sheetNames = XLSXParser.getSheetNames(fileURL: url)
                selectedSheetName = sheetNames.first ?? ""
                fileRawGrid = XLSXParser.parse(fileURL: url, sheetName: selectedSheetName)
            } else {
                sheetNames = []
                selectedSheetName = ""
                if let fileData = try? Data(contentsOf: url),
                   let content = String(data: fileData, encoding: .utf8) ?? String(data: fileData, encoding: .ascii) ?? String(data: fileData, encoding: .windowsCP1252) {
                    fileRawGrid = CSVParser.parse(content: content)
                }
            }
            
            // Auto detect initial header offset if top rows are empty
            if let firstDataRowIdx = fileRawGrid.firstIndex(where: { row in
                row.contains(where: { cell in
                    let val = cell.trimmingCharacters(in: .whitespacesAndNewlines)
                    return !val.isEmpty && (ImportEngine.parseDate(val) != nil || ImportEngine.inferTxType(val) != nil || val.lowercased().contains("date") || val.lowercased().contains("asset"))
                })
            }) {
                headerRowOffset = firstDataRowIdx
            } else {
                headerRowOffset = 0
            }
        case .failure(let err):
            errorMessage = err.localizedDescription
        }
    }
    
    private func reloadSheetContent(sheetName: String) {
        guard let url = selectedFileURL else { return }
        let shouldStop = url.startAccessingSecurityScopedResource()
        defer { if shouldStop { url.stopAccessingSecurityScopedResource() } }
        fileRawGrid = XLSXParser.parse(fileURL: url, sheetName: sheetName)
        
        if let firstDataRowIdx = fileRawGrid.firstIndex(where: { row in
            row.contains(where: { cell in
                let val = cell.trimmingCharacters(in: .whitespacesAndNewlines)
                return !val.isEmpty && (ImportEngine.parseDate(val) != nil || ImportEngine.inferTxType(val) != nil || val.lowercased().contains("date") || val.lowercased().contains("asset"))
            })
        }) {
            headerRowOffset = firstDataRowIdx
        }
    }
    
    private func autoDetectColumnMappings() {
        columnMappings.removeAll()
        let sampleRow = dataContentRows.first ?? headerRow
        
        for cIdx in 0..<headerRow.count {
            let header = headerRow[cIdx].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let sampleVal = sampleRow.indices.contains(cIdx) ? sampleRow[cIdx].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            
            if header.contains("date") || header.contains("time") {
                columnMappings[cIdx] = .date
            } else if header.contains("symbol") || header.contains("asset") || header.contains("stock") || header.contains("scheme") || header.contains("name") || header.contains("ticker") {
                columnMappings[cIdx] = .assetName
            } else if header.contains("type") || header.contains("action") || header.contains("side") || header.contains("transaction") {
                columnMappings[cIdx] = .transactionType
            } else if header.contains("qty") || header.contains("unit") || header.contains("quantity") || header.contains("shares") {
                columnMappings[cIdx] = .quantity
            } else if header.contains("price") || header.contains("nav") || header.contains("rate") || header.contains("amount") || header.contains("cost") || header.contains("value") {
                if columnMappings.values.contains(.price) {
                    if header.contains("rate") || header.contains("forex") || header.contains("inr") {
                        columnMappings[cIdx] = .inrExchangeRate
                    }
                } else {
                    columnMappings[cIdx] = .price
                }
            } else if header.contains("tt buy") {
                columnMappings[cIdx] = .ttBuyRate
            } else if header.contains("tt sell") {
                columnMappings[cIdx] = .ttSellRate
            } else if header.contains("inr") || header.contains("exchange") {
                columnMappings[cIdx] = .inrExchangeRate
            } else if !sampleVal.isEmpty {
                // Smart fallback inspection if header text isn't descriptive
                if columnMappings.values.contains(.date) == false, ImportEngine.parseDate(sampleVal) != nil {
                    columnMappings[cIdx] = .date
                } else if columnMappings.values.contains(.transactionType) == false, ImportEngine.inferTxType(sampleVal) != nil {
                    columnMappings[cIdx] = .transactionType
                } else if columnMappings.values.contains(.assetName) == false, Double(sampleVal) == nil, ImportEngine.parseDate(sampleVal) == nil, ImportEngine.inferTxType(sampleVal) == nil {
                    columnMappings[cIdx] = .assetName
                } else if Double(sampleVal) != nil {
                    if !columnMappings.values.contains(.quantity) {
                        columnMappings[cIdx] = .quantity
                    } else if !columnMappings.values.contains(.price) {
                        columnMappings[cIdx] = .price
                    }
                }
            }
        }
    }
    
    private func advanceToNextStep() {
        if currentStep == 1 {
            autoDetectColumnMappings()
            currentStep = 2
        } else if currentStep == 2 {
            initializeAssetMappings()
            currentStep = 3
        } else if currentStep == 3 {
            buildAndAnalyzeParsedRows()
            currentStep = 4
        }
    }
    
    private func buildAndAnalyzeParsedRows() {
        var rows: [ParsedImportRow] = []
        
        let dateCol = columnMappings.first(where: { $0.value == .date })?.key
        let assetNameCol = columnMappings.first(where: { $0.value == .assetName })?.key
        let txTypeCol = columnMappings.first(where: { $0.value == .transactionType })?.key
        let qtyCol = columnMappings.first(where: { $0.value == .quantity })?.key
        let priceCol = columnMappings.first(where: { $0.value == .price })?.key
        let inrRateCol = columnMappings.first(where: { $0.value == .inrExchangeRate })?.key
        let ttBuyCol = columnMappings.first(where: { $0.value == .ttBuyRate })?.key
        let ttSellCol = columnMappings.first(where: { $0.value == .ttSellRate })?.key
        
        for (rIdx, rawRow) in dataContentRows.enumerated() {
            // Ignore completely empty rows (e.g. manually deleted or blank spacing rows)
            let isRowEmpty = rawRow.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if isRowEmpty { continue }
            
            // Ignore rows where no mapped target column contains non-empty data
            if !columnMappings.isEmpty {
                var hasMappedData = false
                for (colIdx, field) in columnMappings {
                    if field != .ignore, rawRow.indices.contains(colIdx) {
                        let cellVal = rawRow[colIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cellVal.isEmpty {
                            hasMappedData = true
                            break
                        }
                    }
                }
                if !hasMappedData { continue }
            }
            
            var row = ParsedImportRow(rowIndex: rIdx + headerRowOffset + 2, rawData: rawRow)
            
            // 1. Parse Date
            if let dCol = dateCol, rawRow.indices.contains(dCol) {
                row.date = ImportEngine.parseDate(rawRow[dCol])
            }
            if row.date == nil {
                row.validationError = "Missing/invalid date"
            }
            
            // 2. Parse Asset
            if let aCol = assetNameCol, rawRow.indices.contains(aCol) {
                let rawName = rawRow[aCol].trimmingCharacters(in: .whitespacesAndNewlines)
                row.rawAssetName = rawName
                if let choice = assetMappings[rawName] {
                    switch choice {
                    case .existing(let dbAsset):
                        row.mappedAsset = dbAsset
                    case .createNew(let newName):
                        row.newAssetName = newName
                    case .ignore:
                        row.validationError = "Ignored asset name"
                    }
                }
            } else if let fallbackAsset = initialAsset ?? availableAssetsForCategory.first {
                row.mappedAsset = fallbackAsset
            } else {
                row.validationError = "No target asset assigned"
            }
            
            // 3. Parse Transaction Type
            if let tCol = txTypeCol, rawRow.indices.contains(tCol) {
                let rawType = rawRow[tCol].trimmingCharacters(in: .whitespacesAndNewlines)
                if let mapped = txTypeMappings[rawType] {
                    row.txType = mapped
                } else {
                    row.txType = ImportEngine.inferTxType(rawType)
                }
            } else if initialMode == .dividends {
                row.txType = .dividend
            } else {
                row.txType = .buy // Default fallback if unspecified
            }
            
            // 4. Parse Quantity & Price
            if row.txType == .dividend {
                row.units = 1.0
                if let pCol = priceCol, rawRow.indices.contains(pCol) {
                    row.pricePerUnit = ImportEngine.parseNumber(rawRow[pCol])
                }
            } else {
                if let qCol = qtyCol, rawRow.indices.contains(qCol) {
                    row.units = ImportEngine.parseNumber(rawRow[qCol])
                }
                if let pCol = priceCol, rawRow.indices.contains(pCol) {
                    row.pricePerUnit = ImportEngine.parseNumber(rawRow[pCol])
                }
            }
            
            if (row.units ?? 0) <= 0 || (row.pricePerUnit ?? 0) <= 0 {
                row.validationError = "Invalid quantity or price"
            }
            
            // 5. Parse Exchange Rate (TT Buy / TT Sell rules for non-INR)
            let inrVal = inrRateCol.flatMap { rawRow.indices.contains($0) ? ImportEngine.parseNumber(rawRow[$0]) : nil }
            let ttBuyVal = ttBuyCol.flatMap { rawRow.indices.contains($0) ? ImportEngine.parseNumber(rawRow[$0]) : nil }
            let ttSellVal = ttSellCol.flatMap { rawRow.indices.contains($0) ? ImportEngine.parseNumber(rawRow[$0]) : nil }
            
            let catRate = selectedCategory?.lastInrExchangeRate
            if let txType = row.txType {
                row.inrExchangeRate = ImportEngine.resolveExchangeRate(
                    txType: txType,
                    inrRateCol: inrVal,
                    ttBuyRateCol: ttBuyVal,
                    ttSellRateCol: ttSellVal,
                    categoryFallbackRate: catRate
                )
            }
            
            rows.append(row)
        }
        
        // Run Duplicate Detection
        parsedRows = ImportEngine.detectDuplicates(
            rows: rows,
            existingTransactions: existingTransactions,
            brokerFilter: selectedBroker
        )
    }
    
    private func executeFinalImport() {
        isImporting = true
        var imported = 0
        var newAssetsCreated = 0
        var createdAssetMap: [String: Asset] = [:]
        var insertedTransactions: [AssetTransaction] = []
        
        var report = PostImportReport()
        report.categoryName = selectedCategory?.name ?? "General"
        report.currencyCode = selectedCategory?.currencyCode ?? "INR"
        report.currencySymbol = selectedCategory?.currencyCode == "INR" ? "₹" : "$"
        
        var assetImpactDict: [String: PostImportReport.AssetImpact] = [:]
        
        for row in parsedRows where row.isSelected && row.isValid {
            guard let date = row.date,
                  let units = row.units,
                  let price = row.pricePerUnit,
                  let txType = row.txType
            else { continue }
            
            // Determine target asset
            var targetAsset: Asset? = row.mappedAsset
            if targetAsset == nil, let newName = row.newAssetName ?? row.rawAssetName {
                if let existingCreated = createdAssetMap[newName] {
                    targetAsset = existingCreated
                } else {
                    let newAsset = Asset(name: newName, currentPrice: price, category: selectedCategory)
                    modelContext.insert(newAsset)
                    createdAssetMap[newName] = newAsset
                    targetAsset = newAsset
                    newAssetsCreated += 1
                }
            }
            
            guard let finalAsset = targetAsset else { continue }
            
            let transaction = AssetTransaction(
                type: txType,
                units: units,
                pricePerUnit: price,
                date: date,
                asset: finalAsset,
                broker: selectedBroker,
                inrExchangeRate: row.inrExchangeRate
            )
            modelContext.insert(transaction)
            insertedTransactions.append(transaction)
            
            if let rate = row.inrExchangeRate {
                selectedCategory?.lastInrExchangeRate = rate
            }
            
            imported += 1
            
            // Update Report Metrics
            let val = units * price
            var impact = assetImpactDict[finalAsset.name] ?? PostImportReport.AssetImpact(assetName: finalAsset.name)
            
            switch txType {
            case .buy:
                report.buyCount += 1
                report.totalBuyValue += val
                impact.buyCount += 1
                impact.buyUnits += units
                impact.buyValue += val
            case .sell:
                report.sellCount += 1
                report.totalSellValue += val
                impact.sellCount += 1
                impact.sellUnits += units
                impact.sellValue += val
            case .dividend:
                report.dividendCount += 1
                report.totalDividendValue += val
                impact.dividendCount += 1
                impact.dividendValue += val
            }
            
            assetImpactDict[finalAsset.name] = impact
        }
        
        do {
            try modelContext.save()
            report.totalImportedCount = imported
            report.newAssetsCreatedCount = newAssetsCreated
            report.assetImpacts = Array(assetImpactDict.values).sorted(by: { $0.assetName < $1.assetName })
            report.insertedTransactionIDs = insertedTransactions.map { $0.persistentModelID }
            report.insertedAssetIDs = Array(createdAssetMap.values).map { $0.persistentModelID }
            
            isImporting = false
            self.postImportReport = report
        } catch {
            isImporting = false
            errorMessage = "Failed to save imported transactions: \(error.localizedDescription)"
        }
    }
    
    private func undoImport(report: PostImportReport) {
        for txID in report.insertedTransactionIDs {
            if let tx = modelContext.model(for: txID) as? AssetTransaction {
                modelContext.delete(tx)
            }
        }
        
        for assetID in report.insertedAssetIDs {
            if let asset = modelContext.model(for: assetID) as? Asset {
                modelContext.delete(asset)
            }
        }
        
        do {
            try modelContext.save()
            postImportReport = nil
            currentStep = 4 // Return user back to Step 4 for revision
        } catch {
            errorMessage = "Failed to undo import: \(error.localizedDescription)"
        }
    }
}

// MARK: - Post Import Comprehensive Result & Impact Summary Sheet

struct ImportResultSummarySheet: View {
    let report: PostImportReport
    let onDismiss: () -> Void
    let onUndo: () -> Void
    
    @State private var showUndoConfirmation = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Banner
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.profit)
                        
                        Text("Import Complete!")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Statement processed for \(report.categoryName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                    
                    // High Level Summary Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        summaryCard(
                            title: "Total Imported",
                            value: "\(report.totalImportedCount) Entries",
                            subtitle: "\(report.buyCount) Buy • \(report.sellCount) Sell\(report.dividendCount > 0 ? " • \(report.dividendCount) Div" : "")",
                            color: AppTheme.accent,
                            icon: "tray.and.arrow.down.fill"
                        )
                        
                        summaryCard(
                            title: "Net Flow Impact",
                            value: "\(report.currencySymbol)\(abs(report.netFlowValue).formattedComma)",
                            subtitle: report.netFlowValue >= 0 ? "Net Invested" : "Net Withdrawn",
                            color: report.netFlowValue >= 0 ? AppTheme.profit : AppTheme.loss,
                            icon: "arrow.left.arrow.right"
                        )
                        
                        summaryCard(
                            title: "Total Invested (Buy)",
                            value: "\(report.currencySymbol)\(report.totalBuyValue.formattedComma)",
                            subtitle: "\(report.buyCount) Buy Transaction(s)",
                            color: AppTheme.profit,
                            icon: "arrow.down.left"
                        )
                        
                        summaryCard(
                            title: "Total Retrieved (Sell)",
                            value: "\(report.currencySymbol)\(report.totalSellValue.formattedComma)",
                            subtitle: "\(report.sellCount) Sell Transaction(s)",
                            color: report.sellCount == 0 ? .secondary : AppTheme.loss,
                            icon: "arrow.up.right"
                        )
                    }
                    
                    if report.dividendCount > 0 || report.newAssetsCreatedCount > 0 {
                        HStack(spacing: 12) {
                            if report.dividendCount > 0 {
                                miniStatBadge(
                                    title: "Dividend Income",
                                    value: "\(report.currencySymbol)\(report.totalDividendValue.formattedComma)",
                                    icon: "dollarsign.circle.fill",
                                    color: AppTheme.warning
                                )
                            }
                            
                            if report.newAssetsCreatedCount > 0 {
                                miniStatBadge(
                                    title: "New Assets",
                                    value: "\(report.newAssetsCreatedCount) Created",
                                    icon: "plus.circle.fill",
                                    color: AppTheme.accent
                                )
                            }
                        }
                    }
                    
                    // Per-Asset Impact List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Asset-by-Asset Impact Breakdown")
                            .font(.headline)
                        
                        VStack(spacing: 10) {
                            ForEach(report.assetImpacts) { impact in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(impact.assetName)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 4) {
                                            if impact.buyCount > 0 {
                                                Text("\(impact.buyCount) Buy")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(AppTheme.profit.opacity(0.15))
                                                    .foregroundStyle(AppTheme.profit)
                                                    .clipShape(Capsule())
                                            }
                                            if impact.sellCount > 0 {
                                                Text("\(impact.sellCount) Sell")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(AppTheme.loss.opacity(0.15))
                                                    .foregroundStyle(AppTheme.loss)
                                                    .clipShape(Capsule())
                                            }
                                            if impact.dividendCount > 0 {
                                                Text("\(impact.dividendCount) Div")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(AppTheme.warning.opacity(0.15))
                                                    .foregroundStyle(AppTheme.warning)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Units Impact")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(impact.netUnits >= 0 ? "+\(impact.netUnits.formatted2) units" : "\(impact.netUnits.formatted2) units")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(impact.netUnits >= 0 ? AppTheme.profit : AppTheme.loss)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("Value Added")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            HStack(spacing: 6) {
                                                if impact.buyValue > 0 {
                                                    Text("+\(report.currencySymbol)\(impact.buyValue.formattedComma)")
                                                        .font(.caption)
                                                        .fontWeight(.bold)
                                                        .foregroundStyle(AppTheme.profit)
                                                }
                                                if impact.sellValue > 0 {
                                                    Text("-\(report.currencySymbol)\(impact.sellValue.formattedComma)")
                                                        .font(.caption)
                                                        .fontWeight(.bold)
                                                        .foregroundStyle(AppTheme.loss)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Color(.systemGray6).opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                    // Undo Action Button at Bottom
                    Button(role: .destructive) {
                        showUndoConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Undo Import")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Text("Remove all \(report.totalImportedCount) imported entries & re-configure")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.loss.opacity(0.8))
                            }
                            Spacer()
                        }
                        .padding()
                        .background(AppTheme.loss.opacity(0.1))
                        .foregroundStyle(AppTheme.loss)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.loss.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.top, 12)
                }
                .padding()
            }
            .navigationTitle("Import Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Undo", role: .destructive) {
                        showUndoConfirmation = true
                    }
                    .foregroundStyle(AppTheme.loss)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .confirmationDialog("Undo Import?", isPresented: $showUndoConfirmation, titleVisibility: .visible) {
                Button("Undo Import & Remove Entries", role: .destructive) {
                    onUndo()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all \(report.totalImportedCount) transaction(s) created during this import and let you revise your mappings.")
            }
        }
    }
    
    @ViewBuilder
    private func summaryCard(title: String, value: String, subtitle: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private func miniStatBadge(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
            }
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
