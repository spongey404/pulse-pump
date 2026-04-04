//
//  Item.swift
//  Pump
//
//  Created by Vasanth Santosh on 4/4/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
