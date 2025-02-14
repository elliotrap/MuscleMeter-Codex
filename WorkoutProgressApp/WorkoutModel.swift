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
}

class WorkoutViewModel: ObservableObject {
    @Published var workouts: [WorkoutModel] = []
    
    @Published var sectionTitles: [String] = ["Light", "Moderate", "Heavy", "Extra Heavy", "D-load"]
    
    // Use the private database (recommended so data isn’t public)
    private let database = CKContainer.default().privateCloudDatabase
    
    func fetchWorkouts() {
        let query = CKQuery(recordType: "UserWorkout", predicate: NSPredicate(value: true))
        let sort = NSSortDescriptor(key: "creationDate", ascending: false)
        query.sortDescriptors = [sort]
        
        database.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                print("Error fetching workouts:", error)
                return
            }
            guard let records = records else { return }
            
            let fetchedWorkouts = records.compactMap { record in
                WorkoutModel(
                    id: record.recordID,
                    name: record["name"] as? String ?? "Unnamed Workout",
                    sectionTitle: record["sectionTitle"] as? String,
                    date: record["date"] as? Date
                )
            }
            print("Successfully fetched \(fetchedWorkouts.count) workout(s) from CloudKit.")
            DispatchQueue.main.async {
                self.workouts = fetchedWorkouts
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
        
        database.save(record) { savedRecord, error in
            if let error = error {
                print("Error saving workout:", error)
                completion(nil)
                return
            }
            guard let savedRecord = savedRecord else {
                completion(nil)
                return
            }
            
            let newWorkout = WorkoutModel(
                id: savedRecord.recordID,
                name: named,
                sectionTitle: savedRecord["sectionTitle"] as? String,
                date: savedRecord["date"] as? Date
            )
            DispatchQueue.main.async {
                self.workouts.insert(newWorkout, at: 0)
                completion(newWorkout)
            }
        }
    }
    
    func updateWorkout(workout: WorkoutModel, newName: String) {
        database.fetch(withRecordID: workout.id) { record, error in
            if let error = error {
                print("Error fetching workout record for update: \(error.localizedDescription)")
                return
            }
            guard let record = record else { return }
            
            record["name"] = newName as CKRecordValue
            self.database.save(record) { savedRecord, error in
                if let error = error {
                    print("Error updating workout record: \(error.localizedDescription)")
                    return
                }
                if savedRecord != nil {
                    print("Successfully updated workout record with new name: \(newName)")
                    DispatchQueue.main.async {
                        if let index = self.workouts.firstIndex(where: { $0.id == workout.id }) {
                            self.workouts[index].name = newName
                        }
                    }
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
    
    
    func deleteWorkout(_ workout: WorkoutModel) {
        database.delete(withRecordID: workout.id) { recordID, error in
            if let error = error {
                print("Error deleting workout:", error)
                return
            }
            print("Successfully deleted workout with record ID: \(workout.id).")
            DispatchQueue.main.async {
                self.workouts.removeAll { $0.id == workout.id }
            }
        }
    }
}
