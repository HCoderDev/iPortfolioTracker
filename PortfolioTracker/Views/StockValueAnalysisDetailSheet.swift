//
//  StockValueAnalysisDetailSheet.swift
//  PortfolioTracker
//
//  Created by Antigravity on 30/05/26.
//

import SwiftUI
import SwiftData

struct StockValueAnalysisDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let analysis: StockValueAnalysis
    @State private var showEditForm = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Premium Header Diagnosis Card
                    headerDiagnosisCard
                    
                    // Round-2: Value Analysis
                    round2ValueAnalysisCard
                    
                    // Round-3: Additional Ratios
                    round3AdditionalRatiosCard
                    
                    // Round-4: Gains Projections
                    round4GainsProjectionsCard
                    
                    // CRUD Actions
                    crudActionBar
                    
                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("\(analysis.asset?.name ?? "Stock") Valuation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    HStack(spacing: 16) {
                        Button {
                            shareAnalysis()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        
                        Button("Edit") { showEditForm = true }
                            .fontWeight(.bold)
                    }
                }
            }
            .sheet(isPresented: $showEditForm) {
                if let asset = analysis.asset {
                    StockValueAnalysisFormSheet(asset: asset)
                }
            }
            .confirmationDialog("Delete Valuation Analysis?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete Analysis", role: .destructive) {
                    deleteAnalysis()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to permanently remove this stock value analysis?")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerDiagnosisCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(analysis.asset?.name ?? "STOCK")
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundStyle(.white)
                    Text(analysis.industry.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                
                // undervaluation badge
                Text(analysis.isUndervalued ? "UNDERVALUED" : "OVERVALUED")
                    .font(.caption)
                    .fontWeight(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white)
                    .foregroundStyle(analysis.isUndervalued ? AppTheme.profit : AppTheme.loss)
                    .clipShape(Capsule())
            }
            
            Divider()
                .background(.white.opacity(0.3))
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("INTRINSIC VALUE")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(String(format: "₹ %.2f", analysis.intrinsicValue))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .center, spacing: 4) {
                    Text("CURRENT PRICE")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(String(format: "₹ %.2f", analysis.cmp))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("MARGIN OF SAFETY")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                    let margin = analysis.valuationMarginPercent * 100
                    Text(String(format: "%@%.1f%%", margin >= 0 ? "+" : "", margin))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(margin >= 0 ? AppTheme.profit : AppTheme.loss)
                }
            }
        }
        .padding(20)
        .background(AppTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }
    
    private var round2ValueAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundStyle(AppTheme.accent)
                Text("Round-2: Value Analysis (Intrinsics)")
                    .font(.headline)
            }
            
            Divider()
            
            // Historical EPS row
            VStack(alignment: .leading, spacing: 6) {
                Text("HISTORICAL EPS TIMELINE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        let epsList = analysis.epsList
                        ForEach(0..<epsList.count, id: \.self) { index in
                            VStack(spacing: 4) {
                                Text(index == 0 ? "Latest" : "Yr -\(index)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .fontWeight(.bold)
                                Text(String(format: "%.2f", epsList[index]))
                                    .font(.footnote)
                                    .fontWeight(.bold)
                            }
                            .frame(width: 55)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            
            let YoYRates = analysis.yearWiseGrowthRates
            if !YoYRates.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("EPS YEAR-WISE YoY GROWTH")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<YoYRates.count, id: \.self) { index in
                                VStack(spacing: 4) {
                                    Text("Yr -\(index+1) → -\(index)")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                        .fontWeight(.bold)
                                    
                                    let rate = YoYRates[index] * 100
                                    Text(String(format: "%@%.1f%%", rate >= 0 ? "+" : "", rate))
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(rate >= 0 ? AppTheme.profit : AppTheme.loss)
                                }
                                .frame(width: 75)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                GridRow {
                    metricItem(title: "Hist Growth CAGR", value: String(format: "%.2f%%", analysis.epsGrowthRate * 100.0), highlightColor: AppTheme.accent)
                    metricItem(title: "Current P/E", value: String(format: "%.2f", analysis.currentPE))
                }
                GridRow {
                    metricItem(title: "Industry P/E", value: String(format: "%.2f", analysis.industryPE))
                    metricItem(title: "Intrinsic P/E (Avg)", value: String(format: "%.2f", analysis.intrinsicPE))
                }
                GridRow {
                    metricItem(title: "Best Case P/E", value: String(format: "%.2f", analysis.bestCasePE))
                    metricItem(title: "PEG Ratio", value: String(format: "%.2f", analysis.pegRatio), highlightColor: analysis.pegRatio < 1.0 ? AppTheme.profit : .primary)
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackgroundElevated)
        .colorScheme(.dark)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    private var round3AdditionalRatiosCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "percent")
                    .foregroundStyle(AppTheme.accentSecondary)
                Text("Round-3: Additional Ratios & FCF")
                    .font(.headline)
            }
            
            Divider()
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                GridRow {
                    metricItem(title: "Book Value/Share", value: String(format: "₹ %.2f", analysis.bookValue))
                    metricItem(title: "P/B Ratio", value: String(format: "%.2f", analysis.pbRatio))
                }
                GridRow {
                    metricItem(title: "Return on Equity (ROE)", value: String(format: "%.2f%%", analysis.roe * 100.0), highlightColor: analysis.roe >= 0.15 ? AppTheme.profit : .primary)
                    metricItem(title: "Debt / Equity (D/E)", value: String(format: "%.2f", analysis.debtToEquity), highlightColor: analysis.debtToEquity < 0.5 ? AppTheme.profit : .primary)
                }
                GridRow {
                    metricItem(title: "Price / Sales (P/S)", value: String(format: "%.2f", analysis.priceToSales))
                    metricItem(title: "Free Cash Flow (FCF)", value: String(format: "₹ %.0fM", analysis.freeCashFlow))
                }
                GridRow {
                    metricItem(title: "FCF / Income Ratio", value: String(format: "%.1f%%", analysis.freeCashFlowRatio), highlightColor: analysis.freeCashFlowRatio >= 80.0 ? AppTheme.profit : .primary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    private var round4GainsProjectionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(AppTheme.profit)
                Text("Round-4: Gains & CAGR Estimations")
                    .font(.headline)
            }
            
            Divider()
            
            // Projected year-by-year EPS & dividends table
            VStack(alignment: .leading, spacing: 8) {
                Text("PROJECTED YEAR-BY-YEAR FORECAST")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                
                let projectedEps = analysis.projectedEpsYearWise
                let projectedDividends = analysis.projectedDividendsYearWise
                
                VStack(spacing: 0) {
                    // Header row
                    HStack {
                        Text("Period")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Projected EPS")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text("Projected Div")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color(.systemGray6))
                    
                    ForEach(0..<projectedEps.count, id: \.self) { index in
                        Divider()
                        HStack {
                            Text("Year \(index + 1)")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(String(format: "₹ %.2f", projectedEps[index]))
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(String(format: "₹ %.2f", projectedDividends[index]))
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
            }
            
            Divider()
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                GridRow {
                    metricItem(title: "Projected Growth", value: String(format: "%.1f%%", analysis.consensusGrowthRate * 100.0))
                    metricItem(title: "Projected Payout Ratio", value: String(format: "%.1f%%", analysis.consensusDivPayoutRatio * 100.0))
                }
                GridRow {
                    metricItem(title: "Projected Price (\(analysis.investmentPeriod)yr)", value: String(format: "₹ %.2f", analysis.projectedPrice), highlightColor: AppTheme.accent)
                    metricItem(title: "Overall Proj gains", value: String(format: "₹ %.2f", analysis.overallProjectedCapitalGains), highlightColor: AppTheme.profit)
                }
                GridRow {
                    metricItem(title: "Consolidated Proj CAGR", value: String(format: "%.2f%%", analysis.overallProjectedCAGR * 100.0), highlightColor: analysis.overallProjectedCAGR >= 0.15 ? AppTheme.profit : AppTheme.accent)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    private var crudActionBar: some View {
        VStack(spacing: 12) {
            Button {
                shareAnalysis()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Infographic Card")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.heroGradient)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            HStack(spacing: 16) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.loss)
                
                Button {
                    showEditForm = true
                } label: {
                    Label("Edit", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.bold)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func metricItem(title: String, value: String, highlightColor: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(highlightColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Actions
    
    private func deleteAnalysis() {
        if let asset = analysis.asset {
            asset.valueAnalysis = nil
        }
        modelContext.delete(analysis)
        try? modelContext.save()
        dismiss()
    }
    
    @MainActor
    private func shareAnalysis() {
        let shareCard = StockAnalysisShareCard(analysis: analysis)
        let renderer = ImageRenderer(content: shareCard)
        renderer.scale = 3.0
        
        guard let uiImage = renderer.uiImage,
              let pngData = uiImage.pngData() else {
            return
        }
        
        let cleanName = (analysis.asset?.name ?? "Stock")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "_")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(cleanName)_Valuation_Analysis.png")
        
        do {
            try pngData.write(to: tempURL)
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let topVC = UIApplication.shared.topMostViewController {
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = topVC.view
                    popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                topVC.present(activityVC, animated: true)
            }
        } catch {
            print("Failed to write share image: \(error)")
        }
    }
}

// MARK: - Stock Analysis Share Card (Static render-optimized view)
struct StockAnalysisShareCard: View {
    let analysis: StockValueAnalysis
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(analysis.asset?.name.uppercased() ?? "STOCK")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(analysis.industry.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.accentSecondary)
                    }
                    Spacer()
                    
                    Text(analysis.isUndervalued ? "UNDERVALUED" : "OVERVALUED")
                        .font(.system(size: 11, weight: .black))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(analysis.isUndervalued ? AppTheme.profit : AppTheme.loss)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                    .padding(.top, 8)
            }
            
            // Intrinsic Summary Row
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("INTRINSIC VALUE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(String(format: "₹ %.2f", analysis.intrinsicValue))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("CURRENT PRICE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(String(format: "₹ %.2f", analysis.cmp))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("MARGIN OF SAFETY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                    let margin = analysis.valuationMarginPercent * 100
                    Text(String(format: "%@%.1f%%", margin >= 0 ? "+" : "", margin))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(margin >= 0 ? AppTheme.profit : AppTheme.loss)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Historic EPS Timeline
            VStack(alignment: .leading, spacing: 8) {
                Text("HISTORICAL EPS TIMELINE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                
                HStack(spacing: 8) {
                    let epsList = analysis.epsList
                    ForEach(0..<min(6, epsList.count), id: \.self) { index in
                        VStack(spacing: 4) {
                            Text(index == 0 ? "Latest" : "Yr -\(index)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(String(format: "%.2f", epsList[index]))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            
            // Value Analysis Ratios Grid
            VStack(alignment: .leading, spacing: 8) {
                Text("VALUATION RATIOS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    GridRow {
                        cardMetric(title: "Hist Growth CAGR", value: String(format: "%.2f%%", analysis.epsGrowthRate * 100.0), highlight: AppTheme.accentSecondary)
                        cardMetric(title: "Current P/E", value: String(format: "%.2f", analysis.currentPE))
                        cardMetric(title: "PEG Ratio", value: String(format: "%.2f", analysis.pegRatio), highlight: analysis.pegRatio < 1.0 ? AppTheme.profit : .white)
                    }
                    GridRow {
                        cardMetric(title: "Industry P/E", value: String(format: "%.2f", analysis.industryPE))
                        cardMetric(title: "Intrinsic P/E", value: String(format: "%.2f", analysis.intrinsicPE))
                        cardMetric(title: "Best Case P/E", value: String(format: "%.2f", analysis.bestCasePE))
                    }
                    GridRow {
                        cardMetric(title: "ROE", value: String(format: "%.2f%%", analysis.roe * 100.0), highlight: analysis.roe >= 0.15 ? AppTheme.profit : .white)
                        cardMetric(title: "D/E Ratio", value: String(format: "%.2f", analysis.debtToEquity), highlight: analysis.debtToEquity < 0.5 ? AppTheme.profit : .white)
                        cardMetric(title: "P/B Ratio", value: String(format: "%.2f", analysis.pbRatio))
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Projections & Forecast
            VStack(alignment: .leading, spacing: 8) {
                Text("GAINS & CAGR FORECAST")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Consensus Growth")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                        Text(String(format: "%.1f%%", analysis.consensusGrowthRate * 100.0))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .center, spacing: 4) {
                        Text("Projected Price")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                        Text(String(format: "₹ %.2f", analysis.projectedPrice))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.accentSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Projected CAGR")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                        Text(String(format: "%.2f%%", analysis.overallProjectedCAGR * 100.0))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(analysis.overallProjectedCAGR >= 0.15 ? AppTheme.profit : AppTheme.accentSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(12)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Watermark & Footer
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.accentSecondary)
                    Text("PortfolioTracker Analyzer")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                Spacer()
                
                Text(Date(), style: .date)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 440)
        .background(
            LinearGradient(
                colors: [Color(hex: "0D0D14"), Color(hex: "1A1A2E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    @ViewBuilder
    private func cardMetric(title: String, value: String, highlight: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(highlight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - UIApplication Extension for Sheet Presentation
extension UIApplication {
    @MainActor
    var topMostViewController: UIViewController? {
        guard let windowScene = connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else {
            return nil
        }
        var topController = window.rootViewController
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        return topController
    }
}

