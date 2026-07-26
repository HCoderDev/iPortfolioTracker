//
//  AppState.swift
//  PortfolioTracker
//

import Foundation
import Combine
import SwiftData
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var modelContainer: ModelContainer
    @Published var isReloadingStore = false
    @Published var storeReloadID = UUID()
    
    @AppStorage("useClassicTabBarLayout") var useClassicTabBarLayout: Bool = false
    @AppStorage("colorSchemeOption") var colorSchemeOption: String = "system" // "system", "light", "dark"
    
    let storeURL: URL

    
    init(storeURL: URL? = nil, inMemory: Bool = false) {
        let resolvedURL = storeURL ?? Self.defaultStoreURL()
        self.storeURL = resolvedURL
        self.modelContainer = Self.makeContainer(at: resolvedURL, inMemory: inMemory)
    }
    
    static var preview: AppState {
        AppState(storeURL: FileManager.default.temporaryDirectory.appendingPathComponent("PortfolioTrackerPreview.sqlite"), inMemory: true)
    }
    
    func exportDatabaseDocument() throws -> SQLiteDatabaseDocument {
        try flushStoreToDisk()
        return SQLiteDatabaseDocument(data: try Data(contentsOf: storeURL))
    }
    
    func importDatabase(from sourceURL: URL) async throws {
        let shouldStopAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let databaseData = try Data(contentsOf: sourceURL)
        try flushStoreToDisk()
        
        isReloadingStore = true
        
        do {
            modelContainer = Self.makeContainer(at: storeURL, inMemory: true)
            try await Task.sleep(nanoseconds: 150_000_000)
            try SQLiteDatabaseManager.replaceDatabase(at: storeURL, with: databaseData)
            modelContainer = Self.makeContainer(at: storeURL, inMemory: false)
            storeReloadID = UUID()
            isReloadingStore = false
        } catch {
            modelContainer = Self.makeContainer(at: storeURL, inMemory: false)
            storeReloadID = UUID()
            isReloadingStore = false
            throw error
        }
    }
    
    private func flushStoreToDisk() throws {
        try modelContainer.mainContext.save()
        try SQLiteDatabaseManager.checkpointDatabase(at: storeURL)
    }
    
    private static func makeContainer(at url: URL, inMemory: Bool) -> ModelContainer {
        let schema = Schema(modelTypes)
        let configuration: ModelConfiguration
        
        if inMemory {
            configuration = ModelConfiguration(
                "PortfolioTracker",
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else {
            let parentDirectory = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)
            configuration = ModelConfiguration(
                "PortfolioTracker",
                schema: schema,
                url: url,
                cloudKitDatabase: .none
            )
        }
        
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    private static func defaultStoreURL() -> URL {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let appDirectory = baseDirectory.appendingPathComponent("PortfolioTracker", isDirectory: true)
        return appDirectory.appendingPathComponent("portfolio_database.sqlite")
    }
    
    private static let modelTypes: [any PersistentModel.Type] = [
        User.self,
        Currency.self,
        Category.self,
        Asset.self,
        Broker.self,
        AssetTransaction.self,
        AssetNote.self,
        SubCategory.self,
        StockValueAnalysis.self,
        StockDCFAnalysis.self,
        AssetReminder.self,
        PortfolioSnapshot.self,
        CategorySnapshot.self,
        AssetSnapshot.self,
    ]
}
