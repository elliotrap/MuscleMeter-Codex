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
                        // 1) Fetch from CloudKit
                        viewModel.fetchExercises()
                        
                        // 2) If no exercises, assign dummy data
                        if viewModel.exercises.isEmpty {
                            let dummy1 = Exercise(
                                recordID: nil,
                                name: "Bench Press",
                                sets: 3,
                                reps: 10,
                                setWeights: [100, 105, 110],
                                setCompletions: [false, false, false],
                                setNotes: ["", "", ""],
                                exerciseNote: "Focus on form.",
                                setActualReps: [10, 10, 10],
                                timestamp: Date()
                            )
                            let dummy2 = Exercise(
                                recordID: nil,
                                name: "Squats",
                                sets: 3,
                                reps: 12,
                                setWeights: [135, 145, 155],
                                setCompletions: [true, false, false],
                                setNotes: ["Felt heavy", "", ""],
                                exerciseNote: "Keep your back straight.",
                                setActualReps: [12, 12, 10],
                                timestamp: Date()
                            )
                            
                            viewModel.exercises = [dummy1, dummy2]
                        }
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
                        exercise: exercise,
                        evm: viewModel,
                        subLevelProgress: { (ExperienceLevel.noob, ExperienceLevel.intermediate, 0.3) } // Extra argument 'subLevelProgress' in call
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
    // The entire exercise model
    var exercise: Exercise
    
    @ObservedObject var evm: ExerciseViewModel
    
    // MARK: - Incoming Data
    var recordID: CKRecord.ID?
    
    // For controlling plus-icon vs. text field on a per-index basis
    @State private var isTextFieldVisible: [Bool]
    @State private var isEditing = false
    @State private var showColorPicker = false
    @State private var accentColor: Color = .blue

    // For editing name/sets
    @State private var editedName: String = ""
    @State private var editedSets: Int = 0
    
    // A closure returning (currentLevel, nextLevel, fraction)
    let subLevelProgress: () -> (ExperienceLevel, ExperienceLevel?, Double)
    var rectangleProgress: CGFloat = 0.05
    var cornerRadius: CGFloat = 15
    var cardWidth: CGFloat = 336
    
    let formatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2 // Change based on your needs
        return nf
    }()


    
    // MARK: - Custom init
    init(
        exercise: Exercise,
        evm: ExerciseViewModel,
        // Accept subLevelProgress from outside
        subLevelProgress: @escaping () -> (ExperienceLevel, ExperienceLevel?, Double),
        // Provide defaults for these so they're optional
        rectangleProgress: CGFloat = 0.05,
        cornerRadius: CGFloat = 15,
        cardWidth: CGFloat = 336
    ) {
        self.exercise = exercise
        self.evm = evm
        self.subLevelProgress = subLevelProgress
        self.rectangleProgress = rectangleProgress
        self.cornerRadius = cornerRadius
        self.cardWidth = cardWidth
        
        // Initialize the boolean array based on setActualReps
        // If actualReps[i] != 0, we show the text field. If 0, show the plus icon.
        _isTextFieldVisible = State(initialValue: exercise.setActualReps.map { $0 != 0 })
    }
    var body: some View {
        VStack(spacing: 16) {
            
            
            if isEditing {
                
                let (currentLevel, _, fraction) = subLevelProgress()
                // 2) dynamicHeight based on setWeights
                ZStack(alignment: .center) {
                    // 1) Background shape with accent color
                    ExerciseCustomRoundedRectangle(
                        progress: rectangleProgress,
                        accentColor: isEditing ? accentColor : .blue,
                        cornerRadius: cornerRadius,
                        width: cardWidth,
                        height: 200
                    )
                    // 2) Main content
                    VStack(alignment: .leading, spacing: 16) {
                        // ---------------------------------------
                        // EDITING MODE
                        // ---------------------------------------
                        
                        // A pencil button to open color picker
                        Button {
                            showColorPicker = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(.black)
                                .padding(8)
                                .background(Color.white.opacity(0.3))
                                .clipShape(Circle())
                        }
                        
                        // 2.1) Edit the exercise name
                        ExerciseNameField(exercise: exercise, evm: evm)

                        
                        // 2.2) Edit the number of sets
                        SetsField(exercise: exercise, evm: evm)

                        
                        // 2.3) "Done" button to exit editing mode
                        Button("Done Editing") {
                            if let recordID = recordID {
                                evm.updateExercise(
                                    recordID: recordID,
                                    newName: editedName,
                                    newSets: editedSets
                                )
                            }
                            isEditing = false
                        }
                        .foregroundColor(.yellow)
                    }
                }
            } else {
                let (currentLevel, _, fraction) = subLevelProgress()
                // 2) dynamicHeight based on setWeights
                let dynamicHeight = 120.0 + Double(exercise.setWeights.count) * 80.0
                ZStack(alignment: .center) {
                    // 1) Background shape with accent color
                    ExerciseCustomRoundedRectangle(
                        progress: rectangleProgress,
                        accentColor: isEditing ? accentColor : .blue,
                        cornerRadius: cornerRadius,
                        width: cardWidth,
                        height: dynamicHeight
                    )
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(exercise.name)
                                .font(.title3)
                                .bold()
                                .foregroundColor(.white)
                            
                            Spacer()
                                .frame(width: 150)
                            
                            // Pencil to enter editing mode
                            Button {
                                // Prepare editing states
                                editedName = exercise.name
                                editedSets = exercise.sets
                                isEditing = true
                            } label: {
                                Image(systemName: exercise.exerciseNote.isEmpty ? "square.and.pencil" : "note.text")
                                    .foregroundColor(exercise.exerciseNote.isEmpty ? .white : .yellow)
                            }
                        }
                        // 1) Show the overall note
                        if exercise.exerciseNote.isEmpty {
                            Text("No note")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        } else {
                            Text(exercise.exerciseNote)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        
                        // Show reps/sets
                        Text("\(exercise.sets) X \(exercise.reps)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))

                        
                        // For each set, show row with setWeights and setActualReps
                        ForEach(exercise.setWeights.indices, id: \.self) { index in
                            rowForIndex(index)
                        }
                    }
                }
            }
            }
                .padding()
        
    }
    
    // MARK: - Row UI
    private func rowForIndex(_ index: Int) -> some View {
        HStack(spacing: 25) {
            
            // 3) Toggle set completion (optional)
            Button {
                var newCompletions = exercise.setCompletions
                newCompletions[index].toggle()
                if let recordID = exercise.recordID {
                    evm.updateExercise(recordID: recordID, newCompletions: newCompletions)
                }
            } label: {
                Image(systemName: exercise.setCompletions[index] ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(exercise.setCompletions[index] ? .green : .white)
            }
            
            // Within rowForIndex(_:)
            WeightField(exercise: exercise, index: index, evm: evm)
            .keyboardType(.numberPad)
            .foregroundColor(.white)
            .frame(width: 50, height: 30)
            
   
            
            // 2) Actual Reps: plus icon or text field
            // Plus icon -> toggles isTextFieldVisible[index] = true
            if !isTextFieldVisible[index] {
                Button {
                    isTextFieldVisible[index] = true
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.white.opacity(0.6))
                }
            } else {
                // Show parentheses + text field
                ActualRepsField(exercise: exercise, index: index, evm: evm)

            }
            
            // 4) Note button
            Button {
                // Possibly open a note editor for just this set
            } label: {
                Image(systemName: exercise.setNotes[index].isEmpty ? "square.and.pencil" : "note.text")
                    .foregroundColor(exercise.setNotes[index].isEmpty ? .white : .yellow)
            }
            
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(lineWidth: 2)
                .foregroundColor(Color.white.opacity(0.3))
        )
    }
    
    // MARK: - Update actual reps
    private func setActualRepsValue(index: Int, newValue: Int) {
        if let recordID = exercise.recordID {
            var newReps = exercise.setActualReps
            newReps[index] = newValue
            evm.updateExercise(recordID: recordID, newActualReps: newReps)
        }
    }
    
    func updateWeightValue(for exercise: Exercise, at index: Int, newWeight: Double) {
        guard let recordID = exercise.recordID else { return }
        
        // Copy the current weights and update only the specified index.
        var updatedWeights = exercise.setWeights
        updatedWeights[index] = newWeight
        
        // Call the existing CloudKit update function.
        evm.updateExercise(recordID: recordID, newWeights: updatedWeights)
    }
    // Helper to dismiss keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

struct ExerciseCardView2: View {
    // The entire exercise model
    let exercise: Exercise
    
    @ObservedObject var evm: ExerciseViewModel
    
    // MARK: - Incoming Data
    var recordID: CKRecord.ID?
    
    
    
    // A closure returning (currentLevel, nextLevel, fraction)
    let subLevelProgress: () -> (ExperienceLevel, ExperienceLevel?, Double)
    var rectangleProgress: CGFloat = 0.05
    var cornerRadius: CGFloat = 15
    var cardWidth: CGFloat = 336
    
    // MARK: - Local State
    @State private var editingExerciseNote = false
    @State private var showNoteEditor = false
    @State private var isTextFieldVisible = false
    
    @State private var isEditing = false
    @State private var showColorPicker = false
    @State private var accentColor: Color = .blue
    
    // For editing name/sets
    @State private var editedName: String = ""
    @State private var editedSets: Int = 0
    @State private var editingSetIndex: EditingSetIndex? = nil
    
    // Debounce
    @State private var debounceTimer: Timer?
    
    
    // A custom NumberFormatter for weights
    private let zeroFormatter: NumberFormatter = {
        let formatter = ZeroDefaultNumberFormatter()
        formatter.numberStyle = .decimal
        formatter.allowsFloats = true
        return formatter
    }()
    
    
    // If you have any local editing states (like isEditing for name), keep them here:
    @State private var isEditingName = false
    
    var body: some View {
        
  
        if isEditing {
//            
//            let (currentLevel, _, fraction) = subLevelProgress()
//            // 2) dynamicHeight based on setWeights
//            ZStack(alignment: .center) {
//                // 1) Background shape with accent color
//                ExerciseCustomRoundedRectangle(
//                    progress: rectangleProgress,
//                    accentColor: isEditing ? accentColor : .blue,
//                    cornerRadius: cornerRadius,
//                    width: cardWidth,
//                    height: 200
//                )
//                // 2) Main content
//                VStack(alignment: .leading, spacing: 16) {
//                    // ---------------------------------------
//                    // EDITING MODE
//                    // ---------------------------------------
//                    
//                    // A pencil button to open color picker
//                    Button {
//                        showColorPicker = true
//                    } label: {
//                        Image(systemName: "pencil")
//                            .foregroundColor(.black)
//                            .padding(8)
//                            .background(Color.white.opacity(0.3))
//                            .clipShape(Circle())
//                    }
//                    
//                    // 2.1) Edit the exercise name
//                    HStack {
//                        Text("Name:")
//                            .foregroundColor(.white)
//                        TextField(
//                            "Exercise Name",
//                            text: Binding(
//                                get: { exercise.name },
//                                set: { newValue in
//                                    // Immediately call update when user types
//                                    if let recordID = exercise.recordID {
//                                        evm.updateExercise(recordID: recordID, newName: newValue)
//                                    }
//                                }
//                            )
//                        )
//                        .textFieldStyle(RoundedBorderTextFieldStyle())
//                        .frame(width: 200)
//                    }
//                    
//                    // 2.2) Edit the number of sets
//                    HStack {
//                        Text("Sets:")
//                            .foregroundColor(.white)
//                        TextField(
//                            "Sets",
//                            text: Binding<String>(
//                                get: {
//                                    // Show "" if sets=0, or the integer as a string otherwise
//                                    exercise.sets == 0 ? "" : String(exercise.sets)
//                                },
//                                set: { newString in
//                                    // If user typed empty, do NOT update model to 0. Let them keep typing.
//                                    guard !newString.isEmpty else {
//                                        return // show empty in the UI, but keep the model's old sets
//                                    }
//                                    
//                                    // If typed a valid integer
//                                    if let newValue = Int(newString) {
//                                        // Update CloudKit
//                                        if let recordID = exercise.recordID {
//                                            evm.updateExercise(recordID: recordID, newSets: newValue)
//                                        }
//                                    } else {
//                                        // If typed invalid chars, do nothing. The user sees them,
//                                        // but the model remains unchanged.
//                                    }
//                                }
//                            )
//                        )
//                        .keyboardType(.numberPad)
//                        .textFieldStyle(RoundedBorderTextFieldStyle())
//                        .frame(width: 60)
//                        .toolbar {
//                            ToolbarItemGroup(placement: .keyboard) {
//                                Spacer()
//                                Button("Done") {
//                                    // Dismiss keyboard only
//                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
//                                }
//                            }
//                        }
//                    }
//                    
//                    // 2.3) "Done" button to exit editing mode
//                    Button("Done Editing") {
//                        if let recordID = recordID {
//                            evm.updateExercise(
//                                recordID: recordID,
//                                newName: editedName,
//                                newSets: editedSets
//                            )
//                        }
//                        isEditing = false
//                    }
//                    .foregroundColor(.yellow)
//                }
//            }
        } else {
                    let (currentLevel, _, fraction) = subLevelProgress()
                    // 2) dynamicHeight based on setWeights
                    let dynamicHeight = 120.0 + Double(exercise.setWeights.count) * 80.0
                    ZStack(alignment: .center) {
                        // 1) Background shape with accent color
                        ExerciseCustomRoundedRectangle(
                            progress: rectangleProgress,
                            accentColor: isEditing ? accentColor : .blue,
                            cornerRadius: cornerRadius,
                            width: cardWidth,
                            height: dynamicHeight
                        )
                        
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(exercise.name)
                                .font(.title3)
                                .bold()
                                .foregroundColor(.white)
                            
                            Spacer()
                                .frame(width: 150)
                            
                            // Pencil to enter editing mode
                            Button {
                                // Prepare editing states
                                editedName = exercise.name
                                editedSets = exercise.sets
                                isEditing = true
                            } label: {
                                Image(systemName: exercise.exerciseNote.isEmpty ? "square.and.pencil" : "note.text")
                                    .foregroundColor(exercise.exerciseNote.isEmpty ? .white : .yellow)
                            }
                        }
                        // 1) Show the overall note
                            if exercise.exerciseNote.isEmpty {
                                Text("No note")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            } else {
                                Text(exercise.exerciseNote)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                   

                        // Show reps/sets
                        Text("\(exercise.sets) X \(exercise.reps)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
          
                        
                        // Now display each set row
                        ForEach(exercise.setWeights.indices, id: \.self) { index in
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(lineWidth: 5)
                                    .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                                    .frame(width: 220, height: 50)
                                HStack {
                                    // 1) Toggle for set completion
                                    Button {
                                        var newCompletions = exercise.setCompletions
                                        newCompletions[index].toggle()
                                        
                                        // Update in CloudKit
                                        if let recordID = exercise.recordID {
                                            evm.updateExercise(
                                                recordID: recordID,
                                                newCompletions: newCompletions
                                            )
                                        }
                                    } label: {
                                        Image(systemName: exercise.setCompletions[index]
                                              ? "checkmark.circle.fill"
                                              : "circle")
                                        .foregroundColor(exercise.setCompletions[index] ? .green : .white)
                                    }
                                    
                                    
                                    // 2) Weight text field
                                    TextField(
                                        "Weight",
                                        value: Binding(
                                            get: {
                                                exercise.setWeights[index]
                                            },
                                            set: { newValue in
                                                var newWeights = exercise.setWeights
                                                newWeights[index] = newValue
                                                
                                                // Save the updated array
                                                if let recordID = exercise.recordID {
                                                    evm.updateExercise(
                                                        recordID: recordID,
                                                        newWeights: newWeights
                                                    )
                                                }
                                            }
                                        ),
                                        formatter: zeroFormatter
                                    )
                                    .keyboardType(.decimalPad)
                                    .foregroundColor(.white)
                                    .frame(width: 40)
                                    
                                    
 
                                    Spacer()
                                        .frame(width: 50)
                                    
              
                                }
                            }
                        }
                    }
                    .padding(50)
                }
                
            }
        }
    
    
    // A helper to dismiss the keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

struct SetRowView: View {
    let index: Int
    let exercise: Exercise
    @ObservedObject var evm: ExerciseViewModel
    
    // Local state controlling plus icon vs. text field for "actual reps"
    @State private var isTextFieldVisible: Bool = false
    
    // A number formatter for numeric text fields
    private let zeroFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.allowsFloats = true
        return f
    }()
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .stroke(lineWidth: 5)
                .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                .frame(width: 220, height: 50)
            
            HStack {

                
                // 2) Weight text field
                TextField(
                    "Weight",
                    value: Binding(
                        get: {
                            exercise.setWeights[index]
                        },
                        set: { newValue in
                            var newWeights = exercise.setWeights
                            newWeights[index] = newValue
                            if let recordID = exercise.recordID {
                                evm.updateExercise(recordID: recordID, newWeights: newWeights)
                            }
                        }
                    ),
                    formatter: zeroFormatter
                )
                .keyboardType(.decimalPad)
                .foregroundColor(.white)
                .frame(width: 40)
                
           
                SetRowView(index: index, exercise: exercise, evm: evm)
                          
                .onAppear {
                    // Decide initial visibility based on model's actualReps
                    let reps = exercise.setActualReps[index]
                    isTextFieldVisible = (reps != 0)
                }
                
                Spacer()
                    .frame(width: 10)
            }
        }
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
