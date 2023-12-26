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
    @State var text = "Sending..."
    
    var body: some View {
        VStack {
            Text(text)
                .padding()
        }
        .frame(width: 200, height: 200)
        .onAppear {
            let device = Awake.Device(MAC: host.mac, BroadcastAddr: host.broadcast, Port: UInt16(host.port))
            if let err = Awake.target(device: device) {
                text = err.localizedDescription
            } else {
                text = "Wake sent"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        }
        
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [WakeHost]
    
    @State var isAdd = false
    
    @State var isWake: PersistentIdentifier?

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Form {
                            LabeledContent("Mac", value: item.mac)
                            LabeledContent("Broadcast", value: item.broadcast)
                            LabeledContent("Port", value: "\(item.port)")
                            Button(action: { isWake = item.id }) {
                                Text("Wake")
                            }
                        }
                    } label: {
                        Text(item.name)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar {
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
        .sheet(isPresented: $isAdd) {
            WakeHostForm()
        }
        .sheet(item: $isWake) { id in
            WakeView(host: items.first(where: {$0.id == id})!)
        }
    }

    private func addItem() {
        isAdd = true
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WakeHost.self, inMemory: true)
}
