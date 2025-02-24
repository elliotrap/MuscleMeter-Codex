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
    let id = UUID()
    
    var recordID: CKRecord.ID?
    var name: String
    var sets: Int
    var reps: Int
    var setWeights: [Double] // this is set weights
    var setCompletions: [Bool]
    var setNotes: [String]
    var exerciseNote: String
    var setActualReps: [Int]
    var timestamp: Date

    var accentColorHex: String  

}

class ExerciseViewModel: ObservableObject {
    @Published var exercises: [Exercise] = []
    let workoutID: CKRecord.ID
    
    private let privateDatabase = CKContainer.default().privateCloudDatabase

    init(workoutID: CKRecord.ID) {
        self.workoutID = workoutID
    }
    
    func addExercise(
        name: String,
        sets: Int,
        reps: Int,
        setWeights: [Double],
        exerciseNote: String = "",
        setCompletions: [Bool]
    ) {
        print("ExerciseViewModel: Creating exercise locally with:")
        print("  Name: \(name)")
        print("  Sets: \(sets)")
        print("  Reps: \(reps)")
        print("  setWeights: \(setWeights)")
        print("  setCompletions: \(setCompletions)")

        let setNotes = Array(repeating: "", count: sets)
        let setActualReps = Array(repeating: 0, count: sets)
        
        let newExercise = Exercise(
            recordID: nil,
            name: name,
            sets: sets,
            reps: reps,
            setWeights: setWeights,
            setCompletions: setCompletions,
            setNotes: setNotes,
            exerciseNote: exerciseNote,
            setActualReps: setActualReps,
            timestamp: Date(), 
            accentColorHex: "#0000FF"
        )
        
        // 2) Insert locally
        exercises.append(newExercise)
        
        // 3) Save to CloudKit
        print("ExerciseViewModel: Saving new exercise to CloudKit...")
        self.saveUserExercise(
            name: name,
            sets: sets,
            reps: reps,
            setWeights: setWeights,
            setCompletions: setCompletions,
            setNotes: setNotes,            // <— Provide them
            setActualReps: setActualReps,  // <— Provide them
            workoutID: workoutID
        ) { result in
            switch result {
            case .success(let record):
                print("ExerciseViewModel: Successfully saved to CloudKit. Record ID:", record.recordID)
                
                // 4) Update local recordID so we can do updates/deletions later
                DispatchQueue.main.async {
                    if let index = self.exercises.firstIndex(where: { $0.id == newExercise.id }) {
                        self.exercises[index].recordID = record.recordID
                    }
                }
                
            case .failure(let error):
                print("ExerciseViewModel: Error saving to CloudKit:", error.localizedDescription)
            }
        }
    }
    
    // MARK: - Save to CloudKit
    func saveUserExercise(
        name: String,
        sets: Int,
        reps: Int,
        setWeights: [Double],
        setCompletions: [Bool],
        setNotes: [String],
        setActualReps: [Int],
        workoutID: CKRecord.ID,
        completion: @escaping (Result<CKRecord, Error>) -> Void
    ) {
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
        record["timestamp"] = Date() as CKRecordValue
        record["setWeights"] = setWeights as CKRecordValue
        record["setCompletions"] = setCompletions.map { NSNumber(value: $0) } as CKRecordValue
        record["setNotes"] = setNotes as CKRecordValue
        record["setActualReps"] = setActualReps.map { NSNumber(value: $0) } as CKRecordValue
        
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
    
    // MARK: - Fetch Exercises
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
                    if let name = record["name"] as? String,
                       let sets = record["sets"] as? Int,
                       let reps = record["reps"] as? Int {
                        
                        // 1) Parse setWeights, completions, notes
                        let weights = record["setWeights"] as? [Double] ?? Array(repeating: 0.0, count: sets)
                        let completionsArray = record["setCompletions"] as? [NSNumber] ?? []
                        let boolCompletions = completionsArray.map { $0.boolValue }
                        let notes = record["setNotes"] as? [String] ?? Array(repeating: "", count: sets)
                        let timestamp = record["timestamp"] as? Date ?? Date()
                        let exerciseNote = record["exerciseNote"] as? String ?? ""
                        
                        // 2) Parse actualReps, then pad/slice to ensure it has `sets` elements
                        let actualRepsArray = record["setActualReps"] as? [NSNumber] ?? []
                        var actualReps = actualRepsArray.map { $0.intValue }
                        
                        if actualReps.count < sets {
                            let needed = sets - actualReps.count
                            actualReps.append(contentsOf: Array(repeating: 0, count: needed))
                        }
                        if actualReps.count > sets {
                            actualReps = Array(actualReps.prefix(sets))
                        }
                        
                        // 3) Parse accent color (hex string) from record; default to blue ("#0000FF") if not set.
                        let accentColorHex = record["accentColor"] as? String ?? "#0000FF"
                        
                        // 4) Create the Exercise with the new accentColorHex property.
                        let exercise = Exercise(
                            recordID: record.recordID,
                            name: name,
                            sets: sets,
                            reps: reps,
                            setWeights: weights,
                            setCompletions: boolCompletions,
                            setNotes: notes,
                            exerciseNote: exerciseNote,
                            setActualReps: actualReps,
                            timestamp: timestamp, accentColorHex: accentColorHex
                        )
                        
                        fetchedExercises.append(exercise)
                    } else {
                        print("Skipping record: missing 'name', 'sets', or 'reps'")
                    }
                }
                
                // 5) Assign on the main thread so the UI updates
                DispatchQueue.main.async {
                    self.exercises = fetchedExercises
                }
            }
        }
    }
    
    func updateExercise(
        recordID: CKRecord.ID,
        newName: String? = nil,
        newSets: Int? = nil,
        newReps: Int? = nil,
        newAccentColor: String? = nil,
        newNote: String? = nil,
        newWeights: [Double]? = nil,
        newCompletions: [Bool]? = nil,
        newSetNotes: [String]? = nil,
        newActualReps: [Int]? = nil
    ) {
        print("ExerciseViewModel: Updating record \(recordID) with multiple fields if provided.")
        
        privateDatabase.fetch(withRecordID: recordID) { record, error in
            if let error = error {
                print("Error fetching record for update:", error.localizedDescription)
                return
            }
            guard let record = record else {
                print("No record found for ID:", recordID)
                return
            }
            
            if let newName = newName {
                record["name"] = newName as CKRecordValue
            }
            
            if let newSets = newSets {
                record["sets"] = newSets as CKRecordValue
                
                // Retrieve current arrays from the record (or use empty arrays if not found)
                let currentWeights = record["setWeights"] as? [Double] ?? []
                let currentCompletions = (record["setCompletions"] as? [NSNumber])?.map { $0.boolValue } ?? []
                let currentNotes = record["setNotes"] as? [String] ?? []
                let currentActualReps = (record["setActualReps"] as? [NSNumber])?.map { $0.intValue } ?? []
                
                // Debug: Print counts before resizing
                print("updateExercise: newSets = \(newSets)")
                print("Current array counts: weights: \(currentWeights.count), completions: \(currentCompletions.count), notes: \(currentNotes.count), actualReps: \(currentActualReps.count)")
                
                // Resize arrays to newSets count:
                let updatedWeights = self.resizeArray(currentWeights, to: newSets, defaultValue: 0.0)
                let updatedCompletions = self.resizeArray(currentCompletions, to: newSets, defaultValue: false)
                let updatedNotes = self.resizeArray(currentNotes, to: newSets, defaultValue: "")
                let updatedActualReps = self.resizeArray(currentActualReps, to: newSets, defaultValue: 0)
                
                // Debug: Print counts after resizing
                print("After resizing arrays: weights: \(updatedWeights.count), completions: \(updatedCompletions.count), notes: \(updatedNotes.count), actualReps: \(updatedActualReps.count)")
                
                record["setWeights"] = updatedWeights as CKRecordValue
                record["setCompletions"] = updatedCompletions.map { NSNumber(value: $0) } as CKRecordValue
                record["setNotes"] = updatedNotes as CKRecordValue
                record["setActualReps"] = updatedActualReps.map { NSNumber(value: $0) } as CKRecordValue
            }
            
            if let newReps = newReps {
                record["reps"] = newReps as CKRecordValue
            }
            if let newAccentColor = newAccentColor {
                record["accentColor"] = newAccentColor as CKRecordValue
            }
            if let newNote = newNote {
                record["exerciseNote"] = newNote as CKRecordValue
            }
            if let newWeights = newWeights {
                record["setWeights"] = newWeights as CKRecordValue
            }
            if let newCompletions = newCompletions {
                record["setCompletions"] = newCompletions.map { NSNumber(value: $0) } as CKRecordValue
            }
            if let newSetNotes = newSetNotes {
                record["setNotes"] = newSetNotes as CKRecordValue
            }
            if let newActualReps = newActualReps {
                record["setActualReps"] = newActualReps.map { NSNumber(value: $0) } as CKRecordValue
            }
            
            self.privateDatabase.save(record) { savedRecord, error in
                if let error = error {
                    print("Error saving updated record:", error.localizedDescription)
                } else if let savedRecord = savedRecord {
                    print("Successfully updated record in CloudKit:", savedRecord.recordID)
                    DispatchQueue.main.async {
                        if let index = self.exercises.firstIndex(where: { $0.recordID == recordID }) {
                            // Update local model accordingly:
                            if let newName = newName {
                                self.exercises[index].name = newName
                            }
                            if let newSets = newSets {
                                self.exercises[index].sets = newSets
                                // Also update local arrays:
                                self.exercises[index].setWeights = self.resizeArray(self.exercises[index].setWeights, to: newSets, defaultValue: 0.0)
                                self.exercises[index].setCompletions = self.resizeArray(self.exercises[index].setCompletions, to: newSets, defaultValue: false)
                                self.exercises[index].setNotes = self.resizeArray(self.exercises[index].setNotes, to: newSets, defaultValue: "")
                                self.exercises[index].setActualReps = self.resizeArray(self.exercises[index].setActualReps, to: newSets, defaultValue: 0)
                                
                                // Debug: Print updated local model array counts
                                print("Local model updated arrays for exercise \(self.exercises[index].name):")
                                print("  Weights count: \(self.exercises[index].setWeights.count)")
                                print("  Completions count: \(self.exercises[index].setCompletions.count)")
                                print("  Notes count: \(self.exercises[index].setNotes.count)")
                                print("  ActualReps count: \(self.exercises[index].setActualReps.count)")
                            }
                            if let newReps = newReps {
                                self.exercises[index].reps = newReps
                            }
                            if let newAccentColor = newAccentColor {
                                self.exercises[index].accentColorHex = newAccentColor
                            }
                            if let newNote = newNote {
                                self.exercises[index].exerciseNote = newNote
                            }
                            if let newWeights = newWeights {
                                self.exercises[index].setWeights = newWeights
                            }
                            if let newCompletions = newCompletions {
                                self.exercises[index].setCompletions = newCompletions
                            }
                            if let newSetNotes = newSetNotes {
                                self.exercises[index].setNotes = newSetNotes
                            }
                            if let newActualReps = newActualReps {
                                self.exercises[index].setActualReps = newActualReps
                            }
                        }
                    }
                }
            }
        }
    }

    func resizeArray<T>(_ array: [T], to count: Int, defaultValue: T) -> [T] {
        if array.count < count {
            return array + Array(repeating: defaultValue, count: count - array.count)
        } else if array.count > count {
            return Array(array.prefix(count))
        } else {
            return array
        }
    }


    
    // MARK: - Resize Arrays to Match 'sets'
    private func resizeArraysForSets(index: Int, newSets: Int) {
        guard index < exercises.count else { return }
        
        var exercise = exercises[index]
        
        // Resize setWeights
        if exercise.setWeights.count < newSets {
            let additional = newSets - exercise.setWeights.count
            exercise.setWeights.append(contentsOf: Array(repeating: 0.0, count: additional))
        } else if exercise.setWeights.count > newSets {
            exercise.setWeights = Array(exercise.setWeights.prefix(newSets))
        }
        
        // Resize setActualReps
        if exercise.setActualReps.count < newSets {
            let additional = newSets - exercise.setActualReps.count
            exercise.setActualReps.append(contentsOf: Array(repeating: 0, count: additional))
        } else if exercise.setActualReps.count > newSets {
            exercise.setActualReps = Array(exercise.setActualReps.prefix(newSets))
        }
        
        // Resize setCompletions
        if exercise.setCompletions.count < newSets {
            let additional = newSets - exercise.setCompletions.count
            exercise.setCompletions.append(contentsOf: Array(repeating: false, count: additional))
        } else if exercise.setCompletions.count > newSets {
            exercise.setCompletions = Array(exercise.setCompletions.prefix(newSets))
        }
        
        // Resize setNotes
        if exercise.setNotes.count < newSets {
            let additional = newSets - exercise.setNotes.count
            exercise.setNotes.append(contentsOf: Array(repeating: "", count: additional))
        } else if exercise.setNotes.count > newSets {
            exercise.setNotes = Array(exercise.setNotes.prefix(newSets))
        }
        
        // Update the exercise in your local array (to trigger SwiftUI updates)
        exercises[index] = exercise
    }

    


    

    
    // MARK: - Delete Exercise
    func deleteExercise(at offsets: IndexSet) {
        offsets.forEach { index in
            let exercise = exercises[index]
            exercises.remove(at: index)  // Remove locally first
            
            // If the exercise has a recordID, we can delete it in CloudKit too
            if let recordID = exercise.recordID {
                privateDatabase.delete(withRecordID: recordID) { _, error in
                    if let error = error {
                        print("Error deleting exercise from CloudKit:", error.localizedDescription)
                    } else {
                        print("Successfully deleted exercise from CloudKit with recordID:", recordID)
                    }
                }
            }
        }
    }
    
    
    // MARK: - Delete All Exercises (Dev Only)
    func deleteAllExercises() {
        let query = CKQuery(recordType: "UserExercises", predicate: NSPredicate(value: true))
        
        privateDatabase.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                print("Error fetching exercises to delete:", error)
                return
            }
            guard let records = records else { return }
            
            let recordIDs = records.map { $0.recordID }
            
            let deleteOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
            deleteOp.modifyRecordsResultBlock = { result in
                switch result {
                case .failure(let error):
                    print("Error deleting records:", error.localizedDescription)
                case .success:
                    print("Successfully deleted all exercises.")
                }
            }
            self.privateDatabase.add(deleteOp)
        }
    }
}
