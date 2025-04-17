//
//  KeyCardView.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/26/25.
//

import SwiftUI
import CloudKit
import CoreImage
import AVFoundation

struct MembershipCardScannerView: View {
    @State private var showingScanner = false
    @State private var membershipCard: MembershipCard?
    @State private var pendingBarcodeValue: String?
    @State private var showDetailsEntry = false
    @State private var detailsEntryBarcode: BarcodeWrapper?
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ZStack {
            Color(red: 35/255, green: 36/255, blue: 49/255)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Text("Membership Card")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                
                let dummyMembershipCard = MembershipCard(
                    barcodeValue: "",
                    barcodeImage: nil,
                    memberName: "Elliot",
                    gymName: "Carbon",
                    nextChargeDate: Date(),
                    membershipLevel: "Standerd"
                )
                
                if let _ = membershipCard {
                    EditableMembershipCardView(
                        card: Binding(
                            get: { membershipCard ?? dummyMembershipCard }, // Provide a safe fallback
                            set: { membershipCard = $0 }
                        ),
                        onSave: { updatedCard in
                            membershipCard = updatedCard
                        },
                        onDelete: {
                            if let card = membershipCard {
                                MembershipCard.deleteMembershipCard(card) { result in
                                    switch result {
                                    case .success:
                                        // Delay clearing to allow SwiftUI to finish transition
                                        DispatchQueue.main.async {
                                            withAnimation { membershipCard = nil }
                                        }
                                    case .failure(let error):
                                        // Present error as you wish
                                        print("Delete failed: \(error)")
                                    }
                                }
                            }
                        }
                    )
                } else {
                    NoCardPlaceholder()
                }
                Spacer()
                Button(action: { showingScanner = true }) {
                    Text(membershipCard == nil ? "Scan Membership Card" : "Update Membership Card")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(20)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 18)
            .navigationBarTitleDisplayMode(.inline)
            // Barcode scanning & details entry flow unchanged
            .onAppear {
                print("👀 Attempting to fetch card…")
                MembershipCard.fetchMembershipCard { card in
                    if let card = card {
                        print("✅ Loaded card with ID: \(card.id?.recordName ?? "nil")")
                    }
                    membershipCard = card
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingScanner) {
            BarcodeScannerView { scannedValue in
                showingScanner = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    detailsEntryBarcode = BarcodeWrapper(value: scannedValue)
                }
            }
        }
        
        .sheet(item: $detailsEntryBarcode) { wrapped in
            MembershipCardDetailsEntryView(barcodeValue: wrapped.value) { card in
                membershipCard = card
                MembershipCard.saveMembershipCard(card)
                detailsEntryBarcode = nil
            }
        }
    }
}

struct BarcodeWrapper: Identifiable {
    let id = UUID()
    let value: String
}

// The stylized digital membership card UI!
struct MembershipCardView: View {
    var gymName: String
    var cardHolder: String
    var nextChargeDate: Date
    var barcodeValue: String
    var barcodeImage: UIImage
    var membershipLevel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.green)
                Text(gymName)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(membershipLevel)
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(16)
            }
            Divider().background(Color.white.opacity(0.15))
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Member")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(cardHolder)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next Charge:")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(nextChargeDate, format: .dateTime.month().day().year())
                        .font(.callout)
                        .foregroundColor(.white)
                }
            }
            
            VStack(spacing: 6) {
                Image(uiImage: barcodeImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 48)
                    .background(Color.white)
                    .cornerRadius(9)
                Text(barcodeValue)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(red: 46/255, green: 46/255, blue: 58/255).opacity(0.92))
                .shadow(color: .black.opacity(0.13), radius: 7, x: 0, y: 6)
        )
        .padding(.vertical, 10)
    }
}



struct NoCardPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(red: 46/255, green: 46/255, blue: 58/255).opacity(0.6))
                .frame(height: 160)
                .overlay(
                    VStack(spacing: 10) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 46))
                            .foregroundColor(.gray)
                        Text("No Membership Card Saved")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                )
            Text("Add your gym card for instant sign-in at the front desk.\nYou can update anytime.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.vertical)
    }
}

struct MembershipCardDetailsEntryView: View {
    let barcodeValue: String
    var onSubmit: (MembershipCard) -> Void

    @State private var memberName = ""
    @State private var gymName = ""
    @State private var nextChargeDate = Date()
    @State private var membershipLevel = ""

    @State private var saving = false
    @State private var saveError: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Member Info")) {
                    TextField("Member Name", text: $memberName)
                    TextField("Gym Name", text: $gymName)
                    TextField("Membership Level", text: $membershipLevel)
                }
                Section(header: Text("Next Charge Date")) {
                    DatePicker("Next Charge", selection: $nextChargeDate, displayedComponents: .date)
                }
                if let saveError = saveError {
                    Section {
                        Text(saveError)
                            .foregroundColor(.red)
                    }
                }
                Section {
                    Button(saving ? "Saving..." : "Save Card") {
                        saving = true
                        saveError = nil
                        let barcodeImage = MembershipCard.generateBarcode(from: barcodeValue)
                        let card = MembershipCard(
                            barcodeValue: barcodeValue,
                            barcodeImage: barcodeImage,
                            memberName: memberName.isEmpty ? "Member Name" : memberName,
                            gymName: gymName.isEmpty ? "Gym Name" : gymName,
                            nextChargeDate: nextChargeDate,
                            membershipLevel: membershipLevel.isEmpty ? "Standard" : membershipLevel
                        )
                        MembershipCard.saveMembershipCard(card) { result in
                            saving = false
                            switch result {
                            case .success:
                                onSubmit(card)
                            case .failure(let error):
                                saveError = error.localizedDescription
                            }
                        }
                    }
                    .disabled(memberName.isEmpty || gymName.isEmpty || membershipLevel.isEmpty || saving)
                }
            }
            .navigationTitle("Card Details")
        }
    }
}

struct EditableMembershipCardView: View {
    @Binding var card: MembershipCard
    var onSave: (MembershipCard) -> Void
    var onDelete: () -> Void

    @State private var isEditing = false
    @State private var tempMemberName = ""
    @State private var tempGymName = ""
    @State private var tempMembershipLevel = ""
    @State private var tempNextChargeDate = Date()
    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top row: Gym name and edit button
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.green)
                if isEditing {
                    TextField("Gym Name", text: $tempGymName)
                        .font(.headline)
                        .foregroundColor(.white)
                } else {
                    Text(card.gymName)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                Spacer()
                Text(card.membershipLevel)
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)
                Button {
                    if isEditing {
                        // Cancel editing
                        isEditing = false
                    } else {
                        // Start editing and buffer values
                        tempGymName = card.gymName
                        tempMemberName = card.memberName
                        tempMembershipLevel = card.membershipLevel
                        tempNextChargeDate = card.nextChargeDate
                        isEditing = true
                    }
                } label: {
                    Image(systemName: isEditing ? "xmark" : "pencil")
                        .foregroundColor(.green)
                }
            }
            Divider().background(Color.white.opacity(0.15))
            // Member info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Member")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    if isEditing {
                        TextField("Name", text: $tempMemberName)
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    } else {
                        Text(card.memberName)
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    }
                }
                Spacer()
            }
            // Membership Level
            if isEditing {
                TextField("Membership Level", text: $tempMembershipLevel)
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .background(Color.white.opacity(0.04))
            }
            // Next Charge Date
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next Charge")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    if isEditing {
                        DatePicker("",
                                   selection: $tempNextChargeDate,
                                   displayedComponents: [.date])
                            .datePickerStyle(CompactDatePickerStyle())
                            .labelsHidden()
                            .colorScheme(.dark)
                    } else {
                        Text(card.nextChargeDate, format: .dateTime.month().day().year())
                            .font(.callout)
                            .foregroundColor(.white)
                    }
                }
                Spacer()
            }
            VStack(spacing: 6) {
                if let barcodeImage = card.barcodeImage {
                    Image(uiImage: barcodeImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150) // <<-- Larger barcode
                        .background(Color.white)
                        .cornerRadius(9)
                    Text(card.barcodeValue ?? "")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            // Edit controls
            if isEditing {
                HStack {
                    Button("Save") {
                        // Update and save
                        card.gymName = tempGymName
                        card.memberName = tempMemberName
                        card.membershipLevel = tempMembershipLevel
                        card.nextChargeDate = tempNextChargeDate
                        MembershipCard.updateMembershipCard(card) { result in
                            switch result {
                            case .success:
                                onSave(card)
                            case .failure(let error):
                                // Optionally show error message
                                print("🛑 Error updating card: \(error.localizedDescription)")
                            }
                        }
                        isEditing = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(tempMemberName.isEmpty || tempGymName.isEmpty || tempMembershipLevel.isEmpty)
                    Spacer()
                }
            }
            // Delete button
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Card")
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 8)
            .alert("Are you sure you want to delete this membership card?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { onDelete() }
                Button("Cancel", role: .cancel) { }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(red: 46/255, green: 46/255, blue: 58/255).opacity(0.92))
                .shadow(color: .black.opacity(0.13), radius: 7, x: 0, y: 6)
        )
        .padding(.vertical, 10)
    }
}




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
