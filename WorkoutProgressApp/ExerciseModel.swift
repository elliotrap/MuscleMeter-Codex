//
//  ExerciseModel.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/11/25.
//

import SwiftUI
import CloudKit
import Foundation





import SwiftUI
import CloudKit
import Foundation

struct Exercise: Identifiable {
    let id = UUID()
    var name: String
    var sets: Int
    var reps: Int
    var setWeights: [Double]
    var setCompletions: [Bool]
    var setNotes: [String]    // <-- This is required
    var timestamp: Date
}

class ExerciseViewModel: ObservableObject {
    @Published var exercises: [Exercise] = []
    
    /// The workout that these exercises belong to.
    let workoutID: CKRecord.ID
    
    /// Reference to the private database
    private let privateDatabase = CKContainer.default().privateCloudDatabase

    // MARK: - Init
    init(workoutID: CKRecord.ID) {
        self.workoutID = workoutID
    }
    
    // MARK: - Add Exercise
    /// Add a new exercise associated with the given workout.
    func addExercise(
        name: String,
        sets: Int,
        reps: Int,
        setWeights: [Double],
        setCompletions: [Bool]
    ) {
        // 1) Log that we're about to create an exercise locally
        print("ExerciseViewModel: Creating exercise locally with:")
        print("  Name: \(name)")
        print("  Sets: \(sets)")
        print("  Reps: \(reps)")
        print("  setWeights: \(setWeights)")
        print("  setCompletions: \(setCompletions)")

        let setNotes = Array(repeating: "", count: sets)

        // 2) Create the Exercise instance
        let newExercise = Exercise(
            name: name,
            sets: sets,
            reps: reps,
            setWeights: setWeights,
            setCompletions: setCompletions,
            setNotes: setNotes,         // <-- Provide the array
            timestamp: Date()
        )
        exercises.insert(newExercise, at: 0)

        // 3) Log that we are about to save to CloudKit
        print("ExerciseViewModel: Saving new exercise to CloudKit...")

        // 4) Save to CloudKit
        self.saveUserExercise(
            name: name,
            sets: sets,
            reps: reps,
            setWeights: setWeights,
            setCompletions: setCompletions,
            workoutID: workoutID
        ) { result in
            switch result {
            case .success(let record):
                print("ExerciseViewModel: Successfully saved to CloudKit. Record ID:", record.recordID)
            case .failure(let error):
                print("ExerciseViewModel: Error saving to CloudKit:", error.localizedDescription)
            }
        }
    }
    
    // MARK: - Save to CloudKit
    /// Saves the exercise data into a "UserExercises" record.
    func saveUserExercise(
        name: String,
        sets: Int,
        reps: Int,
        setWeights: [Double],
        setCompletions: [Bool],
        workoutID: CKRecord.ID,
        completion: @escaping (Result<CKRecord, Error>) -> Void
    ) {
        // 1) Log that we're about to create a CKRecord
        print("CloudKitManager: Attempting to save new exercise:")
        print("  Name: \(name)")
        print("  Sets: \(sets)")
        print("  Reps: \(reps)")
        print("  setWeights: \(setWeights)")
        print("  setCompletions: \(setCompletions)")
        print("  Under workoutID: \(workoutID)")

        let record = CKRecord(recordType: "UserExercises")
        record["name"] = name as CKRecordValue
        record["sets"] = sets as CKRecordValue
        record["reps"] = reps as CKRecordValue
        record["setWeights"] = setWeights as CKRecordValue
        record["setCompletions"] = setCompletions.map { NSNumber(value: $0) } as CKRecordValue
        record["timestamp"] = Date() as CKRecordValue

        let workoutRef = CKRecord.Reference(recordID: workoutID, action: .none)
        record["workoutRef"] = workoutRef

        privateDatabase.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("CloudKitManager: Error saving exercise:", error.localizedDescription)
                    completion(.failure(error))
                } else if let savedRecord = savedRecord {
                    print("CloudKitManager: Successfully saved exercise with recordID:", savedRecord.recordID)
                    completion(.success(savedRecord))
                }
            }
        }
    }
    
    func updateExercise(
        recordID: CKRecord.ID,
        newWeights: [Double],
        newCompletions: [Bool],
        newNotes: [String]
    ) {
        print("ExerciseViewModel: Updating record \(recordID) in CloudKit...")
        privateDatabase.fetch(withRecordID: recordID) { record, error in
            if let error = error {
                print("Error fetching record for update:", error.localizedDescription)
                return
            }
            guard let record = record else { return }
            
            record["setWeights"] = newWeights as CKRecordValue
            record["setCompletions"] = newCompletions.map { NSNumber(value: $0) } as CKRecordValue
            record["setNotes"] = newNotes as CKRecordValue
            
            self.privateDatabase.save(record) { savedRecord, error in
                if let error = error {
                    print("Error saving updated record:", error.localizedDescription)
                } else if let savedRecord = savedRecord {
                    print("Successfully updated record:", savedRecord.recordID)
                }
            }
        }
    }
    // MARK: - Fetch Exercises
    /// Fetch exercises that belong to the current workout.
    func fetchExercises() {
        print("ExerciseViewModel: Fetching exercises from CloudKit for workout:", workoutID)
        
        CloudKitManager.shared.fetchUserExercises(for: workoutID) { result in
            switch result {
            case .failure(let error):
                print("Error fetching from CloudKit:", error.localizedDescription)
                
            case .success(let records):
                print("ExerciseViewModel: Successfully fetched \(records.count) record(s).")
                
                var fetchedExercises: [Exercise] = []
                
                for record in records {
                    // EXAMPLE PARSE SNIPPET:
                    if let name = record["name"] as? String,
                       let sets = record["sets"] as? Int,
                       let reps = record["reps"] as? Int {
                        
                        let weights = record["setWeights"] as? [Double] ?? Array(repeating: 0.0, count: sets)
                        let completionsArray = record["setCompletions"] as? [NSNumber] ?? []
                        let boolCompletions = completionsArray.map { $0.boolValue }
                        let notes = record["setNotes"] as? [String] ?? Array(repeating: "", count: sets)
                        let timestamp = record["timestamp"] as? Date ?? Date()
                        
                        let exercise = Exercise(
                            name: name,
                            sets: sets,
                            reps: reps,
                            setWeights: weights,
                            setCompletions: boolCompletions,
                            setNotes: notes,
                            timestamp: timestamp
                        )
                        fetchedExercises.append(exercise)
                    } else {
                        print("Skipping record: missing 'name', 'sets', or 'reps'")
                    }
                }
                
                // *** Must assign on main thread for UI to update
                DispatchQueue.main.async {
                    self.exercises = fetchedExercises
                }
            }
        }
    }
    // MARK: - Delete Exercise
    func deleteExercise(at offsets: IndexSet) {
        offsets.forEach { index in
            let exercise = exercises[index]
            // Remove locally.
            exercises.remove(at: index)
            
            // Optionally, delete from CloudKit by record ID if you store it.
            // e.g. if you had an exercise.ckRecordID
        }
    }
    // Warning DON'T ALWAYS CALL THIS FUNCTION
    func deleteAllExercises() {
        // 1) Fetch all exercises (with no specific workout filter) or only those for a specific workout
        let query = CKQuery(recordType: "UserExercises", predicate: NSPredicate(value: true))
        
        // If you're using private DB:
        let database = CKContainer.default().privateCloudDatabase
        
        // 2) Perform the query
        database.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                print("Error fetching exercises to delete:", error)
                return
            }
            guard let records = records else { return }
            
            // 3) Create an array of record IDs
            let recordIDs = records.map { $0.recordID }
            
            // 4) Delete them (batch delete)
            let deleteOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
            deleteOp.modifyRecordsResultBlock = { result in
                switch result {
                case .failure(let error):
                    print("Error deleting records:", error.localizedDescription)
                case .success:
                    print("Successfully deleted all exercises.")
                }
            }
            database.add(deleteOp)
        }
    }
}
