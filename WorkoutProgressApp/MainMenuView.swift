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
    @State private var selectedOneRM: Double?

    @EnvironmentObject var blockManager: WorkoutBlockManager
    @EnvironmentObject var workoutViewModel: WorkoutViewModel
    
    @State private var showAddBlockSheet = false


    var body: some View {
        ZStack {
            // 1. True BG at Root
            LinearGradient(
                gradient: Gradient(colors: [Color("NeomorphBG2"), Color("NeomorphBG2")]),
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 2. Top AppBar area (custom nav-like)
                HStack {
                    Text("Blocks")
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.leading, 20)
                        .padding(.top, 50)
                    Spacer()
                    NavigationLink(destination: MembershipCardScannerView()
                        .navigationBarBackButtonHidden(true)
                        .trackNavigation("Membership Card Scanner View")
                    ) {
                        Image(systemName: "creditcard")
                            .font(.title2)
                            .foregroundColor(Color.blue)
                            .padding(.trailing, 18)
                            .padding(.top, 50)

                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 156) // Responsive height—tune as needed
                .background(
                    Color("NeomorphBG5")
                        .opacity(0.6)
                        .blur(radius: 0.5)
                        .shadow(color: .black.opacity(0.33), radius: 10, x: 0, y: 8)
                )
                .overlay(
                    Rectangle()
                        .fill(Color.black.opacity(0.30))
                        .frame(height: 2),
                    alignment: .bottom
                )
                // Padding so content never is squeezed at the top
                .padding(.top, UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0)

                // 3. Main Content Below AppBar
                VStack(spacing: 16) {
                    BlocksTabView()
                    // --- your beautiful nav buttons as before ---
                    NavigationLink(destination:
                        AllWorkoutsListView()
                            .navigationBarBackButtonHidden(true)
                            .trackNavigation("All Workouts List View")
                    ) {
                        Text("Workouts List")
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(NeumorphicButtonStyle(accent: Color("NeomorphBG5")))
                    .padding(.horizontal, 18)
                    
                    let defaultBlock = WorkoutBlock(
                         title: "Default Block"
                     )
                    
                    NavigationLink(destination: MainAppView(blockManager: blockManager, isAuthenticated: $isAuthenticated, block: defaultBlock)
                        .navigationBarBackButtonHidden(true)
                        .trackNavigation("Main App View")
                    ) {
                        Text("Rank Your Weight Class")
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(NeumorphicButtonStyle(accent: Color("NeomorphBG5")))
                    .padding(.horizontal, 18)
                    
                    NavigationLink(destination: NewOneRepMaxCalculatorView()) {
                        Text("One Rep Max Calculator")
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(NeumorphicButtonStyle(accent: Color("NeomorphBG5")))
                    .padding(.horizontal, 18)            }
                .padding(.top, 10) // Give it a nudge down to accommodate nav bar height
                }
                .padding(.bottom, 190)
                
                Spacer(minLength: 0)
            
        }
    
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: MembershipCardScannerView() /* ... */) {
                    Image(systemName: "creditcard")
                        .font(.title2)
                }
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color("NeomorphBG2"), Color("NeomorphBG2")]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}


struct NeumorphicButtonStyle: ButtonStyle {
    var accent: Color = Color("NeomorphBG3")
    var highlight: Color = Color.white.opacity(0.12)
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                ZStack {
                    // Soft background glow
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(accent)
                        .shadow(color: Color.black.opacity(0.16), radius: 6, x: 0, y: 4)
                    
                    // “Glassy” highlight
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(highlight, lineWidth: 1.2)
                        .blur(radius: 1.2)
                        .offset(y: -2)
                        .opacity(configuration.isPressed ? 0.07 : 0.13)
                    
                    // “Pressed” overlay
                    if configuration.isPressed {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.13), value: configuration.isPressed)
    }
}
struct NewOneRepMaxCalculatorView: View {
    @State private var weight: String = ""
    @State private var reps: String = ""
    @State private var oneRepMax: Double?
    
    var body: some View {
        ZStack {
            Color(red: 35/255, green: 36/255, blue: 49/255)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Text("One Rep Max Calculator")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 30)
                
                VStack(spacing: 20) {
                    CustomTextField(placeholder: "Weight Lifted (kg/lb)", text: $weight)
                    CustomTextField(placeholder: "Number of Reps", text: $reps)
                }
                
                Button(action: calculateOneRepMax) {
                    Text("Calculate")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(20)
                }
                .padding(.horizontal)
                
                if let result = oneRepMax {
                    Text("Estimated 1RM: \(result, specifier: "%.1f")")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.top)
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    func calculateOneRepMax() {
        guard let weightValue = Double(weight),
              let repsValue = Double(reps),
              repsValue > 0 else {
            oneRepMax = nil
            return
        }
        // Epley's formula: 1RM = weight * (1 + reps/30)
        oneRepMax = weightValue * (1 + repsValue/30)
    }
}

struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad)
            .padding()
            .background(Color(.systemGray6).opacity(0.2))
            .foregroundColor(.white)
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .font(.headline)
    }
}

#Preview {
    NavigationView {
        MainMenuView()
            .environmentObject(WorkoutViewModel())
            .environmentObject(WorkoutBlockManager.withSampleData())
    }
}

