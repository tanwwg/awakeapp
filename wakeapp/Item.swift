//
//  Item.swift
//  wakeapp
//
//  Created by Tan Thor Jen on 26/12/23.
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
