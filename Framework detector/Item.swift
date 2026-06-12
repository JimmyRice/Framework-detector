//
//  Item.swift
//  Framework detector
//
//  Created by 张烨轩 on 2026/6/12.
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
