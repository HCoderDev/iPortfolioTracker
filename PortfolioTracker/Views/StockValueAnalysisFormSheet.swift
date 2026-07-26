//
//  StockValueAnalysisFormSheet.swift
//  PortfolioTracker
//
//  Created by Antigravity on 30/05/26.
//

import SwiftUI
import SwiftData

struct StockValueAnalysisFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let asset: Asset
    
    // Worksheet form fields
    @State private var cmp: String = ""
    @State private var industry: String = ""
    
    // Dynamic history array inputs
    @State private var historicalYears: Int = 4
    @State private var epsInputs: [String] = ["", "", "", ""]
    @State private var dpsInputs: [String] = ["", "", "", ""]
    
    @State private var industryPE: String = ""
    @State private var intrinsicPE: String = ""
    @State private var bookValue: String = ""
    @State private var debtToEquity: String = ""
    @State private var priceToSales: String = ""
    @State private var freeCashFlow: String = ""
    @State private var freeCashFlowRatio: String = ""
    @State private var investmentPeriod: Int = 3
    
    // Live calculations from form state
    private var parsedCmp: Double {
        Double(cmp) ?? asset.currentPrice
    }
    
    private var parsedLatestEps: Double {
        epsList.first ?? 0.0
    }
    
    private var epsList: [Double] {
        epsInputs.compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }
    
    private var dpsList: [Double] {
        dpsInputs.compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }
    
    private var parsedIntrinsicPE: Double {
        Double(intrinsicPE) ?? 0.0
    }
    
    private var computedIntrinsicValue: Double {
        parsedIntrinsicPE * parsedLatestEps
    }
    
    private var isUndervalued: Bool {
        parsedCmp < computedIntrinsicValue
    }
    
    private var epsGrowthRate: Double {
        let list = epsList
        guard list.count >= 2, let latest = list.first, let oldest = list.last, oldest > 0, latest > 0 else {
            return 0.0
        }
        let years = Double(list.count - 1)
        return pow(latest / oldest, 1.0 / years) - 1.0
    }
    
    private var currentPE: Double {
        guard parsedLatestEps > 0 else { return 0.0 }
        return parsedCmp / parsedLatestEps
    }
    
    private var computedOverallCAGR: Double {
        let period = Double(investmentPeriod)
        guard period > 0, parsedCmp > 0 else { return 0.0 }
        
        let gRate = epsGrowthRate
        let pRate = (epsList.first ?? 0.0) > 0 ? ((dpsList.first ?? 0.0) / (epsList.first ?? 1.0)) : 0.0
        let bestPE = suggestedBestCasePE
        
        var currentEps = parsedLatestEps
        var sumDividends = 0.0
        for _ in 1...investmentPeriod {
            currentEps = currentEps * (1.0 + gRate)
            sumDividends += currentEps * pRate
        }
        
        let projectedPrice = bestPE * currentEps
        let endValue = parsedCmp + (projectedPrice - parsedCmp + sumDividends)
        guard endValue > 0 else { return 0.0 }
        return pow(endValue / parsedCmp, 1.0 / period) - 1.0
    }
    
    private var suggestedBestCasePE: Double {
        let basePE = parsedIntrinsicPE > 0 ? parsedIntrinsicPE : currentPE
        guard basePE > 0 else { return 0.0 }
        return basePE * (1.0 + epsGrowthRate)
    }
    
    private func updateHistoryArrays(to count: Int) {
        if epsInputs.count < count {
            let diff = count - epsInputs.count
            epsInputs.append(contentsOf: Array(repeating: "", count: diff))
            dpsInputs.append(contentsOf: Array(repeating: "", count: diff))
        } else if epsInputs.count > count {
            epsInputs = Array(epsInputs.prefix(count))
            dpsInputs = Array(dpsInputs.prefix(count))
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Live valuation dashboard block
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("LIVE VALUATION")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.accentSecondary)
                            Spacer()
                            if computedIntrinsicValue > 0 {
                                Text(isUndervalued ? "Undervalued" : "Overvalued")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(isUndervalued ? AppTheme.profit : AppTheme.loss)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background((isUndervalued ? AppTheme.profit : AppTheme.loss).opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Intrinsic Value")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(computedIntrinsicValue > 0 ? String(format: "₹ %.2f", computedIntrinsicValue) : "N/A")
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Projected CAGR")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(computedIntrinsicValue > 0 ? String(format: "%.2f%%", computedOverallCAGR * 100.0) : "N/A")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(computedOverallCAGR >= 0 ? AppTheme.profit : AppTheme.loss)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color(.systemGray6).opacity(0.4))
                
                Section("Round 0 & 1: Initial Filter") {
                    TextField("Industry (e.g. Banking, IT, Pharma)", text: $industry)
                    
                    HStack {
                        Text("Current Market Price (CMP)")
                        Spacer()
                        TextField("CMP", text: $cmp)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    
                    HStack {
                        Text("Book Value / Share")
                        Spacer()
                        TextField("Book Value", text: $bookValue)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }
                
                Section("Round 2: Dynamic Earnings & DPS History") {
                    Stepper(value: $historicalYears, in: 2...30) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(AppTheme.accent)
                            Text("Historical Years: **\(historicalYears)**")
                        }
                    }
                    .onChange(of: historicalYears) { oldValue, newValue in
                        updateHistoryArrays(to: newValue)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Table Header
                        HStack {
                            Text("Period")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("EPS (₹)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .trailing)
                            Text("DPS (₹)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .trailing)
                        }
                        .padding(.bottom, 4)
                        
                        // Dynamic Rows
                        ForEach(0..<historicalYears, id: \.self) { index in
                            HStack {
                                Text(index == 0 ? "Latest (Yr 0)" : "Yr -\(index)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                TextField("e.g. 10.0", text: Binding(
                                    get: { index < epsInputs.count ? epsInputs[index] : "" },
                                    set: { newValue in
                                        if index < epsInputs.count {
                                            epsInputs[index] = newValue
                                        }
                                    }
                                ))
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                
                                TextField("e.g. 1.5", text: Binding(
                                    get: { index < dpsInputs.count ? dpsInputs[index] : "" },
                                    set: { newValue in
                                        if index < dpsInputs.count {
                                            dpsInputs[index] = newValue
                                        }
                                    }
                                ))
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            }
                        }
                        
                        // Add/Remove buttons for convenient table editing
                        HStack {
                            Button(action: {
                                if historicalYears < 30 {
                                    historicalYears += 1
                                }
                            }) {
                                Label("Add Year", systemImage: "plus.circle.fill")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .buttonStyle(.borderless)
                            
                            Spacer()
                            
                            Button(action: {
                                if historicalYears > 2 {
                                    historicalYears -= 1
                                }
                            }) {
                                Label("Remove Year", systemImage: "minus.circle.fill")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(historicalYears > 2 ? AppTheme.loss : .secondary)
                            }
                            .buttonStyle(.borderless)
                            .disabled(historicalYears <= 2)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 6)
                    
                    if epsList.count >= 2 {
                        HStack {
                            Text("EPS Growth CAGR (Historical)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.2f%%", epsGrowthRate * 100.0))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                }
                
                Section("Round 2 Multiples & Valuation") {
                    HStack {
                        Text("Industry P/E")
                        Spacer()
                        TextField("Industry PE", text: $industryPE)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Intrinsic P/E (Average PE)")
                        Spacer()
                        TextField("Intrinsic PE", text: $intrinsicPE)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Best Case P/E")
                                .font(.body)
                            Text("(Calculated from Growth Expansion)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(suggestedBestCasePE > 0 ? String(format: "%.2f", suggestedBestCasePE) : "N/A")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.accentSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.accentSecondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                
                Section("Round 3: Additional Ratios & FCF") {
                    HStack {
                        Text("Debt / Equity (D/E)")
                        Spacer()
                        TextField("D/E Ratio", text: $debtToEquity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Price / Sales (P/S)")
                        Spacer()
                        TextField("P/S Ratio", text: $priceToSales)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Free Cash Flow (FCF)")
                        Spacer()
                        TextField("FCF", text: $freeCashFlow)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("FCF / Net Income Ratio (%)")
                        Spacer()
                        TextField("FCF Ratio", text: $freeCashFlowRatio)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                
                Section("Round 4: Projections & Forecast") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Consensus Growth Rate")
                                .font(.body)
                            Text("(Calculated from EPS Growth CAGR)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(epsGrowthRate > 0 ? String(format: "%.2f%%", epsGrowthRate * 100.0) : "N/A")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.profit)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.profit.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Consensus Div Payout Ratio")
                                .font(.body)
                            Text("(Calculated from Latest Dividend/EPS)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        let latestEPS = epsList.first ?? 0.0
                        let latestDPS = dpsList.first ?? 0.0
                        let calculatedDivRatio = latestEPS > 0 ? (latestDPS / latestEPS) : 0.0
                        Text(calculatedDivRatio > 0 ? String(format: "%.2f%%", calculatedDivRatio * 100.0) : "N/A")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.accent.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    Stepper("Investment Period: \(investmentPeriod) years", value: $investmentPeriod, in: 1...10)
                }
            }
            .navigationTitle(asset.valueAnalysis == nil ? "Perform Value Analysis" : "Edit Value Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(industry.trimmingCharacters(in: .whitespaces).isEmpty || epsList.isEmpty)
                }
            }
            .onAppear {
                if let analysis = asset.valueAnalysis {
                    cmp = String(format: "%.2f", analysis.cmp)
                    industry = analysis.industry
                    
                    let eList = analysis.epsList
                    let dList = analysis.dpsList
                    historicalYears = max(2, eList.count)
                    epsInputs = eList.map { String(format: "%.2f", $0) }
                    dpsInputs = dList.map { String(format: "%.2f", $0) }
                    
                    // Fill up if there is a mismatch
                    if epsInputs.count < historicalYears {
                        epsInputs.append(contentsOf: Array(repeating: "", count: historicalYears - epsInputs.count))
                    }
                    if dpsInputs.count < historicalYears {
                        dpsInputs.append(contentsOf: Array(repeating: "", count: historicalYears - dpsInputs.count))
                    }
                    
                    industryPE = String(format: "%.2f", analysis.industryPE)
                    intrinsicPE = String(format: "%.2f", analysis.intrinsicPE)
                    bookValue = String(format: "%.2f", analysis.bookValue)
                    debtToEquity = String(format: "%.2f", analysis.debtToEquity)
                    priceToSales = String(format: "%.2f", analysis.priceToSales)
                    freeCashFlow = String(format: "%.2f", analysis.freeCashFlow)
                    freeCashFlowRatio = String(format: "%.2f", analysis.freeCashFlowRatio)
                    investmentPeriod = analysis.investmentPeriod
                } else {
                    cmp = String(format: "%.2f", asset.currentPrice)
                    historicalYears = 4
                    epsInputs = ["", "", "", ""]
                    dpsInputs = ["", "", "", ""]
                }
            }
        }
    }
    
    private func save() {
        let indPE = Double(industryPE) ?? 0.0
        let intPE = Double(intrinsicPE) ?? 0.0
        let bestPE = suggestedBestCasePE
        let bValue = Double(bookValue) ?? 0.0
        let deRatio = Double(debtToEquity) ?? 0.0
        let psRatio = Double(priceToSales) ?? 0.0
        let fcfValue = Double(freeCashFlow) ?? 0.0
        let fcfRate = Double(freeCashFlowRatio) ?? 0.0
        
        let cGrowth = epsGrowthRate
        
        let latestEPS = epsList.first ?? 0.0
        let latestDPS = dpsList.first ?? 0.0
        let cDiv = latestEPS > 0 ? (latestDPS / latestEPS) : 0.0
        
        let epsString = epsList.map { String($0) }.joined(separator: ",")
        let dpsString = dpsList.map { String($0) }.joined(separator: ",")
        
        if let analysis = asset.valueAnalysis {
            analysis.cmp = parsedCmp
            analysis.industry = industry
            analysis.epsValuesString = epsString
            analysis.dpsValuesString = dpsString
            analysis.industryPE = indPE
            analysis.intrinsicPE = intPE
            analysis.bestCasePE = bestPE
            analysis.bookValue = bValue
            analysis.debtToEquity = deRatio
            analysis.priceToSales = psRatio
            analysis.freeCashFlow = fcfValue
            analysis.freeCashFlowRatio = fcfRate
            analysis.consensusGrowthRate = cGrowth
            analysis.consensusDivPayoutRatio = cDiv
            analysis.investmentPeriod = investmentPeriod
            analysis.analysisDate = Date()
        } else {
            let newAnalysis = StockValueAnalysis(
                cmp: parsedCmp,
                industry: industry,
                epsValuesString: epsString,
                dpsValuesString: dpsString,
                industryPE: indPE,
                intrinsicPE: intPE,
                bestCasePE: bestPE,
                bookValue: bValue,
                debtToEquity: deRatio,
                priceToSales: psRatio,
                freeCashFlow: fcfValue,
                freeCashFlowRatio: fcfRate,
                consensusGrowthRate: cGrowth,
                consensusDivPayoutRatio: cDiv,
                investmentPeriod: investmentPeriod
            )
            modelContext.insert(newAnalysis)
            asset.valueAnalysis = newAnalysis
        }
        
        try? modelContext.save()
        dismiss()
    }
}
