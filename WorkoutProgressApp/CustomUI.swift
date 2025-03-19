//
//  CustomUI.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/12/25.
//
import SwiftUI
import Combine




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


/// A rectangle shape with individually rounded corners.
struct CustomRoundedRectangle4: Shape {
    var topLeftRadius: CGFloat = 0
    var topRightRadius: CGFloat = 0
    var bottomLeftRadius: CGFloat = 0
    var bottomRightRadius: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let w = rect.size.width
        let h = rect.size.height
        
        // Ensure radii do not exceed half the rectangle’s dimensions
        let tr = min(topRightRadius, min(w, h))
        let tl = min(topLeftRadius, min(w, h))
        let bl = min(bottomLeftRadius, min(w, h))
        let br = min(bottomRightRadius, min(w, h))
        
        var path = Path()

        // Start at top-left, move right to the beginning of the top-right curve
        path.move(to: CGPoint(x: tl, y: 0))
        
        // Top edge (straight line) + top-right corner
        path.addLine(to: CGPoint(x: w - tr, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: w, y: tr),
            control: CGPoint(x: w, y: 0)
        )
        
        // Right edge (straight line) + bottom-right corner
        path.addLine(to: CGPoint(x: w, y: h - br))
        path.addQuadCurve(
            to: CGPoint(x: w - br, y: h),
            control: CGPoint(x: w, y: h)
        )
        
        // Bottom edge (straight line) + bottom-left corner
        path.addLine(to: CGPoint(x: bl, y: h))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: h - bl),
            control: CGPoint(x: 0, y: h)
        )
        
        // Left edge (straight line) + top-left corner
        path.addLine(to: CGPoint(x: 0, y: tl))
        path.addQuadCurve(
            to: CGPoint(x: tl, y: 0),
            control: CGPoint(x: 0, y: 0)
        )
        
        return path
    }
}

struct ExerciseCustomRoundedRectangle: View {
    var progress: CGFloat = 0.5
    var accentColor: Color = .blue
    var cornerRadius: CGFloat = 10
    var width: CGFloat = 340
    var height: CGFloat = 140
    
    var body: some View {
        
        ZStack {
            VStack {
    
                // MARK: - The partial glow background
                HStack {
                    RoundedRectangle(cornerRadius: 50)
                        .fill(
                            AnyShapeStyle(accentColor.opacity(0.65))
                        )
                        .frame(width: 55, height: height)
                        .blur(radius: 20)
                    
                    Spacer().frame(height: 300)
                }
            }
            ZStack {
                // Outline stroke
                RoundedRectangle(cornerRadius: cornerRadius + 9)
                    .stroke(lineWidth: 5)
                    .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                    .frame(width: width + 15, height: height + 15)
                
         
                
                // Main accent rectangle
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: accentColor,              location: 0.03),
                                .init(color: accentColor.opacity(0.3), location: 0.015),
                                .init(color: Color("NeomorphBG3").opacity(0.6), location: progress),
                                .init(color: Color("NeomorphBG3").opacity(0.2), location: 1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width, height: height)
                
            }
        }
    }
}

struct WorkoutCustomRoundedRectangle: View {
    /// The fraction [0..1] controlling how much of the rectangle is tinted vs. lighter.
    var progress: CGFloat = 0.5
    
    /// The user-selected color for accenting this rectangle.
    var accentColor: Color = .blue
    
    var cornerRadius: CGFloat = 10
    var width: CGFloat = 366
    var height: CGFloat = 116
    
    var body: some View {
        ZStack {
            
            // MARK: - The partial glow background
            VStack {
                Spacer().frame(height: 100)

                RoundedRectangle(cornerRadius: 50)
                    .fill(
                        AnyShapeStyle(accentColor.opacity(0.35))
                    )
                    .frame(width: width + 50, height: 55)
                    .blur(radius: 20)
                
            }
            // Outline shape
            RoundedRectangle(cornerRadius: 20)
                .stroke(lineWidth: 5)
                .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                .frame(width: width + 13, height: height + 13)
            
            // Glow behind the rectangle (optional)
      
                Spacer().frame(height: 120)
                RoundedRectangle(cornerRadius: 50)
                    .fill(accentColor.opacity(0.65))
                    .frame(width: width, height: 0)
                    .blur(radius: 30)
            
            
            // Main accent rectangle
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            // 0..progress: accent color
                            .init(color: accentColor,              location: 0.08),
                            .init(color: accentColor.opacity(0.3), location: progress),
                            
                            // progress..1: “NeomorphBG3” to lighten the top portion
                            .init(color: Color("NeomorphBG3").opacity(0.6), location: progress),
                            .init(color: Color("NeomorphBG3").opacity(0.3), location: 1.0)
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: width, height: height)
        }
    }
}

struct BlockCustomRoundedRectangle: View {
    /// The fraction [0..1] controlling how much of the rectangle is tinted vs. lighter.
    var progress: CGFloat = 0.07
    
    /// The user-selected color for accenting this rectangle.
    var accentColor: Color = .blue
    
    var cornerRadius: CGFloat = 30
    var width: CGFloat = 266
    var height: CGFloat = 266
    
    var body: some View {
        ZStack {
            // Outline shape
            RoundedRectangle(cornerRadius: 30)
                .stroke(lineWidth: 5)
                .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                .frame(width: width + 20, height: height + 20)
            
            // Glow behind the rectangle (optional)
      
             VStack {
                 Spacer().frame(height: 250)

                RoundedRectangle(cornerRadius: 50)
                    .fill(
                        AnyShapeStyle(accentColor.opacity(0.65))
                    )
                    .frame(width: width + 70, height: 35)
                    .blur(radius: 30)
                
            }
            
            
            // Main accent rectangle
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            // 0..progress: accent color
                            .init(color: accentColor,              location: 0.00),
                            .init(color: accentColor.opacity(0.3), location: progress),
                            
                            // progress..1: “NeomorphBG3” to lighten the top portion
                            .init(color: Color("NeomorphBG3").opacity(0.6), location: progress),
                            .init(color: Color("NeomorphBG3").opacity(0.3), location: 1.0)
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: width, height: height)
        }
    }
}
struct WeightField: View {
    let exercise: Exercise
    let index: Int
    let evm: ExerciseViewModel
    @FocusState private var isFocused: Bool  // Focus for this field
    
    // Local state to hold the current text value.
    @State private var localText: String = ""
    // Track whether we've initialized the field to prevent automatic updates
    @State private var hasInitialized: Bool = false
    // A debouncing work item.
    @State private var debouncedWorkItem: DispatchWorkItem?

    // A NumberFormatter to display the weight correctly.
    private let formatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2 // Adjust as needed
        return nf
    }()

    var body: some View {
        TextField(
            "lbs",
            text: $localText
        )
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.center)      // Centers the text horizontally
        .padding(.vertical, 4)               // Some vertical padding inside the field
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.black).opacity(0.2))
        )
        .foregroundColor(.white).opacity(0.8)
        .frame(width: 50)
        .focused($isFocused)  // <-- We'll track focus
        .onAppear {
            // Initialize the text field with the current weight, but only once
            if !hasInitialized {
                let weight = exercise.setWeights[index]
                localText = weight == 0 ? "" : (formatter.string(from: NSNumber(value: weight)) ?? "")
                hasInitialized = true
            }
        }
        // Only update when the text changes due to user input, not during rendering
        .onChange(of: localText) { newValue in
            // Only proceed if we've been initialized
            guard hasInitialized else { return }
            
            // Cancel any pending update.
            debouncedWorkItem?.cancel()
            
            // Create a new work item for the update.
            let workItem = DispatchWorkItem {
                // Convert the string to a double and update CloudKit.
                if newValue.isEmpty {
                    updateWeightValueIfChanged(for: exercise, at: index, newWeight: 0)
                } else if let weightValue = Double(newValue) {
                    updateWeightValueIfChanged(for: exercise, at: index, newWeight: weightValue)
                }
            }
            debouncedWorkItem = workItem
            
            // Schedule the update after a 0.5-second delay.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }
        // Update when focus is lost to ensure changes are saved
        .onChange(of: isFocused) { focused in
            if !focused {
                // Focus was lost, update if needed
                debouncedWorkItem?.cancel() // Cancel any pending debounced update
                
                if let weightValue = Double(localText) {
                    updateWeightValueIfChanged(for: exercise, at: index, newWeight: weightValue)
                } else if localText.isEmpty {
                    updateWeightValueIfChanged(for: exercise, at: index, newWeight: 0)
                }
            }
        }
    }

    // Only update if the value actually changed
    private func updateWeightValueIfChanged(for exercise: Exercise, at index: Int, newWeight: Double) {
        guard let recordID = exercise.recordID else { return }
        
        // Check if the value has actually changed to avoid unnecessary updates
        if abs(exercise.setWeights[index] - newWeight) > 0.001 { // Use a small epsilon for floating point comparison
            // Copy the current weights and update only the specified index.
            var updatedWeights = exercise.setWeights
            updatedWeights[index] = newWeight
            
            // Call the CloudKit update method.
            evm.updateExercise(recordID: recordID, newWeights: updatedWeights)
        }
    }
}


struct ActualRepsField: View {
    let exercise: Exercise
    let index: Int
    let evm: ExerciseViewModel
    
    @Binding var isTextFieldVisible: Bool
    @FocusState private var isFocused: Bool
    @State private var localText: String = ""
    
    // Track whether we've initialized the field to prevent automatic updates
    @State private var hasInitialized: Bool = false
    @State private var debouncedWorkItem: DispatchWorkItem?
    
    var body: some View {
        HStack(spacing: 2) {
            Text("(")
                .foregroundColor(.white).opacity(0.8)
            
            TextField("", text: $localText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(.black).opacity(0.2))
                )
                .foregroundColor(.white).opacity(0.8)
                .frame(width: 25)
                .focused($isFocused)
                        
            Text(")")
                .foregroundColor(.white).opacity(0.8)
        }
        .onAppear {
            // Initialize the field with the current reps, but only once
            if !hasInitialized {
                let reps = exercise.setActualReps[index]
                localText = reps == 0 ? "" : String(reps)
                hasInitialized = true
            }
        }
        // Only update when the text changes due to user input
        .onChange(of: localText) { newValue in
            // Only proceed if we've been initialized
            guard hasInitialized else { return }
            
            // Cancel any pending update
            debouncedWorkItem?.cancel()
            
            // Create a new work item for the update
            let workItem = DispatchWorkItem {
                // Convert the string to an int and update CloudKit
                if newValue.isEmpty {
                    updateActualReps(for: exercise, at: index, newReps: 0)
                } else if let repsValue = Int(newValue) {
                    updateActualReps(for: exercise, at: index, newReps: repsValue)
                }
            }
            debouncedWorkItem = workItem
            
            // Schedule the update after a 0.5-second delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }
        // Update when focus is lost and handle plus icon visibility
        .onChange(of: isFocused) { focused in
            if !focused {
                // Focus was lost, update if needed
                debouncedWorkItem?.cancel() // Cancel any pending debounced update
                
                if let repsValue = Int(localText) {
                    updateActualReps(for: exercise, at: index, newReps: repsValue)
                } else if localText.isEmpty {
                    updateActualReps(for: exercise, at: index, newReps: 0)
                    isTextFieldVisible = false // Revert to plus icon when empty
                }
            }
        }
    }
    
    // Only update if the value has actually changed
    private func updateActualReps(for exercise: Exercise, at index: Int, newReps: Int) {
        guard let recordID = exercise.recordID else { return }
        
        // Check if the value has actually changed
        if exercise.setActualReps[index] != newReps {
            // Copy the current reps and update only the specified index
            var updatedReps = exercise.setActualReps
            updatedReps[index] = newReps
            
            // Call the CloudKit update method
            evm.updateExercise(recordID: recordID, newActualReps: updatedReps)
        }
    }
}


    struct SetsField: View {
        let exercise: Exercise
        let evm: ExerciseViewModel
        private let maxSets: Int = 15
        private let minSets: Int = 1
        
        // Use StateObject for persistent state across view updates
        @StateObject private var fieldState = NumericFieldState()
        @State private var isInitialized = false
        
        // Keep focus state local to prevent cascading updates
        @FocusState private var isFocused: Bool
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Sets:")
                        .foregroundColor(.white.opacity(0.8))
                    TextField("Sets", text: $fieldState.text)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.black.opacity(0.2))
                        )
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 60)
                        .focused($isFocused)
                        .onChange(of: fieldState.text) { newValue in
                            if isInitialized {
                                fieldState.validate(
                                    value: newValue,
                                    minValue: minSets,
                                    maxValue: maxSets,
                                    exercise: exercise,
                                    evm: evm,
                                    updateField: { viewModel, recordID, newSets in
                                        // Only update if value changed
                                        if newSets != exercise.sets {
                                            // Use the "quiet" update method
                                            viewModel.updateExerciseWithoutRefresh(
                                                recordID: recordID,
                                                newSets: newSets
                                            )
                                        }
                                    }
                                )
                            }
                        }
                }
                .background(
                    // Simplified background to avoid gradient issues
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color("NeomorphBG2").opacity(0.6))
                        .frame(width: 156, height: 60)
                )
                
                // Display error message if one exists
                if let errorMessage = fieldState.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .onAppear {
                // Initialize once to prevent duplicate updates
                if !isInitialized {
                    fieldState.text = exercise.sets == 0 ? "" : String(exercise.sets)
                    // Use a slight delay to mark as initialized
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isInitialized = true
                    }
                }
            }
            // Add a stable identity to this view
            .id("Exercise-\(exercise.id)-SetsField")
            // Add a toolbar with Done button for numeric keyboard
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isFocused = false
                    }
                }
            }
        }
    }

    // Also create a matching RepsField implementation
    struct RepsField: View {
        let exercise: Exercise
        let evm: ExerciseViewModel
        private let maxReps: Int = 100
        private let minReps: Int = 1
        
        // Use StateObject for persistent state across view updates
        @StateObject private var fieldState = NumericFieldState()
        @State private var isInitialized = false
        
        // Keep focus state local to prevent cascading updates
        @FocusState private var isFocused: Bool
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Reps:")
                        .foregroundColor(.white.opacity(0.8))
                    TextField("Reps", text: $fieldState.text)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.black.opacity(0.2))
                        )
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 60)
                        .focused($isFocused)
                        .onChange(of: fieldState.text) { newValue in
                            if isInitialized {
                                fieldState.validate(
                                    value: newValue,
                                    minValue: minReps,
                                    maxValue: maxReps,
                                    exercise: exercise,
                                    evm: evm,
                                    updateField: { viewModel, recordID, newReps in
                                        // Only update if value changed
                                        if newReps != exercise.reps {
                                            // Use the "quiet" update method
                                            viewModel.updateExerciseWithoutRefresh(
                                                recordID: recordID,
                                                newReps: newReps
                                            )
                                        }
                                    }
                                )
                            }
                        }
                }
                .background(
                    // Simplified background to avoid gradient issues
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color("NeomorphBG2").opacity(0.6))
                        .frame(width: 156, height: 60)
                )
                
                // Display error message if one exists
                if let errorMessage = fieldState.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .onAppear {
                // Initialize once to prevent duplicate updates
                if !isInitialized {
                    fieldState.text = exercise.reps == 0 ? "" : String(exercise.reps)
                    // Use a slight delay to mark as initialized
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isInitialized = true
                    }
                }
            }
            // Add a stable identity to this view
            .id("Exercise-\(exercise.id)-RepsField")
            // Add a toolbar with Done button for numeric keyboard
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isFocused = false
                    }
                }
            }
        }
    }
struct WorkoutNameField: View {
    let workout: WorkoutModel
    let evm: WorkoutViewModel
    @FocusState private var isFocused: Bool  // Focus for this field

    // Local state for the text field's current value
    @State private var localText: String = ""
    @State private var isEditing: Bool = false
    
    var body: some View {
        HStack {
            Text("Name:")
                .foregroundColor(.white).opacity(0.8)
            
           
                    TextField("Workout Name", text: $localText)
                    
                        .multilineTextAlignment(.center)      // Centers the text horizontally
                        .padding(.vertical, 4)               // Some vertical padding inside the field
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color(.black).opacity(0.2))
                        )
                        .foregroundColor(.white).opacity(0.8)
                        .frame(width: 50)
                        .frame(width: 60)
                        .focused($isFocused)  // <-- We'll track focus

                    }
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(lineWidth: 5)
                                .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                                .frame(width: 156, height: 60)
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color("NeomorphBG2").opacity(0.6),
                                                Color("NeomorphBG2").opacity(0.6)
                                            ]),
                                            startPoint: .bottom,
                                            endPoint: .topTrailing
                                        )
                                    )
                                    .frame(width: 143, height: 46)
                            }
                        }
                    )
        .onAppear {
            // Initialize the text field with the current workout name
            localText = workout.name
        }
    }
}

struct ExerciseNameField: View {
    let exercise: Exercise
    let evm: ExerciseViewModel
    
    // IMPORTANT: Use @StateObject for a publisher that persists across view updates
    @StateObject private var textState = TextFieldState()
    
    // Track if initialization is complete
    @State private var isInitialized = false
    
    var body: some View {
        HStack {
            Text("Name:")
                .foregroundColor(.white.opacity(0.8))
            
            TextField("Exercise Name", text: $textState.text)
                .multilineTextAlignment(.center)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.black.opacity(0.2))
                )
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 200)
                // Key improvement: Disable autocorrection that can cause focus issues
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                // Make sure changes don't affect the view hierarchy
                .onChange(of: textState.text) { newValue in
                    if isInitialized {
                        // Instead of updating directly, schedule an update
                        textState.scheduleUpdate(newText: newValue, exercise: exercise, evm: evm)
                    }
                }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color("NeomorphBG2").opacity(0.6))
                .frame(width: 286, height: 60)
        )
        .onAppear {
            // Only initialize once
            if !isInitialized {
                textState.text = exercise.name
                
                // Mark initialization complete after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInitialized = true
                }
            }
        }
        // THIS IS IMPORTANT: Prevent focus changes from cascading to parent view
        .id("Exercise-\(exercise.id)-NameField")
        .allowsHitTesting(true)
    }
}


#Preview {
    WorkoutCustomRoundedRectangle()
}
