//
//  TargetAllocationConfigSheet.swift
//  PortfolioTracker
//
//  Created by Antigravity on 21/06/26.
//

import SwiftUI
import SwiftData

struct TargetAllocationConfigSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Category.name) private var categories: [Category]
    
    @State private var targets: [PersistentIdentifier: Double] = [:]
    
    private var totalSum: Double {
        targets.values.reduce(0.0, +)
    }
    
    private var isSumValid: Bool {
        abs(totalSum - 100.0) < 0.01
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if categories.isEmpty {
                    Section {
                        Text("Please add some categories first to configure target allocations.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else {
                    Section {
                        ForEach(categories) { category in
                            let id = category.persistentModelID
                            let currentTarget = targets[id] ?? 0.0
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(category.name)
                                        .font(.headline)
                                    Spacer()
                                    Text(String(format: "%.0f%%", currentTarget))
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(AppTheme.accent)
                                }
                                
                                Slider(
                                    value: Binding(
                                        get: { currentTarget },
                                        set: { newValue in
                                            targets[id] = newValue.rounded()
                                        }
                                    ),
                                    in: 0...100,
                                    step: 1.0
                                )
                                .tint(AppTheme.accent)
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Category Target Percentages")
                    } footer: {
                        Text("Set the desired asset allocation target for each category. The total sum must equal exactly 100%.")
                    }
                    
                    Section {
                        HStack {
                            Text("Total Target Sum")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(String(format: "%.0f%%", totalSum))
                                .font(.title3)
                                .fontWeight(.black)
                                .foregroundStyle(isSumValid ? AppTheme.profit : AppTheme.loss)
                        }
                        
                        if !isSumValid {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(AppTheme.warning)
                                Text("The target allocations must sum up to exactly 100%.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Validation Summary")
                    }
                }
            }
            .navigationTitle("Target Allocations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.bold)
                    .disabled(!isSumValid)
                }
            }
            .onAppear {
                var initialTargets: [PersistentIdentifier: Double] = [:]
                for category in categories {
                    initialTargets[category.persistentModelID] = category.targetAllocationPercent
                }
                targets = initialTargets
            }
        }
    }
    
    private func save() {
        for category in categories {
            if let targetValue = targets[category.persistentModelID] {
                category.targetAllocationPercent = targetValue
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save target allocations: \(error)")
        }
        
        dismiss()
    }
}
