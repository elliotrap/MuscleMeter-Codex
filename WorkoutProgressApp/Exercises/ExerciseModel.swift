//
//  ExerciseModel.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/11/25.
//

import SwiftUI
import Combine
import CloudKit
import Foundation



struct Exercise: Identifiable {
    let id = UUID()
    
    var recordID: CKRecord.ID?
    var name: String
    var sets: Int
    var reps: Int
    var setWeights: [Double]
    var setCompletions: [Bool]
    var setNotes: [String]
    var exerciseNote: String
    var setActualReps: [Int]
    var timestamp: Date
    var accentColorHex: String
    var sortIndex: Int
    var tempID: String?
}
extension Exercise: Equatable {
    static func == (lhs: Exercise, rhs: Exercise) -> Bool {
        // Compare only the fields that matter for UI diffing
        lhs.recordID?.recordName == rhs.recordID?.recordName &&
        lhs.name                 == rhs.name &&
        lhs.sets                 == rhs.sets &&
        lhs.reps                 == rhs.reps &&
        lhs.setWeights           == rhs.setWeights &&
        lhs.setCompletions       == rhs.setCompletions &&
        lhs.setNotes             == rhs.setNotes &&
        lhs.exerciseNote         == rhs.exerciseNote &&
        lhs.setActualReps        == rhs.setActualReps &&
        lhs.accentColorHex       == rhs.accentColorHex &&
        lhs.sortIndex            == rhs.sortIndex
    }
}

class ExerciseViewModel: ObservableObject {
    
    @Published var hasCompletedInitialFetch = false
    @Published var exercises: [Exercise] = []
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil
    @Published var refreshID = UUID()
    @Published var lastFetchTime = Date()
    @Published var stateVersion = 0
    @Published var lastFetchedWorkoutID: String?
    
    // Track the current fetch operation to prevent race conditions
    var currentFetchID: String?
    let workoutID: CKRecord.ID
    
    
    private static var operationTimeouts: [String: Timer] = [:]
    
    
    private var operationQueue = OperationQueue()
    private var updateOperations: [String: Operation] = [:]
    private var updateQueue = UpdateQueue()
    private let privateDatabase = CKContainer.default().privateCloudDatabase
    private var isFetchingExercises = false
    private var pendingUpdates: [String: [Bool]] = [:]

    @MainActor
    var fetchTask: Task<Void, Error>?      // put this with your other @Published vars
    
    // MARK: - Init
    init(workoutID: CKRecord.ID) {
        self.workoutID = workoutID
    }
    
    // Get the most up-to-date completions for an exercise
    func getCurrentCompletions(for exercise: Exercise) -> [Bool] {
        guard let recordID = exercise.recordID else { return exercise.setCompletions }
        // Use recordName as the dictionary key
        return pendingUpdates[recordID.recordName] ?? exercise.setCompletions
    }
    
    // MARK: - CloudKit Notification Handling
    // Subscribe to CloudKit changes for real-time updates
    func subscribeToCloudKitChanges() {
        // Create a subscription to the UserExercises record type
        let predicate = NSPredicate(format: "workoutRef == %@", CKRecord.Reference(recordID: workoutID, action: .none))
        let subscription = CKQuerySubscription(
            recordType: "UserExercises",
            predicate: predicate,
            subscriptionID: "exercises-\(workoutID.recordName)",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        // Configure the notification
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // For silent notifications
        subscription.notificationInfo = notificationInfo
        
        // Save the subscription
        privateDatabase.save(subscription) { _, error in
            if let error = error {
                print("Error creating subscription: \(error.localizedDescription)")
            } else {
                print("Successfully subscribed to exercise changes")
            }
        }
        
        // Register for remote notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteNotification),
            name: NSNotification.Name("receivedCloudKitNotification"),
            object: nil
        )
    }
    
    @MainActor @objc func handleRemoteNotification(_ notification: Notification) {
        // Refresh data when a CloudKit change notification is received
        fetchExercises()
    }
    
    
    // Make sure to call this when the view disappears
    func unsubscribeFromCloudKitChanges() {
        privateDatabase.delete(withSubscriptionID: "exercises-\(workoutID.recordName)") { _, error in
            if let error = error {
                print("Error removing subscription: \(error.localizedDescription)")
            } else {
                print("Successfully unsubscribed from exercise changes")
            }
        }
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("receivedCloudKitNotification"), object: nil)
    }
    
    
    func addExercise(
        name: String,
        sets: Int,
        reps: Int,
        setWeights: [Double],
        exerciseNote: String = "",
        setCompletions: [Bool],
        completion: (() -> Void)? = nil
    ) {
        print("🏋️‍♂️ ExerciseViewModel: Creating exercise with name: \(name), sets: \(sets)")
        
        let setNotes = Array(repeating: "", count: sets)
        let setActualReps = Array(repeating: 0, count: sets)
        
        // Create a temporary ID to track this exercise before it gets a CloudKit recordID
        let temporaryID = UUID().uuidString
        
        // Log current exercises
        print("🏋️‍♂️ Current exercises count: \(exercises.count)")
        
        // Create the new Exercise
        let newSortIndex = (exercises.map { $0.sortIndex }.max() ?? -1) + 1
        var newExercise = Exercise(
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
            accentColorHex: "#0000FF",
            sortIndex: newSortIndex
        )
        
        // Add tempID to track the exercise
        newExercise.tempID = temporaryID
        
        // Add to local array IMMEDIATELY for instant UI feedback
        DispatchQueue.main.async {
            self.isLoading = true
            print("🏋️‍♂️ Setting isLoading to true")
            
            // Add to local array first
            var updatedExercises = self.exercises
            updatedExercises.append(newExercise)
            self.exercises = updatedExercises
            
            // Force UI refresh
            self.refreshID = UUID()
            
            print("🏋️‍♂️ Added exercise locally (temp ID: \(temporaryID)). Count: \(self.exercises.count)")
        }
        
        // Then SAVE to CloudKit
        print("🏋️‍♂️ Saving exercise to CloudKit...")
        self.self.saveUserExercise(
            name: name,
            sets: sets,
            reps: reps,
            setWeights: setWeights,
            setCompletions: setCompletions,
            setNotes: setNotes,
            setActualReps: setActualReps,
            workoutID: workoutID,
            sortIndex: newSortIndex      
        ) { result in
            switch result {
            case .success(let record):
                print("🏋️‍♂️ Successfully saved to CloudKit. Record ID: \(record.recordID)")
                
                DispatchQueue.main.async {
                    // Find and update the local exercise with the real CloudKit recordID
                    if let index = self.exercises.firstIndex(where: { $0.tempID == temporaryID }) {
                        self.exercises[index].recordID = record.recordID
                        print("🏋️‍♂️ Updated local exercise with CloudKit recordID")
                        
                        // Force UI refresh again
                        self.refreshID = UUID()
                    } else {
                        print("🏋️‍♂️ Warning: Could not find local exercise with tempID: \(temporaryID)")
                    }
                }
                
                // After a delay, fetch from CloudKit to ensure everything is in sync
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("🏋️‍♂️ Performing sync fetch from CloudKit...")
                    
                    // Fetch to ensure consistency with CloudKit
                    self.fetchExercises { fetchSuccess in
                        DispatchQueue.main.async {
                            self.isLoading = false
                            
                            if fetchSuccess {
                                print("🏋️‍♂️ Sync fetch completed successfully, \(self.exercises.count) exercises")
                            } else {
                                print("🏋️‍♂️ Sync fetch failed, but local data already updated")
                            }
                            
                            // Emit notification for listeners
                            NotificationCenter.default.post(
                                name: Notification.Name("ExercisesUpdated"),
                                object: nil,
                                userInfo: ["count": self.exercises.count]
                            )
                            
                            // Call completion handler
                            completion?()
                        }
                    }
                }
                
            case .failure(let error):
                print("🏋️‍♂️ Error saving to CloudKit: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    // Even on CloudKit error, keep the local exercise
                    // but mark it with an error if desired
                    if let index = self.exercises.firstIndex(where: { $0.tempID == temporaryID }) {
                        // Optional: Mark exercise as having sync error
                        // self.exercises[index].syncError = true
                        print("🏋️‍♂️ Exercise remains in local array but failed to save to CloudKit")
                    }
                    
                    self.error = error
                    self.isLoading = false
                    
                    // Call completion handler
                    completion?()
                }
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
        sortIndex: Int,
        completion: @escaping (Result<CKRecord, Error>) -> Void
    ) {
        print("CloudKitManager: Attempting to save new exercise with sortIndex \(sortIndex)")

        let record = CKRecord(recordType: "UserExercises")
        record["name"]            = name as CKRecordValue
        record["sets"]            = sets as CKRecordValue
        record["reps"]            = reps as CKRecordValue
        record["timestamp"]       = Date() as CKRecordValue
        record["setWeights"]      = setWeights as CKRecordValue
        record["setCompletions"]  = setCompletions.map { NSNumber(value: $0) } as CKRecordValue
        record["setNotes"]        = setNotes as CKRecordValue
        record["setActualReps"]   = setActualReps.map { NSNumber(value: $0) } as CKRecordValue
        record["sortIndex"]       = sortIndex as CKRecordValue          // 🆕 persisted
        record["workoutRef"]      = CKRecord.Reference(recordID: workoutID, action: .none)

        privateDatabase.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("CloudKitManager: Error saving exercise:", error.localizedDescription)
                    completion(.failure(error))
                } else if let savedRecord = savedRecord {
                    print("CloudKitManager: Saved exercise ▸ \(savedRecord.recordID.recordName)")
                    completion(.success(savedRecord))
                }
            }
        }
    }
    
    // MARK: - Exercise Sort Index Update Function
    // Fixed version that correctly updates local model
    func updateExerciseSortIndices(_ exercises: [Exercise]) {
        print("📊 SORT: Beginning to update sort indices for \(exercises.count) exercises")

        // Gather record IDs to update
        let recordIDsToFetch = exercises.compactMap { $0.recordID }
        guard !recordIDsToFetch.isEmpty else {
            print("📊 SORT: No exercise records to update")
            return
        }

        // Fetch actual records first from CloudKit
        let fetchOp = CKFetchRecordsOperation(recordIDs: recordIDsToFetch)
        fetchOp.fetchRecordsCompletionBlock = { [weak self] recordDict, error in
            guard let self = self else { return }
            if let error = error {
                print("❌ SORT: Error fetching exercise records for sort index update: \(error.localizedDescription)")
                return
            }
            guard let fetchedRecords = recordDict else {
                print("❌ SORT: No records returned from fetch")
                return
            }

            var recordsToSave: [CKRecord] = []
            var sortChanges: [(name: String, oldIndex: Int, newIndex: Int)] = []

            for (index, exercise) in exercises.enumerated() {
                guard let recordID = exercise.recordID,
                      let record = fetchedRecords[recordID] else {
                    print("⚠️ SORT: Exercise \(exercise.name) could not fetch record, skipping")
                    continue
                }

                // Track/log changes
                let oldIndex = (record["sortIndex"] as? Int) ?? -1
                sortChanges.append((name: exercise.name, oldIndex: oldIndex, newIndex: index))

                // Update the record's sortIndex
                record["sortIndex"] = index as CKRecordValue
                recordsToSave.append(record)

                // Update the local model using the array reference
                if oldIndex != index, let localIndex = self.exercises.firstIndex(where: { $0.id == exercise.id }) {
                    self.exercises[localIndex].sortIndex = index
                }
            }

            // Log the sort changes
            for change in sortChanges {
                if change.oldIndex != change.newIndex {
                    print("📊 SORT: Moving \(change.name) from index \(change.oldIndex) to \(change.newIndex)")
                }
            }

            // No records to save after all?
            if recordsToSave.isEmpty {
                print("📊 SORT: No exercise records to update after fetch")
                return
            }

            // Save the changed records as a batch operation
            let modifyOp = CKModifyRecordsOperation(recordsToSave: recordsToSave)
            modifyOp.savePolicy = .changedKeys

            modifyOp.modifyRecordsCompletionBlock = { [weak self] savedRecords, _, error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ SORT: Error batch updating exercise indices: \(error.localizedDescription)")
                        if let saved = savedRecords, !saved.isEmpty {
                            print("📊 SORT: Partially successful - updated \(saved.count) of \(recordsToSave.count) records")
                        }
                        return
                    }
                    print("✅ SORT: Successfully updated \(savedRecords?.count ?? 0) exercise indices")
                    self.sortExercises()
                    self.objectWillChange.send()
                    self.refreshID = UUID()
                }
            }

            self.privateDatabase.add(modifyOp)
        }
        self.privateDatabase.add(fetchOp)
    }
    
    

    // MARK: - Helper function to ensure exercises are always sorted correctly
    func sortExercises() {
        // Capture the pre-sorted state for logging
        let preSort = self.exercises.map { "\($0.name) [\($0.sortIndex)]" }
        
        // Sort by sortIndex
        self.exercises.sort { $0.sortIndex < $1.sortIndex }
        
        // Capture the post-sorted state
        let postSort = self.exercises.map { "\($0.name) [\($0.sortIndex)]" }
        
        // Only log if the order changed
        if preSort != postSort {
            print("📊 SORT: Exercise order changed after sorting:")
            print("  BEFORE: \(preSort.joined(separator: ", "))")
            print("  AFTER: \(postSort.joined(separator: ", "))")
        } else {
            print("📊 SORT: Exercise order unchanged after sorting")
        }
    }
    
    
    // Enhanced fetchExercises method with optimized behavior
    // MARK: - Fetch exercises (flash‑free, efficient)
    @MainActor
    func fetchExercises(
        forceRefresh: Bool = false,
        completion: ((Bool) -> Void)? = nil
    ) {
        // 1. Prevent duplicate concurrent fetches
        guard !isFetchingExercises else {
            print("🏋️‍♂️ Duplicate fetch ignored")
            completion?(false)
            return
        }
        isFetchingExercises = true
        defer { isFetchingExercises = false }   // always reset

        // 2. Decide if we even need to hit CloudKit
        let sameWorkout   = lastFetchedWorkoutID == workoutID.recordName
        let needRefresh   = forceRefresh || !sameWorkout || exercises.isEmpty
        guard needRefresh else {
            print("🏋️‍♂️ Using in‑memory cache (\(exercises.count) items)")
            completion?(true)
            return
        }

        isLoading = true                        // spinner overlay (don’t clear list!)

        // 3. Kick off CloudKit request
        CloudKitManager.shared.fetchUserExercises(
            for: workoutID,
            forceRefresh: forceRefresh,
            maxRetries: 1                       // lightweight retry
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {

            case .failure(let error):
                print("🏋️‍♂️ CloudKit error:", error.localizedDescription)
                self.error     = error
                self.isLoading = false
                completion?(false)

            case .success(let records):
                // ---- Parse records → [Exercise] ----
                let parsed = records.compactMap { Self.exercise(from: $0) }
                                     .sorted { $0.sortIndex < $1.sortIndex }

                // 4. Only mutate state if there is a real difference
                if parsed != self.exercises { // 
                    withAnimation(.easeInOut) {          // smooth diff‑animate
                        self.exercises = parsed
                    }
                    print("🏋️‍♂️ List updated (\(parsed.count) items)")
                } else {
                    print("🏋️‍♂️ No diff – UI unchanged")
                }

                self.lastFetchedWorkoutID = self.workoutID.recordName
                self.isLoading            = false
                completion?(true)
            }
        }
    }
    private static func exercise(from record: CKRecord) -> Exercise? {
        guard
            let name  = record["name"]  as? String,
            let sets  = record["sets"]  as? Int,
            let reps  = record["reps"]  as? Int
        else { return nil }

        let weights       = record["setWeights"]     as? [Double]       ?? Array(repeating: 0, count: sets)
        let completions   = (record["setCompletions"] as? [NSNumber]   ?? []).map(\.boolValue)
        let notes         = record["setNotes"]       as? [String]       ?? Array(repeating: "", count: sets)
        let actualRepNums = (record["setActualReps"] as? [NSNumber]     ?? []).map(\.intValue)
        let paddedReps    = actualRepNums + Array(repeating: 0, count: max(0, sets - actualRepNums.count))

        return Exercise(
            recordID:        record.recordID,
            name:            name,
            sets:            sets,
            reps:            reps,
            setWeights:      weights,
            setCompletions:  completions,
            setNotes:        notes,
            exerciseNote:    record["exerciseNote"] as? String ?? "",
            setActualReps:   Array(paddedReps.prefix(sets)),
            timestamp:       record["timestamp"]     as? Date ?? Date(),
            accentColorHex:  record["accentColorHex"]   as? String ?? "#0000FF",
            sortIndex:       record["sortIndex"]     as? Int  ?? 0
        )
    }
    
    // Correct implementation of cancelFetches for your ExerciseViewModel
    func cancelFetches() {
        print("🏋️‍♂️ Cancelling any in-progress fetches")
        
        // Cancel CloudKit operation first
        let workoutIDString = self.workoutID.recordName
        CloudKitManager.shared.cancelFetch(for: workoutIDString)
        
        // Then update local state
        self.currentFetchID = nil
        self.isLoading = false
        self.isFetchingExercises = false
    }


    
    // Add this method to your ExerciseViewModel
    @MainActor func fetchExercisesOnce(completion: @escaping (Bool) -> Void) {
        // Check if we already have exercises and don't need to fetch
        if !exercises.isEmpty {
            print("🏋️‍♂️ Already have \(exercises.count) exercises loaded, skipping fetch")
            completion(true)
            return
        }
        
        // Only do the fetch if we don't have exercises yet
        fetchExercises(completion: completion)
    }
    
    // Track active update operations to prevent duplicates
    private static var operationsInProgress = Set<String>()

    // Add this static method to your ExerciseViewModel
    static func clearOperationsForWorkout(_ workoutID: String) {
        // Find all operations related to this workout and remove them
        let keysToRemove = operationsInProgress.filter { $0.contains(workoutID) }
        for key in keysToRemove {
            operationsInProgress.remove(key)
            operationTimeouts[key]?.invalidate()
            operationTimeouts.removeValue(forKey: key)
        }
        print("🧹 Cleared \(keysToRemove.count) in-progress operations for workout \(workoutID)")
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
        let recordIDString = recordID.recordName
        
        // If this is a checkbox update (completions), handle it optimistically
        if newCompletions != nil &&
           newName == nil && newSets == nil && newReps == nil &&
           newAccentColor == nil && newNote == nil && newWeights == nil &&
           newSetNotes == nil && newActualReps == nil {
            
            handleCompletionsUpdate(recordID: recordID, newCompletions: newCompletions!)
            return
        }
        
        // For other types of updates, use your existing flow
        // CRITICAL: Prevent duplicate operations on the same record
        guard !Self.operationsInProgress.contains(recordIDString) else {
            print("⚠️ Skipping duplicate update for \(recordIDString) - operation already in progress")
            return
        }
        
        // Mark this record as having an update in progress
        Self.operationsInProgress.insert(recordIDString)
        print("🔄 Starting update for record \(recordIDString)")
        
        // Add stack trace to see what's calling this function
        let stackSymbols = Thread.callStackSymbols
        print("🔍 updateExercise called for \(recordIDString) from:\n\(stackSymbols[1...min(3, stackSymbols.count-1)].joined(separator: "\n"))")
        
        // In updateExercise
        // Invalidate existing timer if present
        if let existingTimer = Self.operationTimeouts[recordIDString] {
            existingTimer.invalidate()
            Self.operationTimeouts.removeValue(forKey: recordIDString)
        }

        // Create new timer
        Self.operationTimeouts[recordIDString] = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            print("⚠️ Operation timeout for \(recordIDString) - removing from in-progress")
            DispatchQueue.main.async {
                Self.operationsInProgress.remove(recordIDString)
                Self.operationTimeouts.removeValue(forKey: recordIDString)
            }
        }
        
        // Update local model immediately for better UI responsiveness
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                Self.operationsInProgress.remove(recordIDString)
                Self.operationTimeouts[recordIDString]?.invalidate()
                Self.operationTimeouts.removeValue(forKey: recordIDString)
                return
            }
            
            if let index = self.exercises.firstIndex(where: { $0.recordID == recordID }) {
                // Update local model with new values
                if let newName = newName {
                    self.exercises[index].name = newName
                }
                if let newSets = newSets {
                    self.exercises[index].sets = newSets
                    self.resizeArraysForSets(index: index, newSets: newSets)
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
                
                // Trigger UI updates
                self.refreshID = UUID()
                self.objectWillChange.send()
            }
        }
        
        // Use Timer instead of DispatchQueue for delay to avoid syntax issues
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else {
                DispatchQueue.main.async {
                    Self.operationsInProgress.remove(recordIDString)
                    Self.operationTimeouts[recordIDString]?.invalidate()
                    Self.operationTimeouts.removeValue(forKey: recordIDString)
                }
                return
            }
            
            self.privateDatabase.fetch(withRecordID: recordID) { record, error in
                // Always remove from in-progress set when done, even if there's an error
                defer {
                    DispatchQueue.main.async {
                        Self.operationsInProgress.remove(recordIDString)
                        Self.operationTimeouts[recordIDString]?.invalidate()
                        Self.operationTimeouts.removeValue(forKey: recordIDString)
                    }
                }
                
                if let error = error {
                    print("🔄 Error fetching record for update: \(error.localizedDescription)")
                    return
                }
                
                guard let record = record else {
                    print("🔄 No record found for ID: \(recordID)")
                    return
                }
                
                // Track if any changes were made
                var recordChanged = false
                
                // Update record fields
                if let newName = newName {
                    record["name"] = newName as CKRecordValue
                    recordChanged = true
                }
                
                if let newSets = newSets {
                    record["sets"] = newSets as CKRecordValue
                    recordChanged = true
                    
                    // Handle array resizing safely
                    do {
                        // Get current arrays
                        let currentWeights = record["setWeights"] as? [Double] ?? []
                        let currentCompletions = (record["setCompletions"] as? [NSNumber])?.map { $0.boolValue } ?? []
                        let currentNotes = record["setNotes"] as? [String] ?? []
                        let currentActualReps = (record["setActualReps"] as? [NSNumber])?.map { $0.intValue } ?? []
                        
                        // Resize arrays
                        var updatedWeights = currentWeights
                        var updatedCompletions = currentCompletions
                        var updatedNotes = currentNotes
                        var updatedActualReps = currentActualReps
                        
                        // Resize weights
                        if updatedWeights.count < newSets {
                            updatedWeights.append(contentsOf: Array(repeating: 0.0, count: newSets - updatedWeights.count))
                        } else if updatedWeights.count > newSets {
                            updatedWeights = Array(updatedWeights.prefix(newSets))
                        }
                        
                        // Resize completions
                        if updatedCompletions.count < newSets {
                            updatedCompletions.append(contentsOf: Array(repeating: false, count: newSets - updatedCompletions.count))
                        } else if updatedCompletions.count > newSets {
                            updatedCompletions = Array(updatedCompletions.prefix(newSets))
                        }
                        
                        // Resize notes
                        if updatedNotes.count < newSets {
                            updatedNotes.append(contentsOf: Array(repeating: "", count: newSets - updatedNotes.count))
                        } else if updatedNotes.count > newSets {
                            updatedNotes = Array(updatedNotes.prefix(newSets))
                        }
                        
                        // Resize actualReps
                        if updatedActualReps.count < newSets {
                            updatedActualReps.append(contentsOf: Array(repeating: 0, count: newSets - updatedActualReps.count))
                        } else if updatedActualReps.count > newSets {
                            updatedActualReps = Array(updatedActualReps.prefix(newSets))
                        }
                        
                        // Update record with resized arrays
                        record["setWeights"] = updatedWeights as CKRecordValue
                        record["setCompletions"] = updatedCompletions.map { NSNumber(value: $0) } as CKRecordValue
                        record["setNotes"] = updatedNotes as CKRecordValue
                        record["setActualReps"] = updatedActualReps.map { NSNumber(value: $0) } as CKRecordValue
                    } catch {
                        print("🔄 Error resizing arrays: \(error)")
                    }
                }
                
                // Update other fields
                if let newReps = newReps {
                    record["reps"] = newReps as CKRecordValue
                    recordChanged = true
                }
                if let newAccentColor = newAccentColor {
                    record["accentColorHex"] = newAccentColor as CKRecordValue
                    recordChanged = true
                }
                if let newNote = newNote {
                    record["exerciseNote"] = newNote as CKRecordValue
                    recordChanged = true
                }
                if let newWeights = newWeights {
                    record["setWeights"] = newWeights as CKRecordValue
                    recordChanged = true
                }
                if let newCompletions = newCompletions {
                    record["setCompletions"] = newCompletions.map { NSNumber(value: $0) } as CKRecordValue
                    recordChanged = true
                }
                if let newSetNotes = newSetNotes {
                    record["setNotes"] = newSetNotes as CKRecordValue
                    recordChanged = true
                }
                if let newActualReps = newActualReps {
                    record["setActualReps"] = newActualReps.map { NSNumber(value: $0) } as CKRecordValue
                    recordChanged = true
                }
                
                // Skip saving if no changes were made
                if !recordChanged {
                    print("🔄 No changes needed for record \(recordID)")
                    return
                }
                
                // Save to CloudKit
                print("🔄 Saving changes to CloudKit for record \(recordID)")
                self.privateDatabase.save(record) { savedRecord, error in
                    if let error = error {
                        print("🔄 Error saving record: \(error.localizedDescription)")
                    } else if let savedRecord = savedRecord {
                        print("🔄 Successfully updated record in CloudKit: \(savedRecord.recordID)")
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


    
    // Special handler for checkbox/completion updates only
    private func handleCompletionsUpdate(recordID: CKRecord.ID, newCompletions: [Bool]) {
        let recordIDString = recordID.recordName
        print("🔄 Queueing rapid checkbox update for record \(recordIDString)")
        
        // Store in pendingUpdates for immediate UI feedback
        pendingUpdates[recordIDString] = newCompletions
        
        // Immediately update local data model
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update the model
            if let index = self.exercises.firstIndex(where: { $0.recordID == recordID }) {
                // Don't update the model directly here to avoid conflicts with pending updates
                // Just force a UI refresh so it uses pendingUpdates for display
                self.refreshID = UUID()
                self.objectWillChange.send()
            }
        }
        
        // Cancel any existing operation
        if let existingOperation = updateOperations[recordIDString] {
            existingOperation.cancel()
            updateOperations.removeValue(forKey: recordIDString)
        }
        
        // Create a new operation
        let operation = BlockOperation { [weak self] in
            guard let self = self else { return }
            
            // Skip if operation was cancelled
            if Thread.current.isCancelled {
                return
            }
            
            // Get the most recent completion state
            guard let completions = self.pendingUpdates[recordIDString] else {
                return
            }
            
            print("🔄 Starting CloudKit update for checkbox record \(recordIDString)")
            
            // Use completion-only update to CloudKit
            self.privateDatabase.fetch(withRecordID: recordID) { record, error in
                if let error = error {
                    print("🔄 Error fetching record for checkbox update: \(error.localizedDescription)")
                    
                    // Clean up
                    DispatchQueue.main.async {
                        self.updateOperations.removeValue(forKey: recordIDString)
                    }
                    return
                }
                
                guard let record = record else {
                    print("🔄 No record found for checkbox update ID: \(recordID)")
                    
                    // Clean up
                    DispatchQueue.main.async {
                        self.updateOperations.removeValue(forKey: recordIDString)
                    }
                    return
                }
                
                // Update the record with new completions
                record["setCompletions"] = completions.map { NSNumber(value: $0) } as CKRecordValue
                
                // Save to CloudKit
                print("🔄 Saving checkbox changes to CloudKit for record \(recordID)")
                self.privateDatabase.save(record) { savedRecord, error in
                    if let error = error {
                        print("🔄 Error saving checkbox record: \(error.localizedDescription)")
                    } else if let savedRecord = savedRecord {
                        print("🔄 Successfully updated checkbox record in CloudKit: \(savedRecord.recordID)")
                        
                        // Update model from CloudKit data
                        DispatchQueue.main.async {
                            if let index = self.exercises.firstIndex(where: { $0.recordID == recordID }) {
                                self.exercises[index].setCompletions = completions
                                
                                // Remove from pending now that it's in sync
                                self.pendingUpdates.removeValue(forKey: recordIDString)
                            }
                        }
                    }
                    
                    // Clean up
                    DispatchQueue.main.async {
                        self.updateOperations.removeValue(forKey: recordIDString)
                    }
                }
            }
        }
        
        // Store and start the operation
        updateOperations[recordIDString] = operation
        operationQueue.addOperation(operation)
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
    
    
    // MARK: - Reorder Exercises in Local Array
    func reorderExercise(oldIndex: Int, newIndex: Int) {
        // Remove from oldIndex, insert at newIndex
        let item = exercises.remove(at: oldIndex)
        
        // Clamp the newIndex so it doesn't go out of range
        let safeIndex = min(newIndex, exercises.count)
        exercises.insert(item, at: safeIndex)
        
        // Reassign sortIndex in local array
        for (i, _) in exercises.enumerated() {
            exercises[i].sortIndex = i
        }
    }
    
    // MARK: - Push new order to CloudKit
    func updateAllSortIndicesInCloudKit() {
        for (index, ex) in exercises.enumerated() {
            updateExerciseSortIndex(exercise: ex, newSortIndex: index)
        }
    }
    
    private func updateExerciseSortIndex(exercise: Exercise, newSortIndex: Int) {
        guard let recordID = exercise.recordID else { return }
        
        privateDatabase.fetch(withRecordID: recordID) { record, error in
            if let error = error {
                print("Error fetching exercise for sortIndex update:", error.localizedDescription)
                return
            }
            guard let record = record else { return }
            
            record["sortIndex"] = newSortIndex as CKRecordValue
            self.privateDatabase.save(record) { savedRecord, error in
                if let error = error {
                    print("Error updating exercise sortIndex:", error.localizedDescription)
                    return
                }
                print("Successfully updated sortIndex to \(newSortIndex) for \(exercise.name)")
            }
        }
    }
}

// ExerciseViewModel+Async.swift
extension ExerciseViewModel {

    /// Fetches exercises once per workout (unless the list is empty).
    @MainActor
    func loadIfNeeded() async -> Bool {
        let needsFetch = lastFetchedWorkoutID != workoutID.recordName || exercises.isEmpty
        guard needsFetch else { return false }

        // Cancel any previous attempt for safety
        fetchTask?.cancel()

        fetchTask = Task {
            try await fetchExercises(forceRefresh: true)
            await MainActor.run {       // hop back to main to mutate state
                self.lastFetchedWorkoutID = self.workoutID.recordName
            }
        }

        do {
            try await fetchTask?.value
            return true
        } catch is CancellationError {
            // Ignore if view disappeared
            return false
        } catch {
            print("🛑 fetch failed:", error)
            return false
        }
    }

    /// Cancels CloudKit operations **and** any async task in flight.
    @MainActor
    func cancelOutstandingTasks() {
        ExerciseViewModel.clearOperationsForWorkout(workoutID.recordName)
        fetchTask?.cancel()
        fetchTask = nil
    }

    // Fixed version of updateExerciseWithoutRefresh that properly handles all fields
    func updateExerciseWithoutRefresh(
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
        let recordIDString = recordID.recordName
        
        // CRITICAL: Prevent duplicate operations
        guard !Self.operationsInProgress.contains(recordIDString) else {
            print("⚠️ Skipping duplicate update for \(recordIDString)")
            return
        }
        
        // Mark this record as being updated
        Self.operationsInProgress.insert(recordIDString)
        print("🔄 Starting silent update for record \(recordIDString)")
        
        // Handle timeouts
        if let existingTimer = Self.operationTimeouts[recordIDString] {
            existingTimer.invalidate()
            Self.operationTimeouts.removeValue(forKey: recordIDString)
        }
        
        // Create new timeout timer
        Self.operationTimeouts[recordIDString] = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            DispatchQueue.main.async {
                Self.operationsInProgress.remove(recordIDString)
                Self.operationTimeouts.removeValue(forKey: recordIDString)
            }
        }
        
        // Update local model quietly without triggering refreshes
        if let index = self.exercises.firstIndex(where: { $0.recordID == recordID }) {
            // Update local model with new values
            if let newName = newName {
                self.exercises[index].name = newName
            }
            if let newSets = newSets {
                self.exercises[index].sets = newSets
                self.resizeArraysForSets(index: index, newSets: newSets)
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
        
        // Use CloudKit directly without view refreshes
        self.privateDatabase.fetch(withRecordID: recordID) { [weak self] record, error in
            guard let self = self else {
                DispatchQueue.main.async {
                    Self.operationsInProgress.remove(recordIDString)
                    Self.operationTimeouts[recordIDString]?.invalidate()
                    Self.operationTimeouts.removeValue(forKey: recordIDString)
                }
                return
            }
            
            // Always clean up when finished
            defer {
                DispatchQueue.main.async {
                    Self.operationsInProgress.remove(recordIDString)
                    Self.operationTimeouts[recordIDString]?.invalidate()
                    Self.operationTimeouts.removeValue(forKey: recordIDString)
                }
            }
            
            if let error = error {
                print("❌ Error fetching record for silent update: \(error.localizedDescription)")
                return
            }
            
            guard var record = record else {
                print("❌ No record found for ID: \(recordID)")
                return
            }
            
            // Track if any changes were made
            var recordChanged = false
            
            // Update record fields
            if let newName = newName {
                record["name"] = newName as CKRecordValue
                recordChanged = true
            }
            
            if let newSets = newSets {
                record["sets"] = newSets as CKRecordValue
                recordChanged = true
            }
            
            if let newReps = newReps {
                record["reps"] = newReps as CKRecordValue
                recordChanged = true
            }
            
            if let newAccentColor = newAccentColor {
                record["accentColorHex"] = newAccentColor as CKRecordValue
                recordChanged = true
            }
            
            if let newNote = newNote {
                record["exerciseNote"] = newNote as CKRecordValue
                recordChanged = true
            }
            
            if let newWeights = newWeights {
                record["setWeights"] = newWeights as CKRecordValue
                recordChanged = true
            }
            
            if let newCompletions = newCompletions {
                record["setCompletions"] = newCompletions.map { NSNumber(value: $0) } as CKRecordValue
                recordChanged = true
            }
            
            if let newSetNotes = newSetNotes {
                record["setNotes"] = newSetNotes as CKRecordValue
                recordChanged = true
            }
            
            if let newActualReps = newActualReps {
                record["setActualReps"] = newActualReps.map { NSNumber(value: $0) } as CKRecordValue
                recordChanged = true
            }
            
            // Save to CloudKit without triggering UI updates
            if recordChanged {
                print("🔄 Silently saving to CloudKit: \(recordID)")
                self.privateDatabase.save(record) { savedRecord, saveError in
                    if let saveError = saveError {
                        print("❌ Error saving record: \(saveError.localizedDescription)")
                    } else {
                        print("✅ Successfully saved record silently: \(recordID)")
                    }
                }
            } else {
                print("ℹ️ No changes needed for record \(recordID)")
            }
        }
    }
    
    // MARK: - Update a single exercise's accent color
    @MainActor
    func updateColor(for exercise: Exercise, to newHex: String) {
        guard let idx = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }

        // 1️⃣ local mutation (publishes UI change)
        exercises[idx].accentColorHex = newHex

        // 2️⃣ persist to CloudKit (ignore if recordID == nil e.g. unsynced temp)
        if let recordID = exercises[idx].recordID {
            updateExerciseColor(recordID: recordID, hex: newHex)
        }
    }
    
    // MARK: - Patch only the accent color field for an Exercise
    func updateExerciseColor(recordID: CKRecord.ID, hex: String) {
        // Fetch → modify → save, but only the changed key
        privateDatabase.fetch(withRecordID: recordID) { record, error in
            guard var record = record, error == nil else {
                print("⚡️ CloudKit: fetch error 👉", error?.localizedDescription ?? "nil")
                return
            }

            record["accentColorHex"] = hex as CKRecordValue

            let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            op.savePolicy = .changedKeys          // only updated field gets written
            op.modifyRecordsCompletionBlock = { _, _, e in
                if let e = e {
                    print("⚡️ CloudKit: color update failed 👉", e.localizedDescription)
                } else {
                    print("⚡️ CloudKit: accentColorHex updated to", hex)
                }
            }
            self.privateDatabase.add(op)
        }
    }
}

// Add this property to your ExerciseViewModel
extension ExerciseViewModel {
    var isActive: Bool {
        // Simple check to see if the view is still active for the current workout
        // This helps prevent updates to views that have been navigated away from
        return !Self.operationsInProgress.isEmpty
    }
}



// A queue that processes operations sequentially
class UpdateQueue {
    private var operations: [() -> AnyPublisher<String, Never>] = []
    private var isProcessing = false
    
    func enqueue(operation: @escaping () -> AnyPublisher<String, Never>) {
        operations.append(operation)
        processNextIfNeeded()
    }
    
    private func processNextIfNeeded() {
        guard !isProcessing, !operations.isEmpty else { return }
        
        isProcessing = true
        let operation = operations.removeFirst()
        
        // Execute the operation
        operation()
            .sink(receiveValue: { [weak self] _ in
                guard let self = self else { return }
                
                self.isProcessing = false
                self.processNextIfNeeded()
            })
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
}
