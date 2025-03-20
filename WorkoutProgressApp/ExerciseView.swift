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
    
    // Add these state variables to prevent navigation issues
    @State private var isInitiallyLoading = true
    @State private var hasCompletedInitialLoad = false
    
    // Track which exercise is currently being moved
    @State private var selectedToMove: Exercise? = nil
    
    // In your parent view that shows the workout
    @State private var showAddExerciseSheet = false
    @State private var lastFetchedWorkoutID: String?
    
    // Add these properties to your view:
    @State private var lastNavigationTime = Date.distantPast
    private let navigationDebounceInterval: TimeInterval = 0.3
    
    @State private var viewRefreshID = UUID() // Additional local refresh trigger
    
    // Add these properties to your view
    @State private var isLoading = false
    @State private var hasAttemptedLoad = false
    
    
    init(workoutID: CKRecord.ID) {
        self.viewModel = ExerciseViewModel(workoutID: workoutID)
    }
    
    
    var body: some View {
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
                            name: "Knelling Lat Pulldowns",
                            sets: 1,
                            reps: 10,
                            setWeights: [100, 105, 110],
                            setCompletions: [false, false, false],
                            setNotes: ["", "", ""],
                            exerciseNote: "Focus on form.",
                            setActualReps: [10, 10, 10],
                            timestamp: Date(),
                            accentColorHex: "#0000FF",
                            sortIndex: 0
                        )
                        let dummy2 = Exercise(
                            recordID: nil,
                            name: "Squats",
                            sets: 1,
                            reps: 12,
                            setWeights: [135, 145, 155],
                            setCompletions: [true, false, false],
                            setNotes: ["Felt heavy", "", ""],
                            exerciseNote: "Keep your back straight.",
                            setActualReps: [12, 12, 10],
                            timestamp: Date(),
                            accentColorHex: "#0000FF",
                            sortIndex: 1
                        )
                        
                        viewModel.exercises = [dummy1, dummy2]
                    }
                }
            
            // And update your sheet presentation:
                .sheet(isPresented: $showAddExercise) {
                    NavigationView {
                        AddExerciseView(viewModel: viewModel, onExerciseAdded: {
                            print("Exercise added successfully")
                        })
                        .presentationDetents([.fraction(0.4)])
                        .presentationDragIndicator(.visible)
                    }
                }
        }
        // Add this to the end of your body:
        .onDisappear {
            print("ExercisesView disappeared, cleaning up resources")
            viewModel.unsubscribeFromCloudKitChanges()
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
        // Wrapper for the entire list
        return ZStack {
            VStack {
                // Debug info
                Group {
                    Text("\(viewModel.exercises.count) exercises loaded (v\(viewModel.stateVersion))")
                    Text("Workout: \(viewModel.workoutID.recordName.prefix(8))...")
                }
                .font(.caption)
                .foregroundColor(.gray)
                .opacity(0.7)
                .padding(.top, 4)
                
                // Main content with clear loading states
                if isLoading {
                    // Show loading indicator when we're actively loading
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                        Text("Loading exercises...")
                            .foregroundColor(.gray)
                    }
                    .transition(.opacity)
                } else if viewModel.exercises.isEmpty {
                    // Only show empty state if we've tried loading and got nothing
                    if hasAttemptedLoad {
                        emptyStateView
                            .transition(.opacity)
                    } else {
                        // If we haven't attempted to load yet, show a loading indicator
                        // This handles the initial state
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                            Text("Preparing...")
                                .foregroundColor(.gray)
                        }
                        .transition(.opacity)
                    }
                } else {
                    // We have exercises to show
                    exercisesContentView
                        .transition(.opacity)
                }
            }
            
            // Use a simpler ID that won't cause excessive rebuilds
            .id("workout-\(viewModel.workoutID.recordName)-\(viewRefreshID)")
        }
        .onAppear {
            print("🔍 VIEW: exercisesListView appeared for workout: \(viewModel.workoutID.recordName)")
            
            // IMPORTANT: Set loading state immediately on appear for better UX
            self.isLoading = true
            
            // Check if this is a rapid navigation
            let now = Date()
            let isRapidNavigation = now.timeIntervalSince(lastNavigationTime) < navigationDebounceInterval
            lastNavigationTime = now
            
            // Determine if we need to fetch
            let differentWorkout = viewModel.lastFetchedWorkoutID != viewModel.workoutID.recordName
            let shouldFetch = !hasAttemptedLoad || differentWorkout || viewModel.exercises.isEmpty
            
            // Only fetch if needed and not navigating too rapidly
            if shouldFetch && !isRapidNavigation {
                print("🔍 VIEW: Triggering fetch for workout: \(viewModel.workoutID.recordName)")
                
                // Clear any existing operations
                ExerciseViewModel.clearOperationsForWorkout(viewModel.workoutID.recordName)
                
                // Add a slight delay to allow the loading state to be visible
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Verify view is still visible
                    guard viewModel.isActive else {
                        print("🔍 VIEW: Skipping fetch - view no longer active")
                        self.isLoading = false
                        return
                    }
                    
                    // Perform the fetch
                    self.viewModel.fetchExercises(forceRefresh: differentWorkout) { success in
                        print("🔍 VIEW: Fetch completed with success: \(success). Exercises: \(self.viewModel.exercises.count)")
                        
                        // Ensure loading indicator stays visible long enough to be seen
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation {
                                self.isLoading = false
                                self.hasAttemptedLoad = true
                                self.viewRefreshID = UUID()
                            }
                        }
                    }
                }
            } else {
                let reason = isRapidNavigation ? "rapid navigation" : "data appears valid"
                print("🔍 VIEW: Skipping fetch on appear, \(reason)")
                
                // Even if we skip the fetch, show a brief loading indicator for consistency
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        self.isLoading = false
                        self.hasAttemptedLoad = true
                    }
                }
            }
        }
        .onDisappear {
            print("🔍 VIEW: exercisesListView disappeared for workout: \(viewModel.workoutID.recordName)")
            
            // Reset loading state and clear operations
            self.isLoading = false
            ExerciseViewModel.clearOperationsForWorkout(viewModel.workoutID.recordName)
        }
    }
    
    
    
    // Helper to check if we should expect exercises for this workout
    private func shouldHaveExercises() -> Bool {
        let workoutIDString = viewModel.workoutID.recordName
        
        // Check if we've previously fetched exercises for this workout
        if let lastCount = UserDefaults.standard.object(forKey: "LastFetchCount-\(workoutIDString)") as? Int {
            return lastCount > 0
        }
        
        return false
    }
    
    // Add this helper function to your view
    private func needsFreshData() -> Bool {
        // Logic to determine if we need fresh data:
        // 1. Current exercises count is zero
        // 2. OR The last fetched workout ID doesn't match current workout
        // 3. OR It's been too long since last fetch
        
        if viewModel.exercises.isEmpty {
            print("🔍 VIEW: Need fresh data - exercises array is empty")
            return true
        }
        
        if lastFetchedWorkoutID != viewModel.workoutID.recordName {
            print("🔍 VIEW: Need fresh data - workout ID changed from \(lastFetchedWorkoutID ?? "nil") to \(viewModel.workoutID.recordName)")
            return true
        }
        
        // Optional: Check if data is stale based on time
        if Date().timeIntervalSince(viewModel.lastFetchTime) > 60 { // 1 minute
            print("🔍 VIEW: Need fresh data - last fetch was too long ago")
            return true
        }
        
        return false
    }
    
    
    
    // Empty state view
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell")
                .font(.system(size: 50))
                .foregroundColor(.gray)
                .padding(.bottom, 8)
            
            Text("No Exercises Yet")
                .font(.headline)
            
            Text("Add your first exercise to get started")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(.vertical, 40)
    }
    
    // Regular content with exercises
    private var exercisesContentView: some View {
        ScrollView {
            VStack(spacing: 8) {
                // If we're moving an exercise, show the "move to start" button
                // only if the exercise isn't already at the start
                if let movingExercise = selectedToMove,
                   let currentIndex = viewModel.exercises.firstIndex(where: { $0.id == movingExercise.id }),
                   currentIndex > 0 {
                    insertionButton(position: "start", exercise: nil, targetIndex: 0)
                        .padding(.bottom, 8)
                }
                
                // List all exercises with insertion points
                ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { (localIndex, exercise) in
                    VStack(spacing: 0) {
                        // Exercise card
                        ExerciseCardView(
                            exercise: exercise,
                            evm: viewModel,
                            onRequestMove: { exercise in
                                selectedToMove = exercise
                                print("DEBUG: onRequestMove called for \(exercise.name)")
                                viewModel.refreshID = UUID() // Force view refresh
                            }
                        )
                        .id("\(viewModel.refreshID)-card-\(exercise.id)")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 2)
                        
                        // Show cancel button directly under the exercise being moved
                        if let movingExercise = selectedToMove, movingExercise.id == exercise.id {
                            Button(action: {
                                selectedToMove = nil
                                viewModel.refreshID = UUID()
                            }) {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.red)
                                    Text("Cancel Moving \(exercise.name)")
                                        .foregroundColor(.red)
                                        .fontWeight(.medium)
                                }
                                .padding(.vertical, 8)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                        
                        // If we're moving an exercise, show insertion points between exercises
                        if let movingExercise = selectedToMove,
                           movingExercise.id != exercise.id,
                           localIndex < viewModel.exercises.count - 1 {
                            let nextExercise = viewModel.exercises[localIndex + 1]
                            
                            // Don't show insertion point if moving exercise is already at this position
                            if movingExercise.id != nextExercise.id {
                                insertionButton(
                                    position: "after",
                                    exercise: exercise,
                                    targetIndex: localIndex + 1
                                )
                            }
                        }
                    }
                }
                
                // If we're moving an exercise, show the "move to end" button
                // only if the exercise isn't already at the end
                if let movingExercise = selectedToMove,
                   let currentIndex = viewModel.exercises.firstIndex(where: { $0.id == movingExercise.id }),
                   currentIndex < viewModel.exercises.count - 1 {
                    insertionButton(
                        position: "end",
                        exercise: nil,
                        targetIndex: viewModel.exercises.count
                    )
                    .padding(.top, 8)
                }
            }
            .padding(.vertical, 16)
        }
    }
    
    
    
    // MARK: - Exercise Insertion Button View
    private func insertionButton(position: String, exercise: Exercise?, targetIndex: Int) -> AnyView {
        guard let movingExercise = selectedToMove else { return AnyView(EmptyView()) }
        
        // Calculate the button text based on position
        let buttonText: String
        let systemImage: String
        
        switch position {
        case "before":
            buttonText = "Move \(movingExercise.name) Before \(exercise?.name ?? "")"
            systemImage = "arrow.up.circle"
        case "after":
            buttonText = "Move \(movingExercise.name) After \(exercise?.name ?? "")"
            systemImage = "arrow.down.circle"
        case "start":
            buttonText = "Move \(movingExercise.name) To Start"
            systemImage = "arrow.up.to.line.circle"
        case "end":
            buttonText = "Move \(movingExercise.name) To End"
            systemImage = "arrow.down.to.line.circle"
        default:
            buttonText = "Move \(movingExercise.name) Here"
            systemImage = "plus.circle"
        }
        
        return AnyView(
            Button(action: {
                print("DEBUG: Moving \(movingExercise.name) to index \(targetIndex)")
                
                // Get current index of the moving exercise
                if let currentIndex = viewModel.exercises.firstIndex(where: { $0.id == movingExercise.id }) {
                    print("DEBUG: Current index of \(movingExercise.name) is \(currentIndex)")
                    
                    // Special handling for end position
                    if position == "end" {
                        moveExerciseToEnd(moving: movingExercise)
                    } else {
                        // Regular position movement with index adjustment
                        var adjustedTargetIndex = targetIndex
                        
                        // If moving to a later position, account for the removal of the current item
                        if targetIndex > currentIndex {
                            adjustedTargetIndex -= 1
                        }
                        
                        // Move the exercise
                        moveExercise(moving: movingExercise, newIndex: adjustedTargetIndex)
                    }
                    
                    // Reset movement state and refresh UI
                    selectedToMove = nil
                    viewModel.refreshID = UUID()
                }
            }) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.title)
                    Text(buttonText)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .padding(.vertical, 8)
            }
                .id("exercise-insertion-\(position)-\(targetIndex)-\(viewModel.refreshID)")
                .padding(.horizontal, 16)
        )
    }
    
    // MARK: - Move Exercise Logic
    private func moveExercise(moving: Exercise, newIndex: Int) {
        // Find the current index
        guard let currentIndex = viewModel.exercises.firstIndex(where: { $0.id == moving.id }) else {
            print("ERROR: Exercise not found in the list")
            return
        }
        
        print("DEBUG: Moving \(moving.name) from \(currentIndex) to \(newIndex)")
        
        // Don't do anything if trying to move to the same position
        if currentIndex == newIndex {
            print("DEBUG: Exercise is already at the desired index, no need to move")
            return
        }
        
        // Create a copy of the exercises and remove the one being moved
        var updatedExercises = viewModel.exercises
        let exerciseToMove = updatedExercises.remove(at: currentIndex)
        
        // Insert the exercise at the new position
        if newIndex >= updatedExercises.count {
            updatedExercises.append(exerciseToMove)
        } else {
            updatedExercises.insert(exerciseToMove, at: newIndex)
        }
        
        // Update all sort indices in the array
        for index in 0..<updatedExercises.count {
            updatedExercises[index].sortIndex = index
        }
        
        // Update the model with the new exercise order
        viewModel.exercises = updatedExercises
        
        // Print the new sort order for debugging
        print("DEBUG: New exercise order:")
        for (i, ex) in updatedExercises.enumerated() {
            print("  \(i): \(ex.name) (sortIndex: \(ex.sortIndex))")
        }
        
        // Save the updated indices to CloudKit
        viewModel.updateExerciseSortIndices(updatedExercises)
        
        // Force refresh and sorting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            viewModel.sortExercises()
            viewModel.refreshID = UUID() // Force UI refresh
        }
    }
    
    // MARK: - Special function to move an exercise to the end
    private func moveExerciseToEnd(moving: Exercise) {
        // Find the current index
        guard let currentIndex = viewModel.exercises.firstIndex(where: { $0.id == moving.id }) else {
            print("ERROR: Exercise not found in the list")
            return
        }
        
        let lastIndex = viewModel.exercises.count - 1
        print("DEBUG: Moving \(moving.name) from \(currentIndex) to end position (index \(lastIndex))")
        
        // Don't do anything if already at the end
        if currentIndex == lastIndex {
            print("DEBUG: Exercise is already at the end, no need to move")
            return
        }
        
        // Create a copy of the exercises and remove the one being moved
        var updatedExercises = viewModel.exercises
        let exerciseToMove = updatedExercises.remove(at: currentIndex)
        
        // Add the exercise to the end
        updatedExercises.append(exerciseToMove)
        
        // Update all sort indices in the array
        for index in 0..<updatedExercises.count {
            updatedExercises[index].sortIndex = index
        }
        
        // Update the model with the new exercise order
        viewModel.exercises = updatedExercises
        
        // Save the updated indices to your database
        viewModel.updateExerciseSortIndices(updatedExercises)
        
        // Print the new sort order for debugging
        print("DEBUG: New exercise order:")
        for (i, ex) in updatedExercises.enumerated() {
            print("  \(i): \(ex.name) (sortIndex: \(ex.sortIndex))")
        }
    }
}


struct AddExerciseView: View {
    @ObservedObject var viewModel: ExerciseViewModel
    @Environment(\.dismiss) var dismiss
    @State private var exerciseName = ""
    @State private var setsText = ""
    @State private var repsText = ""
    @FocusState private var focusedField: Field?
    
    // For focus management
    enum Field {
        case name, sets, reps
    }
    
    var onExerciseAdded: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Add Exercise")
                .font(.title)
                .padding(.top, 20)
                .padding(.bottom, 10)
            
            // Main content in ScrollView
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Form fields
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Exercise Details").font(.headline)
                        
                        TextField("Exercise name", text: $exerciseName)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .focused($focusedField, equals: .name)
                        
                        TextField("Sets", text: $setsText)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .sets)
                        
                        TextField("Reps", text: $repsText)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .reps)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            
            // Save button - fixed at the bottom
            saveButton
                .padding(.vertical, 16)
                .padding(.horizontal)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
    }
    
    private var saveButton: some View {
        Button(action: {
            guard
                !exerciseName.isEmpty,
                let sets = Int(setsText),
                let reps = Int(repsText)
            else { return }
            
            let setWeights = Array(repeating: 0.0, count: sets)
            let setCompletions = Array(repeating: false, count: sets)
            
            // Show loading state
            viewModel.isLoading = true
            
            viewModel.addExercise(
                name: exerciseName,
                sets: sets,
                reps: reps,
                setWeights: setWeights,
                setCompletions: setCompletions
            ) {
                DispatchQueue.main.async {
                    viewModel.isLoading = false
                    onExerciseAdded?()
                    dismiss()
                }
            }
        }) {
            HStack {
                Text("Save Exercise")
                    .font(.headline)
                    .foregroundColor(.white)
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                !exerciseName.isEmpty &&
                !setsText.isEmpty && Int(setsText) != nil &&
                !repsText.isEmpty && Int(repsText) != nil ?
                Color.blue : Color.gray
            )
            .cornerRadius(10)
        }
        .disabled(
            exerciseName.isEmpty ||
            setsText.isEmpty || Int(setsText) == nil ||
            repsText.isEmpty || Int(repsText) == nil ||
            viewModel.isLoading
        )
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
    @State private var showColorPicker = false

    // For editing name/sets
    @State private var editedName: String = ""
    @State private var editedSets: Int = 0
    
    // Let's add a state variable to capture the note height.
    @State private var noteHeight: CGFloat = 0
    @State private var nameHeight: CGFloat = 0

    // This makes isEditing persistent across view rebuilds
    @State private var isEditing: Bool = false {
        // This didSet helps diagnose when isEditing changes
        didSet {
            print("🔄 isEditing changed to: \(isEditing)")
        }
    }

    var rectangleProgress: CGFloat = 0.01
    var cornerRadius: CGFloat = 15
    var cardWidth: CGFloat = 336
    
    // A callback for moving the exercise (optional)
    let onRequestMove: ((Exercise) -> Void)?
    
    // Determine the accent color from the stored hex.
    var accentColor: Color {
        Color(hex: exercise.accentColorHex) ?? .blue
    }
    
    @State private var localAccentColor: Color = .blue


    // State variable to trigger the deletion confirmation alert.
     @State private var showDeleteConfirmation = false
    
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
        rectangleProgress: CGFloat = 0.05,
        cornerRadius: CGFloat = 15,
        cardWidth: CGFloat = 336,
        onRequestMove: ((Exercise) -> Void)? = nil

    ) {
        self.exercise = exercise
        self.evm = evm
        self.rectangleProgress = rectangleProgress
        self.cornerRadius = cornerRadius
        self.cardWidth = cardWidth
        self.onRequestMove = onRequestMove

        // Initialize the boolean array based on setActualReps
        // If actualReps[i] != 0, we show the text field. If 0, show the plus icon.
        _isTextFieldVisible = State(initialValue: exercise.setActualReps.map { $0 != 0 })
    }
    var body: some View {
        VStack(spacing: 16) {
            
            
            if isEditing {
                
                // 2) dynamicHeight based on setWeights
                ZStack(alignment: .center) {
                    // 1) Background shape with accent color
                    ExerciseCustomRoundedRectangle(
                               progress: rectangleProgress,
                               accentColor: accentColor,
                               cornerRadius: cornerRadius,
                               width: cardWidth,
                               height: 400
                           )
                    // 2) Main content
                    VStack(alignment: .center, spacing: 46) {
                        // ---------------------------------------
                        // EDITING MODE
                        // ---------------------------------------
                        HStack {
                            // Pencil button to open the color picker.
                               Button {
                                   showColorPicker = true
                               } label: {
                                   Image(systemName: "pencil")
                                       .foregroundColor(.black)
                                       .padding(8)
                                       .background(Color.white.opacity(0.3))
                                       .clipShape(Circle())
                                   
                               }
                               .buttonStyle(.borderless)
                               .background(
                                   Color("NeomorphBG4").opacity(0.4)
                                       .frame(width: 30, height: 30)
                                       .cornerRadius(5)
                               )
                            
                            Spacer()
                                .frame(width: 200)
                            
                            Button("Move Exercise") {
                                   print("DEBUG: 'Move Exercise' tapped for \(exercise.name)")
                                   onRequestMove?(exercise)
                               }
                               .padding(.top, 8)
                            
                            Button {
                                showDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)

                            .foregroundColor(.red)
                            .alert("Delete Exercise", isPresented: $showDeleteConfirmation) {
                                Button("Delete", role: .destructive) {
                                    // Find the exercise's index in the view model's array.
                                    if let index = evm.exercises.firstIndex(where: { $0.id == exercise.id }) {
                                        evm.deleteExercise(at: IndexSet(integer: index))
                                    }
                                }
                                Button("Cancel", role: .cancel) { }
                            } message: {
                                Text("Are you sure you want to delete this exercise?")
                            }
                        }
                     
                        VStack(alignment: .center, spacing: 50) {
                            // 2.1) Edit the exercise name
                            ExerciseNameField(exercise: exercise, evm: evm)
                            
                            
                            // 2.2) Edit the number of sets
                            SetsField(exercise: exercise, evm: evm)
                            
                            RepsField(exercise: exercise, evm: evm)
      

                            // Then modify the Button("Done Editing") part:
                            // Updated Done Editing Button Implementation
                            Button("Done Editing") {
                                withAnimation(.none) {  // Disable animation to prevent cascade refreshes
                                    if let recordID = exercise.recordID {
                                        // First, collect any pending changes from our stable fields
                                        // by forcing any debounced updates to execute immediately
                                        
                                        // Short delay to ensure all field updates are processed first
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            // Using regular updateExercise for this final update as we want
                                            // the UI to refresh once we exit edit mode
                                            evm.updateExercise(
                                                recordID: recordID,
                                                // Use the current values from the exercise object
                                                // which should be up-to-date from our field components
                                                newName: exercise.name,
                                                newSets: exercise.sets,
                                                newReps: exercise.reps
                                            )
                                            
                                            // Exit edit mode after a delay to ensure CloudKit update completes
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                isEditing = false
                                            }
                                        }
                                    } else {
                                        // No recordID available, just exit edit mode
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            isEditing = false
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.white.opacity(0.8))
                            // And modify your gear icon button that enters edit mode:
                            Button {
                                withAnimation(.none) {  // Disable animation to prevent cascade refreshes
                                    // Set up any initial values first
                                    editedName = exercise.name
                                    editedSets = exercise.sets
                                    
                                    // Use asyncAfter to set isEditing to true AFTER any view setup completes
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isEditing = true
                                    }
                                }
                            } label: {
                                Image(systemName: "gearshape")
                                    .foregroundColor(.white)
                            }

                        }
    
                    }
                }
            } else {
                // Calculate dynamic height to account for all elements
                let dynamicHeight = 60.0 // Base padding
                    + nameHeight // Account for the name view height
                    + Double(exercise.sets) * 60.0 // Height for each set row
                    + Double(noteHeight) // Note height
                    + 40.0 // Extra padding for consistent spacing
            
                ZStack(alignment: .center) {
              
                    ExerciseCustomRoundedRectangle(
                        progress: rectangleProgress,
                        accentColor: accentColor,
                        cornerRadius: cornerRadius,
                        width: cardWidth,
                        height: dynamicHeight
                    )
                    
                    VStack(spacing: 16) {

                        Spacer()
                            .frame(height: 30)
                        // -- Overall note view
                        ExerciseNoteView(evm: evm, exercise: exercise)
                            .measureHeight()
                            .onPreferenceChange(HeightPreferenceKey.self) { newHeight in
                                noteHeight = newHeight
                            }
                        
                        // -- Show reps/sets
                        Text("\(exercise.sets) X \(exercise.reps)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    
                        // -- For each set
                        ForEach(0..<exercise.sets, id: \.self) { index in
                            SetRowView(exercise: exercise, index: index, evm: evm)
                        }
                    }
                }
                .overlay(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        // Exercise name view with integrated gear icon
                        ExerciseNameView(
                                   name: exercise.name,
                                   fixedWidth: cardWidth,
                                   nameHeight: $nameHeight,
                                   action: {
                                       // Set these values before changing isEditing
                                       editedName = exercise.name
                                       editedSets = exercise.sets
                                       
                                       // Use withAnimation for smooth transition
                                       withAnimation {
                                           isEditing = true
                                       }
                                   }
                               )
                        .padding(.leading, 36)
                        .padding(.top, 7.5)
                        
                        Spacer()
                    }
                    .frame(width: cardWidth, alignment: .center) // Ensure alignment is consistent
                }
      
            }
        }
                .padding()
        // Present the color picker sheet.
        .sheet(isPresented: $showColorPicker) {
                ColorPickerSheet(accentColor: $localAccentColor, evm: evm, exercise: exercise)
                .presentationDetents([.fraction(0.55)])
                .presentationDragIndicator(.visible)
            }
    }
    func calculateTextHeight(text: String, width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = text.boundingRect(
            with: constraintRect,
            options: .usesLineFragmentOrigin,
            attributes: [NSAttributedString.Key.font: font],
            context: nil
        )
        return ceil(boundingBox.height)
    }
    
    /// Makes sure isTextFieldVisible has the same count as the current number of sets.
    private func syncTextFieldVisibility(with newCount: Int) {
        if isTextFieldVisible.count < newCount {
            let additionalCount = newCount - isTextFieldVisible.count
            isTextFieldVisible.append(contentsOf: Array(repeating: false, count: additionalCount))
        } else if isTextFieldVisible.count > newCount {
            isTextFieldVisible = Array(isTextFieldVisible.prefix(newCount))
        }
    }

    
    // Helper to dismiss keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

struct ExerciseNameView: View {
    let name: String
    let fixedWidth: CGFloat
    @Binding var nameHeight: CGFloat
    let verticalPadding: CGFloat = 6
    let extraHeight: CGFloat = 20
    let iconSpace: CGFloat = 45
    let minHeight: CGFloat = 40
    let action: () -> Void
    
    // Add state to track text size more precisely
    @State private var textSize: CGSize = .zero
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background shape - making sure it's correctly sized
            CustomRoundedRectangle4(
                topLeftRadius: 0,
                topRightRadius: 20,
                bottomLeftRadius: 0,
                bottomRightRadius: 0
            )
            .fill(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color("NeomorphBG2").opacity(1), location: 0.0),
                        .init(color: Color("NeomorphBG2").opacity(0.35), location: 0.9),
                        .init(color: Color("NeomorphBG2").opacity(0), location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: fixedWidth - 10, height: nameHeight)
            
            // Content with text and icon
            HStack(spacing: 0) {
                // Add extra padding at the beginning
                Spacer(minLength: 10)
                
                // Actual visible text
                Text(name)
                    .font(.title3)
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, verticalPadding)
                    .padding(.horizontal, 4)
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear {
                                textSize = geo.size
                                nameHeight = max(geo.size.height + extraHeight, minHeight)
                            }
                            .onChange(of: geo.size) { newSize in
                                textSize = newSize
                                nameHeight = max(newSize.height + extraHeight, minHeight)
                            }
                        }
                    )
                    .frame(maxWidth: fixedWidth - iconSpace - 10, alignment: .leading)
                
                Spacer(minLength: 0)
                
                // Gear icon with consistent sizing
                Button(action: action) {
                    Image(systemName: "gear")
                        .opacity(0.7)
                        .foregroundColor(.white)
                        .frame(width: iconSpace - 8, height: iconSpace - 8)
                        .padding(.trailing, 4)
                }
                .buttonStyle(.borderless)
            }
            .frame(width: fixedWidth) // Match exactly with the card width
        }
        // Force layout update when name changes
        .onChange(of: name) { _ in
            DispatchQueue.main.async {
                nameHeight = max(textSize.height + extraHeight, minHeight)
            }
        }
    }
}

struct NameHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        // Use the maximum height found (if there are multiple values)
        value = max(value, nextValue())
    }
}

extension View {
    func measureHeight() -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: HeightPreferenceKey.self, value: geometry.size.height)
            }
        )
    }
}

extension View {
    /// Measures this view's height and assigns it to a given preference key.
    func measureHeight<K: PreferenceKey>(using key: K.Type) -> some View where K.Value == CGFloat {
        self.background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: key, value: geometry.size.height)
            }
        )
    }
}



struct ColorPickerSheet: View {
    @Binding var accentColor: Color
    @Environment(\.presentationMode) var presentationMode
    let evm: ExerciseViewModel
    let exercise: Exercise
    
    // Define 8 distinct color options
    let colorOptions: [(name: String, color: Color)] = [
        ("Blue", Color.blue),
        ("Green", Color(hex: "#4CAF50")), // Material Green
        ("Purple", Color(hex: "#9C27B0")), // Material Purple
        ("Orange", Color(hex: "#FF9800")), // Material Orange
        ("Red", Color(hex: "#F44336")), // Material Red
        ("Teal", Color(hex: "#009688")), // Material Teal
        ("Pink", Color(hex: "#E91E63")), // Material Pink
        ("Amber", Color(hex: "#FFC107")) // Material Amber
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Choose an accent color")
                .font(.headline)
                .padding(.top)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 15) {
                ForEach(colorOptions, id: \.name) { option in
                    ColorOption(
                        color: option.color,
                        name: option.name,
                        isSelected: accentColor.toHex() == option.color.toHex(),
                        action: {
                            accentColor = option.color
                        }
                    )
                }
            }
            .padding()
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
                .foregroundColor(.gray)
                
                Spacer()
                
                Button("Done") {
                    if let newHex = accentColor.toHex(), let recordID = exercise.recordID {
                        evm.updateExercise(recordID: recordID, newAccentColor: newHex)
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
                .foregroundColor(.blue)
                .bold()
            }
            .padding(.horizontal)
        }
        .padding()
        .navigationTitle("Pick Accent Color")
    }
}

// A custom color option view for each color in the grid
struct ColorOption: View {
    let color: Color
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Circle()
                    .fill(color)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .padding(2)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .opacity(isSelected ? 1 : 0)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                
                Text(name)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
    }
}

// Extension to support hex colors if not already present
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

struct SetRowView: View {
    let exercise: Exercise
    let index: Int
    let evm: ExerciseViewModel

    // Local state for controlling whether the actual reps text field is visible.
    @State private var isTextFieldVisible: Bool = false
    // Local state for showing the note editor sheet.
    @State private var showNoteEditor: Bool = false
    // Local note text for editing.
    @State private var localNote: String = ""
    // This tracks which text field is focused.
    // We can store an optional index (if we have multiple fields).
    @FocusState private var focusedField: Int?
    
    var body: some View {
        
        HStack(spacing: 25) {
            // 1) Toggle set completion
            Button {
                // Guard against out-of-range access.
                guard index < exercise.setCompletions.count else { return }
                
                if let recordID = exercise.recordID {
                    // Get the most up-to-date completions
                    var newCompletions = evm.getCurrentCompletions(for: exercise)
                    newCompletions[index].toggle()
                    
                    // Update with optimistic UI
                    evm.updateExercise(recordID: recordID, newCompletions: newCompletions)
                }
            } label: {
                // Use the most current state for UI
                let completions = evm.getCurrentCompletions(for: exercise)
                if index < completions.count {
                    Image(systemName: completions[index] ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(completions[index] ? .green : .white)
                        .opacity(0.8)
                } else {
                    // Fallback: display a default icon.
                    Image(systemName: "circle")
                        .foregroundColor(.white)
                        .opacity(0.8)
                }
            }
            .buttonStyle(.borderless)
            .background(
                Color("NeomorphBG4").opacity(0.4)
                    .frame(width: 30, height: 30)
                    .cornerRadius(5)
            )

            
            
            HStack(spacing: 15) {
                // 1) Weight Field
                WeightField(exercise: exercise, index: index, evm: evm)
                    .keyboardType(.decimalPad)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 30)
                    .focused($focusedField, equals: index)

                // 2) Actual Reps Container
                ZStack {
                    // This invisible container is always the same width
                    // so the UI doesn't jump when we switch from plus button
                    // to (text field + minus button).
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.clear)
                        .frame(width: 80)  // <-- Adjust as needed
                        .fixedSize()

                    if isTextFieldVisible {
                        
                        ActualRepsField(
                            exercise: exercise,
                            index: index,
                            evm: evm,
                            isTextFieldVisible: $isTextFieldVisible
                        )
                        .focused($focusedField, equals: index)

                        
                    } else {
                        Button {
                            isTextFieldVisible = true
                        } label: {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.borderless)
                        .background(
                            Color("NeomorphBG4").opacity(0.4)
                                .frame(width: 30, height: 30)
                                .cornerRadius(100)
                        )
                    }
                }
            }
            
            // 4) Note Button
            Button {
                // Initialize the local note from the exercise's setNotes at this index.
                if exercise.setNotes.indices.contains(index) {
                    localNote = exercise.setNotes[index]
                } else {
                    localNote = ""
                }
                showNoteEditor = true
            } label: {
                Image(systemName: (exercise.setNotes.indices.contains(index) && !exercise.setNotes[index].isEmpty) ? "note.text" : "square.and.pencil")
                    .foregroundColor((exercise.setNotes.indices.contains(index) && !exercise.setNotes[index].isEmpty) ? .yellow : .white)
                    .opacity(0.8)

            }
            .buttonStyle(.borderless)
            .background(
                Color("NeomorphBG4").opacity(0.4)
                    .frame(width: 30, height: 30)
                    .cornerRadius(5)
            )

        }
        .padding()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(lineWidth: 5)
                    .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                    .frame(width: 286, height: 60)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color("NeomorphBG2").opacity(0.6),
                                    Color("NeomorphBG2").opacity(0.6)
                                ]),
                                startPoint: .bottom,
                                endPoint: .topTrailing
                            )
                        )
                        .frame(width: 273, height: 46)
                    
          
                }
            }
        )
        .onAppear {
            if exercise.setActualReps.indices.contains(index) {
                isTextFieldVisible = exercise.setActualReps[index] != 0
            } else {
                isTextFieldVisible = false
            }
        }
        // A single .toolbar for the entire parent
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField != nil {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                        // Clear the focus
                        focusedField = nil
                    }
                }
            }
        }
        // Present the note editor sheet.
        .sheet(isPresented: $showNoteEditor) {
            NavigationView {
                NoteEditorView(note: $localNote, onSave: {
                    // When saving, update the note for this set.
                    if let recordID = exercise.recordID {
                        var updatedNotes = exercise.setNotes
                        if updatedNotes.indices.contains(index) {
                            updatedNotes[index] = localNote
                        } else {
                            updatedNotes.append(localNote)
                        }
                        evm.updateExercise(recordID: recordID, newSetNotes: updatedNotes)
                    }
                }
                )
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)

            }
  
        }
        .onAppear {
            // Set initial state for the text field visibility.
            if exercise.setActualReps.indices.contains(index) {
                isTextFieldVisible = exercise.setActualReps[index] != 0
            } else {
                isTextFieldVisible = false
            }
        }
        
    }
    // Utility to dismiss the keyboard
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

struct EditingSetIndex: Identifiable {
    let id = UUID()
    let index: Int
}

struct ExerciseNoteView: View {
    @ObservedObject var evm: ExerciseViewModel
    var exercise: Exercise

    @State private var showNoteEditor: Bool = false
    @State private var localNote: String = ""
    @State private var isNoteExpanded: Bool = true
    // State to hold the measured height of the note view.
    @State private var noteHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            if exercise.exerciseNote.isEmpty {
                // If there's no note, show an "Add note" button in the center
                HStack {
                    Spacer()
                    Button(action: {
                        localNote = ""
                        showNoteEditor = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.pencil")
                            Text("Add note")
                        }
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.borderless)
                    .background(
                        Color("NeomorphBG2").opacity(0.6)
                            .frame(width: 100, height: 30)
                            .cornerRadius(7)
                    )
                    Spacer()
                }

            } else {
                if isNoteExpanded {
                    // Place the note text and pencil icon side by side,
                    // then center the entire HStack horizontally
                    HStack {
                        Spacer()
                        Text(exercise.exerciseNote)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color("NeomorphBG2").opacity(0.6))
                                    .blur(radius: 3)
                            )
                            
                            .onTapGesture {
                                localNote = exercise.exerciseNote
                                showNoteEditor = true
                            }
                        Spacer()
                    }
                }
                
                // Chevron to expand/minimize note
                HStack {
                    Spacer()
                    Button(action: {
                        isNoteExpanded.toggle()
                    }) {
                        Image(systemName: isNoteExpanded ? "chevron.up" : "chevron.down")
                            .resizable()
                            .foregroundColor(.white).opacity(0.8)
                            // Keep bounding box consistent
                            .frame(width: 56, height: 5)
                    }
                    .buttonStyle(.borderless)
                    .background(
                        Color("NeomorphBG2").opacity(0.5)
                            .frame(width: 80, height: 20)
                            .cornerRadius(100)
                    )
                    Spacer()
                }
            }
        }
        .onPreferenceChange(HeightPreferenceKey.self) { newHeight in
            // Update the state variable with the measured height.
            noteHeight = newHeight
        }
        .padding(.vertical, 10)
        .sheet(isPresented: $showNoteEditor) {
            NavigationView {
                NoteEditorView(note: $localNote, onSave: {
                    if let recordID = exercise.recordID {
                        evm.updateExercise(recordID: recordID, newNote: localNote)
                    }
                })
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
            }
           
        }
    }
}


struct NoteEditorView: View {
    @Binding var note: String
    var onSave: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
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
    NavigationView {
        ExercisesView(workoutID: CKRecord.ID(recordName: "UserExercises"))
    }
}
