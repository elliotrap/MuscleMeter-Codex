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
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                mainContent
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    addWorkoutButton
                }
            }
            .onAppear {
                onAppearActions()
            }
            .sheet(isPresented: $showAddWorkoutSheet) {
                AddWorkoutView(workoutViewModel: workoutViewModel)
            }
        }
    }
    
    // MARK: - Subviews / Computed Properties
    
    /// The background gradient that covers the entire screen.
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color("NeomorphBG2"), Color("NeomorphBG2")]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    /// The main content (the List) on top of the gradient.
    private var mainContent: some View {
        listView
            .listStyle(.plain)
            .background(Color.clear)
            .scrollContentBackground(.hidden) // iOS 16+ to hide default background
    }
    
    /// The grouped list of workouts.
    private var listView: some View {
        List {
            ForEach(groupedWorkouts, id: \.key) { group in
                Section(header: Text(group.key)) {
                    ForEach(group.value) { workout in
                        WorkoutCardRow(workout: workout, workoutViewModel: workoutViewModel)
                            .listRowBackground(Color.clear)
                    }
                }
            }
        }
    }
    
    /// A computed property that groups workouts by their sectionTitle, sorted by key.
    private var groupedWorkouts: [(key: String, value: [WorkoutModel])] {
        let groups = Dictionary(grouping: workoutViewModel.workouts, by: { $0.sectionTitle ?? "Other" })
        return groups.sorted { $0.key < $1.key }
    }
    
    /// The "Add Workout" toolbar button.
    private var addWorkoutButton: some View {
        Button {
            showAddWorkoutSheet = true
        } label: {
            Image(systemName: "plus")
        }
    }
    
    /// Actions to perform when the view appears.
    private func onAppearActions() {
        workoutViewModel.fetchWorkouts()
        
        // Insert dummy data if no workouts are fetched.
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
    
    // For color picking
    @State private var showColorPicker = false
    @State private var accentColor: Color = .blue  // Default color if none is chosen
    
    // Layout customization
    var cardWidth: CGFloat = 336
    var cardHeight: CGFloat = 120
    var cornerRadius: CGFloat = 15
    
    var body: some View {
        ZStack {
            // 1) Background shape with user-chosen accent color
            WorkoutCustomRoundedRectangle(
                progress: 0.05,
                accentColor: accentColor,
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
            
            // 3) Ellipsis button pinned to top-right
            HStack {
                Spacer().frame(width: 250)
                VStack {
                    Button(action: {
                        // Show the color picker sheet
                        showColorPicker.toggle()
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
        .sheet(isPresented: $showColorPicker) {
            colorPickerSheet
        }
    }
    
    // MARK: - Color Picker Sheet
    private var colorPickerSheet: some View {
        VStack(spacing: 20) {
            Text("Choose a Color")
                .font(.headline)
            
            ColorPicker("Accent Color", selection: $accentColor, supportsOpacity: false)
                .padding()
            
            Button("Save") {
                // If you want to persist this color in your WorkoutModel or CloudKit,
                // you would call an update function here, e.g.:
                // workoutViewModel.updateWorkoutColor(workout, color: accentColor)
                
                showColorPicker = false
            }
            .padding()
            
            Spacer()
        }
        .presentationDetents([.medium, .large])  // iOS 16+ (optional)
        .padding()
    }
}


struct WorkoutCardRow: View {
    let workout: WorkoutModel
    @ObservedObject var workoutViewModel: WorkoutViewModel
    
    // For color picking
    @State private var showColorPicker = false
    @State private var accentColor: Color = .blue  // Or load from model if desired
    
    // For name editing
    @State private var isEditing = false
    @State private var editedWorkoutName: String = ""
    
    // Layout
    var cardWidth: CGFloat = 336
    var cardHeight: CGFloat = 120
    var cornerRadius: CGFloat = 15
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 1) NavigationLink for the main card tap
            NavigationLink(destination: ExercisesView(workoutID: workout.id)) {
                ZStack {
                    // The custom rectangle with a user-chosen color
                    WorkoutCustomRoundedRectangle(
                        progress: 0.05,
                        accentColor: accentColor,
                        cornerRadius: cornerRadius,
                        width: cardWidth,
                        height: cardHeight
                    )
                    
                    // Workout info text
                    VStack(alignment: .leading, spacing: 8) {
                        if isEditing {
                            TextField("Workout Name", text: $editedWorkoutName, onCommit: {
                                workoutViewModel.updateWorkout(workout: workout, newName: editedWorkoutName)
                                // Update local model name
                                // (If you have a color to store, do it here too)
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
                }
                .frame(width: cardWidth, height: cardHeight)
            }
            // Make sure to use a plain button style so the entire card
            // looks like one clickable area (and does not interfere with the ellipsis).
            .buttonStyle(PlainButtonStyle())
            
            // 2) Ellipsis button (outside the NavigationLink)
            // so it can be tapped independently
            Button {
                showColorPicker.toggle()
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.black)
                    .padding(8)
                    .background(Color.white.opacity(0.3))
                    .clipShape(Circle())
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
        // 3) Color picker sheet
        .sheet(isPresented: $showColorPicker) {
            colorPickerSheet
        }
    }
    
    // MARK: - Color Picker Sheet
    private var colorPickerSheet: some View {
        VStack(spacing: 20) {
            Text("Choose a Color")
                .font(.headline)
            
            ColorPicker("Accent Color", selection: $accentColor, supportsOpacity: false)
                .padding()
            
            Button("Save") {
                // If you want to persist accentColor in CloudKit or your model,
                // you would call an update function here, e.g.:
                // workoutViewModel.updateWorkoutColor(workout, color: accentColor)
                
                showColorPicker = false
            }
            .padding()
            
            Spacer()
        }
        .presentationDetents([.medium, .large]) // iOS 16+ (optional)
        .padding()
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
