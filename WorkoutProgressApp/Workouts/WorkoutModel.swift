//
//  WorkoutModel.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/11/25.
//

import SwiftUI
import CloudKit
import Foundation

struct WorkoutModel: Identifiable {
    let id: CKRecord.ID
    var name: String
    var sectionTitle: String?
    var date: Date?
    var sortIndex: Int
    // Add the accent color property with a default blue color
    var accentColorHex: String = "#2196F3"
    
    // Computed property for convenience
    var accentColor: Color {
        Color(hex: accentColorHex) ?? .blue
    }
}



class WorkoutViewModel: ObservableObject {
    @Published var workouts: [WorkoutModel] = []
    
    @Published var refreshTrigger = UUID()

    
    @Published var isProcessingMove: Bool = false
    
    @Published var sectionTitles: [String] = ["Light", "Moderate", "Heavy", "Extra Heavy", "D-load"]
    
    // Use the private database (recommended so data isn’t public)
    @Published var database = CKContainer.default().privateCloudDatabase
    
    // Add this property to your view model class
    private var isFetchingWorkouts = false
    private var currentWorkoutFetchID: String?

    
    
    
    // Enhanced fetchWorkouts method with better debugging and efficiency
    // 1. Enhanced fetchWorkouts method to load color
    func fetchWorkouts() {
        // Guard against duplicate fetches
        guard !isFetchingWorkouts else {
            print("🏋️‍♂️ Already fetching workouts, skipping duplicate request")
            return
        }
        
        // Set flag to prevent concurrent fetches
        isFetchingWorkouts = true
        
        // Create a unique ID for this fetch operation
        let fetchID = UUID().uuidString
        currentWorkoutFetchID = fetchID
        
        print("💪 FETCH: Starting fetchWorkouts")
        
        let query = CKQuery(recordType: "UserWorkout", predicate: NSPredicate(value: true))
        // Sort by sortIndex ascending
        query.sortDescriptors = [NSSortDescriptor(key: "sortIndex", ascending: true)]
        
        // Use a defer block to ensure we reset the flag, even in case of errors
        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.isFetchingWorkouts = false
            }
        }

        print("💪 FETCH: Querying CloudKit for workouts...")
        database.perform(query, inZoneWith: nil) { [weak self] records, error in
            guard let self = self else {
                print("💪 FETCH: Self reference lost")
                return
            }
            
            // Verify this is still the current fetch operation
            guard fetchID == self.currentWorkoutFetchID else {
                print("💪 FETCH: Ignoring stale fetch result for operation \(fetchID)")
                return
            }
            
            if let error = error {
                print("❌ FETCH: Error fetching workouts: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    // Update any error state here if needed
                    // self.error = error
                    // self.objectWillChange.send()
                }
                return
            }
            
            if let records = records {
                print("✅ FETCH: Successfully retrieved \(records.count) workouts from CloudKit")
                
                // Log some details about the workouts
                for (index, record) in records.enumerated() {
                    let name = record["name"] as? String ?? "Untitled"
                    let sortIndex = record["sortIndex"] as? Int ?? 0
                    let color = record["accentColorHex"] as? String ?? "#2196F3"
                    print("📋 FETCH: Workout \(index): '\(name)' with sortIndex: \(sortIndex), color: \(color)")
                }
                
                let fetchedWorkouts = records.map { record -> WorkoutModel in
                    let name = record["name"] as? String ?? "Untitled"
                    let sectionTitle = record["sectionTitle"] as? String
                    let date = record["date"] as? Date
                    let sortIndex = record["sortIndex"] as? Int ?? 0
                    // Extract color from record
                    let accentColorHex = record["accentColorHex"] as? String ?? "#2196F3"
                    
                    return WorkoutModel(
                        id: record.recordID,
                        name: name,
                        sectionTitle: sectionTitle,
                        date: date,
                        sortIndex: sortIndex,
                        accentColorHex: accentColorHex  // Include the color
                    )
                }
                
                print("📦 FETCH: Processed \(fetchedWorkouts.count) workout models")
                
                DispatchQueue.main.async {
                    let oldCount = self.workouts.count
                    self.workouts = fetchedWorkouts
                    print("🔄 FETCH: Updated workouts array from \(oldCount) to \(fetchedWorkouts.count) items")
                    
                    // If you're using a published property or ObservableObject, consider:
                    self.objectWillChange.send()
                    
                    print("✅ FETCH: Completed workout fetch successfully")
                }
            } else {
                print("ℹ️ FETCH: No workout records found")
                
                DispatchQueue.main.async {
                    self.workouts = []
                    print("🔄 FETCH: Cleared workouts array")
                }
            }
        }
    }


    func updateWorkout(
        workout: WorkoutModel,
        newName: String?       = nil,
        newColorHex: String?   = nil,
        newSectionTitle: String? = nil,
        newSortIndex: Int?     = nil,
        completion: @escaping (Bool) -> Void
    ) {
        // Fetch + modify the CKRecord…
        database.fetch(withRecordID: workout.id) { record, error in
            guard let record = record, error == nil else {
                completion(false); return
            }
            if let title = newName       { record["name"]           = title           as CKRecordValue }
            if let color = newColorHex   { record["accentColorHex"] = color           as CKRecordValue }
            if let section = newSectionTitle {
                record["sectionTitle"] = section as CKRecordValue
            }
            if let idx = newSortIndex {
                record["sortIndex"]    = idx     as CKRecordValue
            }

            self.database.save(record) { saved, error in
                DispatchQueue.main.async {
                    guard saved != nil, error == nil else {
                        completion(false); return
                    }
                    // 2) Update local array:
                    if let i = self.workouts.firstIndex(where: { $0.id == workout.id }) {
                        if let section = newSectionTitle {
                            self.workouts[i].sectionTitle = section
                        }
                        if let i = self.workouts.firstIndex(where: { $0.id == workout.id }) {
                            if let title = newName {
                                self.workouts[i].name = title
                            }
                        }
                        if let idx = newSortIndex {
                            self.workouts[i].sortIndex = idx
                        }
                    }
                    self.objectWillChange.send()
                    completion(true)
                }
            }
        }
    }




    // 4. Add a new method for updating just the color
    func updateWorkoutColor(workout: WorkoutModel, newColor: String, completion: @escaping (Bool) -> Void) {
        // Call the enhanced version with just the color parameter
        updateWorkout(workout: workout, newName: nil, newColorHex: newColor, completion: completion)
    }

    // 5. Helper function to fetch a workout's color specifically
    func fetchWorkoutColor(workoutID: CKRecord.ID, completion: @escaping (String) -> Void) {
        database.fetch(withRecordID: workoutID) { record, error in
            if let error = error {
                print("Error fetching workout color:", error.localizedDescription)
                // Return default color as fallback
                completion("#2196F3")
                return
            }
            
            guard let record = record else {
                // Return default color as fallback
                completion("#2196F3")
                return
            }
            
            // Get color from record or use default
            let colorHex = record["accentColorHex"] as? String ?? "#2196F3"
            
            DispatchQueue.main.async {
                completion(colorHex)
            }
        }
    }
    

    
    func addWorkout(named: String, sectionTitle: String?, completion: @escaping (WorkoutModel?) -> Void) {
        let record = CKRecord(recordType: "UserWorkout")
        record["name"] = named as CKRecordValue
        record["date"] = Date() as CKRecordValue
        if let sectionTitle = sectionTitle, !sectionTitle.isEmpty {
            record["sectionTitle"] = sectionTitle as CKRecordValue
        }
        
        // Calculate sortIndex based on current count
        let newSortIndex = (workouts.map { $0.sortIndex }.max() ?? -1) + 1
        record["sortIndex"] = newSortIndex as CKRecordValue
        
        database.save(record) { savedRecord, error in
            if let error = error {
                print("Error saving workout:", error.localizedDescription)
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            guard let savedRecord = savedRecord else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let newWorkout = WorkoutModel(
                id: savedRecord.recordID,
                name: named,
                sectionTitle: savedRecord["sectionTitle"] as? String,
                date: savedRecord["date"] as? Date,
                sortIndex: newSortIndex
            )
            
            DispatchQueue.main.async {
                // Add to local array
                self.workouts.append(newWorkout)
                
                // Sort workouts array by sortIndex if needed
                self.workouts.sort { $0.sortIndex < $1.sortIndex }
                
                // Complete with the new workout
                completion(newWorkout)
            }
        }
    }
    

    



    

    
    
    /// Saves a new section title to CloudKit and appends it to the local list if not already present.
    func addSectionTitle(_ title: String) {
        let record = CKRecord(recordType: "WorkoutSection")
        record["title"] = title as CKRecordValue
        database.save(record) { record, error in
            if let error = error {
                print("Error saving section title: \(error)")
            } else {
                DispatchQueue.main.async {
                    if !self.sectionTitles.contains(title) {
                        self.sectionTitles.append(title)
                    }
                }
            }
        }
    }
    
    // MARK: - Updated moveWorkout function
    func moveWorkout(_ workout: WorkoutModel, toIndex newIndex: Int) {
        guard !isProcessingMove else { return } // Prevent concurrent moves
        
        // First, get the workouts for this specific block to ensure we're
        // only reordering within the correct section
        let blockWorkouts = self.workouts
            .filter { $0.sectionTitle == workout.sectionTitle }
            .sorted(by: { $0.sortIndex < $1.sortIndex })
        
        // Find the actual index of the workout within the filtered section
        guard let currentIndex = blockWorkouts.firstIndex(where: { $0.id == workout.id }) else {
            print("ERROR: Could not find workout in the block")
            return
        }
        
        print("DEBUG: Moving \(workout.name) from \(currentIndex) to \(newIndex)")
        
        // Don't do anything if trying to move to the same position
        if currentIndex == newIndex {
            print("DEBUG: Workout is already at the desired index, no need to move")
            return
        }
        
        isProcessingMove = true
        
        // 1. Create a copy of block workouts and remove the workout being moved
        var updatedBlockWorkouts = blockWorkouts
        let workoutToMove = updatedBlockWorkouts.remove(at: currentIndex)
        
        // 2. Insert the workout at the new position within the block
        if newIndex >= updatedBlockWorkouts.count {
            updatedBlockWorkouts.append(workoutToMove)
        } else {
            updatedBlockWorkouts.insert(workoutToMove, at: newIndex)
        }
        
        // 3. Update all sort indices in the array - only for workouts in this block
        for index in 0..<updatedBlockWorkouts.count {
            updatedBlockWorkouts[index].sortIndex = index
        }
        
        // 4. Update the local workouts array - replace only the workouts for this block
        var newFullWorkouts = self.workouts.filter { $0.sectionTitle != workout.sectionTitle }
        newFullWorkouts.append(contentsOf: updatedBlockWorkouts)
        self.workouts = newFullWorkouts
        
        // 5. Print the new sort order for debugging
        print("DEBUG: New workout order:")
        for (i, w) in updatedBlockWorkouts.enumerated() {
            print("  \(i): \(w.name) (sortIndex: \(w.sortIndex))")
        }
        
        // 6. Update CloudKit in the background
        updateWorkoutSortIndices(updatedBlockWorkouts) { success in
            DispatchQueue.main.async {
                self.isProcessingMove = false
                if !success {
                    print("ERROR: Failed to update workout indices in CloudKit")
                    // Consider rolling back to previous state if needed
                } else {
                    print("Successfully updated workout indices")
                    self.objectWillChange.send()
                }
            }
        }
    }
    
 

    /// Move a workout into another block (week).
    /// - Parameters:
    ///   - workout: the workout to move
    ///   - newBlockTitle: the title of the block (week) to move it into
    func moveWorkoutToBlock(_ workout: WorkoutModel, toBlockTitle newBlockTitle: String) {
        guard !isProcessingMove else { return }
        isProcessingMove = true

        // Local reordering
        guard let oldIndex = workouts.firstIndex(where: { $0.id == workout.id }) else {
            isProcessingMove = false; return
        }
        let existing = workouts
            .filter { $0.sectionTitle == newBlockTitle && $0.id != workout.id }
        let maxIndex = existing.map(\.sortIndex).max() ?? -1
        let newIndex = maxIndex + 1

        // 3) Fire off a single CloudKit update
        updateWorkout(
            workout: workout,
            newSectionTitle: newBlockTitle,
            newSortIndex: newIndex
        ) { success in
            DispatchQueue.main.async {
                self.isProcessingMove = false
                if !success {
                    print("🔴 Failed to move workout on server.")
                    // Maybe roll back your local change here…
                }
            }
        }
    }
    
    // MARK: - Special function to move a workout to the end
    func moveWorkoutToEnd(_ workout: WorkoutModel) {
        guard !isProcessingMove else { return }
        
        // Get the workouts for this specific block
        let blockWorkouts = self.workouts
            .filter { $0.sectionTitle == workout.sectionTitle }
            .sorted(by: { $0.sortIndex < $1.sortIndex })
        
        // Find the current index of the workout
        guard let currentIndex = blockWorkouts.firstIndex(where: { $0.id == workout.id }) else {
            print("ERROR: Could not find workout in the block")
            return
        }
        
        let lastIndex = blockWorkouts.count - 1
        print("DEBUG: Moving \(workout.name) from \(currentIndex) to end position (index \(lastIndex))")
        
        // Don't do anything if already at the end
        if currentIndex == lastIndex {
            print("DEBUG: Workout is already at the end, no need to move")
            return
        }
        
        isProcessingMove = true
        
        // 1. Create a copy of block workouts and remove the workout being moved
        var updatedBlockWorkouts = blockWorkouts
        let workoutToMove = updatedBlockWorkouts.remove(at: currentIndex)
        
        // 2. Add the workout to the end
        updatedBlockWorkouts.append(workoutToMove)
        
        // 3. Update all sort indices in the array
        for index in 0..<updatedBlockWorkouts.count {
            updatedBlockWorkouts[index].sortIndex = index
        }
        
        // 4. Update the local workouts array
        var newFullWorkouts = self.workouts.filter { $0.sectionTitle != workout.sectionTitle }
        newFullWorkouts.append(contentsOf: updatedBlockWorkouts)
        self.workouts = newFullWorkouts
        
        // 5. Print the new sort order for debugging
        print("DEBUG: New workout order:")
        for (i, w) in updatedBlockWorkouts.enumerated() {
            print("  \(i): \(w.name) (sortIndex: \(w.sortIndex))")
        }
        
        // 6. Update CloudKit
        updateWorkoutSortIndices(updatedBlockWorkouts) { success in
            DispatchQueue.main.async {
                self.isProcessingMove = false
                if !success {
                    print("ERROR: Failed to update workout indices in CloudKit")
                } else {
                    print("Successfully updated workout indices")
                    self.objectWillChange.send()
                }
            }
        }
    }
    
    func updateWorkoutSortIndices(_ workouts: [WorkoutModel], completion: @escaping (Bool) -> Void = { _ in }) {
        // Create an operation group for fetching all records first
        let group = DispatchGroup()
        var recordsToUpdate: [(CKRecord, Int)] = []
        var hadError = false
        
        // First fetch all records
        for (newIndex, workout) in workouts.enumerated() {
            group.enter()
            
            database.fetch(withRecordID: workout.id) { record, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Error fetching workout record: \(error.localizedDescription)")
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
                completion(false)
                return
            }
            
            // Create a batch operation for better performance
            var recordsToSave: [CKRecord] = []
            
            for (record, newIndex) in recordsToUpdate {
                record["sortIndex"] = newIndex as CKRecordValue
                recordsToSave.append(record)
            }
            
            if recordsToSave.isEmpty {
                print("No records to update")
                completion(true)
                return
            }
            
            let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            
            operation.modifyRecordsCompletionBlock = { savedRecords, _, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error batch updating workout indices: \(error.localizedDescription)")
                        completion(false)
                        return
                    }
                    
                    print("Successfully updated \(savedRecords?.count ?? 0) workout indices")
                    
                    // Make sure our local workouts array has the updated sort indices
                    self.fetchWorkouts() // Refresh from CloudKit to ensure consistency
                    completion(true)
                }
            }
            
            self.database.add(operation)
        }
    }
    
    /// Optionally, fetch any custom section titles saved in CloudKit.
    func fetchSectionTitles() {
        let query = CKQuery(recordType: "WorkoutSection", predicate: NSPredicate(value: true))
        database.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                print("Error fetching section titles: \(error)")
                return
            }
            guard let records = records else { return }
            let fetchedTitles = records.compactMap { record in
                record["title"] as? String
            }
            DispatchQueue.main.async {
                // Merge the defaults with fetched titles, removing duplicates.
                let merged = Array(Set(self.sectionTitles + fetchedTitles)).sorted()
                self.sectionTitles = merged
            }
        }
    }
    
    
    func deleteWorkout(_ workouts: WorkoutModel) {
        database.delete(withRecordID: workouts.id) { recordID, error in
            if let error = error {
                print("Error deleting workout:", error)
                return
            }
            print("Successfully deleted workout with record ID: \(workouts.id).")
            DispatchQueue.main.async {
                self.workouts.removeAll { $0.id == workouts.id }
            }
        }
    }
    
    // In WorkoutViewModel

    /// Moves a workout from oldIndex to newIndex in the local `workouts` array
    /// and updates each workout's `sortIndex`.
    func reorderWorkout(oldIndex: Int, newIndex: Int) {
        // 1) Remove the item from oldIndex, insert at newIndex
        let item = workouts.remove(at: oldIndex)
        workouts.insert(item, at: newIndex) // Thread 1: Fatal error: Array index is out of range
        
        // 2) Reassign sortIndex for each workout in the new order
        for (i, w) in workouts.enumerated() {
            workouts[i].sortIndex = i
        }
    }

    /// Moves all current workouts' sortIndex to CloudKit
    func updateAllSortIndicesInCloudKit() {
        for (index, w) in workouts.enumerated() {
            updateWorkoutSortIndex(workout: w, newSortIndex: index)
        }
    }
    
    func updateWorkoutSortIndex(workout: WorkoutModel, newSortIndex: Int) {
        database.fetch(withRecordID: workout.id) { record, error in
            if let error = error {
                print("Error fetching workout record for sortIndex update:", error.localizedDescription)
                return
            }
            guard let record = record else { return }
            
            record["sortIndex"] = newSortIndex as CKRecordValue
            
            self.database.save(record) { savedRecord, error in
                if let error = error {
                    print("Error updating workout sortIndex:", error.localizedDescription)
                    return
                }
                guard let savedRecord = savedRecord else { return }
                
                print("Successfully updated sortIndex to \(newSortIndex) for \(workout.name)")
            }
        }
    }
    
    /// Moves the given workout to the specified newIndex in workouts,
    /// handling edge cases (oldIndex < newIndex) and clamping.
    func moveWorkoutAtIndex(movingWorkout: WorkoutModel, newIndex: Int) {
        guard let oldIndex = workouts.firstIndex(where: { $0.id == movingWorkout.id }) else {
            print("DEBUG: Could not find oldIndex for \(movingWorkout.name)")
            return
        }
        
        print("DEBUG: Moving \(movingWorkout.name) from \(oldIndex) to \(newIndex)")
        
        // 1) Remove the item
        let item = workouts.remove(at: oldIndex)
        
        // 2) If oldIndex < newIndex, insertion shifts left by 1
        var finalIndex = newIndex
        if oldIndex < newIndex {
            finalIndex -= 1
        }
        
        // 3) Clamp finalIndex to 0...workouts.count
        finalIndex = max(0, min(finalIndex, workouts.count))
        
        // 4) Insert the item
        workouts.insert(item, at: finalIndex)
        print("DEBUG: \(movingWorkout.name) inserted at index \(finalIndex).")
        
        // 5) Update sortIndex & push to CloudKit
        for (i, _) in workouts.enumerated() {
            workouts[i].sortIndex = i
        }
        updateAllSortIndicesInCloudKit()
    }
    
    
    @MainActor
    func updateColor(for workout: WorkoutModel, to newHex: String) {
        guard let idx = workouts.firstIndex(where: { $0.id == workout.id }) else { return }

        // update in‑memory
        workouts[idx].accentColorHex = newHex

        // persist to CloudKit
        updateWorkoutColor(
            recordID: workouts[idx].id,      // ← use id, not recordID
            hex: newHex
        )
    }
    // CloudKitManager.swift
    func updateWorkoutColor(recordID: CKRecord.ID?, hex: String) {
        guard let recordID else { return }

        database.fetch(withRecordID: recordID) { rec, error in
            guard let rec else { return }
            rec["accentColorHex"] = hex as CKRecordValue
            self.database.save(rec) { _, _ in }
        }
    }
}

