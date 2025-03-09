//
//  BlockModel.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/27/25.
//

import CloudKit
import SwiftUI

// MARK: - WorkoutBlock Model

struct WorkoutBlock: Identifiable {
    var blockID: CKRecord.ID?
    var title: String
    
    // Conform to Identifiable by defining `var id: CKRecord.ID?`
    // if you still want to be Identifiable:
    var id: CKRecord.ID? { blockID }
    
    init(record: CKRecord) {
        self.blockID = record.recordID
        self.title = record["title"] as? String ?? ""
    }
    
    init(title: String) {
        self.title = title
    }
    
    func toCKRecord() -> CKRecord {
        let record: CKRecord
        if let blockID = blockID {
            record = CKRecord(recordType: "WorkoutBlock", recordID: blockID)
        } else {
            record = CKRecord(recordType: "WorkoutBlock")
        }
        record["title"] = title as CKRecordValue
        return record
    }
}



// MARK: - CloudKit Operations for WorkoutBlockManager

class WorkoutBlockManager: ObservableObject {
    @Published var blocks: [WorkoutBlock] = []
    
    let privateDB = CKContainer.default().privateCloudDatabase
    
    // Fetch all blocks from CloudKit.
    func fetchBlocks() {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "WorkoutBlock", predicate: predicate)
        
        privateDB.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                print("Error fetching blocks: \(error.localizedDescription)")
                return
            }
            
            if let records = records {
                DispatchQueue.main.async {
                    self.blocks = records.map { WorkoutBlock(record: $0) }
                    print("Successfully fetched \(records.count) blocks from CloudKit.")
                }
            } else {
                print("Fetch completed: No records found for WorkoutBlock.")
            }
        }
    }
    
    // Add a new block.
    func addBlock(title: String) {
        let block = WorkoutBlock(title: title)
        let record = block.toCKRecord()
        
        privateDB.save(record) { savedRecord, error in
            if let error = error {
                print("Error saving block: \(error.localizedDescription)")
                return
            }
            
            if let savedRecord = savedRecord {
                let savedBlock = WorkoutBlock(record: savedRecord)
                DispatchQueue.main.async {
                    self.blocks.append(savedBlock)
                    print("Successfully added block: \(savedBlock.title)")
                }
            } else {
                print("Error: No record returned after saving block.")
            }
        }
    }
    
    func deleteBlock(block: WorkoutBlock) {
        guard let recordID = block.id else { return }
        privateDB.delete(withRecordID: recordID) { deletedRecordID, error in
            if let error = error {
                print("Error deleting block: \(error.localizedDescription)")
                return
            }
            // Make sure this is on the main thread
            DispatchQueue.main.async {
                self.blocks.removeAll { $0.id == recordID }
                print("Successfully deleted block with record ID: \(recordID.recordName)")
            }
        }
    }
    
    // Update an existing block.
    func updateBlock(block: WorkoutBlock, newTitle: String) {
        guard let recordID = block.id else {
            print("Error: Block has no record ID.")
            return
        }
        
        privateDB.fetch(withRecordID: recordID) { fetchedRecord, error in
            if let error = error {
                print("Error fetching record for update: \(error.localizedDescription)")
                return
            }
            
            if let fetchedRecord = fetchedRecord {
                fetchedRecord["title"] = newTitle as CKRecordValue
                self.privateDB.save(fetchedRecord) { updatedRecord, error in
                    if let error = error {
                        print("Error updating block: \(error.localizedDescription)")
                        return
                    }
                    
                    if let updatedRecord = updatedRecord {
                        let updatedBlock = WorkoutBlock(record: updatedRecord)
                        DispatchQueue.main.async {
                            if let index = self.blocks.firstIndex(where: { $0.id == block.id }) {
                                self.blocks[index] = updatedBlock
                            }
                            print("Successfully updated block. New title: \(updatedBlock.title)")
                        }
                    } else {
                        print("Error: No record returned after updating block.")
                    }
                }
            } else {
                print("Error: No record found for block update.")
            }
        }
    }
    

    
    // MARK: - Update Workout Block Association
    func updateWorkoutBlock(workout: WorkoutModel, newBlock: String, completion: @escaping (Bool) -> Void) {
        let recordID = workout.id  // No optional binding needed since 'id' is non-optional
        
        privateDB.fetch(withRecordID: recordID) { fetchedRecord, error in
            if let error = error {
                print("Error fetching workout record for block update: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            if let fetchedRecord = fetchedRecord {
                fetchedRecord["sectionTitle"] = newBlock as CKRecordValue
                self.privateDB.save(fetchedRecord) { updatedRecord, error in
                    if let error = error {
                        print("Error updating workout block: \(error.localizedDescription)")
                        completion(false)
                        return
                    }
                    
                    if updatedRecord != nil {
                        print("Successfully updated workout block to \(newBlock)")
                        completion(true)
                    } else {
                        print("Error: No record returned after updating workout block.")
                        completion(false)
                    }
                }
            } else {
                print("Error: No workout record found for block update.")
                completion(false)
            }
        }
    }
    
}



class BlockStore: ObservableObject {
    @Published var selectedBlock: WorkoutBlock? = nil
    
    // You could also store multiple blocks or do more logic here.
    // For instance, a dictionary [CKRecord.ID : WorkoutBlock].
    
    // Example function to select a block
    func selectBlock(_ block: WorkoutBlock) {
        self.selectedBlock = block
    }
}

extension WorkoutBlock {
    func delete(using manager: WorkoutBlockManager) {
        manager.deleteBlock(block: self)
    }
}
