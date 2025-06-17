//
//  KeyCardView.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/26/25.
//

import SwiftUI
import CoreImage

import SwiftUI
import CloudKit
import CoreImage

struct MembershipCardScannerView: View {
    @State private var showingScanner = false
    @State private var membershipCard: MembershipCard?
    
    var body: some View {
            VStack(spacing: 20) {
                if let card = membershipCard,
                   let barcodeValue = card.barcodeValue,
                   let barcodeImage = card.barcodeImage {
                    Text("Membership Card")
                        .font(.headline)
                    Text("Barcode: \(barcodeValue)")
                        .font(.title2)
                        .padding(.bottom, 10)
                    
                    Image(uiImage: barcodeImage)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.white)
                        .frame(height: 200)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                } else {
                    Text("No Membership Card Saved")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
                
                Button(action: {
                    showingScanner = true
                }) {
                    Text("Scan Membership Card")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // Optionally, you could add a separate update button if needed.
                
                Spacer()
            }
            .navigationTitle("Membership Card")
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView { scannedValue in
                    // Generate a barcode image from the scanned numeric value.
                    let image = generateBarcode(from: scannedValue)
                    let card = MembershipCard(barcodeValue: scannedValue, barcodeImage: image)
                    membershipCard = card
                    showingScanner = false
                    // Save the card to CloudKit.
                    saveMembershipCard(card)
                }
            }
            .onAppear {
                fetchMembershipCard()
            }
        
    }
    
    /// Generate a barcode image using Core Image's CICode128BarcodeGenerator.
    func generateBarcode(from string: String) -> UIImage? {
        guard let data = string.data(using: .ascii),
              let filter = CIFilter(name: "CICode128BarcodeGenerator")
        else { return nil }
        
        filter.setValue(data, forKey: "inputMessage")
        if let outputImage = filter.outputImage {
            // Scale the image for clarity.
            let scaleX: CGFloat = 3.0
            let scaleY: CGFloat = 3.0
            let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            return UIImage(ciImage: transformedImage)
        }
        return nil
    }
    
    /// Saves the MembershipCard to CloudKit (using the private database).
    func saveMembershipCard(_ card: MembershipCard) {
        guard let barcodeValue = card.barcodeValue,
              let barcodeImage = card.barcodeImage,
              let imageData = barcodeImage.pngData()
        else { return }
        
        let record = CKRecord(recordType: "MembershipCard")
        record["barcodeValue"] = barcodeValue as CKRecordValue
        
        // Save the barcode image as a CKAsset.
        let tempDir = NSTemporaryDirectory()
        let filePath = tempDir + UUID().uuidString + ".png"
        let fileURL = URL(fileURLWithPath: filePath)
        do {
            try imageData.write(to: fileURL)
            let asset = CKAsset(fileURL: fileURL)
            record["barcodeImage"] = asset
            
            let privateDatabase = CKContainer.default().privateCloudDatabase
            privateDatabase.save(record) { savedRecord, error in
                if let error = error {
                    print("Error saving record: \(error.localizedDescription)")
                } else {
                    print("Membership card saved to CloudKit!")
                    // Remove the temporary file.
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        } catch {
            print("Error writing image data to temporary file: \(error.localizedDescription)")
        }
    }
    
    /// Fetches the saved MembershipCard from CloudKit.
    func fetchMembershipCard() {
        let privateDatabase = CKContainer.default().privateCloudDatabase
        let query = CKQuery(recordType: "MembershipCard", predicate: NSPredicate(value: true))
        privateDatabase.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                print("Error fetching membership card: \(error.localizedDescription)")
            } else if let records = records, !records.isEmpty,
                      let record = records.first {
                DispatchQueue.main.async {
                    self.membershipCard = MembershipCard(record: record)
                }
            } else {
                print("No membership card found in CloudKit.")
            }
        }
    }
}





import SwiftUI
import AVFoundation


struct BarcodeScannerView: UIViewRepresentable {
    /// Completion handler called when a barcode is successfully scanned.
    var completion: (String) -> Void

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: BarcodeScannerView
        var captureSession: AVCaptureSession?
        
        init(parent: BarcodeScannerView) {
            self.parent = parent
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first,
               let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
               let stringValue = readableObject.stringValue {
                captureSession?.stopRunning()
                DispatchQueue.main.async {
                    self.parent.completion(stringValue)
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice)
        else {
            return view
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return view
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            // Configure the barcode types you expect.
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .code39, .code128, .upce]
        } else {
            return view
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = UIScreen.main.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.captureSession = captureSession
        captureSession.startRunning()
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

#Preview {
        MembershipCardScannerView()
}
