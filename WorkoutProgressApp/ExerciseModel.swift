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

class ExerciseViewModel: ObservableObject {
    
    @Published var hasCompletedInitialFetch = false
    @Published var exercises: [Exercise] = []
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil
    @Published var refreshID = UUID()
    @Published var lastFetchTime = Date()
    @Published var stateVersion = 0
    // Add this property to your ExerciseViewModel class
    @Published var lastFetchedWorkoutID: String?
    // Track the current fetch operation to prevent race conditions
    var currentFetchID: String?
    let workoutID: CKRecord.ID

    // At the class level, add this property:
    private static var operationTimeouts: [String: Timer] = [:]
    
    private let privateDatabase = CKContainer.default().privateCloudDatabase

    // MARK: - Init
    init(workoutID: CKRecord.ID) {
        self.workoutID = workoutID
        fetchExercises() // Fetch exercises on init
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
    
    @objc func handleRemoteNotification(_ notification: Notification) {
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
    
    deinit {
        unsubscribeFromCloudKitChanges()
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
        let newSortIndex = exercises.count
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
        self.saveUserExercise(
            name: name,
            sets: sets,
            reps: reps,
            setWeights: setWeights,
            setCompletions: setCompletions,
            setNotes: setNotes,
            setActualReps: setActualReps,
            workoutID: workoutID
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
    
    // MARK: - Exercise Sort Index Update Function
    // Add this to your ExerciseViewModel class
    func updateExerciseSortIndices(_ exercises: [Exercise]) {
        // Create an operation group for fetching all records first
        let group = DispatchGroup()
        var recordsToUpdate: [(CKRecord, Int)] = []
        var hadError = false
        
        print("DEBUG: Beginning to update sort indices for \(exercises.count) exercises")
        
        // First fetch all records
        for (newIndex, exercise) in exercises.enumerated() {
            // Skip exercises that don't have a recordID yet (locally created exercises)
            guard let recordID = exercise.recordID else {
                print("WARNING: Exercise \(exercise.name) has no recordID, skipping")
                continue
            }
            
            group.enter()
            
            privateDatabase.fetch(withRecordID: recordID) { record, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Error fetching exercise record: \(error.localizedDescription)")
                    hadError = true
                    return
                }
                
                if let record = record {
                    // Store record with its new index
                    recordsToUpdate.append((record, newIndex))
                }
            }
        }
        
        // After all fetches complete, update and save all records in a batch
        group.notify(queue: .main) {
            if hadError {
                print("ERROR: Had errors fetching exercise records")
                return
            }
            
            // Create a batch operation for better performance
            var recordsToSave: [CKRecord] = []
            
            for (record, newIndex) in recordsToUpdate {
                record["sortIndex"] = newIndex as CKRecordValue
                recordsToSave.append(record)
            }
            
            if recordsToSave.isEmpty {
                print("DEBUG: No exercise records to update")
                return
            }
            
            let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            
            operation.modifyRecordsCompletionBlock = { savedRecords, _, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error batch updating exercise indices: \(error.localizedDescription)")
                        return
                    }
                    
                    print("Successfully updated \(savedRecords?.count ?? 0) exercise indices")
                    
                    // Notify any observers of the change
                    self.objectWillChange.send()
                }
            }
            
            self.privateDatabase.add(operation)
        }
    }
    
    // Enhanced fetchExercises method with better throttling and state preservation
    func fetchExercises(forceRefresh: Bool = false, completion: ((Bool) -> Void)? = nil) {
        print("🏋️‍♂️ Fetching exercises from CloudKit for workout: \(workoutID)")
        func fetchExercises(forceRefresh: Bool = false, completion: ((Bool) -> Void)? = nil) {
            let workoutIDString = workoutID.recordName
            print("🏋️‍♂️ Fetching exercises from CloudKit for workout: \(workoutID)")
            
            // Set loading state
            self.isLoading = true
            
            // IMPORTANT: Create a UUID for this specific fetch operation
            let fetchID = UUID().uuidString
            self.currentFetchID = fetchID
            
            // Store the last attempted fetch time
            UserDefaults.standard.set(Date().timeIntervalSince1970,
                                     forKey: "LastFetchAttempt-\(workoutIDString)")
            
            CloudKitManager.shared.fetchUserExercises(
                for: workoutID,
                forceRefresh: forceRefresh
            ) { [weak self] result in
                guard let self = self else { return }
                
                // Check if this callback is for the most recent fetch operation
                guard fetchID == self.currentFetchID else {
                    print("🏋️‍♂️ Ignoring stale fetch result for operation \(fetchID)")
                    return
                }
                
                switch result {
                case .failure(let error):
                    print("🏋️‍♂️ Error fetching from CloudKit: \(error.localizedDescription)")
                    
                    DispatchQueue.main.async {
                        self.error = error
                        self.lastFetchTime = Date()
                        self.isLoading = false
                        
                        // Even on error, trigger objectWillChange
                        self.objectWillChange.send()
                        completion?(false)
                    }
                    
                case .success(let records):
                    print("🏋️‍♂️ Successfully fetched \(records.count) record(s) from CloudKit")
                    
                    var fetchedExercises: [Exercise] = []
                    
                    // Process records
                    for record in records {
                        if let name = record["name"] as? String,
                           let sets = record["sets"] as? Int,
                           let reps = record["reps"] as? Int {
                            
                            // Parse data
                            let weights = record["setWeights"] as? [Double] ?? Array(repeating: 0.0, count: sets)
                            let completionsArray = record["setCompletions"] as? [NSNumber] ?? []
                            let boolCompletions = completionsArray.map { $0.boolValue }
                            let notes = record["setNotes"] as? [String] ?? Array(repeating: "", count: sets)
                            let timestamp = record["timestamp"] as? Date ?? Date()
                            let exerciseNote = record["exerciseNote"] as? String ?? ""
                            
                            // Process actualReps
                            let actualRepsArray = record["setActualReps"] as? [NSNumber] ?? []
                            var actualReps = actualRepsArray.map { $0.intValue }
                            
                            if actualReps.count < sets {
                                let needed = sets - actualReps.count
                                actualReps.append(contentsOf: Array(repeating: 0, count: needed))
                            }
                            if actualReps.count > sets {
                                actualReps = Array(actualReps.prefix(sets))
                            }
                            
                            let accentColorHex = record["accentColor"] as? String ?? "#0000FF"
                            let sortIndex = record["sortIndex"] as? Int ?? 0
                            
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
                                timestamp: timestamp,
                                accentColorHex: accentColorHex,
                                sortIndex: sortIndex
                            )
                            
                            fetchedExercises.append(exercise)
                            print("🏋️‍♂️ Processed exercise: \(name)")
                        }
                    }
                    
                    DispatchQueue.main.async {
                        // Store old counts for better logging
                        let oldCount = self.exercises.count
                        
                        // Use a consistent approach for checking whether to update the UI
                        let shouldUpdate = forceRefresh ||
                                          !fetchedExercises.isEmpty ||
                                          self.exercises.isEmpty ||
                                          (self.workoutID.recordName != self.lastFetchedWorkoutID)
                        
                        if shouldUpdate {
                            // Sort exercises
                            fetchedExercises.sort { $0.sortIndex < $1.sortIndex }
                            
                            // Force more explicit state changes to trigger UI updates
                            self.stateVersion += 1
                            self.exercises = fetchedExercises
                            self.hasCompletedInitialFetch = true
                            self.lastFetchTime = Date()
                            self.refreshID = UUID()
                            
                            // Track which workout ID this data is for
                            self.lastFetchedWorkoutID = self.workoutID.recordName
                            
                            // Store successful fetch details in UserDefaults
                            UserDefaults.standard.set(Date().timeIntervalSince1970,
                                                     forKey: "LastSuccessfulFetch-\(workoutIDString)")
                            UserDefaults.standard.set(fetchedExercises.count,
                                                     forKey: "LastFetchCount-\(workoutIDString)")
                            
                            // Explicitly update environment via objectWillChange
                            self.objectWillChange.send()
                            
                            print("🏋️‍♂️ Updated exercises array from \(oldCount) to \(fetchedExercises.count) items (stateVersion: \(self.stateVersion))")
                            
                            // Notify observers with workout context
                            NotificationCenter.default.post(
                                name: Notification.Name("ExercisesUpdated"),
                                object: nil,
                                userInfo: [
                                    "count": self.exercises.count,
                                    "workoutID": workoutIDString
                                ]
                            )
                        } else {
                            print("🏋️‍♂️ No update needed. Current: \(self.exercises.count), Fetched: \(fetchedExercises.count)")
                        }
                        
                        self.isLoading = false
                        completion?(true)
                    }
                }
            }
        }
        // Set loading state
        self.isLoading = true
        
        // IMPORTANT: Create a UUID for this specific fetch operation
        let fetchID = UUID().uuidString
        self.currentFetchID = fetchID // Value of type 'ExerciseViewModel' has no member 'currentFetchID'
        
        CloudKitManager.shared.fetchUserExercises(
            for: workoutID,
            forceRefresh: forceRefresh
        ) { [weak self] result in
            guard let self = self else { return }
            
            // Check if this callback is for the most recent fetch operation
            guard fetchID == self.currentFetchID else {
                print("🏋️‍♂️ Ignoring stale fetch result for operation \(fetchID)")
                return
            }
            
            switch result {
            case .failure(let error):
                print("🏋️‍♂️ Error fetching from CloudKit: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    self.error = error
                    self.lastFetchTime = Date()
                    self.isLoading = false
                    
                    // Even on error, trigger objectWillChange
                    self.objectWillChange.send()
                    
                    // Store the fact that we attempted to fetch for this workout
                    UserDefaults.standard.set(Date().timeIntervalSince1970,
                                             forKey: "LastFetchAttempt-\(self.workoutID.recordName)")
                    
                    completion?(false)
                }
                
            case .success(let records):
                print("🏋️‍♂️ Successfully fetched \(records.count) record(s) from CloudKit")
                
                var fetchedExercises: [Exercise] = []
                
                // Process records
                for record in records {
                    if let name = record["name"] as? String,
                       let sets = record["sets"] as? Int,
                       let reps = record["reps"] as? Int {
                        
                        // Parse data
                        let weights = record["setWeights"] as? [Double] ?? Array(repeating: 0.0, count: sets)
                        let completionsArray = record["setCompletions"] as? [NSNumber] ?? []
                        let boolCompletions = completionsArray.map { $0.boolValue }
                        let notes = record["setNotes"] as? [String] ?? Array(repeating: "", count: sets)
                        let timestamp = record["timestamp"] as? Date ?? Date()
                        let exerciseNote = record["exerciseNote"] as? String ?? ""
                        
                        // Process actualReps
                        let actualRepsArray = record["setActualReps"] as? [NSNumber] ?? []
                        var actualReps = actualRepsArray.map { $0.intValue }
                        
                        if actualReps.count < sets {
                            let needed = sets - actualReps.count
                            actualReps.append(contentsOf: Array(repeating: 0, count: needed))
                        }
                        if actualReps.count > sets {
                            actualReps = Array(actualReps.prefix(sets))
                        }
                        
                        let accentColorHex = record["accentColor"] as? String ?? "#0000FF"
                        let sortIndex = record["sortIndex"] as? Int ?? 0
                        
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
                            timestamp: timestamp,
                            accentColorHex: accentColorHex,
                            sortIndex: sortIndex
                        )
                        
                        fetchedExercises.append(exercise)
                        print("🏋️‍♂️ Processed exercise: \(name)")
                    }
                }
                
                DispatchQueue.main.async {
                    // Only update if we have new data, no current data, or forced refresh
                    let shouldUpdate = !fetchedExercises.isEmpty || self.exercises.isEmpty || forceRefresh
                    
                    if shouldUpdate {
                        // Sort exercises
                        fetchedExercises.sort { $0.sortIndex < $1.sortIndex }
                        
                        // Store old count for logging
                        let oldCount = self.exercises.count
                        
                        // Force more explicit state changes to trigger UI updates
                        self.stateVersion += 1
                        self.exercises = fetchedExercises
                        self.hasCompletedInitialFetch = true
                        self.lastFetchTime = Date()
                        self.refreshID = UUID()
                        
                        // Store the successful fetch time for this specific workout
                        UserDefaults.standard.set(Date().timeIntervalSince1970,
                                                 forKey: "LastSuccessfulFetch-\(self.workoutID.recordName)")
                        UserDefaults.standard.set(self.exercises.count,
                                                 forKey: "LastFetchCount-\(self.workoutID.recordName)")
                        
                        // Explicitly update environment via objectWillChange
                        self.objectWillChange.send()
                        
                        print("🏋️‍♂️ Updated exercises array from \(oldCount) to \(fetchedExercises.count) items (stateVersion: \(self.stateVersion))")
                        
                        // Post notification with the workout ID to avoid confusion
                        NotificationCenter.default.post(
                            name: Notification.Name("ExercisesUpdated"),
                            object: nil,
                            userInfo: [
                                "count": self.exercises.count,
                                "workoutID": self.workoutID.recordName
                            ]
                        )
                    } else {
                        print("🏋️‍♂️ No changes needed, keeping current \(self.exercises.count) exercises")
                    }
                    
                    self.isLoading = false
                    completion?(true)
                }
            }
        }
    }
    
    // Add this method to your ExerciseViewModel
    func fetchExercisesOnce(completion: @escaping (Bool) -> Void) {
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
                    record["accentColor"] = newAccentColor as CKRecordValue
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

// IMPORTANT: Add this extension to your ExerciseViewModel class
extension ExerciseViewModel {
    // This version doesn't trigger UI refreshes
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
            
            // DON'T trigger UI updates here - this is the key difference!
            // self.refreshID = UUID() - REMOVED
            // self.objectWillChange.send() - REMOVED
        }
        
        // Use CloudKit directly without view refreshes
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
                // Always clean up
                defer {
                    DispatchQueue.main.async {
                        Self.operationsInProgress.remove(recordIDString)
                        Self.operationTimeouts[recordIDString]?.invalidate()
                        Self.operationTimeouts.removeValue(forKey: recordIDString)
                    }
                }
                
                guard let record = record, error == nil else {
                    return
                }
                
                // Track if any changes were made
                var recordChanged = false
                
                // Update record fields
                if let newName = newName {
                    record["name"] = newName as CKRecordValue
                    recordChanged = true
                }
                
                // Handle other fields (abbreviated for clarity)
                // ...
                
                // Save to CloudKit without triggering UI updates
                if recordChanged {
                    print("🔄 Silently saving to CloudKit: \(recordID)")
                    self.privateDatabase.save(record) { _, _ in }
                }
            }
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
