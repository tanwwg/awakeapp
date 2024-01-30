//
//  ContentView.swift
//  wakeapp
//
//  Created by Tan Thor Jen on 26/12/23.
//

import SwiftUI
import SwiftData
import Awake

struct WakeView: View {
    @Environment(\.dismiss) var dismiss
    var cmd: WakeCommand
    @State var text = "Waking..."
    @State var isError = false
    
    var body: some View {
        VStack {
            Text(text)
                .padding()
            if isError {
                Button(action: { dismiss() }) {
                    Text("OK")
                }
            }
        }
        .frame(width: 200, height: 200)
        .task {
            do {
                if let ph = cmd.host.pingHost, !ph.isAlive {
                    while !ph.isAlive {
                        try cmd.host.sendWake()
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                    NSSound.beep()
                }
                cmd.run()
                dismiss()
            } catch {
                text = error.localizedDescription
                isError = true
            }
        }
    }
}

struct WakeHostView: View {
    var cmd: WakeCommand
    
    @State var isWake = false
    
    var body: some View {
        Form {
//            LabeledContent("Mac", value: host.mac)
//            LabeledContent("Broadcast", value: host.broadcastIp)
//            LabeledContent("Port", value: "\(host.port)")
//            LabeledContent("IP", value: "\(host.pingIp)")
            LabeledContent("Run", value: "\(cmd.config.runCmd)")
            LabeledContent("Args", value: "\(cmd.config.runArgs.joined(separator: " "))")
            Button(action: { isWake = true }) {
                Text("Run")
            }
        }
        .sheet(isPresented: $isWake) {
            WakeView(cmd: cmd)
        }
    }
}

struct GeforceView: View {
    @Environment(WakeApp.self) var app: WakeApp
    
    func formatTime(interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? ""
    }
    
    var body: some View {
        VStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let startTime = app.geforce.startTime {
                    Text(formatTime(interval: context.date.timeIntervalSince(startTime)))
                } else {
                    Text("Not started")
                }
            }
            Button(action: { app.geforce.isRunning ? app.geforce.stop() : app.geforce.start() }) {
                Text(app.geforce.isRunning ? "Stop": "Start")
            }
        }
    }
}

struct LiveIndicator: View {
    
    var isAlive: Bool

    var body: some View {
        Circle().fill(isAlive ? .green : .red)
            .frame(width: 12, height: 12)
    }
}

struct PingHostLineItem: View {
    var host: PingHost
    
    var body: some View {
        HStack {
            LiveIndicator(isAlive: host.isAlive)
            Text(host.name)
//            Spacer()
        }
        .padding(.leading)
    }
}

struct UiCommand: Identifiable {
    var id: String
    var name: String
}

struct ContentView: View {
    @Environment(WakeApp.self) var app: WakeApp
    @State var selectedItem: String?
    @State var error: Error?
    
    @State var geforceCommands: [UiCommand] = [
        UiCommand(id: "geforce::status", name: "Status"),
    ]
    
    func reload() {
//        do {
//            items = try loadItems()
//        } catch {
//            self.error = error
//        }
    }
    
    @ViewBuilder
    var navView: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                ForEach(app.hosts) { host in
                    Section {
                        ForEach(host.commands) { cmd in
                            Text(cmd.name)
                        }
                    } header: {
                        if let ph = host.pingHost {
                            PingHostLineItem(host: ph)
                        } else {
                            Text(host.id)
                        }
                    }
                }
                Section {
                    ForEach(geforceCommands) { item in
                        Text(item.name)
                    }
                } header: {
                    HStack {
                        LiveIndicator(isAlive: app.geforce.isRunning)
                        Text("Geforce Now")
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            if let sel = selectedItem {
                if let cmd = app.commands[sel] {
                    WakeHostView(cmd: cmd)
                } else if sel == "geforce::status" {
                    GeforceView()
                } else {
                    Text("?? \(sel)")
                }
            } else {
                Text("Select an item \(selectedItem ?? "[null]")")
            }
        }
    }
    
    var body: some View {
        Group {
            if let err = error {
                Text(err.localizedDescription)
            } else {
                navView
            }
        }
        .toolbar {
            ToolbarItem {
                Button(action: reload) {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            do {
                try app.load()
            } catch {
                self.error = error
            }
        }
    }

//    private func addItem() {
//        isAdd = true
//    }
//
//    private func deleteItems(offsets: IndexSet) {
//        withAnimation {
//            for index in offsets {
//                modelContext.delete(items[index])
//            }
//        }
//    }
}

