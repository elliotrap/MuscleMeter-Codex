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

struct CustomRoundedRectangle3: View {
    /// The fraction [0..1] controlling where the colored portion ends.
    /// (e.g., 0.2 means 20% tinted, 80% white)
    var progress: CGFloat = 0.2
    
    /// The user's current experience level
    var currentLevel: ExperienceLevel
    
    var cornerRadius: CGFloat = 10
    var width: CGFloat = 130
    var height: CGFloat = 130
    
    // ---------------------------------------------
    // 1) Same color logic for Noob..Elite..Freak
    // ---------------------------------------------
    fileprivate func colorForLevel(_ level: ExperienceLevel) -> (background: Color, foreground: Color) {
        switch level {
        case .noob:
            return (.red, .white)
        case .beginner:
            return (.yellow, .white)
        case .intermediate:
            return (.orange, .black)
        case .advanced:
            return (.blue, .white)
        case .elite:
            return (.green, .white)
        case .freak:
            // We won't actually use .red for freak
            // because we're going to override it with rainbow.
            return (.red, .red)
        }
    }
    
    var body: some View {
        
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .stroke(lineWidth: 5)
                .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                .frame(width: 145, height: 145)
            // 2) Get the normal bgColor for non-freak levels
            let (bgColor, _) = colorForLevel(currentLevel)
            
            
            ZStack {
                
                VStack {
                    Spacer()
                        .frame(height: 120)
                    // MARK: - The partial glow background
                    // This shape’s width is only up to `progress * width`
                    RoundedRectangle(cornerRadius: 50)
                        .fill(bgColor.opacity(0.55)) // tinted color
                        .frame(width: 150, height: 20 )
                    // Add a blur so it looks like a soft glow
                        .blur(radius: 10)
                        
                
                }
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: {
                                if currentLevel == .freak {
                                    // ------------------------------------------------
                                    // 3a) If freak => multiple stops for a rainbow
                                    //     from 0..progress, then white from progress..1
                                    // ------------------------------------------------
                                    return [
                                        .init(color: .red,    location: 0.00),
                                        .init(color: .blue, location: 0.40 * progress),
                                        .init(color: .green,  location: 0.60 * progress),
                                        
                                        // White portion (progress..1.0)
                                        .init(color: .white.opacity(0.14), location: progress),
                                        .init(color: .white.opacity(0.1),  location: 1.0)
                                    ]
                                    
                                } else {
                                    // ------------------------------------------------
                                    // 3b) Normal logic: single color -> white
                                    // ------------------------------------------------
                                    return [
                                        .init(color: bgColor.opacity(1), location: 0.0),
                                        .init(color: bgColor.opacity(0.3), location: progress),
                                        
                                        // White portion
                                        .init(color: Color("NeomorphBG3").opacity(0.6), location: progress),
                                        .init(color: Color("NeomorphBG3").opacity(0.3),  location: 1.0)
                                    ]
                                }
                            }()),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: width, height: 130)
            }
        }
    }
}
#Preview {
    LoadingView()

}
