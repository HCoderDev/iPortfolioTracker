//
//  StockDCFAnalysisFormSheet.swift
//  PortfolioTracker
//
//  Created by Antigravity on 21/06/26.
//

import SwiftUI
import SwiftData

struct StockDCFAnalysisFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let asset: Asset
    
    // Live calculations from form state
    @State private var startingFCF: Double = 1000.0
    @State private var growthRate: Double = 10.0
    @State private var discountRate: Double = 12.0
    @State private var terminalGrowth: Double = 4.0
    @State private var shares: Double = 100.0
    @State private var cmp: Double = 0.0
    
    private let doubleFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()
    
    // MARK: - Dynamic Live DCF Calculations
    private var dynamicYearRows: [StockDCFAnalysis.DCFYearRow] {
        var rows: [StockDCFAnalysis.DCFYearRow] = []
        var currentFCF = startingFCF
        let g = growthRate / 100.0
        let r = discountRate / 100.0
        
        for yr in 1...10 {
            currentFCF = currentFCF * (1.0 + g)
            let factor = 1.0 / pow(1.0 + r, Double(yr))
            let pv = currentFCF * factor
            rows.append(StockDCFAnalysis.DCFYearRow(year: yr, fcf: currentFCF, discountFactor: factor, pv: pv))
        }
        return rows
    }
    
    private var dynamicTerminalValue: Double {
        let g = growthRate / 100.0
        let r = discountRate / 100.0
        let dg = terminalGrowth / 100.0
        
        let fcf10 = startingFCF * pow(1.0 + g, 10.0)
        
        guard r > dg else { return 0.0 }
        return (fcf10 * (1.0 + dg)) / (r - dg)
    }
    
    private var dynamicPVOfTerminalValue: Double {
        let r = discountRate / 100.0
        let factor10 = 1.0 / pow(1.0 + r, 10.0)
        return dynamicTerminalValue * factor10
    }
    
    private var dynamicEnterpriseValue: Double {
        let sumPVOfFCFs = dynamicYearRows.reduce(0.0) { $0 + $1.pv }
        return sumPVOfFCFs + dynamicPVOfTerminalValue
    }
    
    private var dynamicIntrinsicValuePerShare: Double {
        guard shares > 0 else { return 0.0 }
        return dynamicEnterpriseValue / shares
    }
    
    private var dynamicIsUndervalued: Bool {
        cmp < dynamicIntrinsicValuePerShare
    }
    
    private var dynamicValuationMarginPercent: Double {
        guard cmp > 0 else { return 0.0 }
        return (dynamicIntrinsicValuePerShare - cmp) / cmp
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Table Header & Rows
                    VStack(spacing: 8) {
                        HStack {
                            Text("Year")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("FCF (Cr)")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text("Disc. Factor")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text("PV (Cr)")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        
                        Divider()
                            .background(Color.white.opacity(0.15))
                        
                        // Rows
                        ForEach(dynamicYearRows) { row in
                            HStack {
                                Text("Year \(row.year)")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(row.fcf.formattedIndianRupees())
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text(String(format: "%.3f", row.discountFactor))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text(row.pv.formattedIndianRupees())
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .font(.system(size: 12))
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .background(row.year % 2 == 0 ? Color.white.opacity(0.02) : Color.clear)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.15))
                        
                        // Terminal Value Row
                        HStack {
                            Text("Terminal Value")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(dynamicTerminalValue.formattedIndianRupees())
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(String(format: "%.3f", 1.0 / pow(1.0 + (discountRate / 100.0), 10.0)))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(dynamicPVOfTerminalValue.formattedIndianRupees())
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .font(.system(size: 12))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                    }
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    
                    // Summary Section
                    HStack {
                        VStack(spacing: 4) {
                            Text("Enterprise Value")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text("₹\(dynamicEnterpriseValue.formattedIndianRupees()) Cr")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Divider()
                            .frame(height: 30)
                            .background(Color.white.opacity(0.15))
                        
                        VStack(spacing: 4) {
                            Text("Intrinsic Value/Share")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text("₹\(dynamicIntrinsicValuePerShare.formatted2)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.accentSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    
                    // Inputs Section
                    VStack(spacing: 20) {
                        
                        // Starting FCF Stepper
                        customStepper(label: "Starting FCF (Cr)", value: $startingFCF, step: 100.0)
                        
                        // Growth Rate Slider
                        customSlider(label: "Growth Rate (%)", value: $growthRate, range: -20.0...100.0)
                        
                        // Discount Rate Slider
                        customSlider(label: "Discount Rate (%)", value: $discountRate, range: 1.0...50.0)
                        
                        // Terminal Growth Slider
                        customSlider(label: "Terminal Growth (%)", value: $terminalGrowth, range: 0.0...15.0)
                        
                        // Shares Stepper
                        customStepper(label: "Shares (Cr)", value: $shares, step: 5.0)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .background(Color(hex: "0D0D14"))
            .preferredColorScheme(.dark)
            .navigationTitle("Intrinsic Value DCF Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.accentSecondary)
                    .disabled(startingFCF <= 0 || shares <= 0)
                }
            }
            .onAppear {
                if let dcf = asset.dcfAnalysis {
                    startingFCF = dcf.startingFCF
                    growthRate = dcf.growthRate
                    discountRate = dcf.discountRate
                    terminalGrowth = dcf.terminalGrowth
                    shares = dcf.shares
                    cmp = dcf.cmp
                } else {
                    cmp = asset.currentPrice
                    startingFCF = asset.valueAnalysis?.freeCashFlow ?? 1000.0
                    growthRate = 10.0
                    discountRate = 12.0
                    terminalGrowth = 4.0
                    shares = 10.0
                }
            }
        }
    }
    
    // MARK: - Custom UI Components
    
    @ViewBuilder
    private func customStepper(label: String, value: Binding<Double>, step: Double) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 0) {
                Button(action: {
                    if value.wrappedValue >= step {
                        value.wrappedValue = max(0.1, value.wrappedValue - step)
                    } else {
                        value.wrappedValue = 0.1
                    }
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                
                TextField("", value: value, formatter: doubleFormatter)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Button(action: {
                    value.wrappedValue += step
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
        }
    }
    
    @ViewBuilder
    private func customSlider(label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 16) {
            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            
            Slider(value: value, in: range)
                .tint(.white)
            
            TextField("", value: value, formatter: doubleFormatter)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.body)
                .fontWeight(.bold)
                .frame(width: 60)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    // MARK: - Save Logic
    private func save() {
        if let dcf = asset.dcfAnalysis {
            dcf.startingFCF = startingFCF
            dcf.growthRate = growthRate
            dcf.discountRate = discountRate
            dcf.terminalGrowth = terminalGrowth
            dcf.shares = shares
            dcf.cmp = asset.currentPrice // Keep updated with latest price
            dcf.analysisDate = Date()
        } else {
            let newDCF = StockDCFAnalysis(
                cmp: asset.currentPrice,
                startingFCF: startingFCF,
                growthRate: growthRate,
                discountRate: discountRate,
                terminalGrowth: terminalGrowth,
                shares: shares
            )
            modelContext.insert(newDCF)
            asset.dcfAnalysis = newDCF
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save DCF Analysis: \(error)")
        }
        dismiss()
    }
}
