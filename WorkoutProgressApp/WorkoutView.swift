//
//  WorkoutView.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/11/25.
//
import SwiftUI
import CloudKit

struct AllWorkoutsListView: View {

    @EnvironmentObject var workoutViewModel: WorkoutViewModel
    @State private var showAddWorkoutSheet = false
    
    // For color picker
    @State private var showColorPicker = false
    @State private var selectedAccentColor: Color = .blue
    @State private var selectedWorkout: WorkoutModel? = nil
    
    /// Tracks which workout is currently being moved, if any.
    @State private var selectedToMove: WorkoutModel? = nil
    

    
    /// Sort the groups by the block name (or however you wish to order them)
    private var sortedGroups: [(key: String, value: [WorkoutModel])] {
        groupedWorkouts.sorted { $0.key < $1.key }
    }
    
    // A unique ID that forces SwiftUI to re-draw the workout cards when changed
    @State private var refreshID = UUID()
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color("NeomorphBG2"), Color("NeomorphBG2")]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Iterate over each group
                    ForEach(sortedGroups, id: \.key) { group in
                        Section(header:
                            // Group header shows the block name
                            Text(group.key)
                                .font(.headline)
                                .padding(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        ) {
                            // Iterate over workouts in this group
                            ForEach(group.value.indices, id: \.self) { index in
                                let workout = group.value[index]
                                
                                WorkoutCardView(
                                    workout: workout,
                                    workoutViewModel: workoutViewModel,
                                    onColorPickerRequested: {
                                        selectedWorkout = workout
                                        selectedAccentColor = .blue
                                        showColorPicker = true
                                    },
                                    onWorkoutUpdated: {
                                        refreshID = UUID()
                                    },
                                    onRequestMove: { w in
                                        print("DEBUG: onRequestMove called for \(w.name)")
                                        selectedToMove = w
                                    }
                                )
                                .id("\(workout.id)-\(workout.name)-\(refreshID)")
                                .padding(.horizontal, 16)
                                
                                // If a workout is selected to move (and it's not this one), show a plus button
                                if let movingWorkout = selectedToMove, movingWorkout.id != workout.id {
                                    Button(action: {
                                        print("Tapped below plus for \(workout.name)")
                                        // This is where you would implement moving the workout within the group.
                                        // You might call a function like:
                                        workoutViewModel.moveWorkoutAtIndex(movingWorkout: movingWorkout, newIndex: index + 1)
                                        selectedToMove = nil
                                    }) {
                                        Image(systemName: "plus.circle")
                                            .font(.title)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top)
            }
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
                NavigationStack {
                    AddWorkoutView(
                        providedBlockTitle: nil     // user can type a block name
                    )
                }
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
            }
        .sheet(isPresented: $showColorPicker) {
            colorPickerSheet
                .presentationDetents([.fraction(0.5)])
                .presentationDragIndicator(.visible)
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
                if let workout = selectedWorkout {
                    // Handle color update if needed
                }
                showColorPicker = false
            }
            .padding()
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Computed Properties & Methods
    
    // Re-group the workouts by sectionTitle
    private var groupedWorkouts: [(key: String, value: [WorkoutModel])] {
        // If your view model property is "workouts" or "workout" adjust accordingly
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
                date: Date(), sortIndex: 0
            )
            let dummy2 = WorkoutModel(
                id: CKRecord.ID(recordName: "Dummy2"),
                name: "Leg day",
                sectionTitle: "Light",
                date: Date(), sortIndex: 1
            )
            workoutViewModel.workouts = [dummy1, dummy2]
        }
    }
    
    
    /// Moves the given workout to the specified index in the workouts array.
    private func moveWorkout(_ workout: WorkoutModel, toIndex newIndex: Int) {
        guard let oldIndex = workoutViewModel.workouts.firstIndex(where: { $0.id == workout.id }) else {
            print("DEBUG: Could not find old index for \(workout.name)")
            return
        }
        
        print("DEBUG: Moving \(workout.name) from \(oldIndex) to \(newIndex)")
        
        // 1) Remove the item first
        let item = workoutViewModel.workouts.remove(at: oldIndex)
        
        // 2) Adjust the insertion index if oldIndex < newIndex
        var finalIndex = newIndex
        if oldIndex < newIndex {
            finalIndex -= 1
        }
        
        // 3) Clamp finalIndex to 0...workoutViewModel.workouts.count
        //    In Swift, insert(at:) is valid from 0 up to .count (inclusive) to append.
        finalIndex = max(0, min(finalIndex, workoutViewModel.workouts.count))
        
        // 4) Insert the item at the adjusted/clamped index
        workoutViewModel.workouts.insert(item, at: finalIndex)
        print("DEBUG: \(workout.name) moved in local array to index \(finalIndex).")
        
        // 5) Clear the selectedToMove to exit "move mode"
        selectedToMove = nil
    }
}


import SwiftUI

//struct BlockWorkoutsListView: View {
//    let blockTitle: String  // Use the block name to filter workouts
//    
//    @EnvironmentObject var workoutViewModel: WorkoutViewModel
//    @State private var showAddWorkoutSheet = false
//    
//    // For color picker
//    @State private var showColorPicker = false
//    @State private var selectedAccentColor: Color = .blue
//    @State private var selectedWorkout: WorkoutModel? = nil
//    
//    // Tracks which workout is currently being moved, if any.
//    @State private var selectedToMove: WorkoutModel? = nil
//    
//    // A unique ID to force SwiftUI to re-render when needed.
//    @State private var refreshID = UUID()
//    
//    /// Workouts that belong to this block (i.e. have the matching sectionTitle),
//    /// sorted by their sortIndex.
//    private var workoutsForBlock: [WorkoutModel] {
//        // Make sure we're getting the latest data
//        let latestWorkouts = workoutViewModel.workouts
//        
//        return latestWorkouts
//            .filter { $0.sectionTitle == blockTitle }
//            .sorted { $0.sortIndex < $1.sortIndex }
//    }
//    
//    
//    // 1. In your view, add a specific state property for UI refresh:
//    @State private var forceRefresh = UUID()
//
//    
//    var body: some View {
//        ZStack {
//            // Background
//            LinearGradient(
//                gradient: Gradient(colors: [Color("NeomorphBG2"), Color("NeomorphBG2")]),
//                startPoint: .top,
//                endPoint: .bottom
//            )
//            .ignoresSafeArea()
//            ScrollView {
//                        LazyVStack(spacing: 16) {
//                            // Optional top insertion point
//                            if let movingWorkout = selectedToMove {
//                                Button(action: {
//                                    print("Tapped top plus, insert at index 0")
//                                    workoutViewModel.moveWorkout(movingWorkout, toIndex: 0)
//                                    selectedToMove = nil
//                                    refreshID = UUID() // Force view refresh
//                                }) {
//                                    HStack {
//                                        Image(systemName: "plus.circle")
//                                            .font(.title)
//                                        Text("Move \(movingWorkout.name) Here")
//                                            .fontWeight(.medium)
//                                    }
//                                    .foregroundColor(.blue)
//                                    .padding(.vertical, 8)
//                                }
//                                .id("top-insertion-\(refreshID)")
//                                .padding(.horizontal, 16)
//                            }
//                            
//                            // Iterate over the workouts
//                            ForEach(Array(workoutsForBlock.enumerated()), id: \.element.id) { (localIndex, workout) in
//                                WorkoutCardView(
//                                    workout: workout,
//                                    workoutViewModel: workoutViewModel,
//                                    onColorPickerRequested: { /* ... */ },
//                                    onWorkoutUpdated: {
//                                        refreshID = UUID()
//                                    },
//                                    onRequestMove: { workout in
//                                        selectedToMove = workout
//                                        refreshID = UUID() // Force view refresh
//                                    }
//                                )
//                                .id("\(workout.id)-\(workout.sortIndex)-\(refreshID)")
//                                .padding(.horizontal, 16)
//                                
//                                // If a workout is selected to move (and it's not this one), show a plus button below
//                                if let movingWorkout = selectedToMove, movingWorkout.id != workout.id {
//                                    Button(action: {
//                                        print("DEBUG: Insert below \(workout.name) at index \(localIndex + 1)")
//                                        workoutViewModel.moveWorkout(movingWorkout, toIndex: localIndex + 1)
//                                        selectedToMove = nil
//                                        refreshID = UUID() // Force view refresh
//                                    }) {
//                                        HStack {
//                                            Image(systemName: "plus.circle")
//                                                .font(.title)
//                                            Text("Move \(movingWorkout.name) Here")
//                                                .fontWeight(.medium)
//                                        }
//                                        .foregroundColor(.blue)
//                                        .padding(.vertical, 8)
//                                    }
//                                    .id("insertion-\(localIndex)-\(refreshID)")
//                                    .padding(.horizontal, 16)
//                                }
//                            }
//                        }
//                        .padding(.vertical, 16)
//                        .animation(.default, value: selectedToMove != nil)
//                        .animation(.default, value: refreshID)
//                        .overlay(
//                            Group {
//                                if workoutViewModel.isProcessingMove {
//                                    ProgressView()
//                                        .scaleEffect(1.5)
//                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
//                                        .background(Color.black.opacity(0.2))
//                                }
//                            }
//                        )
//                    }
//                    .onChange(of: workoutViewModel.workouts) { _ in
//                        // Force UI refresh when the workouts array changes
//                        refreshID = UUID()
//                    }
//            .onAppear {
//                // Refresh global workouts when the view appears.
//                workoutViewModel.fetchWorkouts()
//            }
//            .navigationTitle("\(blockTitle) Workouts")
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button {
//                        showAddWorkoutSheet = true
//                    } label: {
//                        Image(systemName: "plus")
//                    }
//                }
//            }
//            .sheet(isPresented: $showAddWorkoutSheet) {
//                NavigationStack {
//                    AddWorkoutView(
//                        providedBlockTitle: blockTitle // show "Block: blockTitle" in the UI
//                    )
//                }
//                .presentationDetents([.fraction(0.4)])
//                .presentationDragIndicator(.visible)
//            }
//        }
//    }
//    
//    
//}

// MARK: - Main View Structure
struct BlockWorkoutsListView: View {
    let blockTitle: String  // Use the block name to filter workouts
    
    @EnvironmentObject var workoutViewModel: WorkoutViewModel
    @State private var showAddWorkoutSheet = false
    
    // For color picker
    @State private var showColorPicker = false
    @State private var selectedAccentColor: Color = .blue
    @State private var selectedWorkout: WorkoutModel? = nil
    
    // Tracks which workout is currently being moved, if any.
    @State private var selectedToMove: WorkoutModel? = nil
    
    // A unique ID to force SwiftUI to re-render when needed.
    @State private var refreshID = UUID()
    
    /// Workouts that belong to this block (i.e. have the matching sectionTitle),
    /// sorted by their sortIndex.
    private var workoutsForBlock: [WorkoutModel] {
        // Make sure we're getting the latest data
        let latestWorkouts = workoutViewModel.workouts
        
        return latestWorkouts
            .filter { $0.sectionTitle == blockTitle }
            .sorted { $0.sortIndex < $1.sortIndex }
    }
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            // Main content
            mainContentView
        }
    }
    
    // MARK: - Background View
    private var backgroundView: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color("NeomorphBG2"), Color("NeomorphBG2")]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Main Content View
    private var mainContentView: some View {
        ScrollView {
            workoutListView
                .padding(.vertical, 16)
                .animation(.default, value: selectedToMove != nil)
                .animation(.default, value: refreshID)
                .overlay(loadingOverlay)
        }
        .onReceive(workoutViewModel.$workouts) { _ in
             // Force UI refresh when the workouts array changes
             refreshID = UUID()
         }

        .onAppear {
            // Refresh global workouts when the view appears.
            workoutViewModel.fetchWorkouts()
        }
        .navigationTitle("\(blockTitle) Workouts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                addButton
            }
        }
        .sheet(isPresented: $showAddWorkoutSheet) {
            addWorkoutSheet
        }
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        Group {
            if workoutViewModel.isProcessingMove {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
    }
    
    // MARK: - Add Button
    private var addButton: some View {
        Button {
            showAddWorkoutSheet = true
        } label: {
            Image(systemName: "plus")
        }
    }
    
    // MARK: - Add Workout Sheet
    private var addWorkoutSheet: some View {
        NavigationStack {
            AddWorkoutView(
                providedBlockTitle: blockTitle
            )
        }
        .presentationDetents([.fraction(0.4)])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Workout List View
    private var workoutListView: some View {
        LazyVStack(spacing: 16) {
            workoutCardsList
                .animation(.default, value: selectedToMove != nil) // Using a Bool instead of the model
                .animation(.default, value: refreshID)
        }
    }

    // MARK: - Workout Cards List with Smart Insertion Points
    private var workoutCardsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(workoutsForBlock.enumerated()), id: \.element.id) { (localIndex, workout) in
                // Show insertion button BEFORE this card if appropriate
                if shouldShowInsertionButton(before: workout, at: localIndex) {
                    insertionButton(position: "before", workout: workout, targetIndex: localIndex)
                }
                
                // The workout card itself
                WorkoutCardView(
                    workout: workout,
                    workoutViewModel: workoutViewModel,
                    onColorPickerRequested: { /* ... */ },
                    onWorkoutUpdated: {
                        refreshID = UUID()
                    },
                    onRequestMove: { workout in
                        selectedToMove = workout
                        refreshID = UUID()
                    }
                )
                .id("\(workout.id)-\(workout.sortIndex)-\(refreshID)")
                .padding(.horizontal, 16)
                
                // Show insertion button AFTER this card if appropriate
                if shouldShowInsertionButton(after: workout, at: localIndex) {
                    insertionButton(position: "after", workout: workout, targetIndex: localIndex + 1)
                }
            }
            
            // If we have workouts and are moving a workout, maybe show a final insertion point
            if !workoutsForBlock.isEmpty && shouldShowFinalInsertionButton() {
                insertionButton(position: "end", workout: nil, targetIndex: workoutsForBlock.count)
            }
        }
    }

    // MARK: - Insertion Button Logic
    private func shouldShowInsertionButton(before workout: WorkoutModel, at index: Int) -> Bool {
        guard let movingWorkout = selectedToMove else { return false }
        
        // Don't show insertion button before the workout we're trying to move
        if movingWorkout.id == workout.id { return false }
        
        // Show an insertion button at the very beginning only if there's no redundant button
        if index == 0 { return true }
        
        // Otherwise, only show the button before if the moving workout isn't immediately before this one
        let movingIndex = workoutsForBlock.firstIndex(where: { $0.id == movingWorkout.id }) ?? -1
        return movingIndex != index - 1
    }

    private func shouldShowInsertionButton(after workout: WorkoutModel, at index: Int) -> Bool {
        guard let movingWorkout = selectedToMove else { return false }
        
        // Don't show insertion button after the workout we're trying to move
        if movingWorkout.id == workout.id { return false }
        
        // Don't show an insertion button after the last workout - we'll handle that with the final button
        if index == workoutsForBlock.count - 1 { return false }
        
        // Otherwise, only show the button after if the moving workout isn't immediately after this one
        let movingIndex = workoutsForBlock.firstIndex(where: { $0.id == movingWorkout.id }) ?? -1
        return movingIndex != index + 1
    }

    private func shouldShowFinalInsertionButton() -> Bool {
        guard let movingWorkout = selectedToMove else { return false }
        
        // Show the final button only if we're not already moving the last workout
        let lastIndex = workoutsForBlock.count - 1
        if lastIndex >= 0 {
            let lastWorkoutId = workoutsForBlock[lastIndex].id
            return movingWorkout.id != lastWorkoutId
        }
        
        return false
    }

    // MARK: - Insertion Button View
    private func insertionButton(position: String, workout: WorkoutModel?, targetIndex: Int) -> AnyView {
        guard let movingWorkout = selectedToMove else { return AnyView(EmptyView()) }
        
        // Calculate the button text based on position
        let buttonText: String
        let systemImage: String
        
        switch position {
        case "before":
            buttonText = "Move \(movingWorkout.name) Before \(workout?.name ?? "")"
            systemImage = "arrow.up.circle"
        case "after":
            buttonText = "Move \(movingWorkout.name) After \(workout?.name ?? "")"
            systemImage = "arrow.down.circle"
        case "end":
            buttonText = "Move \(movingWorkout.name) To End"
            systemImage = "arrow.down.circle.fill"
        default:
            buttonText = "Move \(movingWorkout.name) Here"
            systemImage = "plus.circle"
        }
        
        return AnyView(
            Button(action: {
                print("DEBUG: Moving \(movingWorkout.name) to index \(targetIndex)")
                workoutViewModel.moveWorkout(movingWorkout, toIndex: targetIndex)
                selectedToMove = nil
                refreshID = UUID()
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
            .id("insertion-\(position)-\(targetIndex)-\(refreshID)")
            .padding(.horizontal, 16)
        )
    }
}





struct WorkoutCardView: View {
    @EnvironmentObject var blockManager: WorkoutBlockManager
    // We store the workout in @State
    @State private var workout: WorkoutModel
    
    @State private var selectedBlock: String
    @State private var showBlockSelectionSheet = false

    @EnvironmentObject var workoutViewModel: WorkoutViewModel
    
    /// Callback to parent telling it we want to move this workout
    var onRequestMove: ((WorkoutModel) -> Void)?
    
    var onWorkoutUpdated: (() -> Void)?
    
    // Additional callback for color picker
    var onColorPickerRequested: () -> Void
    

    
    @State private var isEditing = false
    @State private var editedWorkoutName: String = ""
    
    // MARK: - Custom init
    init(
        workout: WorkoutModel,
        workoutViewModel: WorkoutViewModel,
        onColorPickerRequested: @escaping () -> Void,
        onWorkoutUpdated: (() -> Void)? = nil,
        onRequestMove: ((WorkoutModel) -> Void)? = nil
    ) {
        self.workout = workout
        _selectedBlock = State(initialValue: workout.sectionTitle ?? "Other")
        self._workout = State(initialValue: workout)
        self.onColorPickerRequested = onColorPickerRequested
        self.onWorkoutUpdated = onWorkoutUpdated
        self.onRequestMove = onRequestMove  // <— Store the callback here!
    }
    
    var body: some View {
        if isEditing {
            editingView
            
        } else {
            navigationView
        }
    }
    
    private var navigationView: some View {
        VStack {
            Spacer().frame(height: 40)
            NavigationLink(destination: ExercisesView(workoutID: workout.id)) {
                ZStack {
                    // Background
                    WorkoutCustomRoundedRectangle(
                        progress: 0.05,
                        accentColor: .blue,
                        cornerRadius: 15,
                        width: 336,
                        height: 120
                    )
                    
                    // Content
                    VStack(alignment: .leading) {
                        Text(workout.name)
                            .font(.title3)
                            .bold()
                            .foregroundColor(.white)
                            .padding(.top, 20)
                        
                        Spacer()
                        
                        if let date = workout.date {
                            Text("Date: \(date, formatter: DateFormatter.workoutDateFormatter)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.bottom, 20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(width: 336, alignment: .leading)
                    
                    // Ellipsis button overlaid
                    VStack {
                        HStack {
                            Spacer()
                            
                            Button {
                                self.isEditing = true
                                self.editedWorkoutName = workout.name
                            } label: {
                                Image(systemName: "ellipsis")
                                    .foregroundColor(.black)
                                    .padding(8)
                                    .background(Color.white.opacity(0.3))
                                    .clipShape(Circle())
                            }
                            .frame(width: 44, height: 44)
                            .padding(.top, 10)
                            .padding(.trailing, 10)
                        }
                        
                        Spacer()
                    }
                    .allowsHitTesting(true)
                }
                .frame(width: 336, height: 120)
            }
            .allowsHitTesting(true)
            .buttonStyle(PlainButtonStyle())
            Spacer().frame(height: 40)
        }
    }
    
    private var editingView: some View {
        VStack {
            Spacer().frame(height: 40)
            ZStack {
                // Background
                WorkoutCustomRoundedRectangle(
                    progress: 0.05,
                    accentColor: .blue,
                    cornerRadius: 15,
                    width: 336,
                    height: isEditing ? 200 : 120
                )
                
                HStack(spacing: 60) {
                    Button {
                        onColorPickerRequested()
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(.white).opacity(0.8)
                            .padding(8)
                            .background(
                                Color("NeomorphBG4").opacity(0.4)
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(100)
                            )
                            .clipShape(Circle())
                    }
                    .buttonStyle(.borderless)
                    .offset(x: -90, y: -70)
                    
                    Button {
                        workoutViewModel.deleteWorkout(workout)
                        print("Deleted workout: \(workout.name)")
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .padding(8)
                            .background(
                                Color("NeomorphBG4").opacity(0.4)
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(100)
                            )
                            .clipShape(Circle())
                    }
                    .buttonStyle(.borderless)
                    .offset(x: 90, y: -70)
                }
                
                VStack(spacing: 16) {
                    HStack {
                        TextField("Workout Name", text: $editedWorkoutName)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color(.black).opacity(0.2))
                            )
                            .foregroundColor(.white).opacity(0.8)
                            .frame(width: 190)
                            .frame(width: 60)
                    }
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(lineWidth: 5)
                                .foregroundColor(Color("NeomorphBG4").opacity(0.7))
                                .frame(width: 256, height: 60)
                            
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
                                    .frame(width: 243, height: 46)
                            }
                        }
                    )
                    
                    // Example: a new "Move" button
   
                    Button("Move Workout") {
                        print("DEBUG: 'Move Workout' tapped for \(workout.name)")
                        print("DEBUG: onRequestMove is nil? \((onRequestMove == nil) ? "Yes" : "No")")
                        onRequestMove?(workout)
                    }
                    .padding(.top, 8)
                    
                    Button("Select Block") {
                        showBlockSelectionSheet = true
                    }
                    .sheet(isPresented: $showBlockSelectionSheet) {
                        // Pass in the binding to selectedBlock, plus the environment object
                        SelectBlockSheet(selectedBlock: $selectedBlock)
                            .environmentObject(blockManager)
                    }
                    
 

                    Button(action: {
                        // Update workout name if it changed.
                        if !editedWorkoutName.isEmpty && editedWorkoutName != workout.name {
                            workoutViewModel.updateWorkout(workout: workout, newName: editedWorkoutName) { success in
                                if success {
                                    print("Workout name updated to \(editedWorkoutName)")
                                    onWorkoutUpdated?()
                                } else {
                                    print("Failed to update workout name.")
                                }
                            }
                            workout.name = editedWorkoutName
                        }
                        // Update the block association if changed.
                        if selectedBlock != workout.sectionTitle {
                            // Then later in your code:
                            blockManager.updateWorkoutBlock(workout: workout, newBlock: selectedBlock) { success in
                                if success {
                                    print("Workout block updated successfully to \(selectedBlock)")
                                } else {
                                    print("Failed to update workout block.")
                                }
                            }
                            workout.sectionTitle = selectedBlock
                        }
                        isEditing = false
                    }) {
                        Text("Done Editing")
                            .foregroundColor(.white).opacity(0.8)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color("NeomorphBG3").opacity(0.9))
                            )
                    }
                    .buttonStyle(.borderless)
                    .offset(x: 0, y: 35)
                }
            }
            .frame(width: 336, height: isEditing ? 200 : 120)
            Spacer().frame(height: 40)
        }
    }
}


struct SelectBlockSheet: View {
    @EnvironmentObject var blockManager: WorkoutBlockManager
    @Binding var selectedBlock: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                if blockManager.blocks.isEmpty {
                    Text("No blocks found!")
                } else {
                    List {
                        ForEach(blockManager.blocks) { block in
                            Button(action: {
                                selectedBlock = block.title
                                dismiss()
                            }) {
                                Text(block.title)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select a Block")
            .onAppear {
                print("SelectBlockSheet onAppear: blockManager.blocks.count = \(blockManager.blocks.count)")

                blockManager.fetchBlocks()
            }
        }
    }
}


struct AddWorkoutView: View {
    @EnvironmentObject var workoutViewModel: WorkoutViewModel

    
    /// The old approach: if provided, the workout is automatically saved under this block *name*.
    let providedBlockTitle: String?
    
 
    
    @State private var workoutName: String = ""
    @State private var enteredBlockTitle: String = ""
    
    @Environment(\.dismiss) var dismiss
    
    /// Determines the final block name (sectionTitle) for the new workout if we don’t have a block ID.
    private var effectiveBlockTitle: String {
        if let provided = providedBlockTitle, !provided.isEmpty {
            return provided
        } else {
            return enteredBlockTitle.isEmpty ? "Other" : enteredBlockTitle
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 1) Workout name text field
            TextField("Workout Name", text: $workoutName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            // 2) If no block title was provided, user can type one
            if providedBlockTitle == nil {
                TextField("Block Name", text: $enteredBlockTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
            } else {
                // Show the block name if it’s provided
                Text("Block: \(providedBlockTitle!)")
                    .font(.subheadline)
                    .padding(.horizontal)
            }
            
            // 3) Save button
            Button(action: {
                saveWorkout()
            }) {
                Text("Save Workout")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(workoutName.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            .disabled(workoutName.isEmpty)
            
            Spacer()
        }
        .navigationTitle("Add Workout")
        .navigationBarItems(leading: Button("Cancel") {
            dismiss()
        })
        
    }
    
    // MARK: - Create the Workout & Optionally Bridge It to a Block
    // In AddWorkoutView
    private func saveWorkout() {
        workoutViewModel.addWorkout(named: workoutName, sectionTitle: effectiveBlockTitle) { newWorkout in
            guard let newWorkout = newWorkout else {
                print("Failed to add workout.")
                return
            }
            print("Successfully added workout: \(newWorkout.name)")
            
            // No need to fetch workouts again, we already added it to the array
            // Just dismiss the view
            DispatchQueue.main.async {
                dismiss()
            }
        }
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
    AllWorkoutsListView()
        .environmentObject(WorkoutViewModel())
        .environmentObject(WorkoutBlockManager())
    
}
