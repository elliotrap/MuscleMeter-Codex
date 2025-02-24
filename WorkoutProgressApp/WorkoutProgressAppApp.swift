//
//  WorkoutProgressAppApp.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 1/18/25.
//

import SwiftUI

@main
struct WorkoutProgressApp: App {
    @State private var isLoading = true
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                if isLoading {
                    LoadingView()
                        .onAppear {
                            // Simulate load for 2 seconds, then continue
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isLoading = false
                            }
                        }
                } else {
                    ContentView()
                }
            }
        }
    }
}


