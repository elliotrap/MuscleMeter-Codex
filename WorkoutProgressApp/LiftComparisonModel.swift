//
//  LiftComparisonModel.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 1/29/25.
//

import Foundation
import SwiftUI
/// A structure to store user performance data in the database.
struct UserPerformance: Codable {
    let userId: String       // or email, or doc ID
    let bodyWeight: Double
    let squat: Double
    let bench: Double
    let deadlift: Double
    let timestamp: Date
}

// MARK: - Supporting Types and Calculation Logic

/// An enum for gender selection.
enum Gender: String, CaseIterable, Identifiable {
    var id: String { self.rawValue }
    case male = "Male"
    case female = "Female"
}

/// A structure that holds the calculated strength metrics.
struct StrengthMetrics {
    let rating: String      // e.g. "Noob", "Beginner", ..., "Freak"
    let percentile: Double  // e.g. 75 means you’re stronger than 75% of your peers.
    let ratio: Double       // The ratio of (lift / body weight)
}

/// Calculates the strength metrics for a given lift.
/// - Parameters:
///   - lift: The weight lifted (or average of several lifts).
///   - bodyWeight: The user’s body weight.
///   - age: The user’s age.
///   - gender: The user’s gender.
/// - Returns: A StrengthMetrics instance.
func calculateStrengthMetrics(lift: Double, bodyWeight: Double, age: Int, gender: Gender) -> StrengthMetrics {
    // Avoid division by zero.
    guard bodyWeight > 0 else {
        return StrengthMetrics(rating: "N/A", percentile: 0, ratio: 0)
    }
    
    // Compute the raw ratio.
    let ratio = lift / bodyWeight
    
    // Adjust the ratio based on gender and age.
    var adjustedRatio = ratio
    if gender == .female {
        // Example adjustment: females may have different performance standards.
        adjustedRatio *= 1.1
    }
    if age < 30 {
        adjustedRatio *= 1.05
    } else if age > 50 {
        adjustedRatio *= 0.95
    }
    
    // Determine a skill rating based on the adjusted ratio.
    let rating: String
    if adjustedRatio < 1 {
        rating = "Noob"
    } else if adjustedRatio < 1.5 {
        rating = "Beginner"
    } else if adjustedRatio < 2 {
        rating = "Intermediate"
    } else if adjustedRatio < 2.5 {
        rating = "Advanced"
    } else if adjustedRatio < 3 {
        rating = "Elite"
    } else {
        rating = "Freak"
    }
    
    // For this example, we assume a maximum adjusted ratio of 3.5 corresponds to 100%.
    let percentile = min(100, max(0, (adjustedRatio / 3.5) * 100))
    
    return StrengthMetrics(rating: rating, percentile: percentile, ratio: ratio)
}

// MARK: - ViewModel

class ComparisonViewModel: ObservableObject {
    @ObservedObject var vm = ViewModel()


    
    // New inputs for the strength calculations.

    
    // (Other properties used for progress and levels, etc., should already exist.)
    // For example:
    // @Published var overallLevel: ExperienceLevel = .beginner
    // @Published var overallProgress: Double = 0.0
    // @Published var levelProgress: Double = 0.0
    // @Published var nextLevel: ExperienceLevel? = nil

    /// Computes overall strength metrics based on the average of the three lifts.
    var overallStrengthMetrics: StrengthMetrics {
        let bodyWeight = Double(vm.bodyWeightText) ?? 0
        let bench = Double(vm.benchText) ?? 0
        let squat = Double(vm.squatText) ?? 0
        let deadlift = Double(vm.deadliftText) ?? 0
        
        // For simplicity, we average the three lifts.
        let averageLift = (bench + squat + deadlift) / 3
        return calculateStrengthMetrics(lift: averageLift, bodyWeight: bodyWeight, age: Int(vm.ageText) ?? 30, gender: vm.gender)
    }
    
    // Dummy functions/properties for the lift cards:
    var benchLevel: ExperienceLevel { .beginner } // Replace with your actual logic.
    var squatLevel: ExperienceLevel { .beginner }
    var deadliftLevel: ExperienceLevel { .beginner }
    
    // Dummy progress calculations.
    func subLevelProgressForBench() -> (ExperienceLevel, ExperienceLevel?, Double) {
        return (benchLevel, nil, 0.3)
    }
    func subLevelProgressForSquat() -> (ExperienceLevel, ExperienceLevel?, Double) {
        return (squatLevel, nil, 0.4)
    }
    func subLevelProgressForDeadlift() -> (ExperienceLevel, ExperienceLevel?, Double) {
        return (deadliftLevel, nil, 0.5)
    }
    
    // Dummy overall progress values.
    var overallLevel: ExperienceLevel { .beginner }
    var overallProgress: Double { 0.07 }
    var levelProgress: Double { 0.5 }
    var nextLevel: ExperienceLevel? { nil }
    
    // For OneRepMax Calculator demo:
    @Published var benchOneRM: Double = 0.0
}
