//
//  ManageSubCategoriesView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct ManageSubCategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let category: Category
    
    @State private var newSubCategoryName = ""
    @State private var subCategoryToEdit: SubCategory?
    @State private var editName = ""
    @State private var showEditAlert = false
    
    var sortedSubCategories: [SubCategory] {
        category.subCategories.sorted(by: { $0.name.localizedCompare($1.name) == .orderedAscending })
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Add Subcategory Input Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add New Subcategory")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        TextField("e.g. Banking, Energy, Automobile", text: $newSubCategoryName)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button(action: addSubCategory) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.accent)
                        }
                        .disabled(newSubCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                
                // List of existing subcategories
                List {
                    Section("Existing Subcategories (\(category.subCategories.count))") {
                        if sortedSubCategories.isEmpty {
                            Text("No subcategories defined. Unmarked assets in this category will be grouped under 'Unassigned'.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(sortedSubCategories) { subCat in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(subCat.name)
                                            .font(.body)
                                            .fontWeight(.semibold)
                                        Text("\(subCat.assets.count) assets")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Edit
                                    Button {
                                        subCategoryToEdit = subCat
                                        editName = subCat.name
                                        showEditAlert = true
                                    } label: {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(AppTheme.accent)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, 8)
                                    
                                    // Delete
                                    Button {
                                        deleteSubCategory(subCat)
                                    } label: {
                                        Image(systemName: "trash.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(AppTheme.loss)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                            .onDelete(perform: deleteSubCategoriesAtIndexes)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Manage Subcategories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Rename Subcategory", isPresented: $showEditAlert) {
                TextField("Subcategory Name", text: $editName)
                Button("Cancel", role: .cancel) {
                    subCategoryToEdit = nil
                }
                Button("Save") {
                    if let subCat = subCategoryToEdit {
                        let trimmed = editName.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            withAnimation {
                                subCat.name = trimmed
                            }
                        }
                    }
                    subCategoryToEdit = nil
                }
            } message: {
                Text("Enter a new name for this subcategory.")
            }
        }
    }
    
    private func addSubCategory() {
        let trimmedName = newSubCategoryName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        // Check for duplicates within this category
        if category.subCategories.contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }) {
            // Already exists, just return or clear
            newSubCategoryName = ""
            return
        }
        
        withAnimation {
            let newSub = SubCategory(name: trimmedName, category: category)
            modelContext.insert(newSub)
            category.subCategories.append(newSub)
            newSubCategoryName = ""
        }
    }
    
    private func deleteSubCategory(_ subCat: SubCategory) {
        withAnimation {
            // Remove from category's array
            category.subCategories.removeAll(where: { $0.persistentModelID == subCat.persistentModelID })
            modelContext.delete(subCat)
        }
    }
    
    private func deleteSubCategoriesAtIndexes(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let subCat = sortedSubCategories[index]
                category.subCategories.removeAll(where: { $0.persistentModelID == subCat.persistentModelID })
                modelContext.delete(subCat)
            }
        }
    }
}
