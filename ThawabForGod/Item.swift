//
//  Item.swift
//  ThawabForGod
//
//  Created by Saad Sherif on 10/08/2026.
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
