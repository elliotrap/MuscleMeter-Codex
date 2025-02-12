//
//  ExerciseView.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/11/25.
//

import SwiftUI

import CloudKit

struct ExercisesView: View {
    // Instead of creating the view model without parameters,
    // we require a workoutID. For example, you could pass in a real CKRecord.ID,
    // or for testing you could use a dummy value.
    @ObservedObject var viewModel: ExerciseViewModel
    
    @State private var showAddExercise = false

    // Provide an initializer that accepts a workoutID.
    init(workoutID: CKRecord.ID) {
        // Initialize the view model with the workoutID.
        self.viewModel = ExerciseViewModel(workoutID: workoutID)
    }
    
    var body: some View {
        NavigationView {
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
                    // Fetch existing exercises from CloudKit
                    viewModel.fetchExercises()
                }
                .sheet(isPresented: $showAddExercise) {
                    AddExerciseView(viewModel: viewModel)
                }
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack {
            if viewModel.exercises.isEmpty {
                noExercisesView
            } else {
                exercisesListView
            }
        }
    }
    
    // MARK: - "No Exercises" View
    private var noExercisesView: some View {
        Text("No exercises added yet.")
            .foregroundColor(.secondary)
            .padding()
    }
    
    // MARK: - Exercises List / ScrollView
    private var exercisesListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Explicitly specify the id so that SwiftUI can identify each exercise.
                ForEach(viewModel.exercises, id: \.id) { exercise in
                    ExerciseCardView(
                        liftName: exercise.name,    // Pass the plain String value.
                        sets: exercise.sets,         // Pass the plain Int value.
                        reps: exercise.reps,         // Pass the plain Int value.
                        weight: exercise.weight,     // Pass the plain Double value.
                        subLevelProgress: {
                            // Example sub-level progress:
                            (ExperienceLevel.noob, ExperienceLevel.intermediate, 0.3)
                        },
                        liftLevel: .noob
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
    @State private var weightText = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Exercise Details")) {
                    TextField("Exercise name", text: $exerciseName)
                    TextField("Sets", text: $setsText)
                        .keyboardType(.numberPad)
                    TextField("Reps", text: $repsText)
                        .keyboardType(.numberPad)
                    TextField("Weight (lbs)", text: $weightText)
                        .keyboardType(.decimalPad)
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
                            let reps = Int(repsText),
                            let weight = Double(weightText)
                        else { return }
                        
                        viewModel.addExercise(name: exerciseName, sets: sets, reps: reps, weight: weight)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ExerciseCardView: View {
    // If you still need an internal ViewModel:
    @ObservedObject var vm = ViewModel()

    // MARK: - Inputs
    let liftName: String   // e.g. "Bench", "Squat", "Deadlift"
    let sets: Int
    let reps: Int
    let weight: Double
    
    /// A function returning `(currentLevel, nextLevel, fraction)`
    /// to color the background of the card
    let subLevelProgress: () -> (ExperienceLevel, ExperienceLevel?, Double)
    
    /// Overall classification for the lift (e.g. vm.benchLevel)
    let liftLevel: ExperienceLevel
    
    // MARK: - Layout Customization
    var rectangleProgress: CGFloat = 0.05
    var cornerRadius: CGFloat = 15
    var cardWidth: CGFloat = 336
    var cardHeight: CGFloat = 120
    
    // MARK: - Body
    var body: some View {
        let (currentLevel, _, fraction) = subLevelProgress()
        
        ZStack {
            // 1) Custom background tinted by fraction & currentLevel
            CustomRoundedRectangle(
                progressFraction: CGFloat(fraction),
                progress: rectangleProgress,
                currentLevel: currentLevel,
                cornerRadius: cornerRadius,
                width: cardWidth,
                height: cardHeight
            )
            
            // 2) Inner content
            VStack(alignment: .leading, spacing: 8) {
                // Lift/Exercise Name
                Text(liftName)
                    .font(.title3)
                    .bold()
                    .foregroundColor(.white)
                
                // Sets, Reps, and Weight
                HStack(spacing: 16) {
                    VStack {
                        Text("Sets")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(sets)")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    VStack {
                        Text("Reps")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(reps)")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    VStack {
                        Text("Weight")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(weight, specifier: "%.0f") lbs")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                
                // Classification
                Text("\(liftName) Level: \(liftLevel.rawValue)")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding()
        }
        // If you want a fixed size, you can also add
        // .frame(width: cardWidth, height: cardHeight)
        // But the background shape is already sized in CustomRoundedRectangle.
    }
}
