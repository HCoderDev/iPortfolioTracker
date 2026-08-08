//
//  AssetNotesAndRemindersCards.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

// MARK: - Asset Investment Notes Card
struct AssetNotesSectionCard: View {
    @Environment(\.modelContext) private var modelContext
    let asset: Asset
    let onAddNote: () -> Void
    let onEditNote: (AssetNote) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "note.text")
                            .foregroundStyle(AppTheme.warning)
                        Text("INVESTMENT THESIS & NOTES")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(.secondary)
                        
                        Text("\(asset.notes.count)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.warning.opacity(0.15))
                            .foregroundStyle(AppTheme.warning)
                            .clipShape(Capsule())
                    }
                    
                    Text("Revisit your thought process and investment rationale over time.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    onAddNote()
                } label: {
                    Label("Add Note", systemImage: "plus.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            let notesList = asset.notes.sorted(by: { $0.date > $1.date })
            
            if notesList.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.title2)
                        .foregroundStyle(.secondary.opacity(0.6))
                    Text("No investment notes recorded yet")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Add your buy rationale, earnings review, or thesis updates to track your thought process.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                VStack(spacing: 10) {
                    ForEach(notesList) { note in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.title)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.primary)
                                    Text(note.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Menu {
                                    Button {
                                        onEditNote(note)
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
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Text(note.noteDescription)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(14)
        .modifier(AppTheme.cardStyle())
    }
}

// MARK: - Asset Reminders Card
struct AssetRemindersSectionCard: View {
    @Environment(\.modelContext) private var modelContext
    let asset: Asset
    let onAddReminder: () -> Void
    let onEditReminder: (AssetReminder) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "bell.fill")
                            .foregroundStyle(AppTheme.accent)
                        Text("REMINDERS & WATCH EVENTS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(.secondary)
                        
                        let upcomingCount = asset.reminders.filter { !$0.isCompleted }.count
                        Text("\(upcomingCount) Active")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent.opacity(0.15))
                            .foregroundStyle(AppTheme.accent)
                            .clipShape(Capsule())
                    }
                    
                    Text("Schedule earnings watch, policy renewal, or review dates.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    onAddReminder()
                } label: {
                    Label("Add Reminder", systemImage: "plus.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            let reminderList = asset.reminders.sorted(by: { $0.eventDate < $1.eventDate })
            
            if reminderList.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bell.badge.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary.opacity(0.6))
                    Text("No reminders set for \(asset.name)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Never miss an earnings call, dividend ex-date, premium due date, or maturity event.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                VStack(spacing: 8) {
                    ForEach(reminderList) { reminder in
                        let isOverdue = !reminder.isCompleted && reminder.eventDate < Date()
                        
                        HStack(alignment: .top, spacing: 10) {
                            Button {
                                reminder.isCompleted.toggle()
                            } label: {
                                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(reminder.isCompleted ? AppTheme.profit : (isOverdue ? Color.red : .secondary))
                            }
                            .buttonStyle(.plain)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(reminder.title)
                                        .font(.system(size: 13, weight: .bold))
                                        .strikethrough(reminder.isCompleted)
                                        .foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                                    
                                    if isOverdue {
                                        Text("OVERDUE")
                                            .font(.system(size: 8, weight: .heavy))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.red.opacity(0.18))
                                            .foregroundStyle(Color.red)
                                            .clipShape(Capsule())
                                    }
                                }
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.caption2)
                                    Text(reminder.eventDate.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2.weight(.medium))
                                }
                                .foregroundStyle(isOverdue ? Color.red : .secondary)
                                
                                if !reminder.notes.isEmpty {
                                    Text(reminder.notes)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .padding(.top, 1)
                                }
                            }
                            
                            Spacer()
                            
                            Menu {
                                Button {
                                    onEditReminder(reminder)
                                } label: {
                                    Label("Edit Reminder", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    modelContext.delete(reminder)
                                } label: {
                                    Label("Delete Reminder", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(14)
        .modifier(AppTheme.cardStyle())
    }
}
