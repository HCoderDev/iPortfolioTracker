//
//  ExportCSVView.swift
//  PortfolioTracker
//
//  Created by Antigravity on 17/07/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ExportCSVView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.name) private var assets: [Asset]
    @Query(sort: \AssetTransaction.date) private var transactions: [AssetTransaction]
    
    @State private var searchText = ""
    @State private var shareItemURL: URL? = nil
    @State private var showShareSheet = false
    
    private var filteredAssets: [Asset] {
        if searchText.isEmpty {
            return assets
        } else {
            return assets.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.category?.name.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Master Share Banner
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: "doc.text.fill")
                        .font(.title)
                        .foregroundStyle(AppTheme.accent)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export Portfolio Data")
                            .font(.headline)
                        Text("Share CSV files to Files, Mail, WhatsApp, Drive, or Excel")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                Button {
                    if let masterURL = generateMasterCSVURL() {
                        shareItemURL = masterURL
                        showShareSheet = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("Share All Assets Master CSV (\(transactions.count) Txs)")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search asset to export...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // List of Assets
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredAssets) { asset in
                        let txCount = asset.transactions.count
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(asset.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                HStack(spacing: 8) {
                                    if let catName = asset.category?.name {
                                        Text(catName)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Text("\(txCount) transaction\(txCount == 1 ? "" : "s")")
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                            
                            Spacer()
                            
                            if txCount > 0 {
                                Button {
                                    if let url = generateCSVURL(for: asset) {
                                        shareItemURL = url
                                        showShareSheet = true
                                    }
                                } label: {
                                    Label("Share CSV", systemImage: "square.and.arrow.up")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .buttonStyle(.bordered)
                                .tint(AppTheme.accent)
                            } else {
                                Text("No Txs")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(12)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Export & Share CSVs")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let url = shareItemURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    private func generateMasterCSVURL() -> URL? {
        let fileName = "All_Portfolio_Transactions.csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        var csvContent = "Asset Name,Category,Currency,Transaction Type,Date,Units,Price Per Unit,Total Amount (Native),INR Exchange Rate,Total Amount (INR)\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let sortedAll = transactions.sorted { $0.date < $1.date }
        
        for tx in sortedAll {
            let assetName = tx.asset?.name ?? "Unknown"
            let catName = tx.asset?.category?.name ?? ""
            let currencyCode = tx.asset?.category?.currencyCode ?? "USD"
            let rate = tx.inrExchangeRate ?? (tx.asset?.category?.lastInrExchangeRate ?? 1.0)
            
            let amountNative = tx.units * tx.pricePerUnit
            let amountINR = amountNative * rate
            
            let line = "\"\(assetName)\",\"\(catName)\",\"\(currencyCode)\",\"\(tx.type.rawValue)\",\"\(dateFormatter.string(from: tx.date))\",\(tx.units.formatted2),\(tx.pricePerUnit.formatted2),\(amountNative.formatted2),\(rate.formatted2),\(amountINR.formatted2)\n"
            csvContent.append(line)
        }
        
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Failed to write master CSV: \(error)")
            return nil
        }
    }
    
    private func generateCSVURL(for asset: Asset) -> URL? {
        let safeName = asset.name.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "_")
        let fileName = "\(safeName)_transactions.csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        var csvContent = "Asset Name,Category,Currency,Transaction Type,Date,Units,Price Per Unit,Total Amount (Native),INR Exchange Rate,Total Amount (INR)\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let sortedTx = asset.transactions.sorted { $0.date < $1.date }
        let catName = asset.category?.name ?? ""
        let currencyCode = asset.category?.currencyCode ?? "USD"
        let rateFallback = asset.category?.lastInrExchangeRate ?? 1.0
        
        for tx in sortedTx {
            let txRate = tx.inrExchangeRate ?? rateFallback
            let amountNative = tx.units * tx.pricePerUnit
            let amountINR = amountNative * txRate
            
            let line = "\"\(asset.name)\",\"\(catName)\",\"\(currencyCode)\",\"\(tx.type.rawValue)\",\"\(dateFormatter.string(from: tx.date))\",\(tx.units.formatted2),\(tx.pricePerUnit.formatted2),\(amountNative.formatted2),\(txRate.formatted2),\(amountINR.formatted2)\n"
            csvContent.append(line)
        }
        
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Failed to write CSV file: \(error)")
            return nil
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
    
    ExportCSVView()
        .modelContainer(for: previewModels, inMemory: true)
}
