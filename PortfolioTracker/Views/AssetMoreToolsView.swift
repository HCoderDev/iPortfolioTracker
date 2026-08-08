//
//  AssetMoreToolsView.swift
//  PortfolioTracker
//
//  Created by Antigravity on 30/05/26.
//

import SwiftUI
import SwiftData

struct AssetMoreToolsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Card 0: Time to FI (Financial Independence)
                NavigationLink(destination: FITrackerDetailView()) {
                    HStack(spacing: 16) {
                        Image(systemName: "flame.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Time to FI (Financial Independence)")
                               .font(.headline)
                               .foregroundStyle(.primary)
                            Text("Freedom projection date, years to FI, monthly SIP growth & milestones")
                               .font(.caption)
                               .foregroundStyle(.secondary)
                               .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                
                // Card 1: Bulk Price Update
                NavigationLink(destination: BulkAssetUpdateView()) {
                    HStack(spacing: 16) {
                        Image(systemName: "list.bullet.rectangle.and.pencil")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.accent)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bulk Price Update")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Fast bulk updating of active assets' current prices")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                
                // Card 1.5: Bulk Exchange Rate Update
                NavigationLink(destination: BulkExchangeRateUpdateView()) {
                    HStack(spacing: 16) {
                        Image(systemName: "banknote")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.accent)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Exchange Rates Update")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Fast updating of exchange rates (TT Buy / TT Sell) for foreign transactions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                
                // Card 2: Tax Liability Planner
                NavigationLink(destination: TaxLiabilityView()) {
                    HStack(spacing: 16) {
                        Image(systemName: "percent")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.accent)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tax Liability Planner")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("FIFO-based STCG/LTCG capital gains estimations")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                
                // Card 3: Stock Splits & Mergers
                NavigationLink(destination: StockSplitMergeView()) {
                    HStack(spacing: 16) {
                        Image(systemName: "arrow.triangle.merge")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.accent)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stock Splits & Mergers")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Handle stock splits, reverse splits, or asset mergers in one shot")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                
                // Card 4: Portfolio Rebalancer
                NavigationLink(destination: PortfolioRebalancerView()) {
                    HStack(spacing: 16) {
                        Image(systemName: "scale.3d")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.accent)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Portfolio Rebalancer")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Compare targets, evaluate drift, and compute rebalancing trades")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                
                // Card 5: Portfolio Snapshots
                NavigationLink(destination: PortfolioSnapshotsView()) {
                    HStack(spacing: 16) {
                        Image(systemName: "camera.viewfinder")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.accent)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Portfolio Snapshots")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Capture and track historical category-wise networth over time")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                
                // Card 6: Export & Share CSVs
                NavigationLink(destination: ExportCSVView()) {
                    HStack(spacing: 16) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.accent)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Export & Share CSVs")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Export and share individual asset CSVs or master portfolio CSV to external apps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                
                // Card 7: Investment Rationale Notes Journal
                NavigationLink(destination: AllAssetNotesView()) {
                    HStack(spacing: 16) {
                        Image(systemName: "note.text")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.warning)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Investment Rationale Notes")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Document buy/sell logic, earnings updates, and investment thought process across all assets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                
                // Card 8: Reminders & Watch Events
                NavigationLink(destination: RemindersListView()) {
                    HStack(spacing: 16) {
                        Image(systemName: "bell.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.accent)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reminders & Watch Events")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("View and schedule asset earnings watch, policy renewals, or maturity reminders")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

            }
            .padding()
        }
        .navigationTitle("More Options")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AssetMoreToolsView()
    }
}
