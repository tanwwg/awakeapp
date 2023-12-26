//
//  AddWakeHostForm.swift
//  wakeapp
//
//  Created by Tan Thor Jen on 26/12/23.
//

import SwiftUI
import SwiftData

struct ValidatingTextField: View {
    
    var label: String
    @Binding var text: String
    @Binding var isValid: Bool
    var prompt: String
        
    var validator: () -> Bool
    
    var body: some View {
        TextField(label, text: $text, prompt: Text(prompt))
            .onChange(of: text) {
                isValid = validator()
            }
            .foregroundStyle(isValid ? Color.primary : Color.red)
            .onAppear {
                isValid = validator()
            }
    }
    
}

struct WakeHostForm: View {
    @Environment(\.dismiss) var dismiss
    
    @Environment(\.modelContext) private var modelContext
    
    @State var name: String = ""
    @State var isNameValid = false
    
    @State var mac: String = ""
    @State var isMacValid = false

    @State var broadcast: String = "0.0.0.0"
    @State var isBroadcastValid = true
    
    @State var port: Int = 9
    
    func isValidMac(s: String) -> Bool {
        let regex = /^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$/
        if let _ = try? regex.wholeMatch(in: s) {
            return true
        } else {
            return false
        }
    }

    var body: some View {
        VStack {
            Text("Add Host")
                .font(.title)
            Form {
                ValidatingTextField(label: "Name", text: $name, isValid: $isNameValid, prompt: "Label (3 characters)") {
                    name.count >= 3
                }
                ValidatingTextField(label: "Mac", text: $mac, isValid: $isMacValid, prompt: "12:34:56:78:90:AB") {
                    isValidMac(s: mac)
                }
                
                ValidatingTextField(label: "Broadcast", text: $broadcast, isValid: $isBroadcastValid, prompt: "IP Address") {
                    inet_addr(broadcast) != INADDR_NONE
                }
                
                Stepper(value: $port, in: 1...255) {
                    Text("Port: \(port)")
                }
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                    }
                    Button(action: { 
                        modelContext.insert(WakeHost(name: name, mac: mac, broadcast: broadcast, port: port))
                        dismiss()
                    }) {
                        Text("OK")
                    }
                    .disabled(!isNameValid || !isBroadcastValid)
                }
            }
            .frame(width: 300)
        }
        .padding()
    }
}
