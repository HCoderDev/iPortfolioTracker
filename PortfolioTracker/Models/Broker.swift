//
//  Broker.swift
//  PortfolioTracker
//

import Foundation
import SwiftData

@Model
final class Broker {
    var name: String
    
    init(name: String) {
        self.name = name
    }
}
