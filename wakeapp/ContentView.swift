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
    var host: WakeHost
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
                try await WakeProcess(host: host).start()
                NSSound.beep()
                dismiss()
            } catch {
                text = error.localizedDescription
                isError = true
            }
        }
    }
}

struct WakeHostView: View {
    var host: WakeHost
    
    @State var isWake = false
    
    var body: some View {
        Form {
            LabeledContent("Mac", value: host.mac)
            LabeledContent("Broadcast", value: host.broadcastIp)
            LabeledContent("Port", value: "\(host.port)")
            LabeledContent("IP", value: "\(host.pingIp)")
            LabeledContent("Run", value: "\(host.runCmd ?? "[None]")")
            LabeledContent("Args", value: "\((host.runArgs ?? []).joined(separator: " "))")
            Button(action: { isWake = true }) {
                Text("Wake")
            }
        }
        .sheet(isPresented: $isWake) {
            WakeView(host: host)
        }
    }
}

struct ContentView: View {
//    @Environment(\.modelContext) private var modelContext
//    @Query private var items: [WakeHost]
    
    @State var items: [WakeHost] = []
    
//    @State var isAdd = false
    
    @State var selectedItem: String?
    @State var error: Error?
    
    @State var geforce = KeystrokeApp()

    func loadItems() throws -> [WakeHost] {
        let docFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let docUrl = docFolder.appending(path: "wake.json")
        let data = try Data(contentsOf: docUrl)
        return try JSONDecoder().decode([WakeHost].self, from: data)
    }
    
    func reload() {
        do {
            items = try loadItems()
        } catch {
            self.error = error
        }
    }
    
    var body: some View {
        Group {
            if let err = error {
                Text(err.localizedDescription)
            } else {
                VStack {
                    NavigationSplitView {
                        List(items, selection: $selectedItem) { item in
                            Text(item.name)
                        }
                        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
                    } detail: {
                        if let sel = selectedItem {
                            WakeHostView(host: items.first(where: { $0.id == sel })!)
                        } else {
                            Text("Select an item")
                        }
                    }
                    HStack {
                        Circle().fill(geforce.isRunning ? .green : .red)
                            .frame(width: 15, height: 15)
                        Text("Geforce NOW")
                        Button(action: { if geforce.isRunning { geforce.stop() } else { geforce.start() } }) {
                            Text(geforce.isRunning ? "Stop": "Start")
                        }
                        Spacer()
                    }
                    .padding()
                }
                //        .sheet(isPresented: $isAdd) {
                //            WakeHostForm()
                //        }
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
                items = try loadItems()
                selectedItem = items.first?.id
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

