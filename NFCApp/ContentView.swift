//
//  ContentView.swift
//  NFCApp
//
//  Created by Javier Calatrava on 25/12/24.
//

import SwiftUI
import CoreNFC

struct ContentView: View {
    @StateObject private var nfcManager = appSingletons.nfcManager
    @State private var message2SaveInTag = ""
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("Mensaje to write in tag", text: $message2SaveInTag)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Read NFC") {
                Task {
                    await nfcManager.startReading()
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Button("Write NFC") {
                Task {
                    await nfcManager.startWriting(message: message2SaveInTag)
                }
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Text(nfcManager.tagMessage)
                .padding()
            
        }
    }
}

#Preview {
    ContentView()
}
