//
//  AllAssetNotesView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct AllAssetNotesView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \AssetNote.date, order: .reverse) private var allNotes: [AssetNote]
    @Query(sort: \Asset.name) private var allAssets: [Asset]
    
    @State private var searchText = ""
    @State private var selectedAssetFilter: Asset?
    @State private var showAddNoteSheet = false
    @State private var noteToEdit: AssetNote?
    
    private var filteredNotes: [AssetNote] {
        var items = allNotes
        
        if let asset = selectedAssetFilter {
            items = items.filter { $0.asset?.persistentModelID == asset.persistentModelID }
        }
        
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            items = items.filter { note in
                note.title.lowercased().contains(query) ||
                note.noteDescription.lowercased().contains(query) ||
                (note.asset?.name.lowercased().contains(query) ?? false)
            }
        }
        
        return items
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar & Search
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("INVESTMENT JOURNAL")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(AppTheme.accent)
                        Text("Asset Thought Process & Thesis Notes")
                            .font(.title3.weight(.bold))
                    }
                    Spacer()
                    
                    Button {
                        showAddNoteSheet = true
                    } label: {
                        Label("Add Note", systemImage: "plus.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(spacing: 10) {
                    // Search box
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search title, rationale, or asset name...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // Filter Asset Menu
                    Menu {
                        Button {
                            selectedAssetFilter = nil
                        } label: {
                            Label("All Assets (\(allAssets.count))", systemImage: selectedAssetFilter == nil ? "checkmark" : "")
                        }
                        Divider()
                        ForEach(allAssets) { asset in
                            Button {
                                selectedAssetFilter = asset
                            } label: {
                                Label(asset.name, systemImage: selectedAssetFilter?.persistentModelID == asset.persistentModelID ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text(selectedAssetFilter?.name ?? "All Assets")
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppTheme.accent.opacity(0.12))
                        .foregroundStyle(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .modifier(AppTheme.cardStyle())
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Notes Content List
            ScrollView {
                LazyVStack(spacing: 12) {
                    if filteredNotes.isEmpty {
                        ContentUnavailableView(
                            searchText.isEmpty ? "No Investment Notes Yet" : "No Matching Notes Found",
                            systemImage: "note.text",
                            description: Text(searchText.isEmpty ? "Document your buy rationale, earnings updates, and investment thought process against any asset." : "Try adjusting your search terms or asset filter.")
                        )
                        .padding(.vertical, 40)
                    } else {
                        ForEach(filteredNotes) { note in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            if let asset = note.asset {
                                                Text(asset.name)
                                                    .font(.system(size: 10, weight: .bold))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .background(AppTheme.accent.opacity(0.15))
                                                    .foregroundStyle(AppTheme.accent)
                                                    .clipShape(Capsule())
                                            }
                                            
                                            Text(note.date.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Text(note.title)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    Menu {
                                        Button {
                                            noteToEdit = note
                                        } label: {
                                            Label("Edit Note", systemImage: "pencil")
                                        }
                                        Button(role: .destructive) {
                                            modelContext.delete(note)
                                        } label: {
                                            Label("Delete Note", systemImage: "trash")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Text(note.noteDescription)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.subtleBorder, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Investment Rationale Notes")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddNoteSheet) {
            AssetNoteFormSheet(defaultAsset: selectedAssetFilter)
        }
        .sheet(item: $noteToEdit) { note in
            EditAssetNoteSheet(note: note)
        }
    }
}
