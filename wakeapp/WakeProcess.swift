//
//  WakeProcess.swift
//  wakeapp
//
//  Created by Tan Thor Jen on 15/1/24.
//

import Foundation
import SwiftUI
import Awake
import SwiftyPing

@MainActor @Observable class WakeProcess {
    
    let host: WakeHost
    var text = "Waking..."
    var isError = false
    var isPinged = false
    
    internal init(host: WakeHost) {
        self.host = host
    }
    
    func start() async throws {
        while !isPinged {
            try tryWake()
            
            try await tryPing()
        }
    }
    
    func tryWake() throws {
        let device = Awake.Device(MAC: host.mac, BroadcastAddr: host.broadcastIp, Port: UInt16(host.port))
        if let err = Awake.target(device: device) {
            text = err.localizedDescription
            isError = true
            return
        }

    }
    
    func safeShell(command: String, args: [String]) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            let task = Process()
            let pipe = Pipe()
            
            task.standardOutput = pipe
            task.standardError = pipe
            task.arguments = args
            task.executableURL = URL(fileURLWithPath: command) //<--updated
            task.standardInput = nil

            try? task.run() //<--updated
        }
//        let task = Process()
//        let pipe = Pipe()
//        
//        task.standardOutput = pipe
//        task.standardError = pipe
//        task.arguments = args
//        task.executableURL = URL(fileURLWithPath: command) //<--updated
//        task.standardInput = nil
//
//        try task.run() //<--updated
//        
//        let data = pipe.fileHandleForReading.readDataToEndOfFile()
//        let output = String(data: data, encoding: .utf8)!
//        
//        return output
    }
    
    func tryPing() async throws {
        print("tryPing")
        let pinger = try SwiftyPing(host: host.pingIp, configuration: PingConfiguration(interval: 0.5, with: 3), queue: DispatchQueue.global())
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            pinger.observer = { [self] (response) in
                if response.error != nil {
                    print("err in observer!")
                    // probably no ping received
                } else {
                    print("isPinged!")
                    
                    if let run = host.runCmd {
                        safeShell(command: run, args: host.runArgs ?? [])
                    }
                    isPinged = true
                    
                }
                pinger.haltPinging()
                continuation.resume()
            }
            do {
                try pinger.startPinging()
            } catch {
                print("err in startPinging()")
                continuation.resume(throwing: error)
            }
        }

    }
}
