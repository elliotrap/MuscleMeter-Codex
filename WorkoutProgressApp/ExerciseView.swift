//
//  ExerciseView.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/11/25.
//

import SwiftUI
import CloudKit

struct ExercisesView: View {
    @ObservedObject var viewModel: ExerciseViewModel
    @State private var showAddExercise = false

    init(workoutID: CKRecord.ID) {
        self.viewModel = ExerciseViewModel(workoutID: workoutID)
    }
    
    var body: some View {

        NavigationView {
            ZStack {
                // Background gradient.
                LinearGradient(
                    gradient: Gradient(colors: [Color("NeomorphBG2"), Color("NeomorphBG2")]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                mainContent
                    .navigationTitle("Your Exercises")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { showAddExercise = true }) {
                                Image(systemName: "plus")
                            }
                        }
                    }
                    .onAppear {
                        viewModel.fetchExercises()
                    }
                    .sheet(isPresented: $showAddExercise) {
                        AddExerciseView(viewModel: viewModel)
                    }
            }
        }
        }
    
    private var mainContent: some View {
        VStack {
            if viewModel.exercises.isEmpty {
                noExercisesView
            } else {
                exercisesListView
            }
        }
    }
    
    private var noExercisesView: some View {
        Text("No exercises added yet.")
            .foregroundColor(.secondary)
            .padding()
    }
    
    private var exercisesListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(viewModel.exercises, id: \.id) { exercise in
                    ExerciseCardView(
                        recordID: exercise.recordID,
                        evm: viewModel,
                        liftName: exercise.name,
                        reps: exercise.reps,
                        liftLevel: .noob,
                        setWeights: exercise.setWeights,
                        setCompletions: exercise.setCompletions,
                        setNotes: exercise.setNotes,
                        subLevelProgress: { (ExperienceLevel.noob, ExperienceLevel.intermediate, 0.3) }, setActualReps: exercise.setActualReps,
                        exerciseNote: exercise.exerciseNote
                    )
                }
            }
            .padding(.top)
        }
    }
}



struct AddExerciseView: View {
    @ObservedObject var viewModel: ExerciseViewModel
    
    @Environment(\.dismiss) var dismiss
    
    @State private var exerciseName = ""
    @State private var setsText = ""
    @State private var repsText = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Exercise Details")) {
                    TextField("Exercise name", text: $exerciseName)
                    
                    TextField("Sets", text: $setsText)
                        .keyboardType(.numberPad)
                    
                    TextField("Reps", text: $repsText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard
                            !exerciseName.isEmpty,
                            let sets = Int(setsText),
                            let reps = Int(repsText)
                        else { return }
                        
                        // Build arrays for each set
                        let setWeights = Array(repeating: 0.0, count: sets)      // All 0.0 by default
                        let setCompletions = Array(repeating: false, count: sets) // All false by default
                        
                        viewModel.addExercise(
                            name: exerciseName,
                            sets: sets,
                            reps: reps,
                            setWeights: setWeights, // Missing argument for parameter 'exerciseNote' in call
                            setCompletions: setCompletions
                        )
                        
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ExerciseCardView: View {
    // 1) recordID first
    var recordID: CKRecord.ID?
    
    // 2) evm second
    @ObservedObject var evm: ExerciseViewModel
    
    // 3) then the other required properties
    let liftName: String
    let reps: Int
    let liftLevel: ExperienceLevel
    
    @State var setWeights: [Double]
    @State var setCompletions: [Bool]
    @State var setNotes: [String]
    
    @State private var debounceTimer: Timer?
    @State private var weightString: String = "0"

    let subLevelProgress: () -> (ExperienceLevel, ExperienceLevel?, Double)
    

    /// Controls whether the sheet is open
    @State private var editingExerciseNote = false
    
    // Then the optional layout properties
    var rectangleProgress: CGFloat = 0.05
    var cornerRadius: CGFloat = 15
    var cardWidth: CGFloat = 336
    
    // 6. NEW: Add states for note editing
    @State private var editingSetIndex: EditingSetIndex? = nil
    @State private var showNoteEditor = false
    @State var setActualReps: [Int]
    
    // Give a default of "" here
    @State var exerciseNote: String = ""
    
    // Then in your view:
    private let zeroFormatter: NumberFormatter = {
        let formatter = ZeroDefaultNumberFormatter()
        formatter.numberStyle = .decimal
        formatter.allowsFloats = true
        // Additional config as needed
        return formatter
    }()
    
    var body: some View {
        let (currentLevel, _, fraction) = subLevelProgress()
        let dynamicHeight = 120.0 + Double(setWeights.count) * 40.0
        
        ZStack(alignment: .center) {
            ExerciseCustomRoundedRectangle(
                progressFraction: CGFloat(fraction),
                progress: rectangleProgress,
                currentLevel: currentLevel,
                cornerRadius: cornerRadius,
                width: cardWidth,
                height: dynamicHeight
            )
            
            VStack(alignment: .center, spacing: 16) {
                Text(liftName)
                    .font(.title3)
                    .bold()
                    .foregroundColor(.white)
                // 2) Single always-visible exercise note
                HStack {
                    if exerciseNote.isEmpty {
                        Text("No note")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    } else {
                        Text(exerciseNote)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    
                    Button(action: {
                        editingExerciseNote = true
                    }) {
                        Image(systemName: exerciseNote.isEmpty ? "square.and.pencil" : "note.text")
                            .foregroundColor(exerciseNote.isEmpty ? .white : .yellow)
                    }
                }
                
                Text("Reps per set: \(reps)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
        
                ForEach(setWeights.indices, id: \.self) { index in
                    HStack {
                        // 1) Toggle for set completion
                        Button(action: {
                            setCompletions[index].toggle()
                        }) {
                            Image(systemName: setCompletions[index]
                                  ? "checkmark.circle.fill"
                                  : "circle")
                            .foregroundColor(setCompletions[index] ? .green : .white)
                        }
                        
                        // 2) Weight text field
                        TextField("Weight", value: $setWeights[index], formatter: zeroFormatter)
                            .keyboardType(.decimalPad)
                            .foregroundColor(.white)
                            .frame(width: 60)
                            .onChange(of: setWeights) { newValue in
                                // Debounce logic for setWeights
                            }
                        
                        Text("lbs").foregroundColor(.white)
                        
                        // 3) "Reps Done" text field
                        TextField("Reps Done", value: $setActualReps[index], format: .number) // Thread 1: Fatal error: Index out of range
                            .keyboardType(.numberPad)
                            .foregroundColor(.white)
                            .frame(width: 60)
                            .onChange(of: setActualReps) { newValue in
                                // Debounce or update logic for setActualReps
                                debounceTimer?.invalidate()
                                debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                    if let recordID = recordID {
                                        evm.updateExerciseActualReps(recordID: recordID, newActualReps: setActualReps)
                                    }
                                }
                            }
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") {
                                        hideKeyboard()
                                    }
                                }
                            }
                        Spacer()
                        
                        // 4) Note button
                        Button(action: {
                            editingSetIndex = EditingSetIndex(index: index)
                        }) {
                            Image(systemName: setNotes[index].isEmpty ? "square.and.pencil" : "note.text")
                                .foregroundColor(setNotes[index].isEmpty ? .white : .yellow)
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: cardWidth, height: dynamicHeight)
        
        // Sheet for editing a note
        .sheet(isPresented: $editingExerciseNote) {
            NoteEditorView(
                note: $exerciseNote,
                onSave: {
                    // 1) The new note is in `exerciseNote`
                    // 2) Optionally update CloudKit if you have a recordID
                    if let recordID = recordID {
                        evm.updateExerciseNotes(
                            recordID: recordID,
                            newNotes: setNotes,
                            exerciseNote: exerciseNote
                        )
                    }
                }
            )
        }
    }
}
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

struct EditingSetIndex: Identifiable {
    let id = UUID()
    let index: Int
}

struct NoteEditorView: View {
    @Binding var note: String
    var onSave: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Set Note")) {
                    TextEditor(text: $note)
                        .frame(height: 200)
                }
            }
            .navigationTitle("Edit Note")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

// A custom NumberFormatter that defaults empty strings to 0
class ZeroDefaultNumberFormatter: NumberFormatter {
    override func getObjectValue(
        _ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
        for string: String,
        range: UnsafeMutablePointer<NSRange>?
    ) throws {
        if string.isEmpty {
            // If user typed nothing, return 0
            obj?.pointee = NSNumber(value: 0)
        } else {
            // Otherwise parse normally
            try super.getObjectValue(obj, for: string, range: range)
        }
    }
}


#Preview {
    ExercisesView(workoutID: CKRecord.ID(recordName: "DummyWorkoutID"))
}
