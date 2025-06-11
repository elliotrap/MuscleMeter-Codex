//
//  ViewModel.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 1/18/25.
//
import SwiftUI
import Combine
import Foundation
import CloudKit

// MARK: - ExperienceLevel Enum

enum ExperienceLevel: String, CaseIterable {
    case noob         = "Noob"
    case beginner     = "Beginner"
    case intermediate = "Intermediate"
    case advanced     = "Advanced"
    case elite        = "Elite"
    case freak        = "Freak"
}


// Your LiftEntry model
struct LiftEntry: Identifiable, CustomStringConvertible {
    let id = UUID()
    let bench: Double
    let squat: Double
    let deadlift: Double
    let timestamp: Date

    var description: String {
        "LiftEntry(id: \(id), bench: \(bench), squat: \(squat), deadlift: \(deadlift), timestamp: \(timestamp))"
    }
}


struct LiftData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let liftType: String
    let weight: Double
}

// MARK: - ViewModel

class ViewModel: ObservableObject {
    // ---------------------------------------------------------
    // MARK: - 1) User Inputs
    // ---------------------------------------------------------
    @Published var ageText: String = "30"             
    @Published var gender: Gender = .male
    @Published var bodyWeightText: String = "170"
    @Published var squatText: String      = "260"
    @Published var benchText: String      = "210"
    @Published var deadliftText: String   = "360"
    
    // If you have other inputs like benchOneRM, add them here
    @Published var benchOneRM: Double = 0
    
    // Array of lift entries (populated when you fetch from CloudKit)
      @Published var liftEntries: [LiftEntry] = []
    
    // ---------------------------------------------------------
    // MARK: - 2) Computed Double Values
    // ---------------------------------------------------------
    var bodyWeight: Double {
        Double(bodyWeightText) ?? 0
    }
    
    var squat: Double {
        Double(squatText) ?? 0
    }
    
    var bench: Double {
        Double(benchText) ?? 0
    }
    
    var deadlift: Double {
        Double(deadliftText) ?? 0
    }
    
    // ---------------------------------------------------------
    // MARK: - 3) Lift Classifications
    // ---------------------------------------------------------
    var squatLevel: ExperienceLevel {
        classifySquat(squat: squat, bodyWeight: bodyWeight)
    }
    
    var benchLevel: ExperienceLevel {
        classifyBench(bench: bench, bodyWeight: bodyWeight)
    }
    
    var deadliftLevel: ExperienceLevel {
        classifyDeadlift(deadlift: deadlift, bodyWeight: bodyWeight)
    }
    
    // ---------------------------------------------------------
    // MARK: - 4) Overall Classification
    // ---------------------------------------------------------
    /// The "overall" classification is the lowest of the three lifts' levels.
    /// (If any lift is at a lower classification, we show that as the overall.)
    var overallLevel: ExperienceLevel {
        [squatLevel, benchLevel, deadliftLevel].min {
            experienceIndex(for: $0) < experienceIndex(for: $1)
        }!
    }
    
    // ---------------------------------------------------------
    // MARK: - 5) Next Level & Overall Progress
    // ---------------------------------------------------------
    /// If the user is not at `freak`, what's the next step?
    var nextLevel: ExperienceLevel? {
        switch overallLevel {
        case .noob:         return .beginner
        case .beginner:     return .intermediate
        case .intermediate: return .advanced
        case .advanced:     return .elite
        case .elite:        return .freak
        case .freak:        return nil
        }
    }
    
    /// A discrete 0..1 fraction from Noob(0) → Freak(5)
    /// We offset the index by 0.5 to center the pointer under each label.
    var overallProgress: Double {
       Double(experienceIndex(for: overallLevel))
       / Double(ExperienceLevel.allCases.count - 1)
    }
    
    // ---------------------------------------------------------
    // MARK: - 6) Sub-Level Progress (0..1) for Overall Classification
    // ---------------------------------------------------------
    /// How close is the user to moving from the current overall classification to the next one
    var levelProgress: Double {
        guard let next = nextLevel else { return 1.0 }
        
        let (limitingLiftName, limitingLiftRatio) = findLimitingLift()
        return subLevelFraction(for: limitingLiftName,
                                ratio: limitingLiftRatio,
                                current: overallLevel,
                                next: next)
    }
    
    func resetValues() {
        // Reset text fields
        bodyWeightText = ""
        benchText = ""
        squatText = ""
        deadliftText = ""
        
        // Reset numerical calculations
        benchOneRM = 0.0
        
        // Reset any other properties if needed, for example:
        // overallProgress = 0.0
        // levelProgress = 0.0
        // overallLevel = 0
        // nextLevel = 1
    }
    
    /// Example: Noob=0, Beginner=1, Intermediate=2, etc.
    func centeredFraction(for level: ExperienceLevel) -> Double {
        let i = experienceIndex(for: level) // 0..5
        let total = Double(ExperienceLevel.allCases.count - 1) // =5
        // Shift by +0.5 to reach the cell center
        let rawFraction = (Double(i) + 0.5) / total
        // If you want to clamp so Freak stays at fraction=1.0:
        return min(rawFraction, 1.0)
    }
    
    /// Identify which of the 3 lifts is the "lowest classification" and return its ratio
    private func findLimitingLift() -> (String, Double) {
        let squatIndex = experienceIndex(for: squatLevel)
        let benchIndex = experienceIndex(for: benchLevel)
        let deadIndex  = experienceIndex(for: deadliftLevel)
        
        let minIndex = min(squatIndex, benchIndex, deadIndex)
        
        if minIndex == squatIndex {
            return ("squat", squat / bodyWeight)
        } else if minIndex == benchIndex {
            return ("bench", bench / bodyWeight)
        } else {
            return ("deadlift", deadlift / bodyWeight)
        }
    }
    
    /// Returns a fraction in [0..1] indicating how far `ratio` is from the "current->next" threshold for the given lift
    func subLevelFraction(for liftName: String,
                          ratio: Double,
                          current: ExperienceLevel,
                          next: ExperienceLevel) -> Double
    {
        // Get numeric boundaries for the current and next levels
        let (low, high) = thresholdRange(for: liftName, current: current, next: next)
        
        // Clamp the fraction between 0 and 1
        if ratio < low { return 0.0 }
        if ratio >= high { return 1.0 }
        
        return (ratio - low) / (high - low)
    }
    
    // ---------------------------------------------------------
    // MARK: - 7) Classification Functions
    // ---------------------------------------------------------
    /// Maps an ExperienceLevel to an integer in 0..5
    func experienceIndex(for level: ExperienceLevel) -> Int {
        switch level {
        case .noob:         return 0
        case .beginner:     return 1
        case .intermediate: return 2
        case .advanced:     return 3
        case .elite:        return 4
        case .freak:        return 5
        }
    }
    
    func classifySquat(squat: Double, bodyWeight: Double) -> ExperienceLevel {
        guard bodyWeight > 0 else { return .noob }  // or handle differently

        
        // 1. “Noob” absolute range 0 ... 135
        if squat <= 135 {
            return .noob
        }
        
        // 2. Ratio thresholds:
        //    Beginner: <1.25
        //    Intermediate: 1.25..<1.75
        //    Advanced: 1.75..<2.5
        //    Elite: 2.5..<3.0
        //    Freak: >=3.0
        let ratio = squat / bodyWeight
        switch ratio {
        case ..<1.25:
            return .beginner
        case 1.25..<1.75:
            return .intermediate
        case 1.75..<2.5:
            return .advanced
        case 2.5..<3.0:
            return .elite
        default:
            return .freak
        }
    }
    
    func classifyBench(bench: Double, bodyWeight: Double) -> ExperienceLevel {
        guard bodyWeight > 0 else { return .noob }  // or handle differently

        
        // 1. “Noob” absolute range for bench: 0 ... 95
        if bench <= 95 {
            return .noob
        }
        
        // 2. Ratio thresholds:
        //    Beginner: <1.0
        //    Intermediate: 1.0..<1.5
        //    Advanced: 1.5..<2.0
        //    Elite: 2.0..<2.25
        //    Freak: >=2.25
        let ratio = bench / bodyWeight
        switch ratio {
        case ..<1.0:
            return .beginner
        case 1.0..<1.5:
            return .intermediate
        case 1.5..<2.0:
            return .advanced
        case 2.0..<2.25:
            return .elite
        default:
            return .freak
        }
    }
    
    func classifyDeadlift(deadlift: Double, bodyWeight: Double) -> ExperienceLevel {
        guard bodyWeight > 0 else { return .noob }  // or handle differently

        // 1. “Noob” absolute range: 0...225
        if deadlift <= 225 {
            return .noob
        }
        
        // 2. Ratio thresholds:
        //    Beginner: <1.5
        //    Intermediate: 1.5..<2.25
        //    Advanced: 2.25..<3.0
        //    Elite: 3.0..<3.5
        //    Freak: >=3.5
        let ratio = deadlift / bodyWeight
        switch ratio {
        case ..<1.5:
            return .beginner
        case 1.5..<2.25:
            return .intermediate
        case 2.25..<3.0:
            return .advanced
        case 3.0..<3.5:
            return .elite
        default:
            return .freak
        }
    }
    
    // ---------------------------------------------------------
    // MARK: - 8) Threshold Ranges for Each Lift
    // ---------------------------------------------------------
    /// Return (low, high) ratio boundary for the given lift from `current` → `next`.
    func thresholdRange(for liftName: String, current: ExperienceLevel, next: ExperienceLevel) -> (Double, Double) {
        switch liftName.lowercased() {
        case "squat":
            return squatBoundaries(from: current, to: next)
        case "bench":
            return benchBoundaries(from: current, to: next)
        case "deadlift":
            return deadliftBoundaries(from: current, to: next)
        default:
            return (0.0, 1.0)
        }
    }
    
     func subLevelProgressForSquat() -> (level: ExperienceLevel, next: ExperienceLevel?, fraction: Double) {
        let level = squatLevel
        // If user is Freak, there's no next level
        if level == .freak {
            return (level, nil, 1.0)
        }
        // Figure out the ratio and the relevant numeric boundaries
        let ratio = squat / bodyWeight

        // next level
        let next = nextExperienceLevel(after: level)

        // get (lowerBound, upperBound) for the *current→next* range
        let (low, high) = squatBoundaries(from: level, to: next)

        // If the ratio is below 'low', progress = 0
        // If above 'high', progress = 1
        // else linear interpolation
        let rawFraction = (ratio - low) / (high - low)
        let fraction = max(0, min(1, rawFraction))

        return (level, next, fraction)
    }
    
    
    /// Maps current→next for Squat ratio boundaries, matching your classification logic.
     func squatBoundaries(from current: ExperienceLevel, to next: ExperienceLevel?) -> (Double, Double) {
        guard let next = next else {
            return (0.0, 1.0) // If there's no next level, just return dummy
        }

        switch (current, next) {
        case (.noob, .beginner):
            // "Noob" is 45..135 lbs absolute, but we can treat it as 0..1.25 ratio, etc.
            // We'll do something approximate:
            return (0.0, 1.25)
        case (.beginner, .intermediate):
            return (1.0, 1.25)   // per your chart for squat
        case (.intermediate, .advanced):
            return (1.25, 1.75)
        case (.advanced, .elite):
            return (1.75, 2.5)
        case (.elite, .freak):
            return (2.5, 3.0)
        default:
            return (0.0, 1.0)
        }
    }
    
    // Same function for bench, or you can create a single function
    // that checks the classification and uses the correct boundaries, etc.
     func subLevelProgressForBench() -> (level: ExperienceLevel, next: ExperienceLevel?, fraction: Double) {
        let level = benchLevel
        if level == .freak {
            return (level, nil, 1.0)
        }
        let ratio = bench / bodyWeight
        let next = nextExperienceLevel(after: level)
        let (low, high) = benchBoundaries(from: level, to: next)
        let rawFraction = (ratio - low) / (high - low)
        let fraction = max(0, min(1, rawFraction))
        return (level, next, fraction)
    }

     func benchBoundaries(from current: ExperienceLevel, to next: ExperienceLevel?) -> (Double, Double) {
        guard let next = next else { return (0.0, 1.0) }
        switch (current, next) {
        case (.noob, .beginner):
            // noob is 45..95 absolute, approximate ratio for .noob -> .beginner
            return (0.3, 1.0)
        case (.beginner, .intermediate):
            return (0.0, 1.0)
        case (.intermediate, .advanced):
            return (1.0, 1.5)
        case (.advanced, .elite):
            return (1.5, 2.0)
        case (.elite, .freak):
            return (2.0, 2.25)
        default:
            return (0.0, 1.0)
        }
    }
    
    
    // Deadlift
     func subLevelProgressForDeadlift() -> (level: ExperienceLevel, next: ExperienceLevel?, fraction: Double) {
        let level = deadliftLevel
        if level == .freak {
            return (level, nil, 1.0)
        }
        let ratio = deadlift / bodyWeight
        let next = nextExperienceLevel(after: level)
        let (low, high) = deadliftBoundaries(from: level, to: next)
        let rawFraction = (ratio - low) / (high - low)
        let fraction = max(0, min(1, rawFraction))
        return (level, next, fraction)
    }

     func deadliftBoundaries(from current: ExperienceLevel, to next: ExperienceLevel?) -> (Double, Double) {
        guard let next = next else { return (0.0, 1.0) }
        switch (current, next) {
        case (.noob, .beginner):
            // noob is 135..225 absolute
            return (0.0, 1.5)  // approximate
        case (.beginner, .intermediate):
            return (0.0, 1.5)
        case (.intermediate, .advanced):
            return (1.5, 2.25)
        case (.advanced, .elite):
            return (2.25, 3.0)
        case (.elite, .freak):
            return (3.0, 3.5)
        default:
            return (0.0, 1.0)
        }
    }
    
    // ---------------------------------------------------------
    // MARK: - 9) Sub-Level Progress for Each Lift
    // ---------------------------------------------------------
    /// Returns (currentLevel, nextLevel, fraction) for Squat
    var squatProgress: (currentLevel: ExperienceLevel, nextLevel: ExperienceLevel?, fraction: Double) {
        let level = squatLevel
        guard let next = nextExperienceLevel(after: level) else {
            return (level, nil, 1.0)
        }
        let ratio = squat / bodyWeight
        let fraction = subLevelFraction(for: "squat", ratio: ratio, current: level, next: next)
        return (level, next, fraction)
    }
    
    /// Returns (currentLevel, nextLevel, fraction) for Bench
    var benchProgress: (currentLevel: ExperienceLevel, nextLevel: ExperienceLevel?, fraction: Double) {
        let level = benchLevel
        guard let next = nextExperienceLevel(after: level) else {
            return (level, nil, 1.0)
        }
        let ratio = bench / bodyWeight
        let fraction = subLevelFraction(for: "bench", ratio: ratio, current: level, next: next)
        return (level, next, fraction)
    }
    
    /// Returns (currentLevel, nextLevel, fraction) for Deadlift
    var deadliftProgress: (currentLevel: ExperienceLevel, nextLevel: ExperienceLevel?, fraction: Double) {
        let level = deadliftLevel
        guard let next = nextExperienceLevel(after: level) else {
            return (level, nil, 1.0)
        }
        let ratio = deadlift / bodyWeight
        let fraction = subLevelFraction(for: "deadlift", ratio: ratio, current: level, next: next)
        return (level, next, fraction)
    }
    
    // ---------------------------------------------------------
    // MARK: - 10) Helper Functions
    // ---------------------------------------------------------
    func nextExperienceLevel(after level: ExperienceLevel) -> ExperienceLevel? {
        switch level {
        case .noob:         return .beginner
        case .beginner:     return .intermediate
        case .intermediate: return .advanced
        case .advanced:     return .elite
        case .elite:        return .freak
        case .freak:        return nil
        }
    }
    
    // Save user data both locally and to CloudKit
    func saveUserData() {
        print("ViewModel: Initiating saveUserData()")
        
        guard let bench = Double(benchText),
              let squat = Double(squatText),
              let deadlift = Double(deadliftText) else {
            print("ViewModel: Conversion error - ensure that bench, squat, and deadlift values are valid numbers.")
            return
        }
        
        let newEntry = LiftEntry(bench: bench, squat: squat, deadlift: deadlift, timestamp: Date())
        liftEntries.append(newEntry)
        print("ViewModel: New local entry appended: \(newEntry)")
        
        let bodyWeight = Double(bodyWeightText) ?? 0
        print("ViewModel: Saving record with bodyWeight: \(bodyWeight), bench: \(bench), squat: \(squat), deadlift: \(deadlift)")
        
        CloudKitManager.shared.saveUserLifts(bodyWeight: bodyWeight, bench: bench, squat: squat, deadlift: deadlift) { result in
            switch result {
            case .success(let record):
                print("ViewModel: Successfully saved record to CloudKit: \(record)")
            case .failure(let error):
                print("ViewModel: Error saving record to CloudKit: \(error.localizedDescription)")
            }
        }
    }
    
    // Load user data from CloudKit and update liftEntries
    func loadUserData() {
        print("ViewModel: Initiating loadUserData()")
        
        CloudKitManager.shared.fetchUserLifts { result in
            switch result {
            case .success(let records):
                print("ViewModel: Successfully fetched \(records.count) record(s) from CloudKit.")
                self.liftEntries.removeAll()
                
                for record in records {
                    if let bench = record["bench"] as? Double,
                       let squat = record["squat"] as? Double,
                       let deadlift = record["deadlift"] as? Double,
                       let timestamp = record["timestamp"] as? Date {
                        let entry = LiftEntry(bench: bench, squat: squat, deadlift: deadlift, timestamp: timestamp)
                        self.liftEntries.append(entry)
                        print("ViewModel: Added entry from CloudKit: \(entry)")
                    } else {
                        print("ViewModel: Error converting record \(record) into LiftEntry.")
                    }
                }
                print("ViewModel: Final local liftEntries array: \(self.liftEntries)")
            case .failure(let error):
                print("ViewModel: Error fetching records from CloudKit: \(error.localizedDescription)")
            }
        }
    }
}
