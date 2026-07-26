//
//  NoteFormView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct AssetNoteFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let asset: Asset
    
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
        Form {
            noteFields
            
            Section {
                Button(action: saveNote) {
                    HStack {
                        Spacer()
                        Text("Save Note")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isValid ? AppTheme.warning : Color.gray.opacity(0.3))
                )
                .disabled(!isValid)
            }
        }
        .navigationTitle("Add Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
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
    
    private func saveNote() {
        let note = AssetNote(
            title: trimmedTitle,
            noteDescription: trimmedDescription,
            date: selectedDate,
            asset: asset
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
