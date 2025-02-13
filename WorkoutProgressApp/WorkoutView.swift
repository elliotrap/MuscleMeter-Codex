//
//  WorkoutView.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/11/25.
//
import SwiftUI
import CloudKit

struct WorkoutDetailView: View {
    @State var workout: WorkoutModel
    @StateObject private var exerciseViewModel: ExerciseViewModel
    @ObservedObject var workoutViewModel: WorkoutViewModel
    
    @State private var showEditNameSheet = false
    @State private var newWorkoutName = ""
    
    init(workout: WorkoutModel, workoutViewModel: WorkoutViewModel) {
        self._workout = State(initialValue: workout)
        self._exerciseViewModel = StateObject(wrappedValue: ExerciseViewModel(workoutID: workout.id))
        self.workoutViewModel = workoutViewModel
    }
    
    var body: some View {
        VStack {
            // Your exercise list and other content...
            List {
                ForEach(exerciseViewModel.exercises) { exercise in
                    VStack(alignment: .leading) {
                        Text(exercise.name)
                        // Other exercise info…
                    }
                }
            }
            .onAppear { exerciseViewModel.fetchExercises() }
        }
        .navigationTitle(workout.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit Name") {
                    newWorkoutName = workout.name
                    showEditNameSheet = true
                }
            }
        }
        .sheet(isPresented: $showEditNameSheet) {
            VStack(spacing: 20) {
                Text("Rename Workout")
                    .font(.headline)
                TextField("Workout Name", text: $newWorkoutName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                Button("Save") {
                    workoutViewModel.updateWorkout(workout: workout, newName: newWorkoutName)
                    workout.name = newWorkoutName
                    showEditNameSheet = false
                }
                .padding()
                Spacer()
            }
            .padding()
        }
    }
}

struct WorkoutsListView: View {
    @StateObject private var workoutViewModel = WorkoutViewModel()
    @State private var showAddWorkoutSheet = false
    
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
                ScrollView {
                    LazyVStack(spacing: 50) {
                        ForEach(workoutViewModel.workouts) { workout in
                            NavigationLink(
                                destination: ExercisesView(workoutID: workout.id)
                            ) {
                                WorkoutCardView(workout: workout, workoutViewModel: workoutViewModel)
                            }
                            .buttonStyle(PlainButtonStyle()) // So the pencil button can be tapped
                        }
                    }
                    .padding()
                }
                .navigationTitle("Workouts")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showAddWorkoutSheet = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
                .onAppear {
                    workoutViewModel.fetchWorkouts()
                    
                    // Insert dummy data if no workouts are fetched
                    if workoutViewModel.workouts.isEmpty {
                        let dummy1 = WorkoutModel(
                            id: CKRecord.ID(recordName: "Dummy1"),
                            name: "New Workout",
                            date: Date()
                        )
                        let dummy2 = WorkoutModel(
                            id: CKRecord.ID(recordName: "Dummy2"),
                            name: "Leg day",
                            date: Date()
                        )
                        workoutViewModel.workouts = [dummy1, dummy2]
                    }
                }
                .sheet(isPresented: $showAddWorkoutSheet) {
                    // Reuse your existing add workout view
                    AddWorkoutView(workoutViewModel: workoutViewModel) { newWorkout in
                        showAddWorkoutSheet = false
                    }
                }
            }
        }
    }
}

struct AddWorkoutView: View {
    @ObservedObject var workoutViewModel: WorkoutViewModel
    @Environment(\.dismiss) var dismiss
    @State private var workoutName: String = ""
    
    // Called when a new workout is successfully created.
    var onSave: (WorkoutModel) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Workout Name")) {
                    TextField("Enter workout name", text: $workoutName)
                }
            }
            .navigationTitle("Add Workout")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard !workoutName.isEmpty else { return }
                        workoutViewModel.addWorkout(named: workoutName) { newWorkout in
                            if let newWorkout = newWorkout {
                                onSave(newWorkout)
                            }
                        }
                    }
                }
            }
        }
    }
}




struct WorkoutCardView: View {
    @State var workout: WorkoutModel
    @ObservedObject var workoutViewModel: WorkoutViewModel
    
    @State private var isEditing = false
    @State private var editedWorkoutName: String = ""
    
    // Layout customization
    var cardWidth: CGFloat = 336
    var cardHeight: CGFloat = 120
    var cornerRadius: CGFloat = 15
    
    var body: some View {
        ZStack {
            // 1) Background shape
            CustomRoundedRectangle(
                progressFraction: 1.0,
                progress: 0.05,
                currentLevel: .noob, // Dummy level for color
                cornerRadius: cornerRadius,
                width: cardWidth,
                height: cardHeight
            )
            
            // 2) Workout info
            VStack(alignment: .leading, spacing: 8) {
                if isEditing {
                    // Editable text field
                    TextField("Workout Name", text: $editedWorkoutName, onCommit: {
                        workoutViewModel.updateWorkout(workout: workout, newName: editedWorkoutName)
                        workout.name = editedWorkoutName
                        isEditing = false
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.top, 8)
                    .frame(width: 250)
                } else {
                    Text(workout.name)
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)
                }
                
                if let date = workout.date {
                    Text("Date: \(date, formatter: DateFormatter.workoutDateFormatter)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding()
            
            // 3) Edit button pinned to top-right
            HStack {
                Spacer()
                    .frame(width: 250)
                VStack {
                    Button(action: {
                        // Start editing
                        editedWorkoutName = workout.name
                        isEditing.toggle()
                    }) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.black)
                            .padding(8)
                            .background(Color.white.opacity(0.3))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
            }
            .padding()
        }
        .frame(width: cardWidth, height: cardHeight)
    }
}

// DateFormatter for display
extension DateFormatter {
    static var workoutDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

//struct WorkoutCardView_Previews: PreviewProvider {
//    static var previews: some View {
//        WorkoutCardView(
//            workout: WorkoutModel(
//                id: CKRecord.ID(recordName: "DummyID"),
//                name: "Sample Workout",
//                date: Date()
//            ),
//            workoutViewModel: WorkoutViewModel()
//        )
//        .preferredColorScheme(.dark)   // See it in dark mode
//        .previewLayout(.sizeThatFits) // Fit the card to its natural size
//        .padding()
//    }
//}
#Preview {
    WorkoutsListView()
}
