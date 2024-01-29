//
//  Item.swift
//  wakeapp
//
//  Created by Tan Thor Jen on 26/12/23.
//

import Foundation

struct WakeHost: Identifiable, Decodable {
//    init(name: String, mac: String, broadcast: String, port: Int) {
//        self.name = name
//        self.mac = mac
//        self.broadcast = broadcast
//        self.port = port
//    }
//    
    
    var id: String { name }
    
    var name: String
    var mac: String
    var broadcastIp: String
    var port: Int
    var pingIp: String
    
    var runCmd: String?
    var runArgs: [String]?
}
