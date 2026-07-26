//
//  AssetReminder.swift
//  PortfolioTracker
//
//  Created by Antigravity on 30/05/26.
//

import Foundation
import SwiftData

@Model
final class AssetReminder {
    var title: String
    var eventDate: Date
    var notes: String
    var isCompleted: Bool
    var createdAt: Date
    
    var asset: Asset?
    
    init(
        title: String,
        eventDate: Date,
        notes: String = "",
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        asset: Asset? = nil
    ) {
        self.title = title
        self.eventDate = eventDate
        self.notes = notes
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.asset = asset
    }
}
