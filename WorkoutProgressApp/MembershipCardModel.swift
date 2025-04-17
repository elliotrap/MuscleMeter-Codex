//
//  KeyCardModel.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/26/25.
//

import CloudKit
import UIKit




struct MembershipCard: Identifiable {
    var id: CKRecord.ID?
    var barcodeValue: String?
    var barcodeImage: UIImage?
    var memberName: String
    var gymName: String
    var nextChargeDate: Date
    var membershipLevel: String
    
    // Create a MembershipCard from a CKRecord.
    init(record: CKRecord) {
        self.id = record.recordID
        self.barcodeValue = record["barcodeValue"] as? String
        self.memberName = record["memberName"] as? String ?? "Your Name"
        self.gymName = record["gymName"] as? String ?? "Your Gym"
        self.nextChargeDate = record["nextChargeDate"] as? Date ?? Date()
        self.membershipLevel = record["membershipLevel"] as? String ?? "Standard"
        
        if let asset = record["barcodeImage"] as? CKAsset,
           let fileURL = asset.fileURL,
           let imageData = try? Data(contentsOf: fileURL),
           let image = UIImage(data: imageData) {
            self.barcodeImage = image
        } else {
            self.barcodeImage = nil
        }
    }
    
    // For creating a new instance.
    init(id: CKRecord.ID? = nil, barcodeValue: String?, barcodeImage: UIImage?, memberName: String, gymName: String, nextChargeDate: Date, membershipLevel: String) {
        self.id = id
        self.barcodeValue = barcodeValue
        self.barcodeImage = barcodeImage
        self.memberName = memberName
        self.gymName = gymName
        self.nextChargeDate = nextChargeDate
        self.membershipLevel = membershipLevel
        
    }
    
    
    
    static func saveMembershipCard(_ card: MembershipCard, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let barcodeValue = card.barcodeValue,
              let barcodeImage = card.barcodeImage,
              let imageData = barcodeImage.pngData() else {
            print("❓ Missing barcode value or image")
            completion?(.failure(NSError(domain: "MembershipCard", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing data"])))
            return
        }
        
        let record = CKRecord(recordType: "MembershipCard")
        record["barcodeValue"] = barcodeValue as CKRecordValue
        record["memberName"] = card.memberName as CKRecordValue
        record["gymName"] = card.gymName as CKRecordValue
        record["nextChargeDate"] = card.nextChargeDate as CKRecordValue
        record["membershipLevel"] = card.membershipLevel as CKRecordValue
        
        let tempDir = NSTemporaryDirectory()
        let filePath = tempDir + UUID().uuidString + ".png"
        let fileURL = URL(fileURLWithPath: filePath)
        do {
            try imageData.write(to: fileURL)
            let asset = CKAsset(fileURL: fileURL)
            record["barcodeImage"] = asset
            
            let privateDatabase = CKContainer.default().privateCloudDatabase
            privateDatabase.save(record) { savedRecord, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("🛑 Error saving record to CloudKit: \(error.localizedDescription)")
                        completion?(.failure(error))
                    } else {
                        try? FileManager.default.removeItem(at: fileURL)
                        completion?(.success(()))
                    }
                }
            }
        } catch {
            print("🖼️ Error writing image data to temporary file: \(error.localizedDescription)")
            completion?(.failure(error))
        }
    }
    
    
    static func updateMembershipCard(_ card: MembershipCard, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let id = card.id else {
            print("❓ Card ID missing when attempting update")
            completion?(.failure(NSError(domain: "MembershipCard", code: -1, userInfo: [NSLocalizedDescriptionKey: "Card ID missing"])))
            return
        }

        let db = CKContainer.default().privateCloudDatabase
        db.fetch(withRecordID: id) { fetchedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🛑 Error fetching card for update: \(error.localizedDescription)")
                    completion?(.failure(error))
                    return
                }
                
                guard let record = fetchedRecord else {
                    print("❓ No existing card record found to update")
                    completion?(.failure(NSError(domain: "MembershipCard", code: -1, userInfo: [NSLocalizedDescriptionKey: "No record found"])))
                    return
                }
                
                // Update record fields
                record["barcodeValue"] = card.barcodeValue as CKRecordValue?
                record["memberName"] = card.memberName as CKRecordValue
                record["gymName"] = card.gymName as CKRecordValue
                record["nextChargeDate"] = card.nextChargeDate as CKRecordValue
                record["membershipLevel"] = card.membershipLevel as CKRecordValue
                if let barcodeImage = card.barcodeImage, let imageData = barcodeImage.pngData() {
                    let tempDir = NSTemporaryDirectory()
                    let filePath = tempDir + UUID().uuidString + ".png"
                    let fileURL = URL(fileURLWithPath: filePath)
                    do {
                        try imageData.write(to: fileURL)
                        let asset = CKAsset(fileURL: fileURL)
                        record["barcodeImage"] = asset
                    } catch {
                        print("🖼️ Error writing image data to temporary file: \(error.localizedDescription)")
                    }
                }

                // Save changes
                db.save(record) { _, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("🛑 Error updating card: \(error.localizedDescription)")
                            completion?(.failure(error))
                        } else {
                            print("✅ Membership card updated!")
                            completion?(.success(()))
                        }
                    }
                }
            }
        }
    }
    
    static func generateBarcode(from string: String) -> UIImage? {
        guard let data = string.data(using: .ascii),
              let filter = CIFilter(name: "CICode128BarcodeGenerator") else {
            print("🖼️ Could not create barcode filter or data")
            return nil
        }
        filter.setValue(data, forKey: "inputMessage")
        if let outputImage = filter.outputImage {
            let scaleX: CGFloat = 3.0
            let scaleY: CGFloat = 3.0
            let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            return UIImage(ciImage: transformedImage)
        }
        print("🖼️ Failed to create output image from barcode filter")
        return nil
    }
    
    static func fetchMembershipCard(completion: @escaping (MembershipCard?) -> Void) {
        let privateDatabase = CKContainer.default().privateCloudDatabase
        let query = CKQuery(recordType: "MembershipCard", predicate: NSPredicate(value: true))
        privateDatabase.perform(query, inZoneWith: nil) { records, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🛑 Error fetching membership card from CloudKit: \(error.localizedDescription)")
                }
                if let records = records, let record = records.first {
                    print("✅ Membership card fetched successfully.")
                    completion(MembershipCard(record: record))
                } else {
                    if error == nil {
                        print("❓ No membership card found in CloudKit")
                    }
                    completion(nil)
                }
            }
        }
    }

    
    static func deleteMembershipCard(_ card: MembershipCard, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let id = card.id else {
            print("❓ Card ID missing when attempting delete")
            completion?(.failure(NSError(domain: "MembershipCard", code: -1, userInfo: [NSLocalizedDescriptionKey: "Card ID missing"])))
            return
        }
        let db = CKContainer.default().privateCloudDatabase
        db.delete(withRecordID: id) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🛑 Error deleting membership card from CloudKit: \(error.localizedDescription)")
                    completion?(.failure(error))
                } else {
                    print("🗑️ Successfully deleted membership card!")
                    completion?(.success(()))
                }
            }
        }
    }
}
