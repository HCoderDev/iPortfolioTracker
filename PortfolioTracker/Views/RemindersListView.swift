//
//  RemindersListView.swift
//  PortfolioTracker
//
//  Created by Antigravity on 30/05/26.
//

import SwiftUI
import SwiftData

struct RemindersListView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \AssetReminder.eventDate) private var allReminders: [AssetReminder]
    @Query(sort: \Asset.name) private var allAssets: [Asset]
    
    @State private var filterSegment = 0 // 0 = Upcoming, 1 = Completed, 2 = All
    @State private var searchText = ""
    @State private var showAddReminder = false
    @State private var reminderToEdit: AssetReminder?
    
    private var filteredReminders: [AssetReminder] {
        var items = allReminders
        
        // 1. Filter by Completion status
        if filterSegment == 0 {
            items = items.filter { !$0.isCompleted }
        } else if filterSegment == 1 {
            items = items.filter { $0.isCompleted }
        }
        
        // 2. Filter by Search Text (Title, Notes, or Asset Name)
        if !searchText.isEmpty {
            items = items.filter { reminder in
                reminder.title.localizedCaseInsensitiveContains(searchText) ||
                reminder.notes.localizedCaseInsensitiveContains(searchText) ||
                (reminder.asset?.name.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return items
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter Bar
            Picker("Status Filter", selection: $filterSegment) {
                Text("Upcoming").tag(0)
                Text("Completed").tag(1)
                Text("All").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .padding(.top, 8)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    if filteredReminders.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                                .frame(height: 40)
                            Image(systemName: filterSegment == 0 ? "bell.fill" : "bell.slash.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text(searchText.isEmpty ? "No reminders found" : "No matching reminders")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text(searchText.isEmpty
                                 ? (filterSegment == 0 ? "You have no upcoming stock watch events." : "You have no completed reminders.")
                                 : "Try refining your search terms.")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            if filterSegment == 0 && searchText.isEmpty {
                                Button {
                                    showAddReminder = true
                                } label: {
                                    Text("Add First Reminder")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(AppTheme.accent)
                                        .clipShape(Capsule())
                                }
                                .padding(.top, 12)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ForEach(filteredReminders) { reminder in
                            let isOverdue = !reminder.isCompleted && reminder.eventDate < Date()
                            
                            HStack(alignment: .top, spacing: 12) {
                                // Checklist check circle button
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        reminder.isCompleted.toggle()
                                        try? modelContext.save()
                                    }
                                } label: {
                                    Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(reminder.isCompleted ? AppTheme.profit : (isOverdue ? AppTheme.loss : .secondary))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 2)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .center, spacing: 8) {
                                        Text(reminder.title)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .strikethrough(reminder.isCompleted)
                                            .foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                                        
                                        if isOverdue {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.caption2)
                                                .foregroundStyle(AppTheme.loss)
                                        }
                                        
                                        Spacer()
                                        
                                        // Asset tag badge
                                        if let asset = reminder.asset {
                                            Text(asset.name)
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(AppTheme.accent.opacity(0.12))
                                                .foregroundStyle(AppTheme.accent)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 10))
                                        Text(reminder.eventDate, style: .date)
                                            .font(.caption2)
                                        Text("at")
                                            .font(.system(size: 9))
                                        Text(reminder.eventDate, style: .time)
                                            .font(.caption2)
                                    }
                                    .foregroundStyle(reminder.isCompleted ? .secondary : (isOverdue ? AppTheme.loss : .secondary))
                                    
                                    if !reminder.notes.isEmpty {
                                        Text(reminder.notes)
                                            .font(.caption)
                                            .foregroundStyle(reminder.isCompleted ? .tertiary : .secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                
                                // Action Menu for Edit & Delete
                                Menu {
                                    Button {
                                        reminderToEdit = reminder
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    
                                    Button(role: .destructive) {
                                        withAnimation {
                                            modelContext.delete(reminder)
                                            try? modelContext.save()
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                }
                            }
                            .padding(14)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Stock Watch Reminders")
        .searchable(text: $searchText, prompt: "Search events, notes, or assets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddReminder = true
                } label: {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title3)
                }
                .disabled(allAssets.isEmpty)
            }
        }
        .sheet(isPresented: $showAddReminder) {
            AssetReminderFormSheet(reminder: nil, defaultAsset: nil)
        }
        .sheet(item: $reminderToEdit) { reminder in
            AssetReminderFormSheet(reminder: reminder, defaultAsset: nil)
        }
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
    
    NavigationStack {
        RemindersListView()
            .modelContainer(for: previewModels, inMemory: true)
    }
}
