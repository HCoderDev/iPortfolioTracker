//
//  NoteFormView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct AssetNoteFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Asset.name) private var allAssets: [Asset]
    
    let defaultAsset: Asset?
    
    @State private var selectedAsset: Asset?
    @State private var title = ""
    @State private var noteDescription = ""
    @State private var selectedDate = Date()
    
    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var trimmedDescription: String {
        noteDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isValid: Bool {
        !trimmedTitle.isEmpty && !trimmedDescription.isEmpty && (selectedAsset != nil || defaultAsset != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Asset Association") {
                    if let asset = defaultAsset {
                        HStack {
                            Text("Asset")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(asset.name)
                                .fontWeight(.semibold)
                        }
                    } else {
                        Picker("Select Asset", selection: $selectedAsset) {
                            Text("Select an asset...").tag(nil as Asset?)
                            ForEach(allAssets) { asset in
                                Text(asset.name).tag(asset as Asset?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section("Investment Thesis / Thought Process Note") {
                    TextField("Title (e.g. Q3 Earnings Review, Buy Rationale)", text: $title)
                    DatePicker("Note Date", selection: $selectedDate, displayedComponents: .date)
                    TextField("Note Details / Rationale...", text: $noteDescription, axis: .vertical)
                        .lineLimit(5...10)
                }
            }
            .navigationTitle("Add Asset Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNote()
                    }
                    .disabled(!isValid)
                    .bold()
                }
            }
            .onAppear {
                if selectedAsset == nil {
                    selectedAsset = defaultAsset ?? allAssets.first
                }
            }
        }
    }
    
    private func saveNote() {
        guard let targetAsset = defaultAsset ?? selectedAsset else { return }
        let note = AssetNote(
            title: trimmedTitle,
            noteDescription: trimmedDescription,
            date: selectedDate,
            asset: targetAsset
        )
        modelContext.insert(note)
        dismiss()
    }
}

struct EditAssetNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let note: AssetNote
    
    @State private var title = ""
    @State private var noteDescription = ""
    @State private var selectedDate = Date()
    
    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var trimmedDescription: String {
        noteDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isValid: Bool {
        !trimmedTitle.isEmpty && !trimmedDescription.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                noteFields
            }
            .navigationTitle("Edit Note")
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
                }
            }
            .onAppear {
                title = note.title
                noteDescription = note.noteDescription
                selectedDate = note.date
            }
        }
    }
    
    @ViewBuilder
    private var noteFields: some View {
        Section("Note Details") {
            TextField("Title", text: $title)
            TextField("Description", text: $noteDescription, axis: .vertical)
                .lineLimit(4...8)
            DatePicker("Note Date", selection: $selectedDate, displayedComponents: .date)
        }
    }
    
    private func save() {
        note.title = trimmedTitle
        note.noteDescription = trimmedDescription
        note.date = selectedDate
    }
}
