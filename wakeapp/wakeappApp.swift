//
//  wakeappApp.swift
//  wakeapp
//
//  Created by Tan Thor Jen on 26/12/23.
//

import SwiftUI
import SwiftData
import Awake

struct WakeConfig: Decodable {
    var hosts: [WakeConfigHost]
}

struct WakeData: Decodable {
    var mac: String
    var broadcastIp: String
    var port: Int
}

struct WakeConfigCommand: Decodable {
    var name: String
    var runCmd: String
    var runArgs: [String]
}

struct WakeConfigHost: Decodable {
    var id: String { name }
    
    var name: String
    var pingIp: String?
    var wake: WakeData?
    var commands: [WakeConfigCommand]
}

struct WakeCommand: Identifiable {
    var id: String
    var host: WakeHost
    var config: WakeConfigCommand
    var name: String { config.name }
    
    var isNeedsWake: Bool {
        guard let ph = host.pingHost else { return false }
        return !ph.isAlive
    }
    
    func run() {
        DispatchQueue.global().async {
            let task = Process()
            let pipe = Pipe()
            
            task.standardOutput = pipe
            task.standardError = pipe
            task.arguments = config.runArgs
            task.executableURL = URL(fileURLWithPath: config.runCmd) //<--updated
            task.standardInput = nil

            try? task.run() //<--updated
        }
    }
}

@Observable class WakeHost: Identifiable {
    init(config: WakeConfigHost) {
        self.config = config
    }
    
    var id: String { config.name }
    var config: WakeConfigHost
    
    var pingHost: PingHost?
    var commands: [WakeCommand] = []
    
    func sendWake() throws {
        if let wake = config.wake {
            let device = Awake.Device(MAC: wake.mac, BroadcastAddr: wake.broadcastIp, Port: UInt16(wake.port))
            if let err = Awake.target(device: device) { throw err }
        }
    }
}

@Observable class WakeApp {
    var hosts: [WakeHost] = []
    var commands: [String:WakeCommand] = [:]
    
    var geforce = KeystrokeApp()
    
    var pinger = Pinger()
    
    init() {
        
    }
    
    func load() throws {
        let docFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let docUrl = docFolder.appending(path: "wake.json")
        let data = try Data(contentsOf: docUrl)
        let config = try JSONDecoder().decode(WakeConfig.self, from: data)
        
        self.hosts = config.hosts.map { h in
            let wake = WakeHost(config: h)
            
            wake.commands = h.commands.map { c in
                let cmd = WakeCommand(id: "\(h.name)::\(c.name)", host: wake, config: c)
                commands[cmd.id] = cmd
                return cmd
            }

            if let pingIp = h.pingIp {
                let ph = PingHost(name: h.name, ipv4: pingIp)
                wake.pingHost = ph
                pinger.hosts.append(ph)
            }
            return wake
        }
        try pinger.startPinging()
    }
}

@main
struct wakeappApp: App {
    
    var app = WakeApp()

    var body: some Scene {
        Window("Wake app", id: "main") {
            ContentView()
                .environment(app)
        }
    }
}


//    var sharedModelContainer: ModelContainer = {
//        let schema = Schema([
//            WakeHost.self,
//        ])
//        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
//
//        do {
//            return try ModelContainer(for: schema, configurations: [modelConfiguration])
//        } catch {
//            fatalError("Could not create ModelContainer: \(error)")
//        }
//    }()
