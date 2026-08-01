//
//  PortfolioSnapshotsView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData
import Charts

struct PortfolioSnapshotsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PortfolioSnapshot.date, order: .reverse) private var snapshots: [PortfolioSnapshot]
    
    // We also need active categories, assets, and currencies to compute the snapshot live preview and insert new ones
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Asset.name) private var allAssets: [Asset]
    @Query(sort: \Currency.code) private var currencies: [Currency]
    
    @State private var showCreateSheet = false
    
    private var chartData: [PortfolioSnapshot] {
        snapshots.sorted(by: { $0.date < $1.date })
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Growth chart over time
                if chartData.count >= 2 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Net Worth Growth")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        let isProfit = (chartData.last?.totalValueINR ?? 0) >= (chartData.last?.totalInvestedINR ?? 0)
                        
                        Chart {
                            ForEach(chartData) { snap in
                                LineMark(
                                    x: .value("Date", snap.date),
                                    y: .value("Invested", snap.totalInvestedINR),
                                    series: .value("Type", "Invested")
                                )
                                .foregroundStyle(AppTheme.accent)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                                
                                LineMark(
                                    x: .value("Date", snap.date),
                                    y: .value("Net Worth", snap.totalValueINR),
                                    series: .value("Type", "Net Worth")
                                )
                                .foregroundStyle(isProfit ? AppTheme.profit : AppTheme.loss)
                                .lineStyle(StrokeStyle(lineWidth: 3))
                                
                                PointMark(
                                    x: .value("Date", snap.date),
                                    y: .value("Net Worth", snap.totalValueINR)
                                )
                                .foregroundStyle(isProfit ? AppTheme.profit : AppTheme.loss)
                            }
                        }
                        .chartForegroundStyleScale([
                            "Invested": AppTheme.accent,
                            "Net Worth": isProfit ? AppTheme.profit : AppTheme.loss
                        ])
                        .chartLegend(position: .bottom)
                        .frame(height: 240)
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                } else if snapshots.isEmpty {
                    ContentUnavailableView(
                        "No Snapshots",
                        systemImage: "camera.viewfinder",
                        description: Text("Take your first snapshot to start tracking net worth growth over time.")
                    )
                    .padding(.top, 40)
                } else {
                    // Just 1 snapshot: not enough to plot a line, so show a card
                    VStack(spacing: 8) {
                        Text("Need at least 2 snapshots to plot growth chart.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }
                
                // Snapshot List
                if !snapshots.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Snapshot History")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            ForEach(snapshots) { snap in
                                NavigationLink(destination: SnapshotDetailView(snapshot: snap)) {
                                    VStack(spacing: 0) {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(snap.date.formatted(date: .abbreviated, time: .shortened))
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.primary)
                                                
                                                if let note = snap.note, !note.isEmpty {
                                                    Text(note)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            VStack(alignment: .trailing, spacing: 4) {
                                                Text("₹\(snap.totalValueINR.formattedComma)")
                                                    .font(.subheadline)
                                                    .fontWeight(.bold)
                                                    .foregroundStyle(AppTheme.accent)
                                                
                                                let gain = snap.totalValueINR - snap.totalInvestedINR
                                                Text("G/L: \(gain >= 0 ? "+" : "")₹\(gain.formattedComma)")
                                                    .font(.caption2)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(gain >= 0 ? AppTheme.profit : AppTheme.loss)
                                            }
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        
                                        Divider()
                                            .padding(.leading, 16)
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteSnapshot(snap)
                                    } label: {
                                        Label("Delete Snapshot", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Portfolio Snapshots")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            TakeSnapshotSheet(
                categories: categories,
                allAssets: allAssets,
                currencies: currencies,
                onSave: { date, note in
                    takeSnapshot(date: date, note: note)
                }
            )
        }
    }
    
    private func takeSnapshot(date: Date, note: String) {
        let newSnapshot = PortfolioSnapshot(date: date, note: note)
        
        var overallCurrentValueINR = 0.0
        var overallInvestedINR = 0.0
        
        for category in categories {
            let assetsInCat = allAssets.filter { $0.category?.persistentModelID == category.persistentModelID }
            let rate = PortfolioMetrics.currentInrExchangeRate(for: category, currencies: currencies)
            
            var catInvested = 0.0
            var catCurrentValue = 0.0
            var catInvestedINR = 0.0
            var catCurrentValueINR = 0.0
            
            var tempAssetSnaps: [AssetSnapshot] = []
            
            for asset in assetsInCat {
                let filteredTx = asset.transactions.filter { $0.date <= date }
                
                let units: Double
                if asset.holdingType.isNonUnitized {
                    units = 1.0
                } else {
                    units = filteredTx.reduce(0.0) { partialResult, transaction in
                        switch transaction.type {
                        case .buy: return partialResult + transaction.units
                        case .sell: return partialResult - transaction.units
                        case .dividend: return partialResult
                        }
                    }
                }
                
                guard units > 0 else { continue }
                
                let invested: Double
                if asset.holdingType.isNonUnitized {
                    let totalInterest = filteredTx.filter { $0.type == .dividend }.reduce(0.0) { $0 + $1.pricePerUnit }
                    invested = max(0, asset.currentPrice - totalInterest)
                } else {
                    invested = FifoCalculator.calculate(transactions: filteredTx).holdings.reduce(0.0) { partialResult, lot in
                        partialResult + (lot.remainingUnits * lot.buyPrice)
                    }
                }
                
                let currentValue = asset.holdingType.isNonUnitized ? asset.currentPrice : (units * asset.currentPrice)
                
                let investedINR = asset.holdingType.isNonUnitized ? {
                    let totalInterest = filteredTx.filter { $0.type == .dividend }.reduce(0.0) { sum, tx in
                        let txRate = tx.inrExchangeRate ?? rate
                        return sum + (tx.pricePerUnit * txRate)
                    }
                    let currentValueInINR = asset.currentPrice * rate
                    return max(0, currentValueInINR - totalInterest)
                }() : {
                    FifoCalculator.calculateInINR(transactions: filteredTx, categoryExchangeRate: rate).holdings.reduce(0.0) { partialResult, lot in
                        partialResult + lot.remainingUnits * lot.buyPriceINR
                    }
                }()
                
                let currentValueINR = currentValue * rate
                
                overallCurrentValueINR += currentValueINR
                overallInvestedINR += investedINR
                
                catInvested += invested
                catCurrentValue += currentValue
                catInvestedINR += investedINR
                catCurrentValueINR += currentValueINR
                
                let assetSnap = AssetSnapshot(
                    assetName: asset.name,
                    units: units,
                    currentPrice: asset.currentPrice,
                    investedValue: invested,
                    currentValue: currentValue,
                    investedValueINR: investedINR,
                    currentValueINR: currentValueINR
                )
                tempAssetSnaps.append(assetSnap)
            }
            
            if !tempAssetSnaps.isEmpty {
                let catSnap = CategorySnapshot(
                    categoryName: category.name,
                    currencyCode: category.currencyCode,
                    investedValue: catInvested,
                    currentValue: catCurrentValue,
                    exchangeRateToINR: rate,
                    investedValueINR: catInvestedINR,
                    currentValueINR: catCurrentValueINR,
                    portfolioSnapshot: newSnapshot
                )
                
                for assetSnap in tempAssetSnaps {
                    assetSnap.categorySnapshot = catSnap
                    catSnap.assetSnapshots.append(assetSnap)
                    modelContext.insert(assetSnap)
                }
                
                newSnapshot.categorySnapshots.append(catSnap)
                modelContext.insert(catSnap)
            }
        }
        
        newSnapshot.totalValueINR = overallCurrentValueINR
        newSnapshot.totalInvestedINR = overallInvestedINR
        
        modelContext.insert(newSnapshot)
        try? modelContext.save()
    }
    
    private func deleteSnapshot(_ snapshot: PortfolioSnapshot) {
        modelContext.delete(snapshot)
        try? modelContext.save()
    }
}

// MARK: - Take Snapshot Sheet

struct TakeSnapshotSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let categories: [Category]
    let allAssets: [Asset]
    let currencies: [Currency]
    let onSave: (Date, String) -> Void
    
    @State private var snapshotDate = Date()
    @State private var note = ""
    
    private var previewMetrics: (totalValue: Double, totalInvested: Double) {
        var overallCurrentValueINR = 0.0
        var overallInvestedINR = 0.0
        
        for category in categories {
            let assetsInCat = allAssets.filter { $0.category?.persistentModelID == category.persistentModelID }
            let rate = PortfolioMetrics.currentInrExchangeRate(for: category, currencies: currencies)
            
            for asset in assetsInCat {
                let filteredTx = asset.transactions.filter { $0.date <= snapshotDate }
                
                let units: Double
                if asset.holdingType.isNonUnitized {
                    units = 1.0
                } else {
                    units = filteredTx.reduce(0.0) { partialResult, transaction in
                        switch transaction.type {
                        case .buy: return partialResult + transaction.units
                        case .sell: return partialResult - transaction.units
                        case .dividend: return partialResult
                        }
                    }
                }
                
                guard units > 0 else { continue }
                
                let invested: Double
                if asset.holdingType.isNonUnitized {
                    let totalInterest = filteredTx.filter { $0.type == .dividend }.reduce(0.0) { sum, tx in
                        let txRate = tx.inrExchangeRate ?? rate
                        return sum + (tx.pricePerUnit * txRate)
                    }
                    let currentValueInINR = asset.currentPrice * rate
                    invested = max(0, currentValueInINR - totalInterest)
                } else {
                    invested = FifoCalculator.calculateInINR(transactions: filteredTx, categoryExchangeRate: rate).holdings.reduce(0.0) { partialResult, lot in
                        partialResult + lot.remainingUnits * lot.buyPriceINR
                    }
                }
                
                let currentValue = asset.holdingType.isNonUnitized ? asset.currentPrice : (units * asset.currentPrice)
                let currentValueINR = currentValue * rate
                
                overallCurrentValueINR += currentValueINR
                overallInvestedINR += invested
            }
        }
        
        return (overallCurrentValueINR, overallInvestedINR)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Snapshot Information") {
                    DatePicker("Snapshot Date", selection: $snapshotDate, displayedComponents: [.date, .hourAndMinute])
                    
                    TextField("Note / Description (Optional)", text: $note, prompt: Text("e.g. End of Q2, Year-end review"))
                }
                
                Section("Estimated Summary (INR)") {
                    let metrics = previewMetrics
                    
                    HStack {
                        Text("Portfolio Value")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("₹\(metrics.totalValue.formattedComma)")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Total Invested")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("₹\(metrics.totalInvested.formattedComma)")
                            .fontWeight(.semibold)
                    }
                    
                    let gain = metrics.totalValue - metrics.totalInvested
                    HStack {
                        Text("Unrealized Gain/Loss")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(gain >= 0 ? "+" : "")₹\(gain.formattedComma)")
                            .fontWeight(.bold)
                            .foregroundStyle(gain >= 0 ? AppTheme.profit : AppTheme.loss)
                    }
                }
                
                Section {
                    Button(role: .none) {
                        onSave(snapshotDate, note.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    } label: {
                        Text("Save Snapshot")
                            .frame(maxWidth: .infinity)
                            .alignmentGuide(.leading) { _ in 0 }
                    }
                    .disabled(previewMetrics.totalValue == 0)
                }
            }
            .navigationTitle("Take Snapshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
