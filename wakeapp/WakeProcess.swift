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
        let device = Awake.Device(MAC: host.mac, BroadcastAddr: host.broadcast, Port: UInt16(host.port))
        if let err = Awake.target(device: device) {
            text = err.localizedDescription
            isError = true
            return
        }

    }
    
    func tryPing() async throws {
        print("tryPing")
        let pinger = try SwiftyPing(host: "192.168.1.239", configuration: PingConfiguration(interval: 0.5, with: 3), queue: DispatchQueue.global())
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            pinger.observer = { [self] (response) in
                if let err = response.error {
                    isError = true
                    text = err.localizedDescription
                    pinger.haltPinging()
                    continuation.resume(throwing: err)
                } else {
                    print("isPinged!")
                    isPinged = true
                    pinger.haltPinging()
                    continuation.resume()
                }
            }
            do {
                try pinger.startPinging()
            } catch {
                continuation.resume(throwing: error)
            }
        }

    }
}
