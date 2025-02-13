//
//  ContentView.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 1/18/25.
//

import SwiftUI
import Combine
import CloudKit

struct LiftItem: Identifiable {
    let id = UUID()
    
    var name: String            // e.g. "Bench"
    var liftText: Binding<String> // e.g. $vm.benchText
    var subLevelProgress: () -> (ExperienceLevel, ExperienceLevel?, Double)
    var liftLevel: ExperienceLevel
}


struct ContentView: View {
    // Track if the user is signed in
    @State private var isAuthenticated = true
    var body: some View {
        Group {
            if isAuthenticated {
                MainAppView(isAuthenticated: $isAuthenticated)
            } else {
                LoginView(isAuthenticated: $isAuthenticated)
            }
        }
    }
}

struct MainAppView: View {
    @Binding var isAuthenticated: Bool
    @ObservedObject var exerciseModel = ExerciseViewModel(workoutID: CKRecord.ID(recordName: "defaultWorkout"))
    @ObservedObject var cm = ComparisonViewModel()
    @ObservedObject var vm = ViewModel()
    @State private var showOneRMCalculator = false
    @State private var showRankingView = false

    
    
    // Hides the keyboard when needed.
    func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        #endif
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                // Compute a scale factor based on available width.
                let scaleFactor: CGFloat = geometry.size.width < 430 ? 0.90 : 1.05
                
                ZStack {
                    // Background gradient.
                    LinearGradient(
                        gradient: Gradient(colors: [Color("NeomorphBG2"), Color("NeomorphBG2")]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    
                    // Main content wrapped in a VStack.
                    VStack {
                        VStack(spacing: 20) {
                            VStack {
                                // Body Weight Section.
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(lineWidth: 5)
                                        .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                                        .frame(width: 220, height: 60)
                                    
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 9)
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color("NeomorphBG3").opacity(0.5),
                                                        Color("NeomorphBG2")
                                                    ]),
                                                    startPoint: .bottom,
                                                    endPoint: .topTrailing
                                                )
                                            )
                                            .frame(width: 206, height: 46)
                                        
                                        HStack {
                                            Text("Body Weight:")
                                            TextField("0", text: $vm.bodyWeightText)
                                                .keyboardType(.decimalPad)
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                                .frame(width: 50, height: 30)
                                        }
                                    }
                                }
                                
    
                                
                                Spacer().frame(height: 20)
                                
                                // Lift Cards Section.
                                VStack(spacing: 20) {
                                    LiftCardView(
                                        liftName: "Bench",
                                        liftText: $vm.benchText,
                                        subLevelProgress: vm.subLevelProgressForBench,
                                        liftLevel: vm.benchLevel
                                    )
                                    
                                    LiftCardView(
                                        liftName: "Squat",
                                        liftText: $vm.squatText,
                                        subLevelProgress: vm.subLevelProgressForSquat,
                                        liftLevel: vm.squatLevel
                                    )
                                    
                                    LiftCardView(
                                        liftName: "Deadlift",
                                        liftText: $vm.deadliftText,
                                        subLevelProgress: vm.subLevelProgressForDeadlift,
                                        liftLevel: vm.deadliftLevel
                                    )
                                }
                                
                                Spacer().frame(height: 15)
                                
                                // Progress Section.
                                VStack {
                                    ZStack {
                                        CustomRoundedRectangle2(progress: 0.07, currentLevel: vm.overallLevel)
                                        CompositeProgressView(
                                            overallProgress: vm.overallProgress,
                                            levelProgress: vm.levelProgress,
                                            currentLevel: vm.overallLevel,
                                            nextLevel: vm.nextLevel
                                        )
                                    }
                                }
                            }
                        }
                        Spacer().frame(height: 45)
                    }
                    // Apply the scale effect and center the content.
                    .scaleEffect(scaleFactor)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .toolbar { // Ambiguous use of 'toolbar(content:)'
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                hideKeyboard()
                            }
                        }
                        
                        ToolbarItemGroup(placement: .bottomBar) {
                            HStack {
                                // OneRM Calculator Button.
                                ZStack {
                                    RoundedRectangle(cornerRadius: 13)
                                        .stroke(lineWidth: 5)
                                        .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                                        .frame(width: 68, height: 48)
                                    
                                    Button(action: {
                                        showOneRMCalculator = true
                                    }) {
                                        Text("OneRM Calculator")
                                            .underline(false)
                                            .foregroundStyle(.white)
                                            .frame(width: 56, height: 35)
                                            .background(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color("NeomorphBG3").opacity(0.5),
                                                        Color("NeomorphBG2")
                                                    ]),
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .cornerRadius(9)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                
                                // OneRM Calculator Button.
                                ZStack {
                                    RoundedRectangle(cornerRadius: 13)
                                        .stroke(lineWidth: 5)
                                        .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                                        .frame(width: 68, height: 48)
                                    
                                    Button(action: {
                                        showRankingView = true
                                        vm.loadUserData()

                                    }) {
                                        Text("Graph View")
                                            .underline(false)
                                            .foregroundStyle(.white)
                                            .frame(width: 56, height: 35)
                                            .background(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color("NeomorphBG3").opacity(0.5),
                                                        Color("NeomorphBG2")
                                                    ]),
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .cornerRadius(9)
                                       
                                        
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                
                                ZStack {
                                    RoundedRectangle(cornerRadius: 13)
                                        .stroke(lineWidth: 5)
                                        .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                                        .frame(width: 68, height: 48)
                                    
                                    Button(action: {
//                                        vm.saveUserData()
                                        exerciseModel.deleteAllExercises()
                                    }) {
                                        Text("delete")
                                            .underline(false)
                                            .foregroundStyle(.white)
                                            .frame(width: 56, height: 35)
                                            .background(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color("NeomorphBG3").opacity(0.5),
                                                        Color("NeomorphBG2")
                                                    ]),
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .cornerRadius(9)
                                     
                                        
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                
                                ZStack {
                                    RoundedRectangle(cornerRadius: 13)
                                        .stroke(lineWidth: 5)
                                        .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                                        .frame(width: 68, height: 48)
                                    
                                    NavigationLink(destination: WorkoutsListView()) {
                                                   Text("Go to ExercisesView")
                                               }
                                }
                            }
                        }
                    }
                }
            }
        }

        // OneRM Calculator Sheet.
        .sheet(isPresented: $showOneRMCalculator) {
            OneRepMaxCalculatorView(selectedOneRM: $vm.benchOneRM)
                .presentationDetents([.fraction(0.5)])
                .presentationDragIndicator(.visible)
        }
        // New Ranking View Sheet.
        .sheet(isPresented: $showRankingView) {
            RankingView(vm: vm)
        }
        .onReceive(vm.$benchOneRM.dropFirst()) { newValue in
            vm.benchText = String(format: "%.0f", newValue)
        }
    }
}



import Charts

struct RankingView: View {
    @ObservedObject var vm = ViewModel()  // This creates a new instance!
    @Environment(\.dismiss) var dismiss  // For iOS 15+, use dismiss() instead of presentationMode

    // Create a computed property to convert each LiftEntry into three LiftData points.
    var chartData: [LiftData] {
        vm.liftEntries.flatMap { entry in
            [
                LiftData(timestamp: entry.timestamp, liftType: "Bench", weight: entry.bench),
                LiftData(timestamp: entry.timestamp, liftType: "Squat", weight: entry.squat),
                LiftData(timestamp: entry.timestamp, liftType: "Deadlift", weight: entry.deadlift)
            ]
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if chartData.isEmpty {
                    Text("No data available")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    Chart(chartData) { data in
                        LineMark(
                            x: .value("Time", data.timestamp),
                            y: .value("Weight", data.weight)
                        )
                        // Differentiate each line by its lift type.
                        .foregroundStyle(by: .value("Lift Type", data.liftType))
                        // Optionally add symbols to each data point.
                        .symbol(by: .value("Lift Type", data.liftType))
                    }
                    .chartYAxisLabel("Weight (lbs)")
                    .chartXAxisLabel("Date")
                    .padding()
                }
                Spacer()
            }
            .navigationTitle("Lifts Ranking")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}


struct CompositeProgressView: View {
    
    @ObservedObject var vm = ViewModel()

    
    /// A value between 0 and 1 for total progress across all experience levels (Noob→Freak).
    let overallProgress: Double
    
    /// A value between 0 and 1 showing how far the user is *within* their current level.
    let levelProgress: Double
    
    /// The user’s current classification (Noob, Beginner, Intermediate, etc.)
    let currentLevel: ExperienceLevel
    
    /// The *next* level. If nil (e.g., user is at “Freak”), we hide the sub-level bar.
    let nextLevel: ExperienceLevel?
    
    var displayedProgress: Int {
        let value = levelProgress * 100
        if value.isNaN || value.isInfinite {
            return 0
        }
        return Int(value)
    }
    
    func colorForLevel(_ level: ExperienceLevel) -> (background: Color, foreground: Color) {
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
            return (.black, .red)
        }
    }
    
    private let rainbowGradient = LinearGradient(
        gradient: Gradient(colors: [.red, .blue, .green]),
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            // 1) The row of labels from Noob → Freak
            HStack {
                ForEach(ExperienceLevel.allCases, id: \.self) { level in
                    if level == currentLevel {
                        if level == .freak {
                            ZStack {
                                let (bg, fg) = colorForLevel(level)

                                
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
                                            ).opacity(1)
                                          )
                                        : AnyShapeStyle(bg.opacity(0.35))
                                    )                                    .frame(width: 60, height: 20 )
                                // Add a blur so it looks like a soft glow
                                    .blur(radius: 15)
                            
                                
                                // Highlight with a rainbow gradient
                                Text(level.rawValue)
                                    .font(.caption2)
                                    .padding(4)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                .red,  .blue, .green
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                        } else {
                            ZStack {
                                
                                let (bg, fg) = colorForLevel(level)

                                // MARK: - The partial glow background
                                // This shape’s width is only up to `progress * width`
                                RoundedRectangle(cornerRadius: 50)
                                    .fill(bg.opacity(0.5)) // tinted color
                                    .frame(width: 50, height: 20 )
                                // Add a blur so it looks like a soft glow
                                    .blur(radius: 15)
                                // Use your existing colorForLevel function for everything else
                                Text(level.rawValue)
                                    .font(.caption2)
                                    .padding(4)
                                    .background(bg)
                                    .foregroundColor(fg)
                                    .cornerRadius(4)
                            }
                        }
                    } else {
                        // Neutral style when it’s not the currentLevel
                        Text(level.rawValue)
                            .font(.caption2)
                            .padding(4)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                }
            }
            .scaleEffect(x: 0.9, y: 1)

            
            
            VStack {
                if currentLevel == .freak {
                    // Custom rainbow bar
                    ZStack(alignment: .leading) {
                        GeometryReader { geo in
                            // Entire rainbow background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(rainbowGradient)
                                .frame(height: 8)
                            
                            // Overlay a dimmer to represent the unfilled portion
                            let fraction = CGFloat(overallProgress)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.2))
                                .frame(width: geo.size.width * (1 - fraction),
                                       height: 8,
                                       alignment: .trailing)
                                .offset(x: geo.size.width * fraction)
                        }
                    }
                    .frame(height: 8)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .scaleEffect(x: 0.9, y: 1, anchor: .center)
                    
                } else {
                    // Normal progress bar
                    let (barColor, _) = colorForLevel(currentLevel)
                    ProgressView(value: overallProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: barColor))
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .scaleEffect(x: 0.9, y: 2)
                        .opacity(0.7)
                }
            }
            
            // 3) Sub-level progress text
            if let nextLevel = nextLevel {
                Text("You are \(displayedProgress)% towards \(nextLevel.rawValue)")                    .font(.caption)
                    .foregroundColor(.white)
 
            } else {
                // If there's no next level
                Text("You have reached the highest level.")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
}




struct LiftProgressView: View {
    var liftName: String
    var currentLevel: ExperienceLevel
    var nextLevel: ExperienceLevel?
    var progressFraction: Double
    
    // Dramatic multi-stop gradient
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
        VStack(alignment: .center, spacing: 5) {
            if let next = nextLevel {
                Text("\(liftName) is \(Int(progressFraction * 100))% from \(currentLevel.rawValue) to \(next.rawValue)")
                    .font(.caption)
            } else {
                Text("\(liftName) is already at the highest level (\(currentLevel.rawValue))!")
                    .font(.caption)
            }
            
            if currentLevel == .freak {
                // -----------------------------------------------
                // When freak, show a custom rainbow bar:
                // -----------------------------------------------
                RainbowBar(fraction: progressFraction)
                    .frame(height: 8)
                    .scaleEffect(x: 1, y: 1, anchor: .center)
            } else {
                // -----------------------------------------------
                // Otherwise, use your existing dynamic color
                // from the “dramaticMultiColorGradient.”
                // -----------------------------------------------
                let dynamicColor = dramaticMultiColorGradient.interpolatedColor(at: progressFraction)
                
                ProgressView(value: progressFraction)
                    .progressViewStyle(LinearProgressViewStyle(tint: dynamicColor))
                    .scaleEffect(x: 0.9, y: 2, anchor: .center)
                    .opacity(0.7)

            }
        }
        .padding(.vertical, 4)
    }
}

struct RainbowBar: View {
    var fraction: Double
    
    var body: some View {
        ZStack(alignment: .leading) {
            GeometryReader { geo in
                // Full rainbow background
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.red, .blue, .green]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 8)
                
                // “Unfilled” portion overlay, so that only fraction is “filled”
                let progressWidth = geo.size.width * CGFloat(fraction)
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: geo.size.width - progressWidth, height: 8)
                    .position(x: progressWidth + (geo.size.width - progressWidth)/2, y: 4)
            }
        }
        .frame(height: 8)
    }
}

struct LiftCardView: View {
    
    @ObservedObject var vm = ViewModel()

    // --------------------------------
    // MARK: - Inputs
    // --------------------------------
    
    /// The name of the lift (e.g. "Bench", "Squat", "Deadlift")
    let liftName: String
    
    /// Binding to the user’s text field (e.g. `$vm.benchText`)
    @Binding var liftText: String
    
    /**
     A function or closure that returns
     `(currentLevel, nextLevel, fraction)`
     for this specific lift’s classification.
     
     Example usage:
     ```swift
     vm.subLevelProgressForBench()
     // returns (ExperienceLevel, ExperienceLevel?, Double)
     ```
     */
    let subLevelProgress: () -> (ExperienceLevel, ExperienceLevel?, Double)
    
    /// The *overall* classification for the lift
    /// (e.g. `vm.benchLevel`)
    let liftLevel: ExperienceLevel
    
    // --------------------------------
    // MARK: - Layout Customization (Optional)
    // --------------------------------
    var rectangleProgress: CGFloat = 0.05
    var cornerRadius: CGFloat = 15
    var cardWidth: CGFloat = 336
    var cardHeight: CGFloat = 120
    
    @State var showMoreInfo: Bool = false

    
    // --------------------------------
    // MARK: - Body
    // --------------------------------
    var body: some View {
        // 1) Call the sub-level progress function *once*
        let (currentLevel, nextLevel, fraction) = subLevelProgress()
        
        ZStack {
            // 2) Use fraction to color our CustomRoundedRectangle
            // 2) Use fraction *and the per-lift currentLevel*
            CustomRoundedRectangle(
                progressFraction: CGFloat(fraction),
                progress: rectangleProgress,
                currentLevel: currentLevel, // <-- Use the per-lift level
                cornerRadius: cornerRadius,
                width: cardWidth,
                height: cardHeight
            )
            
            if showMoreInfo {
                
                
            } else {
                
                // 3) The inner VStack with text field + progress bar
                VStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .foregroundColor(Color("NeomorphBG3").opacity(0.5))
                            .frame(width: 160, height: 45)
                        
                        HStack {
                            Text("\(liftName):")
                            TextField("", text: $liftText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60, height: 30)
                        }
                    }
                    
                    // 4) Our LiftProgressView
                    LiftProgressView(
                        liftName: liftName,
                        currentLevel: currentLevel,
                        nextLevel: nextLevel,
                        progressFraction: fraction
                    )
                    .frame(width: 280)
                    .padding(.bottom, 5)
                    
                    // 5) Display the user’s classification
                    Text("\(liftName) Level: \(liftLevel.rawValue)")
                        .foregroundStyle(Color.white)
                }
            }
        }
    }
}

struct OneRepMaxCalculatorView: View {
    @Environment(\.presentationMode) var presentationMode

    // This will bind back to ContentView
    @Binding var selectedOneRM: Double

    @State private var weightUsedText = ""
    @State private var repsText = ""

    // Epley formula example
    private var estimatedOneRM: Double {
        let weightUsed = Double(weightUsedText) ?? 0
        let reps = Double(repsText) ?? 0
        return weightUsed * (1 + reps / 30.0)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Enter your set info")) {
                    TextField("Weight Used (lbs)", text: $weightUsedText)
                        .keyboardType(.decimalPad)
                    TextField("Number of Reps", text: $repsText)
                        .keyboardType(.numberPad)
                }

                Section(header: Text("Estimated 1RM")) {
                    Text("\(estimatedOneRM, specifier: "%.1f") lbs")
                        .font(.title3)
                }
            }
            .navigationTitle("1RM Calculator")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}


extension Gradient {
    /// Returns a *single* interpolated color for the given location [0..1].
    /// This is a *piecewise* approach that blends linearly between stops.
    func interpolatedColor(at location: CGFloat) -> Color {
        let clampedLocation = max(0, min(1, location))
        
        // 1) If no stops, fallback
        guard !stops.isEmpty else { return .clear }
        
        // 2) If only one stop or location <= first stop
        if stops.count == 1 || clampedLocation <= stops.first!.location {
            return stops.first!.color
        }
        
        // 3) If location >= last stop
        if clampedLocation >= stops.last!.location {
            return stops.last!.color
        }
        
        // 4) Find two adjacent stops the location sits between
        for i in 0..<(stops.count - 1) {
            let left = stops[i]
            let right = stops[i+1]
            if clampedLocation >= left.location && clampedLocation <= right.location {
                // fraction between these two stops
                let range = right.location - left.location
                let localT = (clampedLocation - left.location) / range
                // Interpolate color
                return Color.interpolate(from: left.color, to: right.color, fraction: localT)
            }
        }
        
        // fallback
        return stops.last!.color
    }
}

extension Color {
    /// Linearly interpolate between two SwiftUI Colors in sRGB space.
    static func interpolate(from: Color, to: Color, fraction: CGFloat) -> Color {
        let f = from.components()
        let t = to.components()
        
        let r = f.r + (t.r - f.r) * fraction
        let g = f.g + (t.g - f.g) * fraction
        let b = f.b + (t.b - f.b) * fraction
        let a = f.a + (t.a - f.a) * fraction
        
        return Color(red: r, green: g, blue: b, opacity: a)
    }
    
    /// Extract RGBA components in sRGB color space (approx).
    func components() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        #if os(iOS) || os(tvOS) || os(watchOS)
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
        #elseif os(macOS)
        let nsColor = NSColor(self)
        let color = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        return (color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent)
        #endif
    }
}

#Preview {
    ContentView()
}
