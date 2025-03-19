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
    // Add these properties to manage concurrent operations
    private var updatingRecords = Set<String>()
     private var updatingRecordsLock = NSLock()
     
     // Add these properties for fetch throttling
     private var lastFetchTime: [String: Date] = [:]
     private let minFetchInterval: TimeInterval = 2.0 // seconds
    
    // Add these properties to your CloudKit manager
    private var lastFetchResultCounts: [String: Int] = [:]
    private var recordCache: [String: [CKRecord]] = [:]

    // Add this property to your view model
    var currentFetchID: String?
    
    // Enhanced update record function with concurrency control
    func updateRecord(_ record: CKRecord, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let recordID = record.recordID.recordName
        
        // Check if we're already updating this record
        updatingRecordsLock.lock()
        if updatingRecords.contains(recordID) {
            print("⚠️ CloudKit: Already updating record \(recordID), skipping duplicate update")
            updatingRecordsLock.unlock()
            completion(.failure(NSError(domain: "CloudKitManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Duplicate update in progress"])))
            return
        }
        
        // Mark record as being updated
        updatingRecords.insert(recordID)
        updatingRecordsLock.unlock()
        
        // First fetch the latest version of the record
        privateDatabase.fetch(withRecordID: record.recordID) { fetchedRecord, error in
            if let error = error {
                print("⚠️ CloudKit: Error fetching record before update: \(error.localizedDescription)")
                
                // Remove from updating set
                self.updatingRecordsLock.lock()
                self.updatingRecords.remove(recordID)
                self.updatingRecordsLock.unlock()
                
                completion(.failure(error))
                return
            }
            
            guard let fetchedRecord = fetchedRecord else {
                print("⚠️ CloudKit: Record no longer exists: \(recordID)")
                
                // Remove from updating set
                self.updatingRecordsLock.lock()
                self.updatingRecords.remove(recordID)
                self.updatingRecordsLock.unlock()
                
                completion(.failure(NSError(domain: "CloudKitManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Record not found"])))
                return
            }
            
            // Copy updated values to the fetched record
            self.copyUpdatedValues(from: record, to: fetchedRecord)
            
            // Then save the updated record
            self.privateDatabase.save(fetchedRecord) { savedRecord, error in
                // Remove from updating set
                self.updatingRecordsLock.lock()
                self.updatingRecords.remove(recordID)
                self.updatingRecordsLock.unlock()
                
                if let error = error {
                    print("⚠️ CloudKit: Error saving updated record: \(error.localizedDescription)")
                    completion(.failure(error))
                } else if let savedRecord = savedRecord {
                    print("✅ CloudKit: Successfully updated record: \(savedRecord.recordID)")
                    completion(.success(savedRecord))
                }
            }
        }
    }
    
    // Combined fetchUserExercises with throttling and retry mechanism
    func fetchUserExercises(
        for workoutID: CKRecord.ID,
        attempts: Int = 3,
        forceRefresh: Bool = false,
        completion: @escaping (Result<[CKRecord], Error>) -> Void
    ) {
        let workoutIDString = workoutID.recordName
        let now = Date()
        
        // More intelligent throttling:
        // 1. Always honor forceRefresh
        // 2. Use a longer interval for empty results
        // 3. Track throttling per workout ID string, not per CKRecord.ID object
        if !forceRefresh {
            if let lastFetch = lastFetchTime[workoutIDString] {
                // Check if previous fetch had results
                let lastFetchHadResults = (lastFetchResultCounts[workoutIDString] ?? 0) > 0
                
                // Use shorter interval if we had results before (0.5s vs 5s)
                let interval = lastFetchHadResults ? 0.5 : 5.0
                
                if now.timeIntervalSince(lastFetch) < interval {
                    print("⚡️ CloudKit: Throttling fetch for workout \(workoutIDString) - last fetch was \(now.timeIntervalSince(lastFetch))s ago")
                    
                    // If we previously had results, return cached results instead of empty array
                    if lastFetchHadResults, let cachedRecords = self.recordCache[workoutIDString] {
                        print("⚡️ CloudKit: Returning \(cachedRecords.count) cached records instead of empty result")
                        completion(.success(cachedRecords))
                    } else {
                        completion(.success([]))
                    }
                    return
                }
            }
        }
        
        // Update last fetch time
        lastFetchTime[workoutIDString] = now
        
        // Create the workout reference for the query
        let workoutReference = CKRecord.Reference(recordID: workoutID, action: .none)
        let predicate = NSPredicate(format: "workoutRef == %@", workoutReference)
        let query = CKQuery(recordType: "UserExercises", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        print("⚡️ CloudKit: Fetching UserExercises for workout \(workoutIDString) (Attempt \(4-attempts) of 3)...")
        
        privateDatabase.fetch(withQuery: query,
                              inZoneWith: nil,
                              desiredKeys: nil,
                              resultsLimit: CKQueryOperation.maximumResults) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("⚡️ CloudKit: Error fetching exercises: \(error.localizedDescription)")
                    
                    // If we have attempts left, try again after a delay (retry logic)
                    if attempts > 1 {
                        print("⚡️ CloudKit: Retrying fetch in 1 second...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.fetchUserExercises(
                                for: workoutID,
                                attempts: attempts - 1,
                                forceRefresh: true, // Force refresh on retry
                                completion: completion
                            )
                        }
                    } else {
                        // Out of attempts, return the error
                        completion(.failure(error))
                    }
                    
                case .success(let fetchResult):
                    var records: [CKRecord] = []
                    for (_, recordResult) in fetchResult.matchResults {
                        do {
                            let record = try recordResult.get()
                            records.append(record)
                        } catch {
                            print("⚡️ CloudKit: Error retrieving exercise record: \(error.localizedDescription)")
                        }
                    }
                    
                    print("⚡️ CloudKit: Fetched \(records.count) exercise(s) for workout \(workoutIDString).")
                    
                    // Cache the results and count
                    self.lastFetchResultCounts[workoutIDString] = records.count
                    if !records.isEmpty {
                        self.recordCache[workoutIDString] = records
                    }
                    
                    // If we just saved a record and got 0 results, retry once more after a delay
                    if records.isEmpty && attempts > 1 {
                        print("⚡️ CloudKit: No records found, retrying in 1 second...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.fetchUserExercises(
                                for: workoutID,
                                attempts: attempts - 1,
                                forceRefresh: true, // Force refresh on retry
                                completion: completion
                            )
                        }
                    } else {
                        // Return the records, even if empty
                        completion(.success(records))
                    }
                }
            }
        }
    }
    
    // Helper method to copy values between records
    private func copyUpdatedValues(from sourceRecord: CKRecord, to targetRecord: CKRecord) {
        // Skip system fields
        for key in sourceRecord.allKeys() {
            if !key.starts(with: "__") {  // Skip system fields
                targetRecord[key] = sourceRecord[key]
            }
        }
    }
    
    func fetchUserWorkouts(
        for predicate: NSPredicate,
        completion: @escaping (Result<[CKRecord], Error>) -> Void
    ) {
        let query = CKQuery(recordType: "UserWorkout", predicate: predicate)
        
        // Optionally sort by creation date or any other field
        let sort = NSSortDescriptor(key: "creationDate", ascending: false)
        query.sortDescriptors = [sort]
        
        privateDatabase.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let records = records else {
                completion(.success([]))
                return
            }
            completion(.success(records))
        }
    }
    
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


}
