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
    var order: Int // Property to track block order
    
    // Conform to Identifiable with a String ID that is guaranteed to be unique
    var id: String {
        if let blockID = blockID {
            return blockID.recordName
        } else {
            // Generate a unique ID using title, order and UUID
            return "\(title)-\(order)-\(UUID().uuidString)"
        }
    }
    
    init(record: CKRecord) {
        self.blockID = record.recordID
        self.title = record["title"] as? String ?? ""
        self.order = record["order"] as? Int ?? 0
    }
    
    init(title: String, order: Int = 0) {
        self.title = title
        self.order = order
    }
    
    func toCKRecord() -> CKRecord {
        let record: CKRecord
        if let blockID = blockID {
            record = CKRecord(recordType: "WorkoutBlock", recordID: blockID)
        } else {
            record = CKRecord(recordType: "WorkoutBlock")
        }
        record["title"] = title as CKRecordValue
        record["order"] = order as CKRecordValue
        return record
    }
}




// MARK: - CloudKit Operations for WorkoutBlockManager

class WorkoutBlockManager: ObservableObject {
    @Published var blocks: [WorkoutBlock] = []
    @Published var isEditingBlockIndex: Bool = false
    @Published var blockBeingMoved: WorkoutBlock? = nil
    
    let privateDB = CKContainer.default().privateCloudDatabase
    private var isFetchingBlocks = false

    // Fetch all blocks from CloudKit with duplicate prevention
    func fetchBlocks() {
        // Guard against duplicate fetches
        guard !isFetchingBlocks else {
            print("🔄 FETCH: Already fetching blocks, skipping duplicate request")
            return
        }
        
        // Set flag to indicate fetch is in progress
        isFetchingBlocks = true
        
        print("🔍 FETCH: Starting fetchBlocks")
        
        // Create a query for all WorkoutBlock records
        let query = CKQuery(recordType: "WorkoutBlock", predicate: NSPredicate(value: true))
        
        // Fetch the records from CloudKit
        privateDB.perform(query, inZoneWith: nil) { [weak self] (records, error) in
            // Ensure we reset the flag in all completion paths
            defer {
                DispatchQueue.main.async {
                    self?.isFetchingBlocks = false
                }
            }
            
            guard let self = self else {
                print("❌ FETCH: Self reference lost")
                return
            }
            
            if let error = error {
                print("❌ FETCH: Error fetching blocks: \(error.localizedDescription)")
                return
            }
            
            if let records = records {
                print("✅ FETCH: Retrieved \(records.count) records from CloudKit")
                
                // Check if records have order field
                for (index, record) in records.enumerated() {
                    if let orderValue = record["order"] as? Int {
                        print("📋 FETCH: Record \(index) has order: \(orderValue), title: \(record["title"] as? String ?? "unknown")")
                    } else {
                        print("⚠️ FETCH: Record \(index) is MISSING order field! title: \(record["title"] as? String ?? "unknown")")
                    }
                }
                
                // Convert CKRecords to WorkoutBlock objects
                let fetchedBlocks = records.compactMap { WorkoutBlock(record: $0) }
                print("📦 FETCH: Converted to \(fetchedBlocks.count) WorkoutBlock objects")
                
                // Log blocks before sorting
                print("📊 FETCH: Before sorting:")
                for (index, block) in fetchedBlocks.enumerated() {
                    print("   Block \(index): '\(block.title)' with order: \(block.order)")
                }
                
                // Sort blocks by order property
                let sortedBlocks = fetchedBlocks.sorted { $0.order < $1.order }
                
                // Log blocks after sorting
                print("📊 FETCH: After sorting:")
                for (index, block) in sortedBlocks.enumerated() {
                    print("   Block \(index): '\(block.title)' with order: \(block.order)")
                }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    print("🔄 FETCH: Updating blocks array on main thread")
                    self.blocks = sortedBlocks
                    print("✅ FETCH: Completed with \(sortedBlocks.count) sorted blocks")
                }
            } else {
                print("ℹ️ FETCH: No blocks found")
            }
        }
    }
    
    // Add a new block.
    func addBlock(title: String) {
        // Determine the order for the new block (place it at the end)
        let newOrder = blocks.count
        
        // Create the block with the order
        let block = WorkoutBlock(title: title, order: newOrder)
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
                    print("Successfully added block: \(savedBlock.title) with order: \(savedBlock.order)")
                }
            } else {
                print("Error: No record returned after saving block.")
            }
        }
    }
    
    // Delete a block
    func deleteBlock(block: WorkoutBlock) {
        // Use blockID (the CKRecord.ID) instead of id (the String)
        guard let recordID = block.blockID else {
            print("Error: Cannot delete block without a record ID")
            return
        }
        
        privateDB.delete(withRecordID: recordID) { deletedRecordID, error in
            if let error = error {
                print("Error deleting block: \(error.localizedDescription)")
                return
            }
            
            // Make sure this is on the main thread
            DispatchQueue.main.async {
                // When comparing, use the string id property that's guaranteed to exist
                self.blocks.removeAll { $0.id == block.id }
                print("Successfully deleted block with record ID: \(recordID.recordName)")
            }
        }
    }

    // Update an existing block
    func updateBlock(block: WorkoutBlock, newTitle: String) {
        // Use blockID (the CKRecord.ID) instead of id (the String)
        guard let recordID = block.blockID else {
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
                            // When comparing blocks, use the string id property
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
    


    // In WorkoutBlockManager class
    func updateBlocksOrder(_ newOrderedBlocks: [WorkoutBlock]) {
        print("🔄 UPDATE: Starting updateBlocksOrder with \(newOrderedBlocks.count) blocks")
        
        // Log the order of blocks before updating
        print("📊 UPDATE: Original blocks order:")
        for (index, block) in blocks.enumerated() {
            print("   Block \(index): '\(block.title)' with order: \(block.order)")
        }
        
        // Log the new order being applied
        print("📊 UPDATE: New blocks order to be applied:")
        for (index, block) in newOrderedBlocks.enumerated() {
            print("   Block \(index): '\(block.title)' with current order: \(block.order)")
        }
        
        // Update order property for each block
        var updatedBlocks = newOrderedBlocks
        for i in 0..<updatedBlocks.count {
            var block = updatedBlocks[i]
            // Store previous order for debugging
            let previousOrder = block.order
            // Update order to match position in array
            block.order = i
            updatedBlocks[i] = block
            
            print("🔢 UPDATE: Setting block '\(block.title)' order from \(previousOrder) to \(i)")
        }
        
        // Update the blocks array with the new order
        self.blocks = updatedBlocks
        
        print("📊 UPDATE: Final blocks order in memory:")
        for (index, block) in blocks.enumerated() {
            print("   Block \(index): '\(block.title)' with order: \(block.order)")
        }
        
        // Save all blocks to CloudKit with their new order
        let container = CKContainer.default()
        let database = container.privateCloudDatabase
        
        var recordsToSave: [CKRecord] = []
        
        // Prepare all records to be saved
        for block in blocks {
            let record = block.toCKRecord()
            // Verify the order field is being set in the record
            print("💾 UPDATE: Preparing to save block '\(block.title)' with order: \(block.order)")
            print("   Record has order field: \(record["order"] != nil ? "YES" : "NO")")
            if let orderValue = record["order"] as? Int {
                print("   Record order value: \(orderValue)")
            }
            recordsToSave.append(record)
        }
        
        print("📤 UPDATE: Saving \(recordsToSave.count) records to CloudKit")
        
        // Use a batch operation to save all records at once
        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated
        
        operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ UPDATE: Error updating block orders: \(error.localizedDescription)")
                    if let ckError = error as? CKError {
                        print("   CloudKit error code: \(ckError.errorCode)")
                        if let serverErrorMessage = ckError.userInfo["ServerErrorDescription"] as? String {
                            print("   Server error message: \(serverErrorMessage)")
                        }
                    }
                } else {
                    print("✅ UPDATE: Successfully saved \(savedRecords?.count ?? 0) block records")
                    if let savedRecords = savedRecords {
                        for (index, record) in savedRecords.enumerated() {
                            if let title = record["title"] as? String, let order = record["order"] as? Int {
                                print("   Saved record \(index): '\(title)' with order: \(order)")
                            }
                        }
                    }
                }
            }
        }
        
        database.add(operation)
        print("🔄 UPDATE: Operation added to database queue")
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
