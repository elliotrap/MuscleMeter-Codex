//
//  WorkoutProgressAppApp.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 1/18/25.
//

import SwiftUI

@main
struct WorkoutProgressApp: App {
    // Use sample data in DEBUG mode, empty in production
    #if DEBUG
    @StateObject var blockManager = WorkoutBlockManager.withSampleData()
    #else
    @StateObject var blockManager = WorkoutBlockManager()
    #endif
    
    @StateObject var workoutViewModel = WorkoutViewModel()
    @State private var isLoading = true
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                if isLoading {
                    LoadingView()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isLoading = false
                            }
                        }
                } else {
                    ContentView()
                        .onAppear {
                            blockManager.fetchBlocks()
                        }
                }
            }
            .environmentObject(blockManager)
            .environmentObject(workoutViewModel)
        }
    }
}

// Add this extension to your WorkoutBlockManager
extension WorkoutBlockManager {
    static func withSampleData() -> WorkoutBlockManager {
        let manager = WorkoutBlockManager()
        manager.blocks = [
            WorkoutBlock(title: "Heavy"),
            WorkoutBlock(title: "Moderate"),
            WorkoutBlock(title: "Light")
        ]
        return manager
    }
}


