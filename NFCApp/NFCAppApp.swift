//
//  NFCAppApp.swift
//  NFCApp
//
//  Created by Javier Calatrava on 25/12/24.
//

import SwiftUI

@main
struct NFCAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                handleDeeplink(url: url)
            }
        }
    }

    func handleDeeplink(url: URL) {
        // Maneja el deeplink aquí
        print("Se abrió la app con el URL: \(url)")
    }
}
