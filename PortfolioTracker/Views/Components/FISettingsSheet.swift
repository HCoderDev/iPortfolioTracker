//
//  FISettingsSheet.swift
//  PortfolioTracker
//

import SwiftUI

struct FISettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("fiTargetGoal") private var targetGoal: Double = FICalculator.defaultTargetGoal
    @AppStorage("fiBirthDateTimeInterval") private var birthDateTimeInterval: Double = FICalculator.defaultBirthDate.timeIntervalSince1970
    @AppStorage("fiMonthlySIP") private var monthlySIP: Double = FICalculator.defaultMonthlySIP
    @AppStorage("fiReturnRate") private var returnRate: Double = FICalculator.defaultReturnRate
    @AppStorage("fiInflationRate") private var inflationRate: Double = FICalculator.defaultInflationRate
    @AppStorage("fiSafeWithdrawalRate") private var safeWithdrawalRate: Double = FICalculator.defaultSWR
    
    @State private var inputTargetGoalString: String = ""
    @State private var inputSIPString: String = ""
    @State private var inputReturnRateString: String = ""
    @State private var inputInflationRateString: String = ""
    @State private var birthDate: Date = FICalculator.defaultBirthDate
    
    private let goalPresets: [(String, Double)] = [
        ("₹3 Cr", 30_000_000),
        ("₹5 Cr", 50_000_000),
        ("₹7 Cr", 70_000_000),
        ("₹10 Cr", 100_000_000),
        ("₹15 Cr", 150_000_000),
        ("₹20 Cr", 200_000_000)
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Target Financial Independence Goal (₹)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("Target Goal (e.g. 70000000)", text: $inputTargetGoalString)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        
                        // Preset chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(goalPresets, id: \.1) { preset in
                                    Button {
                                        inputTargetGoalString = String(format: "%.0f", preset.1)
                                    } label: {
                                        Text(preset.0)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                (Double(inputTargetGoalString) == preset.1)
                                                ? AppTheme.accent.opacity(0.2)
                                                : Color(.tertiarySystemFill)
                                            )
                                            .foregroundStyle((Double(inputTargetGoalString) == preset.1) ? AppTheme.accent : .primary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Target Goal")
                } footer: {
                    Text("Enter your freedom target amount in INR. Example: ₹7 Crore = 7,00,00,000.")
                }
                
                Section("Personal Details") {
                    DatePicker(
                        "Date of Birth",
                        selection: $birthDate,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                    
                    let currentAge = FICalculator.calculateCurrentAge(from: birthDate)
                    HStack {
                        Text("Current Calculated Age")
                        Spacer()
                        Text("\(currentAge) years")
                            .foregroundStyle(.secondary)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                    }
                }
                
                Section("Monthly Contribution / SIP") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Monthly Investment Amount (₹)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("Monthly SIP (e.g. 50000)", text: $inputSIPString)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                }
                
                Section("Assumptions & Rates") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Expected Portfolio Return (p.a. %)")
                            Spacer()
                            Text("\(Double(inputReturnRateString)?.formatted2 ?? "0.0")%")
                                .font(.system(.body, design: .rounded).weight(.bold))
                                .foregroundStyle(AppTheme.accent)
                        }
                        
                        TextField("Expected Return % (e.g. 12.0)", text: $inputReturnRateString)
                            .keyboardType(.decimalPad)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Expected Inflation (p.a. %)")
                            Spacer()
                            Text("\(Double(inputInflationRateString)?.formatted2 ?? "0.0")%")
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        
                        TextField("Inflation % (e.g. 6.0)", text: $inputInflationRateString)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("Safe Withdrawal Rate (SWR)")
                        Spacer()
                        Text("\(safeWithdrawalRate.formatted2)%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle("FI Calculation Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & Calculate") {
                        save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                inputTargetGoalString = String(format: "%.0f", targetGoal)
                inputSIPString = String(format: "%.0f", monthlySIP)
                inputReturnRateString = String(format: "%.1f", returnRate)
                inputInflationRateString = String(format: "%.1f", inflationRate)
                birthDate = Date(timeIntervalSince1970: birthDateTimeInterval)
            }
        }
    }
    
    private func save() {
        if let newGoal = Double(inputTargetGoalString), newGoal > 0 {
            targetGoal = newGoal
        }
        if let newSIP = Double(inputSIPString), newSIP >= 0 {
            monthlySIP = newSIP
        }
        if let newReturn = Double(inputReturnRateString), newReturn >= 0 {
            returnRate = newReturn
        }
        if let newInf = Double(inputInflationRateString), newInf >= 0 {
            inflationRate = newInf
        }
        birthDateTimeInterval = birthDate.timeIntervalSince1970
    }
}
