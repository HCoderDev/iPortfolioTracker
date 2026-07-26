//
//  AssetReminderFormSheet.swift
//  PortfolioTracker
//
//  Created by Antigravity on 30/05/26.
//

import SwiftUI
import SwiftData

struct AssetReminderFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Asset.name) private var allAssets: [Asset]
    
    // In edit mode, this reminder will be populated
    let reminder: AssetReminder?
    
    // In add mode, if we are inside a specific asset page
    let defaultAsset: Asset?
    
    @State private var title = ""
    @State private var notes = ""
    @State private var eventDate = Date()
    @State private var isCompleted = false
    @State private var selectedAsset: Asset?
    
    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isValid: Bool {
        !trimmedTitle.isEmpty && (selectedAsset != nil || defaultAsset != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Event Title (e.g. Earnings Report)", text: $title)
                    
                    DatePicker("Event Date", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                    
                    TextField("Notes (e.g. Look out for EPS guidance)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Asset Association") {
                    if let fixedAsset = defaultAsset {
                        HStack {
                            Text("Asset")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(fixedAsset.name)
                                .fontWeight(.semibold)
                        }
                    } else {
                        Picker("Select Asset", selection: $selectedAsset) {
                            Text("Choose an Asset").tag(nil as Asset?)
                            ForEach(allAssets) { asset in
                                Text(asset.name).tag(asset as Asset?)
                            }
                        }
                    }
                }
                
                if reminder != nil {
                    Section("Status") {
                        Toggle("Mark as Completed", isOn: $isCompleted)
                            .tint(AppTheme.profit)
                    }
                }
            }
            .navigationTitle(reminder == nil ? "Schedule Reminder" : "Edit Reminder")
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
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let reminder = reminder {
                    title = reminder.title
                    notes = reminder.notes
                    eventDate = reminder.eventDate
                    isCompleted = reminder.isCompleted
                    selectedAsset = reminder.asset
                } else if let defaultAsset = defaultAsset {
                    selectedAsset = defaultAsset
                }
            }
        }
    }
    
    private func save() {
        if let reminder = reminder {
            reminder.title = trimmedTitle
            reminder.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            reminder.eventDate = eventDate
            reminder.isCompleted = isCompleted
            if defaultAsset == nil {
                reminder.asset = selectedAsset
            }
        } else {
            let targetAsset = defaultAsset ?? selectedAsset
            let newReminder = AssetReminder(
                title: trimmedTitle,
                eventDate: eventDate,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                isCompleted: isCompleted,
                asset: targetAsset
            )
            modelContext.insert(newReminder)
            targetAsset?.reminders.append(newReminder)
        }
        
        try? modelContext.save()
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
    
    AssetReminderFormSheet(reminder: nil, defaultAsset: nil)
        .modelContainer(for: previewModels, inMemory: true)
}
