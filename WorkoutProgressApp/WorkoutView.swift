//
//  WorkoutView.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/11/25.
//
import SwiftUI
import CloudKit

struct WorkoutDetailView: View {
    let workout: WorkoutModel
    @StateObject var exerciseVM = ExerciseViewModel(workoutID: CKRecord.ID(recordName: "defaultWorkout"))
    
    @State private var exerciseName = ""
    @State private var setsText = ""
    @State private var repsText = ""
    @State private var weightText = ""
    
    var body: some View {
        VStack {
            List {
                ForEach(exerciseVM.exercises, id: \.id) { exercise in
                    ExerciseCardView(
                        liftName: exercise.name,
                        sets: exercise.sets,
                        reps: exercise.reps,
                        weight: exercise.weight,
                        subLevelProgress: {
                            (ExperienceLevel.noob, ExperienceLevel.intermediate, 0.3)
                        },
                        liftLevel: .noob
                    )
                    .padding(.horizontal)
                }
                .onDelete { indices in
                    exerciseVM.deleteExercise(at: indices)
                }
            }
        }
        .navigationTitle(workout.name)
        .onAppear {
            exerciseVM.fetchExercises()
        }
    }
}

struct WorkoutsListView: View {
    @StateObject private var workoutViewModel = WorkoutViewModel()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(workoutViewModel.workouts) { workout in
                    NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                        Text(workout.name)
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        let workout = workoutViewModel.workouts[index]
                        workoutViewModel.deleteWorkout(workout)
                    }
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                Button(action: {
                    // Present a sheet or alert to create a new workout.
                    workoutViewModel.addWorkout(named: "New Workout")
                }) {
                    Image(systemName: "plus")
                }
            }
            .onAppear {
                workoutViewModel.fetchWorkouts()
            }
        }
    }
}
#Preview {
    WorkoutsListView()
}
