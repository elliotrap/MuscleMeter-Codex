//
//  CustomUI.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/12/25.
//
import SwiftUI


struct CustomRoundedRectangle: View {
    /// The fraction [0..1] controlling which color to pick from the multi-stop gradient
    var progressFraction: CGFloat = 0.0
    
    /// The portion [0..1] that gets tinted, e.g. 0.2 means
    /// the left segment is tinted, then the rest is white
    var progress: CGFloat = 0.2
    var currentLevel: ExperienceLevel
    var cornerRadius: CGFloat = 10
    var width: CGFloat = 340
    var height: CGFloat = 140
    
    

    // The same dramatic multi-stop gradient as in LiftProgressView
    private let dramaticMultiColorGradient = Gradient(stops: [
        Gradient.Stop(color: .red, location: 0.0),
        Gradient.Stop(color: .red, location:  78.999 / 315.0),
        Gradient.Stop(color: .purple,  location: 79.0 / 315.0),
        Gradient.Stop(color: .purple,  location: 157.999 / 315.0),
        Gradient.Stop(color: .blue,  location: 158.0 / 315.0),
        Gradient.Stop(color: .blue,  location: 235.999 / 315.0),
        Gradient.Stop(color: .green,   location: 236.0 / 315.0),
        Gradient.Stop(color: .green,   location: 315.0)
    ])
    
    var body: some View {
        let dynamicColor = dramaticMultiColorGradient.interpolatedColor(at: progressFraction)

        ZStack {
            RoundedRectangle(cornerRadius: 19)
                .stroke(lineWidth: 5)
                .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                .frame(width: 350, height: 149)

            ZStack {
                
                HStack {
                    // MARK: - The partial glow background
                    // This shape’s width is only up to `progress * width`
                    RoundedRectangle(cornerRadius: 50)
                        .fill(
                            currentLevel == .freak
                            ? AnyShapeStyle(
                                LinearGradient(
                                  gradient: Gradient(colors: [
                                    .red, .blue, .green
                                  ]),
                                  startPoint: .leading,
                                  endPoint: .trailing
                                ).opacity(0.35)
                              )
                            : AnyShapeStyle(dynamicColor.opacity(0.35))
                        )
                        .frame(width: 100, height: 150 )
                    // Add a blur so it looks like a soft glow
                        .blur(radius: 15)
                    Spacer()
                        .frame(width: 300)
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
                                        .init(color: .blue,  location: 0.50 * progress),
                                        .init(color: .green,   location: 0.90 * progress),
                                        
                                        // White portion (progress..1.0)
                                        .init(color: .white.opacity(0.14), location: progress),
                                        .init(color: .white.opacity(0.1),  location: 1.0)
                                    ]
                                    
                                } else {
                                    // ------------------------------------------------
                                    // 3b) Normal logic: single color -> white
                                    // ------------------------------------------------
                                    return [
                                        .init(color: dynamicColor.opacity(1), location: 0.0),
                                        .init(color: dynamicColor.opacity(0.4), location: progress),
                                        
                                        // White portion
                                        .init(color:  Color("NeomorphBG3").opacity(0.6), location: progress),
                                        .init(color: Color("NeomorphBG3").opacity(0.2),  location: 1.0)
                                    ]
                                }
                            }()),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width, height: 136)
            }
        }
    }
}




struct CustomRoundedRectangle2: View {
    /// The fraction [0..1] controlling where the colored portion ends
    /// (e.g., 0.2 => 20% tinted, 80% white).
    var progress: CGFloat = 0.2
    
    /// The user's current experience level
    var currentLevel: ExperienceLevel
    
    var cornerRadius: CGFloat = 10
    var width: CGFloat = 366
    var height: CGFloat = 130
    
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
            // We'll override with rainbow logic below,
            // but keep .red for placeholders if needed
            return (.red, .red)
        }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .stroke(lineWidth: 5)
                .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                .frame(width: 380, height: 129)
            
            // Normal (non-rainbow) base color for levels != freak
            let (bgColor, _) = colorForLevel(currentLevel)
            
            ZStack {
                VStack {
                    Spacer().frame(height: 120)
                    
                    // MARK: - The partial glow background
                    // Here, you can also switch to a rainbow if freak:
                    RoundedRectangle(cornerRadius: 50)
                        .fill(
                            currentLevel == .freak
                            ? AnyShapeStyle(
                                LinearGradient(
                                  gradient: Gradient(colors: [
                                    .red, .orange, .yellow, .green, .blue, .purple
                                  ]),
                                  startPoint: .leading,
                                  endPoint: .trailing
                                )
                              )
                            : AnyShapeStyle(bgColor.opacity(0.65))
                        )
                        .frame(width: 390, height: 20)
                        .blur(radius: 30)
                }
                
                // The main “accent rectangle”
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: {
                                if currentLevel == .freak {
                                    // ------------------------------------------------
                                    // Freak => full rainbow from 0..progress,
                                    // then white(ish) from progress..1
                                    // ------------------------------------------------
                                    return [
                                        // Rainbow portion (compressed to 0..progress):
                                        .init(color: .red,    location: 0.00),
                                        .init(color: .blue, location: 0.60 * progress),
                                        .init(color: .green,  location: 1 * progress),
                                        
                                  
                                        // White(ish) portion (progress..1):
                                        .init(color: .white.opacity(0.14), location: progress),
                                        .init(color: .white.opacity(0.10), location: 1.0)
                                    ]
                                } else {
                                    // ------------------------------------------------
                                    // Normal logic: single color (0..progress) -> white (progress..1)
                                    // ------------------------------------------------
                                    return [
                                        .init(color: bgColor.opacity(1),   location: 0.0),
                                        .init(color: bgColor.opacity(0.3), location: progress),
                                        
                                        // White portion
                                        .init(color: Color("NeomorphBG3").opacity(0.6), location: progress),
                                        .init(color: Color("NeomorphBG3").opacity(0.3), location: 1.0)
                                    ]
                                }
                            }()),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: width, height: 116)
            }
        }
    }
}


struct ExerciseCustomRoundedRectangle: View {
    var progressFraction: CGFloat = 0.0
    var progress: CGFloat = 0.2
    var currentLevel: ExperienceLevel
    var cornerRadius: CGFloat = 10
    var width: CGFloat = 340
    var height: CGFloat = 140
    
    private let dramaticMultiColorGradient = Gradient(stops: [
        Gradient.Stop(color: .red, location: 0.0),
        Gradient.Stop(color: .red, location:  78.999 / 315.0),
        Gradient.Stop(color: .purple,  location: 79.0 / 315.0),
        Gradient.Stop(color: .purple,  location: 157.999 / 315.0),
        Gradient.Stop(color: .blue,  location: 158.0 / 315.0),
        Gradient.Stop(color: .blue,  location: 235.999 / 315.0),
        Gradient.Stop(color: .green,   location: 236.0 / 315.0),
        Gradient.Stop(color: .green,   location: 315.0)
    ])
    
    var body: some View {
        let dynamicColor = dramaticMultiColorGradient.interpolatedColor(at: progressFraction)
        
        ZStack {
            // 1) Outer stroke shape
            RoundedRectangle(cornerRadius: cornerRadius + 9)
                .stroke(lineWidth: 5)
                .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                // Slightly larger than the main shape
                .frame(width: width + 10, height: height + 9)
            
            ZStack {
                // 2) Partial glow background (left side)
                HStack {
                    // You can decide how wide you want the glow to be
                    RoundedRectangle(cornerRadius: cornerRadius * 3)
                        .fill(
                            currentLevel == .freak
                            ? AnyShapeStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.red, .blue, .green]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ).opacity(0.35)
                            )
                            : AnyShapeStyle(dynamicColor.opacity(0.35))
                        )
                        .frame(width: progress * (width * 0.3), height: height)
                        .blur(radius: 15)
                    
                    Spacer()
                }
                
                // 3) Main gradient shape
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: {
                                if currentLevel == .freak {
                                    // Rainbow logic
                                    return [
                                        .init(color: .red,  location: 0.00),
                                        .init(color: .blue, location: 0.50 * progress),
                                        .init(color: .green, location: 0.90 * progress),
                                        
                                        // White portion
                                        .init(color: .white.opacity(0.14), location: progress),
                                        .init(color: .white.opacity(0.1),  location: 1.0)
                                    ]
                                } else {
                                    // Single color -> white logic
                                    return [
                                        .init(color: dynamicColor.opacity(1),   location: 0.0),
                                        .init(color: dynamicColor.opacity(0.4), location: progress),
                                        .init(color: Color("NeomorphBG3").opacity(0.6), location: progress),
                                        .init(color: Color("NeomorphBG3").opacity(0.2), location: 1.0)
                                    ]
                                }
                            }()),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width, height: height)
            }
        }
    }
}
