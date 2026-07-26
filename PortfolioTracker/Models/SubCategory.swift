//
//  SubCategory.swift
//  PortfolioTracker
//

import Foundation
import SwiftData

@Model
final class SubCategory {
    var name: String
    var category: Category?
    
    @Relationship(deleteRule: .nullify, inverse: \Asset.subCategory)
    var assets: [Asset] = []
    
    init(name: String, category: Category? = nil) {
        self.name = name
        self.category = category
    }
}
