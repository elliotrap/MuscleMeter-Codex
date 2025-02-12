//
//  CloudKitManager.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/4/25.
//
import CloudKit

class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    private let privateDatabase = CKContainer.default().privateCloudDatabase
    
    // Save user lifts data to CloudKit
    func saveUserLifts(bodyWeight: Double, bench: Double, squat: Double, deadlift: Double, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let record = CKRecord(recordType: "UserLifts")
        record["bodyWeight"] = bodyWeight as CKRecordValue
        record["bench"] = bench as CKRecordValue
        record["squat"] = squat as CKRecordValue
        record["deadlift"] = deadlift as CKRecordValue
        record["timestamp"] = Date() as CKRecordValue
        
        print("CloudKitManager: Attempting to save record with values -> bodyWeight: \(bodyWeight), bench: \(bench), squat: \(squat), deadlift: \(deadlift)")
        
        privateDatabase.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("CloudKitManager: Error saving record: \(error.localizedDescription)")
                    completion(.failure(error))
                } else if let savedRecord = savedRecord {
                    print("CloudKitManager: Successfully saved record: \(savedRecord)")
                    completion(.success(savedRecord))
                } else {
                    let unknownError = NSError(domain: "CloudKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"])
                    print("CloudKitManager: Unknown error saving record")
                    completion(.failure(unknownError))
                }
            }
        }
    }
    
    // Fetch all user lifts records from CloudKit
    func fetchUserLifts(completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        // Create a predicate that matches all records
        let predicate = NSPredicate(value: true)
        
        // Create a query for the "UserLifts" record type using your predicate
        let query = CKQuery(recordType: "UserLifts", predicate: predicate)
        
        // Sort by your custom "timestamp" field instead of a deprecated or system field
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        print("CloudKitManager: Fetching records from CloudKit...")
        
        // Use the new fetch API (available in iOS 15+)
        privateDatabase.fetch(withQuery: query,
                                inZoneWith: nil,
                                desiredKeys: nil,
                                resultsLimit: CKQueryOperation.maximumResults) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("CloudKitManager: Error fetching records: \(error.localizedDescription)")
                    completion(.failure(error))
                case .success(let fetchResult):
                    // fetchResult.matchResults is an array of (CKRecord.ID, Result<CKRecord, Error>)
                    let records: [CKRecord] = fetchResult.matchResults.compactMap { (recordID, recordResult) in
                        do {
                            return try recordResult.get()
                        } catch {
                            print("CloudKitManager: Error retrieving record for \(recordID): \(error.localizedDescription)")
                            return nil
                        }
                    }
                    print("CloudKitManager: Fetched \(records.count) record(s) from CloudKit.")
                    completion(.success(records))
                }
            }
        }
    }
    
}

extension CloudKitManager {
    func saveUserExercise(
        name: String,
        sets: Int,
        reps: Int,
        weight: Double,
        workoutID: CKRecord.ID,
        completion: @escaping (Result<CKRecord, Error>) -> Void
    ) {
        let record = CKRecord(recordType: "UserExercises")
        record["name"] = name as CKRecordValue
        record["sets"] = sets as CKRecordValue
        record["reps"] = reps as CKRecordValue
        record["weight"] = weight as CKRecordValue
        record["timestamp"] = Date() as CKRecordValue
        
        // Save the workout reference
        let workoutRef = CKRecord.Reference(recordID: workoutID, action: .none)
        record["workoutRef"] = workoutRef

        print("CloudKitManager: Attempting to save new exercise: \(name) under workout \(workoutID)")
        
        privateDatabase.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("CloudKitManager: Error saving exercise: \(error.localizedDescription)")
                    completion(.failure(error))
                } else if let savedRecord = savedRecord {
                    print("CloudKitManager: Successfully saved exercise: \(savedRecord)")
                    completion(.success(savedRecord))
                }
            }
        }
    }
    
    func fetchUserExercises(
        for workoutID: CKRecord.ID,
        completion: @escaping (Result<[CKRecord], Error>) -> Void
    ) {
        // Create a predicate filtering on the workout reference.
        let workoutReference = CKRecord.Reference(recordID: workoutID, action: .none)
        let predicate = NSPredicate(format: "workoutRef == %@", workoutReference)
        let query = CKQuery(recordType: "UserExercises", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        print("CloudKitManager: Fetching UserExercises for workout \(workoutID)...")
        
        privateDatabase.fetch(withQuery: query,
                              inZoneWith: nil,
                              desiredKeys: nil,
                              resultsLimit: CKQueryOperation.maximumResults) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("CloudKitManager: Error fetching exercises: \(error.localizedDescription)")
                    completion(.failure(error))
                case .success(let fetchResult):
                    var records: [CKRecord] = []
                    for (_, recordResult) in fetchResult.matchResults {
                        do {
                            let record = try recordResult.get()
                            records.append(record)
                        } catch {
                            print("CloudKitManager: Error retrieving exercise record: \(error.localizedDescription)")
                        }
                    }
                    print("CloudKitManager: Fetched \(records.count) exercise(s) for workout \(workoutID).")
                    completion(.success(records))
                }
            }
        }
    }
}
