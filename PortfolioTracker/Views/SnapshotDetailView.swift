//
//  SnapshotDetailView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct SnapshotDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let snapshot: PortfolioSnapshot
    
    @State private var expandedCategories: Set<String> = []
    @State private var showDeleteConfirmation = false
    
    private var totalGL: Double {
        snapshot.totalValueINR - snapshot.totalInvestedINR
    }
    
    private var sortedCategories: [CategorySnapshot] {
        snapshot.categorySnapshots.sorted(by: { $0.currentValueINR > $1.currentValueINR })
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroSummaryCard
                assetBreakdownSection
                deleteSnapshotButton
            }
            .padding(.vertical)
        }
        .navigationTitle(snapshot.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(AppTheme.loss)
                }
            }
        }
        .alert("Delete Snapshot?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSnapshot()
            }
        } message: {
            Text("Are you sure you want to delete this snapshot taken on \(snapshot.date.formatted(date: .abbreviated, time: .shortened))? This action cannot be undone.")
        }
    }
    
    // MARK: - Subviews
    
    private var heroSummaryCard: some View {
        VStack(spacing: 12) {
            Text("Consolidated Value at Snapshot")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            
            Text("₹ \(snapshot.totalValueINR.formattedComma)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            if let note = snapshot.note, !note.isEmpty {
                Text("\"\(note)\"")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
                .padding(.vertical, 4)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Total Cost Basis")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("₹ \(snapshot.totalInvestedINR.formattedComma)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Absolute G/L")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("\(totalGL >= 0 ? "+" : "")₹ \(totalGL.formattedComma)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(totalGL >= 0 ? AppTheme.profit : AppTheme.loss)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.heroGradient)
        )
        .padding(.horizontal)
    }
    
    private var assetBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Asset Breakdown (INR)")
                .font(.headline)
                .padding(.horizontal)
            
            if sortedCategories.isEmpty {
                ContentUnavailableView(
                    "No Data Captured",
                    systemImage: "folder.badge.minus",
                    description: Text("This snapshot does not contain any category data.")
                )
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 0) {
                    categoryTableHeader
                    
                    ForEach(sortedCategories) { catSnap in
                        categoryGroupView(catSnap)
                    }
                }
                .background(Color(.systemGray6).opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
                .padding(.horizontal)
            }
        }
    }
    
    private var categoryTableHeader: some View {
        HStack(spacing: 0) {
            Text("Category / Asset")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Invested")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
            
            Text("Current")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
            
            Text("% Alloc")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .frame(width: 55, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
    }
    
    @ViewBuilder
    private func categoryGroupView(_ catSnap: CategorySnapshot) -> some View {
        let isExpanded = expandedCategories.contains(catSnap.categoryName)
        let catAlloc = snapshot.totalValueINR > 0 ? (catSnap.currentValueINR / snapshot.totalValueINR) * 100 : 0.0
        
        Button {
            withAnimation {
                if isExpanded {
                    expandedCategories.remove(catSnap.categoryName)
                } else {
                    expandedCategories.insert(catSnap.categoryName)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 12)
                
                Image(systemName: "folder.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
                
                Text(catSnap.categoryName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.accent)
                
                Spacer()
                
                Text("₹\(catSnap.currentValueINR.formattedCompact) (\(catAlloc.formatted2)%)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray5).opacity(0.4))
        }
        .buttonStyle(.plain)
        
        if isExpanded {
            let sortedAssets = catSnap.assetSnapshots.sorted(by: { $0.currentValueINR > $1.currentValueINR })
            
            ForEach(sortedAssets) { assetSnap in
                assetRowView(catSnap: catSnap, assetSnap: assetSnap)
            }
        }
    }
    
    @ViewBuilder
    private func assetRowView(catSnap: CategorySnapshot, assetSnap: AssetSnapshot) -> some View {
        let assetAlloc = snapshot.totalValueINR > 0 ? (assetSnap.currentValueINR / snapshot.totalValueINR) * 100 : 0.0
        let originalSymbol = catSnap.currencyCode == "INR" ? "₹" : "$"
        
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(assetSnap.assetName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text("Units: \(assetSnap.units.formatted2) · Price: \(originalSymbol)\(assetSnap.currentPrice.formatted2)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
                
                Text("₹\(assetSnap.investedValueINR.formattedCompact)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .trailing)
                
                Text("₹\(assetSnap.currentValueINR.formattedCompact)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 90, alignment: .trailing)
                
                Text("\(assetAlloc.formatted2)%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 55, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .padding(.horizontal, 16)
        }
        .background(Color.white.opacity(0.01))
    }
    
    private var deleteSnapshotButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Snapshot")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.loss)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.loss.opacity(0.1)))
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    private func deleteSnapshot() {
        modelContext.delete(snapshot)
        try? modelContext.save()
        dismiss()
    }
}
