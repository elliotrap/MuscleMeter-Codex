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
                LazyVStack(spacing: 56) {
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
                    .presentationDetents([.fraction(0.4)])
                    .presentationDragIndicator(.visible)
                }
        
            }
        .sheet(isPresented: $showColorPicker) {
            colorPickerSheet
                .presentationDetents([.fraction(0.75)])
                .presentationDragIndicator(.visible)
        }
        
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                // Use the convenient button component
                LoggingDismissButton(viewType: AllWorkoutsListView.self)
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
}


// MARK: - Block Workouts List View
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
    
    private var backgroundView: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color("NeomorphBG2"), Color("NeomorphBG2")]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
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
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                // Use the convenient button component
                LoggingDismissButton(viewType: BlockWorkoutsListView.self)
            }
        }
        // This line adds your custom bar background!
        .toolbarBackground(
            Color("NeomorphBG5").opacity(0.9),   // <- Only Color + opacity
            for: .navigationBar
        )
        .toolbarBackground(.visible, for: .navigationBar)

    }
    
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
    
    private var addButton: some View {
        Button {
            showAddWorkoutSheet = true
        } label: {
            Image(systemName: "plus")
        }
    }
    
    private var addWorkoutSheet: some View {
        NavigationStack {
            AddWorkoutView(
                providedBlockTitle: blockTitle
            )
        }
        .presentationDetents([.fraction(0.4)])
        .presentationDragIndicator(.visible)
    }
    
    private var workoutListView: some View {
        LazyVStack(spacing: 26) {
            workoutCardsList
                .animation(.default, value: selectedToMove != nil) // Using a Bool instead of the model
                .animation(.default, value: refreshID)
        }
    }

    // MARK: - Workout Cards List
    private var workoutCardsList: some View {
        VStack(spacing: 0) {
            // If we're moving a workout, show the "move to start" button only if the workout isn't already at the start
            if let movingWorkout = selectedToMove,
               let currentIndex = workoutsForBlock.firstIndex(where: { $0.id == movingWorkout.id }),
               currentIndex > 0 {
                insertionButton(
                    label: "Move \(movingWorkout.name) to Start",
                    systemImage: "arrow.up.to.line",
                    targetIndex: 0,
                    isEndPosition: false
                )
                .padding(.bottom, 8)
            }
            
            // List all workouts with insertion points
            ForEach(Array(workoutsForBlock.enumerated()), id: \.element.id) { (localIndex, workout) in
                // Only show the workout card
                WorkoutCardView(
                    workout: workout,

                    onColorPickerRequested: {
                        selectedWorkout = workout
                        selectedAccentColor = .blue
                        showColorPicker = true
                    },
                    onWorkoutUpdated: {
                        refreshID = UUID()
                    },
                    onRequestMove: { workout in
                        selectedToMove = workout
                        refreshID = UUID()
                    }
                )
                .id("\(workout.id)-\(workout.sortIndex)-\(refreshID)")
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                
                // If we're moving a workout, show insertion points between workouts
                if let movingWorkout = selectedToMove,
                   movingWorkout.id != workout.id,
                   localIndex < workoutsForBlock.count - 1 {
                    let nextWorkout = workoutsForBlock[localIndex + 1]
                    
                    // Don't show insertion point if moving workout is already at this position
                    if movingWorkout.id != nextWorkout.id {
                        insertionButton(
                            label: "Move \(movingWorkout.name) after \(workout.name)",
                            systemImage: "arrow.down",
                            targetIndex: localIndex + 1,
                            isEndPosition: false
                        )
                    }
                }
            }
            
            // If we're moving a workout, show the "move to end" button only if the workout isn't already at the end
            if let movingWorkout = selectedToMove,
               let currentIndex = workoutsForBlock.firstIndex(where: { $0.id == movingWorkout.id }),
               currentIndex < workoutsForBlock.count - 1 {
                insertionButton(
                    label: "Move \(movingWorkout.name) to End",
                    systemImage: "arrow.down.to.line",
                    targetIndex: workoutsForBlock.count,  // Important: Use count, not count-1 for end position
                    isEndPosition: true  // Flag this as an end position move
                )
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Insertion Button View
    private func insertionButton(label: String, systemImage: String, targetIndex: Int, isEndPosition: Bool) -> some View {
        Button(action: {
            guard let movingWorkout = selectedToMove else { return }
            
            print("DEBUG: Moving \(movingWorkout.name) to index \(targetIndex)")
            
            // Get current index of the moving workout
            if let currentIndex = workoutsForBlock.firstIndex(where: { $0.id == movingWorkout.id }) {
                print("DEBUG: Current index of \(movingWorkout.name) is \(currentIndex)")
                
                // Special handling for end position
                if isEndPosition {
                    workoutViewModel.moveWorkoutToEnd(movingWorkout)
                } else {
                    // Get the correct index if we need to account for removal
                    var adjustedTargetIndex = targetIndex
                    
                    // If moving to a later position, we need to account for the removal of the current item
                    if targetIndex > currentIndex {
                        adjustedTargetIndex -= 1
                    }
                    
                    // Move the workout
                    workoutViewModel.moveWorkout(movingWorkout, toIndex: adjustedTargetIndex)
                }
                
                selectedToMove = nil
                refreshID = UUID()
            }
        }) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(label)
                    .fontWeight(.medium)
            }
            .foregroundColor(.blue)
            .padding(.vertical, 8)
        }
        .buttonStyle(BorderedButtonStyle())
        .id("insertion-\(targetIndex)-\(refreshID)")
        .padding(.horizontal, 16)
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




// MARK: - WorkoutCardView

struct WorkoutCardView: View {
    @EnvironmentObject var blockManager: WorkoutBlockManager
    @EnvironmentObject var workoutViewModel: WorkoutViewModel

    // We store the workout in @State
    @State private var workout: WorkoutModel
    
    @State private var selectedBlock: String
    @State private var selectedToMove: WorkoutModel? = nil
    @State private var showColorPickerSheet = false
    
    /// Callback to parent telling it we want to move this workout
    var onRequestMove: ((WorkoutModel) -> Void)?
    
    var onWorkoutUpdated: (() -> Void)?
    
    // Additional callback for color picker
    var onColorPickerRequested: () -> Void
    
    @State private var showColorPicker = false
    @State private var accentColor: Color

    @State private var currentAccentColor: Color = .blue

    @State private var isEditing = false
    @State private var editedWorkoutName: String = ""
    
    // MARK: - Custom init
    // MARK: - Custom init
    init(
        workout: WorkoutModel,
        onColorPickerRequested: @escaping () -> Void,
        onWorkoutUpdated: (() -> Void)? = nil,
        onRequestMove: ((WorkoutModel) -> Void)? = nil
    ) {
        self.workout = workout
        self.onColorPickerRequested = onColorPickerRequested
        self.onWorkoutUpdated = onWorkoutUpdated
        self.onRequestMove = onRequestMove

        _selectedBlock      = State(initialValue: workout.sectionTitle ?? "Other")
        _accentColor        = State(initialValue: Color(hex: workout.accentColorHex) ?? .blue)
        _currentAccentColor = State(initialValue: Color(hex: workout.accentColorHex) ?? .blue) // 👈
        _showColorPicker    = State(initialValue: false)
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
            NavigationLink(destination:
                            ExercisesView(workoutID: workout.id)
                    .navigationBarBackButtonHidden(true)  // Hide the default back button
                    .trackNavigation("Exercises View")
            ) {
                ZStack {
                    // Background
                    WorkoutCustomRoundedRectangle(
                        progress: 0.05,
                        accentColor: currentAccentColor, // Dynamically set here
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
                            .padding(.top, 30)
                        
                        Spacer()
                        
                        if let date = workout.date {
                            Text("Date: \(date, formatter: DateFormatter.workoutDateFormatter)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.bottom, 35)
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
                            .padding(.top, 20)
                            .padding(.trailing, 30)
                            .buttonStyle(.borderless)
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
            Spacer().frame(height: 80)
            ZStack {
                // Background
                WorkoutCustomRoundedRectangle(
                    progress: 0.05,
                    accentColor: currentAccentColor,
                    cornerRadius: 15,
                    width: 336,
                    height: isEditing ? 250 : 120
                )
                
                HStack(spacing: 60) {
                    Button {
                        showColorPicker = true

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
                    .offset(x: -90, y: -100)
                    
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
                    .offset(x: 90, y: -100)
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
   
                    HStack(spacing: 30) {
                        Button("Move Workout") {
                            print("DEBUG: 'Move Workout' tapped for \(workout.name)")
                            print("DEBUG: onRequestMove is nil? \((onRequestMove == nil) ? "Yes" : "No")")
                            onRequestMove?(workout)
                        }
                        .buttonStyle(.borderless)
                        .padding(8)
                        .foregroundColor(.white).opacity(0.8)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 0)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color("NeomorphBG3").opacity(0.9))
                        )
                        
                        Button("Select Block") {
                                 // 🔥 This replaces showBlockSelectionSheet:
                                 selectedToMove = workout
                             }
                        .buttonStyle(.borderless)
                        .padding(8)
                        .foregroundColor(.white).opacity(0.8)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 0)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color("NeomorphBG3").opacity(0.9))
                        )
                        .sheet(item: $selectedToMove) { workout in
                            SelectBlockSheet(workoutToMove: workout)
                                .environmentObject(blockManager)
                                .environmentObject(workoutViewModel)
                        }
                        
                    }
                    .padding(.top, 20)
                    
 

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
                            .padding(8)
                            .foregroundColor(.white).opacity(0.8)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 0)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color("NeomorphBG3").opacity(0.9))
                            )
                    }
                    
                    .buttonStyle(.borderless)
                    .offset(x: 0, y: 5)
                }
                .offset(x: 0, y: 15)

            }
            .frame(width: 336, height: isEditing ? 200 : 120)
            Spacer().frame(height: 40)
        }
        .sheet(isPresented: $showColorPicker) {
                   ColorPickerSheet(
                       accentColor: $accentColor,
                       onDone: { newColor in
                           if let hex = newColor.toHex(), hex != workout.accentColorHex {
                               workoutViewModel.updateColor(for: workout, to: hex)           // 🠔 save
                           }
                       }
                   )
                   .presentationDetents([.fraction(0.75)])
                   .presentationDragIndicator(.visible)
               }
    }
}


struct SelectBlockSheet: View {
    @EnvironmentObject var workoutViewModel: WorkoutViewModel
    @EnvironmentObject var blockManager: WorkoutBlockManager
    let workoutToMove: WorkoutModel
    @Environment(\.dismiss) var dismiss

    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("Loading blocks…")
                } else if blockManager.blocks.isEmpty {
                    Text("No blocks found!")
                        .padding()
                } else {
                    List {
                        ForEach(blockManager.blocks) { block in
                            Button {
                                // 🔥 Here’s the magic call:
                                workoutViewModel.moveWorkoutToBlock(
                                    workoutToMove,
                                    toBlockTitle: block.title
                                )
                                dismiss()
                            } label: {
                                HStack {
                                    Text(block.title)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select a Block")
            .onAppear {
                if blockManager.blocks.isEmpty {
                    blockManager.fetchBlocks { _ in isLoading = false }
                } else {
                    isLoading = false
                }
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
                .padding()
                .background(Color("NeomorphBG3").opacity(0.3))
                .cornerRadius(10)
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
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                .fill(Color.gray.opacity(0.12))
                .frame(maxWidth: 350)
                .frame(height: 60)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                
            Button(action: {
                saveWorkout()

            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                    
                    Text("Save Workout")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                        .underline(false)
                        
                }
                .padding(.horizontal, 100)
                .padding(.vertical, 12)
                .background(
 
                        RoundedRectangle(cornerRadius: 17)
                            .fill(workoutName.isEmpty ? Color.gray.opacity(0.5) : Color.blue.opacity(0.5))
                )
                .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
            }
            .disabled(workoutName.isEmpty)
            .buttonStyle(.borderless)
                
            }
            
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






#Preview {
    BlockWorkoutsListView(blockTitle:   "Block")
        .environmentObject(WorkoutViewModel())
        .environmentObject(WorkoutBlockManager())
    
}
