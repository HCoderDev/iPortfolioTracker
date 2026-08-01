//
//  ContentView.swift
//  PortfolioTracker
//
//  Created by Hewitt Vijayan on 15/03/26.
//

import SwiftUI
import SwiftData

enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case assets = "Assets"
    case categories = "Categories"
    case flows = "Flows & Cash"
    case reminders = "Reminders"
    case importWizard = "Data Import"
    case rebalancer = "Rebalancer"
    case taxPlanner = "Tax Planner"
    case fiTracker = "Time to FI"
    case brokers = "Brokers"
    case currencies = "Currencies"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return "chart.pie.fill"
        case .assets: return "chart.line.uptrend.xyaxis"
        case .categories: return "square.grid.2x2.fill"
        case .flows: return "arrow.up.arrow.down.circle.fill"
        case .reminders: return "calendar.badge.clock"
        case .importWizard: return "square.and.arrow.down.on.square.fill"
        case .rebalancer: return "scale.3d"
        case .taxPlanner: return "percent"
        case .fiTracker: return "flame.fill"
        case .brokers: return "building.columns.fill"
        case .currencies: return "dollarsign.circle.fill"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \User.username) private var users: [User]
    @State private var selectedItem: NavigationItem? = .dashboard
    @State private var selectedTab: Int = 0
    @State private var showSplash = true
    @State private var showLayoutSettings = false
    
    private var preferredColorScheme: ColorScheme? {
        switch appState.colorSchemeOption {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        ZStack {
            if !showSplash && !appState.isReloadingStore {
                Group {
                    if users.isEmpty {
                        LoginView()
                    } else if appState.useClassicTabBarLayout {
                        // MARK: - Classic TabBar Layout Option
                        TabView(selection: $selectedTab) {
                            NavigationStack {
                                DashboardView()
                            }
                            .tabItem {
                                Label("Dashboard", systemImage: "chart.pie.fill")
                            }
                            .tag(0)
                            
                            NavigationStack {
                                CategoryListView()
                            }
                            .tabItem {
                                Label("Categories", systemImage: "square.grid.2x2.fill")
                            }
                            .tag(1)
                            
                            NavigationStack {
                                PortfolioFlowsView()
                            }
                            .tabItem {
                                Label("Flows", systemImage: "arrow.up.arrow.down.circle.fill")
                            }
                            .tag(2)
                            
                            NavigationStack {
                                AssetListView()
                            }
                            .tabItem {
                                Label("Assets", systemImage: "chart.line.uptrend.xyaxis")
                            }
                            .tag(3)
                            
                            NavigationStack {
                                RemindersListView()
                            }
                            .tabItem {
                                Label("Reminders", systemImage: "calendar.badge.clock")
                            }
                            .tag(4)
                        }
                        .tint(AppTheme.accent)
                    } else {
                        // MARK: - Native macOS Sidebar Layout
                        NavigationSplitView {
                            SidebarView(selection: $selectedItem, showLayoutSettings: $showLayoutSettings)
                        } detail: {
                            NavigationStack {
                                detailView(for: selectedItem ?? .dashboard)
                            }
                        }
                        .tint(AppTheme.accent)
                    }
                }
                .transition(.opacity)
            } else {
                SplashScreenView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .sheet(isPresented: $showLayoutSettings) {
            LayoutAndThemeSettingsSheet()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showSplash = false
                }
            }
        }
    }
    
    @ViewBuilder
    private func detailView(for item: NavigationItem) -> some View {
        switch item {
        case .dashboard:
            DashboardView()
        case .assets:
            AssetListView()
        case .categories:
            CategoryListView()
        case .flows:
            PortfolioFlowsView()
        case .reminders:
            RemindersListView()
        case .importWizard:
            FileImportWizardView()
        case .rebalancer:
            PortfolioRebalancerView()
        case .taxPlanner:
            TaxLiabilityView()
        case .fiTracker:
            FITrackerDetailView()
        case .brokers:
            BrokerListView()
        case .currencies:
            CurrencyListView()
        }
    }
}

// MARK: - Native macOS Sidebar View
struct SidebarView: View {
    @Binding var selection: NavigationItem?
    @Binding var showLayoutSettings: Bool
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Asset.name) private var assets: [Asset]
    @Query(sort: \Currency.code) private var currencies: [Currency]
    
    private var totalNetworth: Double {
        assets.reduce(0.0) { sum, asset in
            guard let cat = asset.category else { return sum }
            let rate = PortfolioMetrics.currentInrExchangeRate(for: cat, currencies: currencies)
            return sum + PortfolioMetrics.currentValueInINR(for: asset, rate: rate)
        }
    }
    
    private var fiSummaryText: String {
        @AppStorage("fiTargetGoal") var targetGoal: Double = FICalculator.defaultTargetGoal
        @AppStorage("fiBirthDateTimeInterval") var birthDateTimeInterval: Double = FICalculator.defaultBirthDate.timeIntervalSince1970
        @AppStorage("fiMonthlySIP") var monthlySIP: Double = FICalculator.defaultMonthlySIP
        @AppStorage("fiReturnRate") var returnRate: Double = FICalculator.defaultReturnRate
        @AppStorage("fiInflationRate") var inflationRate: Double = FICalculator.defaultInflationRate
        @AppStorage("fiSafeWithdrawalRate") var safeWithdrawalRate: Double = FICalculator.defaultSWR
        
        let projection = FICalculator.projectFI(
            currentNetWorth: totalNetworth,
            targetGoal: targetGoal,
            birthDate: Date(timeIntervalSince1970: birthDateTimeInterval),
            monthlySIP: monthlySIP,
            returnRate: returnRate,
            inflationRate: inflationRate,
            safeWithdrawalRate: safeWithdrawalRate
        )
        
        if projection.monthsNeeded == 0 {
            return "ACHIEVED! 🎉"
        } else {
            let yrs = projection.monthsNeeded / 12
            let mos = projection.monthsNeeded % 12
            return "\(yrs)y \(mos)m (\(projection.progressPercentage.formatted1)%)"
        }
    }

    
    var body: some View {
        List(selection: $selection) {
            Section("PORTFOLIO SUMMARY") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NETWORTH (EST.)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    Text("₹\(totalNetworth.formattedComma)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.accent)
                    
                    HStack(spacing: 12) {
                        Label("\(categories.count) Categories", systemImage: "square.grid.2x2")
                        Label("\(assets.count) Assets", systemImage: "chart.bar")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TIME TO FI")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(fiSummaryText)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.accent)
                        }
                        Spacer()
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("OVERVIEW") {
                NavigationLink(value: NavigationItem.dashboard) {
                    Label("Dashboard", systemImage: NavigationItem.dashboard.icon)
                }
                NavigationLink(value: NavigationItem.assets) {
                    Label("All Assets", systemImage: NavigationItem.assets.icon)
                }
                NavigationLink(value: NavigationItem.categories) {
                    Label("Categories", systemImage: NavigationItem.categories.icon)
                }
            }
            
            Section("TRANSACTIONS & CASH") {
                NavigationLink(value: NavigationItem.flows) {
                    Label("Flows & Cash", systemImage: NavigationItem.flows.icon)
                }
                NavigationLink(value: NavigationItem.reminders) {
                    Label("Reminders", systemImage: NavigationItem.reminders.icon)
                }
            }
            
            Section("ANALYTICS & TOOLS") {
                NavigationLink(value: NavigationItem.fiTracker) {
                    Label("Time to FI", systemImage: NavigationItem.fiTracker.icon)
                }
                NavigationLink(value: NavigationItem.importWizard) {
                    Label("Import Wizard", systemImage: NavigationItem.importWizard.icon)
                }
                NavigationLink(value: NavigationItem.rebalancer) {
                    Label("Rebalancer", systemImage: NavigationItem.rebalancer.icon)
                }
                NavigationLink(value: NavigationItem.taxPlanner) {
                    Label("Tax Liability Planner", systemImage: NavigationItem.taxPlanner.icon)
                }
            }
            
            Section("SETTINGS") {
                NavigationLink(value: NavigationItem.brokers) {
                    Label("Brokers", systemImage: NavigationItem.brokers.icon)
                }
                NavigationLink(value: NavigationItem.currencies) {
                    Label("Currencies", systemImage: NavigationItem.currencies.icon)
                }
                
                Button {
                    showLayoutSettings = true
                } label: {
                    Label("Layout & Theme", systemImage: "paintbrush.fill")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Portfolio")
    }
}


// MARK: - Layout & Theme Settings Sheet
struct LayoutAndThemeSettingsSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("NAVIGATION LAYOUT STYLE") {
                    Picker("Layout Style", selection: $appState.useClassicTabBarLayout) {
                        Label("macOS Native Sidebar", systemImage: "sidebar.left").tag(false)
                        Label("Classic Bottom TabBar", systemImage: "filemenu.and.selection").tag(true)
                    }
                    .pickerStyle(.segmented)
                    
                    Text("Choose between modern macOS sidebar navigation or classic iOS bottom tabs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                
                Section("COLOR THEME") {
                    Picker("App Theme", selection: $appState.colorSchemeOption) {
                        Label("System Default", systemImage: "circle.righthalf.filled").tag("system")
                        Label("Light Mode", systemImage: "sun.max.fill").tag("light")
                        Label("Dark Mode", systemImage: "moon.fill").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    
                    Text("Select your preferred visual appearance. High-contrast colors adapt cleanly in Light and Dark modes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Layout & Appearance Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}



// MARK: - Splash Screen View
struct SplashScreenView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Sleek Dark Background
            Color(hex: "0B0B14")
                .ignoresSafeArea()
            
            // Subtly glowing background orb
            Circle()
                .fill(AppTheme.accent.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(y: -40)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
            
            VStack(spacing: 24) {
                Spacer()
                
                // Animated Glowing Logo
                ZStack {
                    // Outer glow
                    Circle()
                        .stroke(AppTheme.accent.opacity(0.3), lineWidth: 4)
                        .frame(width: 90, height: 90)
                        .scaleEffect(isAnimating ? 1.25 : 0.95)
                        .opacity(isAnimating ? 0.0 : 1.0)
                    
                    // Circular surface
                    Circle()
                        .fill(AppTheme.heroGradient)
                        .frame(width: 80, height: 80)
                        .shadow(color: AppTheme.accent.opacity(0.5), radius: 15)
                    
                    // Vector icon
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(y: isAnimating ? 0 : -20)
                
                // App Title
                VStack(spacing: 8) {
                    Text("PORTFOLIO")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .tracking(8)
                        .foregroundStyle(.white)
                    
                    Text("TRACKER")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .tracking(12)
                        .foregroundStyle(AppTheme.accentSecondary)
                        .offset(x: 4) // adjust for letter tracking offset
                }
                .opacity(isAnimating ? 1.0 : 0.0)
                .scaleEffect(isAnimating ? 1.0 : 0.9)
                
                Spacer()
                
                // Minimalist Premium Custom Loading Indicator
                VStack(spacing: 12) {
                    // Linear progress bar
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 140, height: 4)
                        .overlay(
                            GeometryReader { geo in
                                Capsule()
                                    .fill(AppTheme.profitGradient)
                                    .frame(width: isAnimating ? geo.size.width : 0)
                            }
                        )
                    
                    Text("Loading Assets...")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Trigger beautiful launch animations
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isAnimating = true
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
    
    ContentView()
        .environmentObject(AppState.preview)
        .modelContainer(for: previewModels, inMemory: true)
}

