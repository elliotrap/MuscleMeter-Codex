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
    
   @ObservedObject var blockManager = WorkoutBlockManager()

    @State private var showAddBlockSheet = false


    var body: some View {
            VStack(spacing: 30) {
                BlocksTabView()
                // Navigation link to the workouts list.
                NavigationLink(destination: AllWorkoutsListView()
) {
                    Text("Workouts List")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color("NeomorphBG2").opacity(1),
                                    Color("NeomorphBG2").opacity(0.5)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
     
                
                
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
                    Text("Rank Your Weight Class")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color("NeomorphBG2").opacity(1),
                                    Color("NeomorphBG2").opacity(0.5)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        
                        )
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
    
                
                
                Spacer()
            }
            .padding()
            .navigationTitle("Main Menu")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: MembershipCardScannerView()) {
                        Image(systemName: "creditcard")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddBlockSheet) {
                AddBlockView(blockManager: blockManager)
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

        MainMenuView()
    }

