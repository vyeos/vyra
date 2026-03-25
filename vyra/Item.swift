//
//  Item.swift
//  vyra
//
//  Created by Rudra Patel on 25/03/26.
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
