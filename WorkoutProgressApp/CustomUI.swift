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
                            AnyShapeStyle(accentColor.opacity(0.35))
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
                
         
                
                // Main accent rectangle with corrected gradient stop ordering
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                // First stop - start with the lowest location value
                                .init(color: accentColor, location: 0.0),
                                
                                // Second stop - ensures proper ordering with first stop
                                .init(color: accentColor.opacity(0.3), location: 0.03),
                                
                                // Third stop - make sure it's always greater than second stop
                                .init(color: Color("NeomorphBG3").opacity(0.6), location: max(0.04, progress)),
                                
                                // Final stop - always at the end
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
    /// The fraction [0..1] that controls how much of the rectangle is tinted.
        var progress: CGFloat = 5

        /// The user-selected accent color.
        var accentColor: Color = .blue

        var cornerRadius: CGFloat = 10
        var width: CGFloat = 366
        var height: CGFloat = 116

        /// Computed gradient stops based on the `progress` value.
        /// Adjust these values to tweak the gradient transition.
        private var gradientStops: [Gradient.Stop] {
            // Ensure that progress doesn't fall below a minimum value
            let lowerProgress = max(0.08, progress - 0.001)
            let mainProgress = max(0.08, progress)
            return [
                // First stop: The accent color at the start
                .init(color: accentColor, location: 0.1),
                // Second stop: A lighter accent
                .init(color: accentColor.opacity(0.3), location: lowerProgress),
                // Third stop: Transitioning to the background color
                .init(color: Color("NeomorphBG3").opacity(0.6), location: mainProgress),
                // Fourth stop: The background tint at the end
                .init(color: Color("NeomorphBG3").opacity(0.3), location: 1.0)
            ]
        }

        var body: some View {
            ZStack {
                // MARK: Partial Glow Background
                VStack {
                    Spacer().frame(height: height * 0.8)
                    RoundedRectangle(cornerRadius: 50)
                        .fill(accentColor.opacity(0.35))
                        .frame(width: width + 50, height: 55)
                        .blur(radius: 20)
                }
                
                // MARK: Outline Shape
                RoundedRectangle(cornerRadius: cornerRadius + 5)
                    .stroke(lineWidth: 5)
                    .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                    .frame(width: width + 13, height: height + 13)
                
                // MARK: Optional Glow Behind the Rectangle
                VStack {
                    Spacer().frame(height: height * 0.9)
                    RoundedRectangle(cornerRadius: 50)
                        .fill(accentColor.opacity(0.65))
                        .frame(width: width, height: 0)
                        .blur(radius: 30)
                }
                
                // MARK: Main Accent Rectangle with Gradient
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: gradientStops),
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
    var accentColor: Color = .blue // you can change the accent color using this variable
    
    var cornerRadius: CGFloat = 30
    var width: CGFloat = 266
    var height: CGFloat = 266
    
    // Initialize with a block
    init(block: WorkoutBlock, width: CGFloat = 266, height: CGFloat = 266, progress: CGFloat = 0.07) {
        self.width = width
        self.height = height
        self.progress = progress
        // Convert hex string to Color
        self.accentColor = block.accentColor
    }
    
    // Default initializer
    init(accentColor: Color = .blue, width: CGFloat = 266, height: CGFloat = 266, progress: CGFloat = 0.07) {
        self.accentColor = accentColor
        self.width = width
        self.height = height
        self.progress = progress
    }
    
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
                            
                            // progress..1: "NeomorphBG3" to lighten the top portion
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
    
    // Focus state for this field
    @FocusState private var isFocused: Bool
    
    // StateObject to persist state across view updates
    @StateObject private var fieldState = WeightFieldState()
    
    // A NumberFormatter to display the weight correctly
    private let formatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2 // Adjust as needed
        return nf
    }()

    var body: some View {
        TextField(
            "lbs",
            text: $fieldState.text
        )
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.center)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.2))
        )
        .foregroundColor(Color.white.opacity(0.8))
        .frame(width: 50)
        .focused($isFocused)
        .onAppear {
            // Initialize field only if needed
            if !fieldState.hasInitialized {
                let weight = exercise.setWeights[index]
                fieldState.text = weight == 0 ? "" : (formatter.string(from: NSNumber(value: weight)) ?? "")
                fieldState.hasInitialized = true
                fieldState.lastSubmittedValue = fieldState.text
            }
        }
        // Handle text changes with debounce
        .onChange(of: fieldState.text) { newValue in
            // Only proceed if initialized
            guard fieldState.hasInitialized else { return }
            
            // Schedule debounced update
            fieldState.scheduleUpdate(
                newValue: newValue,
                exercise: exercise,
                index: index,
                evm: evm
            )
        }
        // Handle focus changes
        .onChange(of: isFocused) { focused in
            if !focused {
                // Focus was lost, submit immediately
                fieldState.submitImmediate(
                    exercise: exercise,
                    index: index,
                    evm: evm
                )
            }
        }
        // Add a stable identity to prevent focus issues
        .id("WeightField-\(exercise.id)-\(index)")
        // Disable animations that could trigger view rebuilds
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}


struct ActualRepsField: View {
    let exercise: Exercise
    let index: Int
    let evm: ExerciseViewModel
    
    @Binding var isTextFieldVisible: Bool
    @FocusState private var isFocused: Bool
    
    // StateObject to persist state across view updates
    @StateObject private var fieldState = ActualRepsFieldState()
    
    var body: some View {
        HStack(spacing: 2) {
            Text("(")
                .foregroundColor(.white.opacity(0.8))
            
            TextField("", text: $fieldState.text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.black.opacity(0.2))
                )
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 25)
                .focused($isFocused)
                        
            Text(")")
                .foregroundColor(.white.opacity(0.8))
        }
        .onAppear {
            // Initialize field only if needed
            if !fieldState.hasInitialized {
                let reps = exercise.setActualReps[index]
                fieldState.text = reps == 0 ? "" : String(reps)
                fieldState.hasInitialized = true
                fieldState.lastSubmittedValue = fieldState.text
            }
        }
        // Handle text changes with debounce
        .onChange(of: fieldState.text) { newValue in
            // Only proceed if initialized
            guard fieldState.hasInitialized else { return }
            
            // Schedule debounced update
            fieldState.scheduleUpdate(
                newValue: newValue,
                exercise: exercise,
                index: index,
                evm: evm
            )
        }
        // Handle focus changes
        .onChange(of: isFocused) { focused in
            if !focused {
                // Focus was lost, submit immediately and check if we should keep field visible
                let shouldRemainVisible = fieldState.submitImmediate(
                    exercise: exercise,
                    index: index,
                    evm: evm
                )
                
                // Update visibility if needed
                if !shouldRemainVisible {
                    isTextFieldVisible = false
                }
            }
        }
        // Add a stable identity to prevent focus issues
        .id("ActualRepsField-\(exercise.id)-\(index)")
        // Disable animations that could trigger view rebuilds
        .transaction { transaction in
            transaction.animation = nil
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


// MARK: - LoggingDismissButton
// A reusable button that logs properly before dismissing

struct LoggingDismissButton<V: View>: View {
    @Environment(\.dismiss) private var dismiss
    let viewName: String
    let label: String
    let icon: String
    
    // Standard initializer
    init(viewName: String, label: String = "Back", icon: String = "chevron.left") {
        self.viewName = viewName
        self.label = label
        self.icon = icon
    }
    
    // Type-based initializer that automatically gets the view type name
    init(viewType: V.Type, label: String = "Back", icon: String = "chevron.left") {
        self.viewName = String(describing: viewType)
        self.label = label
        self.icon = icon
    }
    
    var body: some View {
        Button {
            // Handle logging properly first
            ViewNavigationLogger.handleDismissal(for: viewName)
            
            // Then dismiss
            dismiss()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                
                if !label.isEmpty {
                    Text(label)
                }
            }
        }
    }
}

// 7. Modify your ColorPickerSheet to work with workouts instead of exercises
// ColorPickerSheet.swift
struct ColorPickerSheet: View {
    @Binding var accentColor: Color
    var onDone: (Color) -> Void
    @Environment(\.presentationMode) private var presentationMode

    /// Expanded palette (16 total)
    private let options: [(name: String, color: Color)] = [
        // Bright basics
        ("Blue",    .blue),
        ("Green",   Color(hex:"#4CAF50")!),
        ("Purple",  Color(hex:"#9C27B0")!),
        ("Orange",  Color(hex:"#FF9800")!),
        ("Red",     Color(hex:"#F44336")!),
        ("Teal",    Color(hex:"#009688")!),
        ("Pink",    Color(hex:"#E91E63")!),
        ("Amber",   Color(hex:"#FFC107")!),

        // Deep / “manly” tones
        ("Navy",    Color(hex:"#1E3A8A")!),   // Slate navy‑700
        ("Indigo",  Color(hex:"#4338CA")!),   // Indigo‑700
        ("Charcoal",Color(hex:"#374151")!),   // Gray‑700
        ("Slate",   Color(hex:"#64748B")!),   // Slate‑500
        ("Steel",   Color(hex:"#94A3B8")!),   // Slate‑400
        ("Olive",   Color(hex:"#4D7C0F")!),   // Olive‑700
        ("Forest",  Color(hex:"#065F46")!),   // Emerald‑800
        ("Maroon",  Color(hex:"#7F1D1D")!),   // Maroon‑800

  
    ]

    var body: some View {
        VStack(spacing: 24) {
            Text("Choose an accent color")
                .font(.headline)

            LazyVGrid(columns: [.init(.adaptive(minimum: 70))], spacing: 16) {
                ForEach(options, id:\.name) { opt in
                    ColorOption(
                        color: opt.color,
                        name:  opt.name,
                        isSelected: accentColor.toHex() == opt.color.toHex(),
                        action: { accentColor = opt.color }
                    )
                }
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.secondary)

                Spacer()

                Button("Done") {
                    onDone(accentColor)
                    presentationMode.wrappedValue.dismiss()
                }
                .bold()
            }
        }
        .padding()
    }
}


#Preview {
    ExerciseCustomRoundedRectangle()
}
