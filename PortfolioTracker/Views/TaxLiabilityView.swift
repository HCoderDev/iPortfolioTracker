//
//  TaxLiabilityView.swift
//  PortfolioTracker
//
//  Created by Antigravity on 28/05/26.
//

import SwiftUI
import SwiftData

struct TaxLiabilityView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.name) private var allAssets: [Asset]
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Currency.code) private var currencies: [Currency]
    @Query(sort: \User.username) private var users: [User]
    
    @State private var selectedTab = 0 // 0 = Unrealized (Est. Future Tax), 1 = Realized (Current FY Tax)
    @State private var assetToOverride: Asset? = nil // For quick tax settings override
    @State private var expandedAssets: Set<PersistentIdentifier> = []
    
    // Group all tax metrics across all assets
    private var taxData: (
        unrealizedTax: Double, unrealizedSTCGTax: Double, unrealizedLTCGTax: Double, unrealizedSlabTax: Double,
        unrealizedSTCGGain: Double, unrealizedLTCGGain: Double, unrealizedSlabGain: Double,
        realizedTax: Double, realizedSTCGTax: Double, realizedLTCGTax: Double, realizedSlabTax: Double,
        realizedSTCGGain: Double, realizedLTCGGain: Double, realizedSlabGain: Double,
        assetTaxDetails: [AssetTaxDetail]
    ) {
        var uTax = 0.0, uSTTax = 0.0, uLTTax = 0.0, uSlabTax = 0.0
        var uSTGain = 0.0, uLTGain = 0.0, uSlabGain = 0.0
        
        var rTax = 0.0, rSTTax = 0.0, rLTTax = 0.0, rSlabTax = 0.0
        var rSTGain = 0.0, rLTGain = 0.0, rSlabGain = 0.0
        
        var assetDetails: [AssetTaxDetail] = []
        
        let slabRate = users.first?.taxSlabRate ?? 0.30
        
        for asset in allAssets {
            let res = FifoCalculator.calculateTax(asset: asset, currencies: currencies, slabRate: slabRate)
            
            uTax += res.totalUnrealizedTax
            uSTTax += res.totalUnrealizedTaxSTCG
            uLTTax += res.totalUnrealizedTaxLTCG
            uSlabTax += res.totalUnrealizedTaxSlab
            uSTGain += res.totalUnrealizedSTCGGains
            uLTGain += res.totalUnrealizedLTCGGains
            uSlabGain += res.totalUnrealizedSlabGains
            
            rTax += res.totalRealizedTax
            rSTTax += res.totalRealizedTaxSTCG
            rLTTax += res.totalRealizedTaxLTCG
            rSlabTax += res.totalRealizedTaxSlab
            rSTGain += res.totalRealizedSTCGGains
            rLTGain += res.totalRealizedLTCGGains
            rSlabGain += res.totalRealizedSlabGains
            
            assetDetails.append(AssetTaxDetail(
                asset: asset,
                result: res
            ))
        }
        
        return (
            uTax, uSTTax, uLTTax, uSlabTax, uSTGain, uLTGain, uSlabGain,
            rTax, rSTTax, rLTTax, rSlabTax, rSTGain, rLTGain, rSlabGain,
            assetDetails
        )
    }
    
    struct AssetTaxDetail: Identifiable {
        var id: PersistentIdentifier { asset.persistentModelID }
        let asset: Asset
        let result: FifoTaxResult
    }
    
    var body: some View {
        let data = taxData
        
        VStack(spacing: 0) {
            // Top Tab Switcher
            Picker("Tax View Mode", selection: $selectedTab) {
                Text("Unrealized Gains").tag(0)
                Text("Realized (Current FY)").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Tax Profile Customizer Card
                    taxProfileCustomizer()
                    
                    // Hero consolidated tax card
                    taxHeroCard(data: data)
                    
                    // Detail grids
                    taxSummaryDetails(data: data)
                    
                    // India vs US holding period context note
                    taxRuleInsightCallout()
                    
                    // List header
                    HStack {
                        Text("Asset FIFO Breakdown")
                            .font(.headline)
                        Spacer()
                        Text("Tap row to view purchase lots")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    
                    // Asset FIFO Lot List
                    if allAssets.isEmpty {
                        ContentUnavailableView(
                            "No Assets Found",
                            systemImage: "percent",
                            description: Text("Add active assets with transactions to calculate tax liability.")
                        )
                        .padding(.vertical, 32)
                    } else {
                        ForEach(data.assetTaxDetails) { detail in
                            assetTaxAccordionRow(detail: detail)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Tax Liability Planner")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $assetToOverride) { asset in
            AssetTaxOverrideSheet(asset: asset)
        }
    }
    
    // MARK: - Tax Profile Customizer
    
    @ViewBuilder
    private func taxProfileCustomizer() -> some View {
        let currentSlab = users.first?.taxSlabRate ?? 0.30
        
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accent)
                Text("Income Tax Profile")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(String(format: "%.0f%% Slab", currentSlab * 100))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.accent)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Your Income Tax Bracket:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontWeight(.semibold)
                
                HStack(spacing: 8) {
                    ForEach([0.05, 0.10, 0.15, 0.20, 0.30, 0.39], id: \.self) { rate in
                        Button {
                            updateSlabRate(rate)
                        } label: {
                            Text(String(format: "%.0f%%", rate * 100))
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(abs(currentSlab - rate) < 0.0001 ? AppTheme.accent : Color.gray.opacity(0.12))
                                .foregroundStyle(abs(currentSlab - rate) < 0.0001 ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text("This slab rate applies to all debt instruments (bonds, debt mutual funds) and dividend or interest distributions for Indian and US assets.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    private func updateSlabRate(_ rate: Double) {
        if let user = users.first {
            user.taxSlabRate = rate
        } else {
            let newUser = User(username: "Investor", taxSlabRate: rate)
            modelContext.insert(newUser)
        }
        try? modelContext.save()
    }
    
    // MARK: - Tax Hero Card
    
    @ViewBuilder
    private func taxHeroCard(data: (
        unrealizedTax: Double, unrealizedSTCGTax: Double, unrealizedLTCGTax: Double, unrealizedSlabTax: Double,
        unrealizedSTCGGain: Double, unrealizedLTCGGain: Double, unrealizedSlabGain: Double,
        realizedTax: Double, realizedSTCGTax: Double, realizedLTCGTax: Double, realizedSlabTax: Double,
        realizedSTCGGain: Double, realizedLTCGGain: Double, realizedSlabGain: Double,
        assetTaxDetails: [AssetTaxDetail]
    )) -> some View {
        let totalTax = selectedTab == 0 ? data.unrealizedTax : data.realizedTax
        let stcgTax = selectedTab == 0 ? data.unrealizedSTCGTax : data.realizedSTCGTax
        let ltcgTax = selectedTab == 0 ? data.unrealizedLTCGTax : data.realizedLTCGTax
        let slabTax = selectedTab == 0 ? data.unrealizedSlabTax : data.realizedSlabTax
        
        VStack(spacing: 8) {
            Text(selectedTab == 0 ? "Estimated Unrealized Tax" : "Realized Tax Liability (FY)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            
            Text("₹ \(totalTax.formattedComma)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("LTCG (12.5%)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("₹\(ltcgTax.formattedComma)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                
                Spacer()
                Divider()
                    .frame(height: 24)
                    .background(Color.white.opacity(0.2))
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("STCG (20%)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("₹\(stcgTax.formattedComma)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                
                Spacer()
                Divider()
                    .frame(height: 24)
                    .background(Color.white.opacity(0.2))
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Slab Rate (30%)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("₹\(slabTax.formattedComma)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }
            .padding(.top, 12)
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
    
    // MARK: - Tax Summary Details Grid
    
    @ViewBuilder
    private func taxSummaryDetails(data: (
        unrealizedTax: Double, unrealizedSTCGTax: Double, unrealizedLTCGTax: Double, unrealizedSlabTax: Double,
        unrealizedSTCGGain: Double, unrealizedLTCGGain: Double, unrealizedSlabGain: Double,
        realizedTax: Double, realizedSTCGTax: Double, realizedLTCGTax: Double, realizedSlabTax: Double,
        realizedSTCGGain: Double, realizedLTCGGain: Double, realizedSlabGain: Double,
        assetTaxDetails: [AssetTaxDetail]
    )) -> some View {
        let stcgGain = selectedTab == 0 ? data.unrealizedSTCGGain : data.realizedSTCGGain
        let ltcgGain = selectedTab == 0 ? data.unrealizedLTCGGain : data.realizedLTCGGain
        let slabGain = selectedTab == 0 ? data.unrealizedSlabGain : data.realizedSlabGain
        
        let totalGain = stcgGain + ltcgGain + slabGain
        
        VStack(spacing: 12) {
            HStack {
                Text(selectedTab == 0 ? "Consolidated Capital Gains (INR)" : "Consolidated Realized Gains (FY)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            
            VStack(spacing: 10) {
                HStack {
                    Text("Total LTCG Gains")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("₹\(ltcgGain.formattedComma)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                
                HStack {
                    Text("Total STCG Gains (Equity)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("₹\(stcgGain.formattedComma)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                
                HStack {
                    Text("Total Slab-taxed Gains (Debt/Foreign STCG)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("₹\(slabGain.formattedComma)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                
                Divider()
                
                HStack {
                    Text("Net Taxable Profit")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Spacer()
                    Text("₹\(totalGain.formattedComma)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(totalGain >= 0 ? AppTheme.profit : AppTheme.loss)
                }
            }
            .padding(16)
            .background(Color(.systemGray6).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
    
    // MARK: - Tax Rule Callout Box
    
    @ViewBuilder
    private func taxRuleInsightCallout() -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.body)
                .foregroundStyle(AppTheme.accent)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Did you know?")
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                Text("Listed Indian Stocks qualify for LTCG (12.5%) after **12 months**. Direct US Stocks qualify as foreign unlisted assets, requiring **24 months** to trigger LTCG. Debt funds bought after April 2023 have no LTCG benefits and are always taxed at your slab rate.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
        }
        .padding(14)
        .background(AppTheme.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.accent.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Accordion Asset Row
    
    @ViewBuilder
    private func assetTaxAccordionRow(detail: AssetTaxDetail) -> some View {
        let isExpanded = expandedAssets.contains(detail.id)
        let totalLots = selectedTab == 0 ? detail.result.activeLots.count : detail.result.realizedTradesCurrentFY.count
        
        let assetGain = selectedTab == 0 ?
            (detail.result.totalUnrealizedSTCGGains + detail.result.totalUnrealizedLTCGGains + detail.result.totalUnrealizedSlabGains) :
            (detail.result.totalRealizedSTCGGains + detail.result.totalRealizedLTCGGains + detail.result.totalRealizedSlabGains)
            
        let assetTax = selectedTab == 0 ? detail.result.totalUnrealizedTax : detail.result.totalRealizedTax
        
        VStack(spacing: 0) {
            // Main clickable Header row
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedAssets.remove(detail.id)
                    } else {
                        expandedAssets.insert(detail.id)
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(detail.asset.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                Button {
                                    assetToOverride = detail.asset
                                } label: {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.accent)
                                        .padding(4)
                                        .background(AppTheme.accent.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Country & Asset Type badging
                            HStack(spacing: 6) {
                                Text(detail.asset.taxCountry.rawValue)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.12))
                                    .clipShape(Capsule())
                                
                                Text(detail.asset.taxAssetType.displayName)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.accent.opacity(0.1))
                                    .foregroundStyle(AppTheme.accent)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(assetGain >= 0 ? "+₹\(assetGain.formattedComma)" : "-₹\(abs(assetGain).formattedComma)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(assetGain >= 0 ? AppTheme.profit : AppTheme.loss)
                            
                            Text("Tax: ₹\(assetTax.formattedComma)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 8)
                    }
                    
                    if selectedTab == 0 {
                        let totalUnits = PortfolioMetrics.totalUnits(for: detail.asset)
                        Text("\(totalUnits.formatted2) units held across \(totalLots) FIFO lot\(totalLots == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(totalLots) realized trade\(totalLots == 1 ? "" : "s") in current FY")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .background(Color(.systemBackground))
            }
            .buttonStyle(.plain)
            
            // Expanded FIFO lot child cards
            if isExpanded {
                Divider()
                
                VStack(spacing: 8) {
                    if totalLots == 0 {
                        Text(selectedTab == 0 ? "No active holdings/lots." : "No realized gains/losses in current FY.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        if selectedTab == 0 {
                            ForEach(detail.result.activeLots) { lot in
                                fifoActiveLotRow(lot: lot)
                            }
                        } else {
                            ForEach(detail.result.realizedTradesCurrentFY) { trade in
                                fifoRealizedTradeRow(trade: trade)
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6).opacity(0.4))
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Active FIFO Lot Child Row
    
    @ViewBuilder
    private func fifoActiveLotRow(lot: FifoHoldingLot) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(lot.purchaseDate, style: .date)
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    let ageYears = Double(lot.holdingAgeDays) / 365.0
                    Text(lot.holdingAgeDays >= 365 ? String(format: "(%.1f yr old)", ageYears) : "(\(lot.holdingAgeDays) d old)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                
                Text("\(lot.remainingUnits.formatted2) units @ ₹\(lot.buyPriceINR.formattedComma)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Text(lot.unrealizedGainINR >= 0 ? "+₹\(lot.unrealizedGainINR.formattedCompact)" : "-₹\(abs(lot.unrealizedGainINR).formattedCompact)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(lot.unrealizedGainINR >= 0 ? AppTheme.profit : AppTheme.loss)
                    
                    Text(lot.taxCategory.rawValue)
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(lot.taxCategory == .ltcg ? AppTheme.profit.opacity(0.15) : (lot.taxCategory == .stcg ? AppTheme.accent.opacity(0.15) : AppTheme.warning.opacity(0.15)))
                        .foregroundStyle(lot.taxCategory == .ltcg ? AppTheme.profit : (lot.taxCategory == .stcg ? AppTheme.accent : AppTheme.warning))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                
                let lotTax = max(0, lot.unrealizedGainINR * lot.taxRate)
                Text("Est. Tax: ₹\(lotTax.formattedComma) (\(String(format: "%.1f%%", lot.taxRate * 100)))")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Realized FIFO Trade Child Row
    
    @ViewBuilder
    private func fifoRealizedTradeRow(trade: FifoRealizedTrade) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sold: \(trade.sellDate.formatted(.dateTime.day().month().year()))")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text("\(trade.units.formatted2) units (Bought: \(trade.buyDate.formatted(.dateTime.day().month().year())))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Text(trade.realizedGainINR >= 0 ? "+₹\(trade.realizedGainINR.formattedCompact)" : "-₹\(abs(trade.realizedGainINR).formattedCompact)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(trade.realizedGainINR >= 0 ? AppTheme.profit : AppTheme.loss)
                    
                    Text(trade.taxCategory.rawValue)
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(trade.taxCategory == .ltcg ? AppTheme.profit.opacity(0.15) : AppTheme.accent.opacity(0.15))
                        .foregroundStyle(trade.taxCategory == .ltcg ? AppTheme.profit : AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                
                let tradeTax = max(0, trade.realizedGainINR * trade.taxRate)
                Text("Tax: ₹\(tradeTax.formattedComma) (\(String(format: "%.1f%%", trade.taxRate * 100)))")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Asset Tax Override Sheet

struct AssetTaxOverrideSheet: View {
    @Environment(\.dismiss) private var dismiss
    let asset: Asset
    
    @State private var selectedCountry: TaxCountry = .india
    @State private var selectedType: TaxAssetType = .equity
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Tax Classification") {
                    Picker("Country / Ruleset", selection: $selectedCountry) {
                        ForEach(TaxCountry.allCases) { country in
                            Text(country.rawValue).tag(country)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Asset Instrument Type", selection: $selectedType) {
                        ForEach(TaxAssetType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tax Rule Info:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        
                        if selectedCountry == .india {
                            if selectedType == .equity {
                                Text("• LTCG applies after 1 year (12 months) at 12.5%.\n• STCG applies at 20%.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else if selectedType == .debt {
                                Text("• All gains taxed at standard slab rate (approx 30%).\n• No LTCG holding benefits.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("• LTCG applies after 3 years (36 months) at 12.5%.\n• STCG taxed at standard slab rate (30%).")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            // US Stocks
                            if selectedType == .equity {
                                Text("• Direct US Stocks qualify as unlisted foreign assets in India.\n• LTCG applies after 2 years (24 months) at 12.5%.\n• STCG taxed at standard slab rates (approx 30%).")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("• US debt/alternate assets qualify for LTCG after 2 years (12.5%).\n• STCG taxed at standard slab rates (approx 30%).")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Configure \(asset.name) Tax")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        asset.taxCountry = selectedCountry
                        asset.taxAssetType = selectedType
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                selectedCountry = asset.taxCountry
                selectedType = asset.taxAssetType
            }
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
    
    TaxLiabilityView()
        .modelContainer(for: previewModels, inMemory: true)
}
