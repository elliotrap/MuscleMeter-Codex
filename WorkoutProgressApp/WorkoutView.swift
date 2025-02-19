//
//  WorkoutView.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/11/25.
//
import SwiftUI
import CloudKit

struct WorkoutsListView: View {
    @StateObject private var workoutViewModel = WorkoutViewModel()
    @State private var showAddWorkoutSheet = false
    
    // For color picker
    @State private var showColorPicker = false
    @State private var selectedAccentColor: Color = .blue
    @State private var selectedWorkout: WorkoutModel? = nil
    
    var body: some View {
        NavigationView {
            listView
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color("NeomorphBG2"), Color("NeomorphBG2")]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
                .navigationTitle("Workouts")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        addWorkoutButton
                    }
                }
                .onAppear {
                    onAppearActions()
                }
                // 1) Add Workout sheet (unchanged)
                .sheet(isPresented: $showAddWorkoutSheet) {
                    AddWorkoutView(workoutViewModel: workoutViewModel)
                }
                // 2) Color picker sheet
                .sheet(isPresented: $showColorPicker) {
                    colorPickerSheet
                }
        }
    }
    
    // MARK: - The List
    
    private var listView: some View {
        List {
            ForEach(groupedWorkouts, id: \.key) { group in
                Section(header: Text(group.key)) {
                    ForEach(group.value) { workout in
                        // Pass a closure to trigger the color picker
                        WorkoutCardView(
                            workout: workout,
                            workoutViewModel: workoutViewModel,
                            onColorPickerRequested: {
                                // This closure is called when the user taps the “edit color” button in the card.
                                selectedWorkout = workout
                                selectedAccentColor = .blue // or load from workout if you store color
                                showColorPicker = true
                            }
                        )
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }
    }
    
    // MARK: - Color Picker Sheet
    
    private var colorPickerSheet: some View {
        VStack(spacing: 20) {
            Text("Choose a Color")
                .font(.headline)
            
            ColorPicker("Accent Color", selection: $selectedAccentColor, supportsOpacity: false)
                .padding()
            
            Button("Done") {
                // If you want to store the color in CloudKit or your model, do it here:
                if let workout = selectedWorkout {
                    // e.g. workoutViewModel.updateWorkoutColor(workout, color: selectedAccentColor)
                    // or store it in some property if you keep color locally
                }
                showColorPicker = false
            }
            .padding()
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Computed Properties & Methods
    
    private var groupedWorkouts: [(key: String, value: [WorkoutModel])] {
        let groups = Dictionary(grouping: workoutViewModel.workouts, by: { $0.sectionTitle ?? "Other" })
        return groups.sorted { $0.key < $1.key }
    }
    
    private var addWorkoutButton: some View {
        Button {
            showAddWorkoutSheet = true
        } label: {
            Image(systemName: "plus")
        }
    }
    
    private func onAppearActions() {
        workoutViewModel.fetchWorkouts()
        if workoutViewModel.workouts.isEmpty {
            let dummy1 = WorkoutModel(
                id: CKRecord.ID(recordName: "Dummy1"),
                name: "Back day",
                sectionTitle: "Heavy",
                date: Date()
            )
            let dummy2 = WorkoutModel(
                id: CKRecord.ID(recordName: "Dummy2"),
                name: "Leg day",
                sectionTitle: "Light",
                date: Date()
            )
            workoutViewModel.workouts = [dummy1, dummy2]
        }
    }
}


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





struct AddWorkoutView: View {
    @ObservedObject var workoutViewModel: WorkoutViewModel
    @Environment(\.dismiss) var dismiss
    @State private var workoutName: String = ""
    
    /// When using the picker, we use an index. The default titles come from the SectionTitleViewModel.
    @State private var selectedSectionIndex: Int = 0
    /// This will hold the custom title text if "Custom" is selected.
    @State private var customSectionTitle: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Workout Name")) {
                    TextField("Enter workout name", text: $workoutName)
                }
                
                Section(header: Text("Section Title")) {
                    Picker("Select a section", selection: $selectedSectionIndex) {
                        ForEach(0..<workoutViewModel.sectionTitles.count, id: \.self) { index in
                            Text(workoutViewModel.sectionTitles[index]).tag(index)
                        }
                        // "Custom" is appended as the last option.
                        Text("Custom").tag(workoutViewModel.sectionTitles.count)
                    }
                    .pickerStyle(.menu)
                    
                    // Show a text field if the user selects "Custom"
                    if selectedSectionIndex == workoutViewModel.sectionTitles.count {
                        TextField("Enter custom section title", text: $customSectionTitle)
                    }
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
                        
                        // Determine the final section title
                        var finalSectionTitle: String
                        if selectedSectionIndex == workoutViewModel.sectionTitles.count {
                            // User chose custom – ensure they typed something.
                            guard !customSectionTitle.isEmpty else { return }
                            finalSectionTitle = customSectionTitle
                            
                            // Save the custom title if it's not already in our list.
                            if !workoutViewModel.sectionTitles.contains(finalSectionTitle) {
                                workoutViewModel.addSectionTitle(finalSectionTitle)
                            }
                        } else {
                            finalSectionTitle = workoutViewModel.sectionTitles[selectedSectionIndex]
                        }
                        
                        // Save the workout with its section title.
                        workoutViewModel.addWorkout(
                            named: workoutName,
                            sectionTitle: finalSectionTitle
                        ) { newWorkout in
                            if newWorkout != nil {
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            workoutViewModel.fetchSectionTitles()
        }
    }
}



struct WorkoutCardView: View {
    @State var workout: WorkoutModel
    @ObservedObject var workoutViewModel: WorkoutViewModel
    
    // For editing the workout name
    @State private var isEditing = false
    @State private var editedWorkoutName: String = ""
    
    // For programmatic navigation
    @State private var navigate = false
    
    // This closure is called when the user wants to pick a color
    var onColorPickerRequested: () -> Void = {                 print("onColorPickerRequested called")
}
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 1) Card background + tap gesture
            cardBackground
                .contentShape(Rectangle())
                .onTapGesture {
                    // Only navigate if not editing
                    if !isEditing {
                        navigate = true
                    }
                }
            
            // 2) Ellipsis button (toggle editing)
            if !isEditing {
                Button {
                    isEditing = true
                    editedWorkoutName = workout.name
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.black)
                        .padding(8)
                        .background(Color.white.opacity(0.3))
                        .clipShape(Circle())
                }
                .padding([.top, .trailing], 8)
                .zIndex(1)
                .buttonStyle(.plain)
            }
            
            // 3) Hidden NavigationLink
            NavigationLink(
                destination: ExercisesView(workoutID: workout.id),
                isActive: $navigate
            ) {
                EmptyView()
            }
            .hidden()
        }
        .frame(width: 336, height: 120)
    }
    
    // MARK: - Card Background
    private var cardBackground: some View {
        // For simplicity, just pick a color or store in the model
        WorkoutCustomRoundedRectangle(
            progress: 0.05,
            accentColor: .blue,
            cornerRadius: 15,
            width: 336,
            height: 120
        )
        .overlay(
            VStack(alignment: .leading, spacing: 8) {
                if isEditing {
                    // Pencil button to request color picker from the parent
                    Button {
                        onColorPickerRequested() // or showColorPicker = true
                        print("Pencil button tapped!")
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(.black)
                            .padding(8)
                            .background(Color.white.opacity(0.3))
                            .clipShape(Circle())
                            // Make the tap area a bit bigger:
                            .frame(width: 44, height: 44)
                    }
                    .zIndex(2)  // So it sits above the card
                    .buttonStyle(.plain) // Prevent SwiftUI from inflating the tap area in weird ways
                    // EDITING MODE: text field, color picker button, etc.
                    TextField("Workout Name", text: $editedWorkoutName, onCommit: {
                        workoutViewModel.updateWorkout(workout: workout, newName: editedWorkoutName)
                        workout.name = editedWorkoutName
                        isEditing = false
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
                    
                    
                } else {
                    // NORMAL MODE: show the name & date
                    Text(workout.name)
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)
                    
                    if let date = workout.date {
                        Text("Date: \(date, formatter: DateFormatter.workoutDateFormatter)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding()
        )
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
