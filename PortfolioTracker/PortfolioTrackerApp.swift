//
//  PortfolioTrackerApp.swift
//  PortfolioTracker
//
//  Created by Hewitt Vijayan on 15/03/26.
//

import SwiftUI
import SwiftData

@main
struct PortfolioTrackerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(appState.storeReloadID)
                .environmentObject(appState)
        }
        .modelContainer(appState.modelContainer)
    }
}
