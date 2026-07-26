//
//  PortfolioBackup.swift
//  PortfolioTracker
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SQLite3

extension UTType {
    static var sqliteDatabase: UTType {
        UTType(filenameExtension: "db")
            ?? UTType(filenameExtension: "sqlite")
            ?? UTType(filenameExtension: "sqlite3")
            ?? .data
    }
    
    static var sqliteImportTypes: [UTType] {
        var types: [UTType] = [.sqliteDatabase, .data]
        if let sqliteType = UTType(filenameExtension: "sqlite") {
            types.append(sqliteType)
        }
        if let sqlite3Type = UTType(filenameExtension: "sqlite3") {
            types.append(sqlite3Type)
        }
        return types
    }
}

struct SQLiteDatabaseDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.sqliteDatabase, .data] }
    
    let data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let regularFileContents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = regularFileContents
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum SQLiteDatabaseManager {
    static func checkpointDatabase(at url: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            throw DatabaseError.openFailed(message: currentErrorMessage(for: database))
        }
        defer {
            sqlite3_close(database)
        }
        
        guard sqlite3_exec(database, "PRAGMA wal_checkpoint(FULL);", nil, nil, nil) == SQLITE_OK else {
            throw DatabaseError.checkpointFailed(message: currentErrorMessage(for: database))
        }
    }
    
    static func replaceDatabase(at url: URL, with data: Data) throws {
        try removeDatabaseFiles(at: url)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try data.write(to: url, options: .atomic)
    }
    
    static func removeDatabaseFiles(at url: URL) throws {
        let fileManager = FileManager.default
        for candidateURL in [url, walURL(for: url), shmURL(for: url)] where fileManager.fileExists(atPath: candidateURL.path) {
            try fileManager.removeItem(at: candidateURL)
        }
    }
    
    private static func walURL(for url: URL) -> URL {
        url.deletingPathExtension().appendingPathExtension("\(url.pathExtension)-wal")
    }
    
    private static func shmURL(for url: URL) -> URL {
        url.deletingPathExtension().appendingPathExtension("\(url.pathExtension)-shm")
    }
    
    private static func currentErrorMessage(for database: OpaquePointer?) -> String {
        guard let database else {
            return "Unknown SQLite error"
        }
        return String(cString: sqlite3_errmsg(database))
    }
    
    enum DatabaseError: LocalizedError {
        case openFailed(message: String)
        case checkpointFailed(message: String)
        
        var errorDescription: String? {
            switch self {
            case .openFailed(let message):
                return "Unable to open the SQLite database. \(message)"
            case .checkpointFailed(let message):
                return "Unable to checkpoint the SQLite database. \(message)"
            }
        }
    }
}
