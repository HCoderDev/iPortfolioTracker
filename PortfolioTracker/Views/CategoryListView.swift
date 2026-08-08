//
//  CategoryListView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct CategoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]
    @Query private var currencies: [Currency]
    
    @State private var showAddSheet = false
    @State private var showTargetAllocationSheet = false
    @State private var categoryToEdit: Category?
    @State private var searchText = ""
    
    var filteredCategories: [Category] {
        if searchText.isEmpty {
            return categories
        } else {
            return categories.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.currencyCode.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        List {
            if filteredCategories.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "No Categories",
                        systemImage: "folder",
                        description: Text("Add a category to organize your assets.")
                    )
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            } else {
                ForEach(filteredCategories) { category in
                    CategoryRow(category: category, onEdit: {
                        categoryToEdit = category
                    }, onDelete: {
                        deleteCategory(category)
                    })
                }
                .onDelete(perform: deleteCategories)
            }
        }
        .navigationTitle("Categories")
        .searchable(text: $searchText, prompt: "Search Categories")
        .navigationDestination(for: Category.self) { category in
            CategoryDetailView(category: category)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    Button {
                        showTargetAllocationSheet = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .disabled(currencies.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            CategoryFormSheet(category: nil, currencies: currencies)
        }
        .sheet(isPresented: $showTargetAllocationSheet) {
            TargetAllocationConfigSheet()
        }
        .sheet(item: $categoryToEdit) { category in
            CategoryFormSheet(category: category, currencies: currencies)
        }
    }
    
    private func deleteCategories(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredCategories[index])
        }
    }
    
    private func deleteCategory(_ category: Category) {
        modelContext.delete(category)
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: Category
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: category) {
                HStack(spacing: 14) {
                    Image(systemName: "folder.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(category.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.primary)
                            
                            if category.isIndividualEquity ?? false {
                                Text("EQUITY")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(AppTheme.accent)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.accent.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Text("Currency: \(category.currencyCode) · Target Alloc: \(category.targetAllocationPercent.formatted2)%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let updatedDate = category.lastUpdatedDate {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 10))
                                Text("Data updated up to: \(updatedDate.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(AppTheme.accent)
                        }
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            HStack(spacing: 8) {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.loss)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }
}



// MARK: - Category Form Sheet

struct CategoryFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let category: Category?
    let currencies: [Currency]
    
    @State private var name: String = ""
    @State private var selectedCurrencyCode: String = ""
    @State private var isIndividualEquity: Bool = false
    @State private var ltcgThresholdMonths: Int = 12
    @State private var hasUpdatedDate: Bool = false
    @State private var lastUpdatedDate: Date = Date()
    
    private var defaultCurrency: Currency? {
        currencies.first(where: { $0.isDefault }) ?? currencies.first
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Category Details") {
                    TextField("Category Name (e.g. Indian Stocks)", text: $name)
                    
                    Picker("Currency", selection: $selectedCurrencyCode) {
                        if currencies.isEmpty {
                            Text("No currencies available").tag("")
                        }
                        ForEach(currencies) { currency in
                            Text(currency.code).tag(currency.code)
                        }
                    }
                    
                    Toggle("Is Individual Equity Category", isOn: $isIndividualEquity)
                        .tint(AppTheme.accent)
                }
                
                Section("Tax & Capital Gains Threshold") {
                    Picker("LTCG Holding Duration", selection: $ltcgThresholdMonths) {
                        Text("1 Year (12 months) — e.g. Indian Equity / MF").tag(12)
                        Text("2 Years (24 months) — e.g. US Stocks / Unlisted").tag(24)
                        Text("3 Years (36 months) — e.g. Debt MFs / Gold").tag(36)
                        Text("6 Months (6 months)").tag(6)
                    }
                    
                    Text("Assets in this category held longer than \(ltcgThresholdMonths) months qualify for Long Term Capital Gains (LTCG). Assets held for \(ltcgThresholdMonths) months or less qualify as STCG.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Data Freshness / Updated Up To") {
                    Toggle("Track Last Updated Date", isOn: $hasUpdatedDate)
                        .tint(AppTheme.accent)
                    
                    if hasUpdatedDate {
                        DatePicker(
                            "Data Updated Up To",
                            selection: $lastUpdatedDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        
                        Button {
                            lastUpdatedDate = Date()
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("Set to Current Date & Time Today")
                            }
                            .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                        .tint(AppTheme.accent)
                    }
                }
                
                if category != nil {
                    Section {
                        Button("Delete Category", role: .destructive) {
                            deleteCategory()
                        }
                    }
                }
            }
            .navigationTitle(category == nil ? "Add Category" : "Edit Category")
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
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || selectedCurrencyCode.isEmpty)
                }
            }
            .onAppear {
                if let category = category {
                    name = category.name
                    selectedCurrencyCode = category.currencyCode
                    isIndividualEquity = category.isIndividualEquity ?? false
                    ltcgThresholdMonths = category.ltcgMonths
                    if let date = category.lastUpdatedDate {
                        hasUpdatedDate = true
                        lastUpdatedDate = date
                    } else {
                        hasUpdatedDate = false
                        lastUpdatedDate = Date()
                    }
                } else {
                    selectedCurrencyCode = defaultCurrency?.code ?? ""
                    isIndividualEquity = false
                    ltcgThresholdMonths = 12
                    hasUpdatedDate = true
                    lastUpdatedDate = Date()
                }
            }
        }
    }
    
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !selectedCurrencyCode.isEmpty else { return }
        
        let finalUpdatedDate = hasUpdatedDate ? lastUpdatedDate : nil
        
        if let category = category {
            category.name = trimmedName
            category.currencyCode = selectedCurrencyCode
            category.isIndividualEquity = isIndividualEquity
            category.ltcgThresholdMonths = ltcgThresholdMonths
            category.lastUpdatedDate = finalUpdatedDate
        } else {
            let newCategory = Category(
                name: trimmedName,
                currencyCode: selectedCurrencyCode,
                isIndividualEquity: isIndividualEquity,
                lastUpdatedDate: finalUpdatedDate,
                ltcgThresholdMonths: ltcgThresholdMonths
            )
            modelContext.insert(newCategory)
        }
    }
    
    private func deleteCategory() {
        guard let category else { return }
        modelContext.delete(category)
        dismiss()
    }
}


