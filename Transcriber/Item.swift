//
//  Item.swift
//  Transcriber
//
//  Created by Marco Wenzel on 14.05.2025.
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
