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
                        liftName: exercise.name,
                        reps: exercise.reps,
                        liftLevel: .noob,
                        setWeights: exercise.setWeights,
                        setCompletions: exercise.setCompletions,
                        setNotes: exercise.setNotes,
                        subLevelProgress: { (ExperienceLevel.noob, ExperienceLevel.intermediate, 0.3) }
                    )
                    .padding(.horizontal)
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
                            setWeights: setWeights,
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
    // 1. Basic inputs
    let liftName: String
    let reps: Int
    let liftLevel: ExperienceLevel
    
    // 2. Arrays for sets
    @State var setWeights: [Double]
    @State var setCompletions: [Bool]
    @State var setNotes: [String]
    
    // 3. Progress
    let subLevelProgress: () -> (ExperienceLevel, ExperienceLevel?, Double)
    
    // 4. Observed object
    @ObservedObject var vm = ViewModel()
    
    // 5. Layout
    var rectangleProgress: CGFloat = 0.05
    var cornerRadius: CGFloat = 15
    var cardWidth: CGFloat = 336
    
    // 6. NEW: Add states for note editing
    @State private var editingSetIndex: Int? = nil
    @State private var showNoteEditor = false
    
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
                
                Text("Reps per set: \(reps)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                ForEach(setWeights.indices, id: \.self) { index in
                    HStack {
                        // Toggle for set completion
                        Button(action: {
                            setCompletions[index].toggle()
                        }) {
                            Image(systemName: setCompletions[index]
                                  ? "checkmark.circle.fill"
                                  : "circle")
                            .foregroundColor(setCompletions[index] ? .green : .white)
                        }
                        
                        // Weight text field
                        TextField("Weight", value: $setWeights[index], format: .number)
                            .keyboardType(.decimalPad)
                            .foregroundColor(.white)
                            .frame(width: 60)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") {
                                        hideKeyboard()
                                    }
                                }
                            }
                        
                        Text("lbs")
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // NOTE Button: indicates whether there's a note
                        Button(action: {
                            editingSetIndex = index
                            showNoteEditor = true
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
        .sheet(isPresented: $showNoteEditor) {
            if let idx = editingSetIndex {
                NoteEditorView(
                    note: $setNotes[idx],
                    onSave: {
                        // Optionally update CloudKit or do something with setNotes[idx]
                    }
                )
            }
        }
    }
}
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
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
#Preview {
    ExercisesView(workoutID: CKRecord.ID(recordName: "DummyWorkoutID"))
}
