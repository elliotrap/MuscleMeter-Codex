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
    var progress: CGFloat = 0.5
    var accentColor: Color = .blue
    var cornerRadius: CGFloat = 10
    var width: CGFloat = 340
    var height: CGFloat = 140
    
    var body: some View {
        ZStack {
            // Outline stroke
            RoundedRectangle(cornerRadius: cornerRadius + 9)
                .stroke(lineWidth: 5)
                .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                .frame(width: width + 15, height: height + 15)
            
            // Partial glow on the left side
            HStack {
                RoundedRectangle(cornerRadius: cornerRadius * 3)
                    .fill(accentColor.opacity(0.65))
                    .frame(width: progress * (width * 0.3), height: height)
                    .blur(radius: 15)
                Spacer()
            }
            
            // Main accent rectangle
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: accentColor,              location: 0.0),
                            .init(color: accentColor.opacity(0.3), location: progress),
                            .init(color: Color("NeomorphBG3").opacity(0.6), location: progress),
                            .init(color: Color("NeomorphBG3").opacity(0.3), location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: height)
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
    var height: CGFloat = 130
    
    var body: some View {
        ZStack {
            // Outline shape
            RoundedRectangle(cornerRadius: 14)
                .stroke(lineWidth: 5)
                .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                .frame(width: 380, height: 129)
            
            // Glow behind the rectangle (optional)
            VStack {
                Spacer().frame(height: 120)
                RoundedRectangle(cornerRadius: 50)
                    .fill(accentColor.opacity(0.65))
                    .frame(width: 390, height: 20)
                    .blur(radius: 30)
            }
            
            // Main accent rectangle
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            // 0..progress: accent color
                            .init(color: accentColor,              location: 0.0),
                            .init(color: accentColor.opacity(0.3), location: progress),
                            
                            // progress..1: “NeomorphBG3” to lighten the top portion
                            .init(color: Color("NeomorphBG3").opacity(0.6), location: progress),
                            .init(color: Color("NeomorphBG3").opacity(0.3), location: 1.0)
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: width, height: 116)
        }
    }
}


struct WeightField: View {
    let exercise: Exercise
    let index: Int
    let evm: ExerciseViewModel

    // Local state to hold the current text value.
    @State private var localText: String = ""
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
            "",
            text: $localText
        )
        .keyboardType(.decimalPad)
        .foregroundColor(.white)
        .onAppear {
            // Initialize the text field with the current weight.
            let weight = exercise.setWeights[index]
            localText = weight == 0 ? "" : (formatter.string(from: NSNumber(value: weight)) ?? "")
        }
        .onChange(of: localText) { newValue in
            // Cancel any pending update.
            debouncedWorkItem?.cancel()
            
            // Create a new work item for the update.
            let workItem = DispatchWorkItem {
                // Convert the string to a double and update CloudKit.
                if newValue.isEmpty {
                    updateWeightValue(for: exercise, at: index, newWeight: 0)
                } else if let weightValue = Double(newValue) {
                    updateWeightValue(for: exercise, at: index, newWeight: weightValue)
                }
            }
            debouncedWorkItem = workItem
            
            // Schedule the update after a 0.5-second delay.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }
    }

    private func updateWeightValue(for exercise: Exercise, at index: Int, newWeight: Double) {
        guard let recordID = exercise.recordID else { return }
        
        // Copy the current weights and update only the specified index.
        var updatedWeights = exercise.setWeights
        updatedWeights[index] = newWeight
        
        // Call the CloudKit update method.
        evm.updateExercise(recordID: recordID, newWeights: updatedWeights)
    }
}


struct ActualRepsField: View {
    let exercise: Exercise
    let index: Int
    let evm: ExerciseViewModel

    // Local state for the text field's current value.
    @State private var localText: String = ""
    // A debouncing work item to delay updates.
    @State private var debouncedWorkItem: DispatchWorkItem?

    var body: some View {
        HStack(spacing: 5) {
            Text("(")
            TextField(
                "",
                text: $localText
            )
            .keyboardType(.numberPad)
            .foregroundColor(.white)
            .frame(width: 23)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        // Dismiss the keyboard.
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            Text(")")
        }
        .onAppear {
            // Initialize the text field with the current reps value.
            let reps = exercise.setActualReps[index]
            localText = reps == 0 ? "" : String(reps)
        }
        .onChange(of: localText) { newValue in
            // Cancel any previously scheduled update.
            debouncedWorkItem?.cancel()
            
            // Create a new work item to update the reps value.
            let workItem = DispatchWorkItem {
                if newValue.isEmpty {
                    updateActualReps(for: exercise, at: index, newReps: 0)
                } else if let repsValue = Int(newValue) {
                    updateActualReps(for: exercise, at: index, newReps: repsValue)
                }
            }
            debouncedWorkItem = workItem
            
            // Schedule the update after a 0.5-second delay.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }
    }
    
    private func updateActualReps(for exercise: Exercise, at index: Int, newReps: Int) {
        guard let recordID = exercise.recordID else { return }
        // Copy the current reps array and update only the specified index.
        var updatedReps = exercise.setActualReps
        updatedReps[index] = newReps
        
        // Call the CloudKit update method.
        evm.updateExercise(recordID: recordID, newActualReps: updatedReps)
    }
}

struct SetsField: View {
    let exercise: Exercise
    let evm: ExerciseViewModel
    private let maxSets: Int = 15
    private let minSets: Int = 1

    // Local state for the text field's current value.
    @State private var localText: String = ""
    // A debouncing work item to delay the update.
    @State private var debouncedWorkItem: DispatchWorkItem?
    // An optional error message for when input is out of range.
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Sets:")
                    .foregroundColor(.white)
                TextField(
                    "Sets",
                    text: $localText
                )
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 60)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil)
                        }
                    }
                }
            }
            // Display error message if one exists.
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .onAppear {
            // Initialize the text field with the current sets value.
            localText = exercise.sets == 0 ? "" : String(exercise.sets)
        }
        .onChange(of: localText) { newValue in
            // Cancel any pending update.
            debouncedWorkItem?.cancel()
            
            let workItem = DispatchWorkItem {
                // If the text field is empty, clear any error and do nothing.
                guard !newValue.isEmpty else {
                    errorMessage = nil
                    return
                }
                
                // Validate input is an integer.
                if let newSets = Int(newValue) {
                    // Enforce minimum number of sets.
                    if newSets < minSets {
                        errorMessage = "Minimum allowed sets is \(minSets)"
                        return
                    }
                    // Enforce maximum number of sets.
                    if newSets > maxSets {
                        errorMessage = "Maximum allowed sets is \(maxSets)"
                        return
                    }
                    
                    // Input is valid—clear any previous error.
                    errorMessage = nil
                    // Only update if the new value differs from the current model.
                    if newSets != exercise.sets, let recordID = exercise.recordID {
                        evm.updateExercise(recordID: recordID, newSets: newSets)
                    }
                } else {
                    // Show an error if the input isn't a valid number.
                    errorMessage = "Please enter a valid number."
                }
            }
            
            debouncedWorkItem = workItem
            // Schedule the update after 0.5 seconds of inactivity.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }
    }
}

struct ExerciseNameField: View {
    let exercise: Exercise
    let evm: ExerciseViewModel

    // Local state for the text field's current value.
    @State private var localText: String = ""
    // A debouncing work item to delay the update.
    @State private var debouncedWorkItem: DispatchWorkItem?

    var body: some View {
        HStack {
            Text("Name:")
                .foregroundColor(.white)
            TextField("Exercise Name", text: $localText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 200)
        }
        .onAppear {
            // Initialize the text field with the current exercise name.
            localText = exercise.name
        }
        .onChange(of: localText) { newValue in
            // Cancel any pending update.
            debouncedWorkItem?.cancel()
            
            // Create a new work item to update the exercise name.
            let workItem = DispatchWorkItem {
                if let recordID = exercise.recordID {
                    evm.updateExercise(recordID: recordID, newName: newValue)
                }
            }
            debouncedWorkItem = workItem
            
            // Schedule the update after a short delay (0.5 seconds).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }
    }
}
