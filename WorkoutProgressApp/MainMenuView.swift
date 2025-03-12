//
//  MainMenuView.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/26/25.
//

import SwiftUI
import CloudKit

struct MainMenuView: View {
    @State private var isAuthenticated: Bool = false
    
    @EnvironmentObject var blockManager: WorkoutBlockManager
    @EnvironmentObject var workoutViewModel: WorkoutViewModel
    
    @State private var showAddBlockSheet = false


    var body: some View {
            VStack(spacing: 0) {
                
                
                BlocksTabView()
                // Navigation link to the workouts list.
                NavigationLink(destination: AllWorkoutsListView()
) {
                    ZStack {
                        // Outer rectangle - base layer
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.gray.opacity(0.12))
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        
                        // Inner rectangle - top layer with subtle bulge effect
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color("NeomorphBG3").opacity(0.9))
                            .frame(maxWidth: 310, maxHeight: 48)
                            
                        // Text layer
                        Text("Workouts List")
                            .font(.system(size: 17, weight: .medium, design: .default))
                            .foregroundColor(Color.white)
                            .underline(false)

                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
.buttonStyle(.borderless)

                
     
                
                
                let defaultBlock = WorkoutBlock(
                     title: "Default Block"
                 )

                NavigationLink(
                    destination: MainAppView(
                        blockManager: blockManager,         // must be a WorkoutBlockManager
                        isAuthenticated: $isAuthenticated,  // must be a Binding<Bool>
                        block: defaultBlock                 // must be a WorkoutBlock? (optional)
                    )
                ) {
                    ZStack {
                        // Outer rectangle - base layer
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.gray.opacity(0.12))
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        
                        // Inner rectangle - top layer with subtle bulge effect
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color("NeomorphBG3").opacity(0.9))
                            .frame(maxWidth: 310, maxHeight: 48)
                            
                        // Text layer
                        Text("Rank Your Weight Class")
                            .font(.system(size: 17, weight: .medium, design: .default))
                            .foregroundColor(Color.white)
                            .underline(false)

                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderless)
    
                
                
                Spacer()
            }
            .padding()
            .navigationTitle("Main Menu")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: MembershipCardScannerView()) {
                        Image(systemName: "creditcard")
                            .font(.title2)
                    }
                }
            }

         
        
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color("NeomorphBG2"), Color("NeomorphBG2")]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}



#Preview {
    NavigationView {
        MainMenuView()
            .environmentObject(WorkoutViewModel())
            .environmentObject(WorkoutBlockManager.withSampleData())
    }
}

