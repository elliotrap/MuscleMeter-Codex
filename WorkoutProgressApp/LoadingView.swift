//
//  LoadingView.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 1/27/25.
//

import SwiftUI

struct LoadingView: View {
    // State to control the rotation animation
    @State private var isAnimating = false
    
    var body: some View {
        VStack {
            ZStack {
                // MARK: - Background
                Color("NeomorphBG2")
                    .edgesIgnoringSafeArea(.all)
                
                // MARK: - Central Circle
                CustomRoundedRectangle3(progress: 0.09, currentLevel: .elite)
                    .overlay(
                        VStack(spacing: 0) {
                            Text("Muscle")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(.white).opacity(0.8))
                            Text("Meter")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(.white).opacity(0.8))
                        }
                    )
                // MARK: - Rotating Spinner
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color("NeomorphBG2"), Color("NeomorphBG3")]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(
                            .linear(duration: 1.2)
                            .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                        .padding(.top, 300)
                }
            }
            
            .onAppear {
                // Start the animation when the view appears
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    
        }
    }
}

#Preview {
    LoadingView()

}
