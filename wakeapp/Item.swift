//
//  Item.swift
//  wakeapp
//
//  Created by Tan Thor Jen on 26/12/23.
//

import Foundation
import SwiftData

@Model
final class WakeHost {
    init(name: String, mac: String, broadcast: String, port: Int) {
        self.name = name
        self.mac = mac
        self.broadcast = broadcast
        self.port = port
    }
    
    var name = ""
    var mac = ""
    var broadcast = ""
    var port = 0
    
}
