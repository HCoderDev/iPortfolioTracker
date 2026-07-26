//
//  AssetNote.swift
//  PortfolioTracker
//

import Foundation
import SwiftData

@Model
final class AssetNote {
    var title: String
    var noteDescription: String
    var date: Date
    var createdAt: Date
    var asset: Asset?
    
    init(
        title: String,
        noteDescription: String,
        date: Date = Date(),
        createdAt: Date = Date(),
        asset: Asset? = nil
    ) {
        self.title = title
        self.noteDescription = noteDescription
        self.date = date
        self.createdAt = createdAt
        self.asset = asset
    }
}
