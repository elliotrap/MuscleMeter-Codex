//
//  ExerciseModel.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/11/25.
//

import SwiftUI
import CloudKit
import Foundation





struct Exercise: Identifiable {
    // For local use you may keep a UUID.
    // For CloudKit-related operations you might want to store the CKRecord.ID.
    // For now, we’ll keep the UUID for local identity.
    let id = UUID()
    var name: String
    var sets: Int
    var reps: Int
    var weight: Double
    var timestamp: Date
}

class ExerciseViewModel: ObservableObject {
    @Published var exercises: [Exercise] = []
    
    /// The workout that these exercises belong to.
    let workoutID: CKRecord.ID

    /// Initialize with a workout's record ID.
    init(workoutID: CKRecord.ID) {
        self.workoutID = workoutID
    }
    
    /// Add a new exercise associated with the given workout.
    func addExercise(name: String, sets: Int, reps: Int, weight: Double) {
        // Locally append the exercise.
        let newExercise = Exercise(
            name: name,
            sets: sets,
            reps: reps,
            weight: weight,
            timestamp: Date()
        )
        exercises.insert(newExercise, at: 0) // Insert at the top (newest first)
        
        // Save to CloudKit with the workoutID.
        CloudKitManager.shared.saveUserExercise(
            name: name,
            sets: sets,
            reps: reps,
            weight: weight,
            workoutID: workoutID,
            completion: { result in
                switch result {
                case .success(let record):
                    print("ExerciseViewModel: Successfully saved to CloudKit: \(record)")
                case .failure(let error):
                    print("ExerciseViewModel: Error saving to CloudKit: \(error.localizedDescription)")
                }
            }
        )
    }
    
    /// Fetch exercises that belong to the current workout.
    func fetchExercises() {
        print("ExerciseViewModel: Initiating fetch of exercises for workout: \(workoutID)...")
        
        CloudKitManager.shared.fetchUserExercises(for: workoutID) { result in
            switch result {
            case .success(let records):
                print("ExerciseViewModel: Successfully fetched \(records.count) record(s).")
                var fetchedExercises: [Exercise] = []
                for record in records {
                    if let name = record["name"] as? String,
                       let sets = record["sets"] as? Int,
                       let reps = record["reps"] as? Int,
                       let weight = record["weight"] as? Double,
                       let timestamp = record["timestamp"] as? Date {
                        let exercise = Exercise(
                            name: name,
                            sets: sets,
                            reps: reps,
                            weight: weight,
                            timestamp: timestamp
                        )
                        fetchedExercises.append(exercise)
                    } else {
                        print("ExerciseViewModel: Could not parse record into Exercise.")
                    }
                }
                DispatchQueue.main.async {
                    self.exercises = fetchedExercises
                }
            case .failure(let error):
                print("ExerciseViewModel: Error fetching from CloudKit: \(error.localizedDescription)")
            }
        }
    }
    
    /// Delete exercises at the specified offsets.
    func deleteExercise(at offsets: IndexSet) {
        offsets.forEach { index in
            let exercise = exercises[index]
            // Remove locally.
            exercises.remove(at: index)
            
            // Optionally, delete from CloudKit.
            // Example:
            // CloudKitManager.shared.deleteUserExercise(with: exercise.ckRecordID) { result in ... }
        }
    }
}
