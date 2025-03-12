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
    var recordID: CKRecord.ID?
    var sortIndex: Int

}



class WorkoutViewModel: ObservableObject {
    @Published var workouts: [WorkoutModel] = []
    
    
    
    @Published var isProcessingMove: Bool = false
    
    @Published var sectionTitles: [String] = ["Light", "Moderate", "Heavy", "Extra Heavy", "D-load"]
    
    // Use the private database (recommended so data isn’t public)
    @Published var database = CKContainer.default().privateCloudDatabase
    
    func fetchWorkouts() {
        let query = CKQuery(recordType: "UserWorkout", predicate: NSPredicate(value: true))
        // Sort by sortIndex ascending
        query.sortDescriptors = [NSSortDescriptor(key: "sortIndex", ascending: true)]

        database.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                print("Error fetching workouts:", error.localizedDescription)
                return
            }
            
            if let records = records {
                let fetchedWorkouts = records.map { record -> WorkoutModel in
                    let name = record["name"] as? String ?? "Untitled"
                    let sectionTitle = record["sectionTitle"] as? String
                    let date = record["date"] as? Date
                    let sortIndex = record["sortIndex"] as? Int ?? 0  // default to 0 if missing
                    
                    return WorkoutModel(
                        id: record.recordID,
                        name: name,
                        sectionTitle: sectionTitle,
                        date: date,
                        sortIndex: sortIndex
                    )
                }
                DispatchQueue.main.async {
                    self.workouts = fetchedWorkouts
                }
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
        let newSortIndex = workouts.count
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
    

    



    
    
    
    func updateWorkout(workout: WorkoutModel, newName: String, completion: @escaping (Bool) -> Void) {
        guard !newName.isEmpty else {
            print("Cannot update workout with empty name")
            completion(false)
            return
        }

        database.fetch(withRecordID: workout.id) { record, error in
            if let error = error {
                print("Error fetching workout record:", error.localizedDescription)
                completion(false)
                return
            }
            guard let record = record else {
                completion(false)
                return
            }

            record["name"] = newName as CKRecordValue
            self.database.save(record) { savedRecord, error in
                if let error = error {
                    print("Error updating workout record:", error.localizedDescription)
                    completion(false)
                    return
                }
                if savedRecord != nil {
                    print("Successfully updated workout record with new name: \(newName)")
                    DispatchQueue.main.async {
                        if let index = self.workouts.firstIndex(where: { $0.id == workout.id }) {
                            self.workouts[index].name = newName
                        }
                    }
                    completion(true)
                } else {
                    completion(false)
                }
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
}
