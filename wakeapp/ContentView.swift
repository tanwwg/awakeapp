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
            LabeledContent("Broadcast", value: host.broadcast)
            LabeledContent("Port", value: "\(host.port)")
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
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [WakeHost]
    
    @State var isAdd = false
    
    @State var selectedItem: PersistentIdentifier?

    var body: some View {
        NavigationSplitView {
            List(items, selection: $selectedItem) { item in
                Text(item.name)
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
            if let sel = selectedItem {
                WakeHostView(host: items.first(where: { $0.id == sel })!)
            } else {
                Text("Select an item")
            }
        }
        .sheet(isPresented: $isAdd) {
            WakeHostForm()
        }
        .onAppear {
            selectedItem = items.first?.id
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
