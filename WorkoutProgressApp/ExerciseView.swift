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

    // Track which exercise is currently being moved
    @State private var selectedToMove: Exercise? = nil
    
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
                                name: "Knelling Lat Pulldowns (wide grip) do extra",
                                sets: 3,
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
                                sets: 3,
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
                    .sheet(isPresented: $showAddExercise) {
                        NavigationView {
                            AddExerciseView(viewModel: viewModel)
                                .presentationDetents([.fraction(0.4)])
                                .presentationDragIndicator(.visible)
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
                // ForEach over the entire array
                ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { (index, exercise) in
                    VStack(spacing: 4) {
                        if let moving = selectedToMove, moving.id != exercise.id {
                            Button {
                                moveExercise(moving: moving, newIndex: index)
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.title)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        ExerciseCardView(
                            exercise: exercise,
                            evm: viewModel,
                            onRequestMove: { ex in
                                selectedToMove = ex
                                print("DEBUG: onRequestMove called for \(ex.name)")
                            }
                        )
                        
                        if let moving = selectedToMove, moving.id != exercise.id {
                            Button {
                                moveExercise(moving: moving, newIndex: index + 1)
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.title)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .padding(.top)
        }
        .onAppear {
            viewModel.fetchExercises()
        }
    }
    private func moveExercise(moving: Exercise, newIndex: Int) {
        // 1) Find oldIndex in the global array
        guard let oldIndex = viewModel.exercises.firstIndex(where: { $0.id == moving.id }) else {
            print("DEBUG: Could not find moving exercise in global array.")
            return
        }
        
        // 2) Reorder locally
        viewModel.reorderExercise(oldIndex: oldIndex, newIndex: newIndex)
        
        // 3) Push to CloudKit
        viewModel.updateAllSortIndicesInCloudKit()
        
        // 4) Clear the selection so we hide plus icons
        selectedToMove = nil
    }
}



struct AddExerciseView: View {
    @ObservedObject var viewModel: ExerciseViewModel
    
    @Environment(\.dismiss) var dismiss
    
    @State private var exerciseName = ""
    @State private var setsText = ""
    @State private var repsText = ""

    var body: some View {
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
                        
                        let setWeights = Array(repeating: 0.0, count: sets)
                        let setCompletions = Array(repeating: false, count: sets)
                        
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

    // For editing name/sets
    @State private var editedName: String = ""
    @State private var editedSets: Int = 0
    
    // Let's add a state variable to capture the note height.
    @State private var noteHeight: CGFloat = 0
    @State private var nameHeight: CGFloat = 0


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
                            .buttonStyle(.borderless)
                            .foregroundColor(.white).opacity(0.8)

                        }
    
                    }
                }
            } else {
                let dynamicHeight = 80.0
                    + Double(exercise.setWeights.count) * 80.0
                    + Double(noteHeight)
                    + Double(nameHeight)
            
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
                        ForEach(exercise.setWeights.indices, id: \.self) { index in
                            SetRowView(exercise: exercise, index: index, evm: evm)
                        }
                    }
                }
                .overlay(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        // Exercise name view with integrated gear icon
                        ExerciseNameView(
                            name: exercise.name,
                            fixedWidth: 328,  // Set your desired fixed width
                            nameHeight: $nameHeight,
                            action: {
                                editedName = exercise.name
                                editedSets = exercise.sets
                                isEditing = true
                            }
                        )
                        .padding(.leading, 48)
                        .padding(.top, 7)

                        // Add space for the rest of your content
                        Spacer().frame(height: nameHeight)
                        
                        // Rest of your exercise content below the name
                        // ...
                    }
                    .frame(width: cardWidth)
                }
            }
        }
                .padding()
        // Present the color picker sheet.
        .sheet(isPresented: $showColorPicker) {
                ColorPickerSheet(accentColor: $localAccentColor, evm: evm, exercise: exercise)
                .presentationDetents([.fraction(0.25)])
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
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Text measurement view
            Text(name)
                .font(.title3)
                .bold()
                .foregroundColor(.clear)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, verticalPadding)
                .padding(.leading, 14) // Increased left padding for measurement
                .padding(.trailing, 4)
                .frame(width: fixedWidth - iconSpace - 8, alignment: .leading)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                nameHeight = max(geo.size.height + extraHeight, minHeight)
                            }
                            .onChange(of: geo.size) { newSize in
                                nameHeight = max(newSize.height + extraHeight, minHeight)
                            }
                            .onChange(of: name) { _ in
                                DispatchQueue.main.async {
                                    nameHeight = max(geo.size.height + extraHeight, minHeight)
                                }
                            }
                    }
                )
            
            // Background shape
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
            .frame(width: fixedWidth, height: nameHeight)
            
            // Content with text and icon
            HStack(spacing: 0) {
                // Add extra padding at the beginning
                Spacer(minLength: 10) // Add 10 points of space at the start
                
                // Actual visible text
                Text(name)
                    .font(.title3)
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, verticalPadding)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: fixedWidth - iconSpace - 10, alignment: .leading) // Adjusted width to account for left padding
                
                Spacer(minLength: 0)
                
                // Gear icon remains in the same position
                Button(action: action) {
                    Image(systemName: "gear")
                        .opacity(0.7)
                        .foregroundColor(.white)
                        .frame(width: iconSpace - 8, height: iconSpace - 8)
                        .padding(.trailing, 4)
                }
                .buttonStyle(.borderless)
            }
            .frame(width: fixedWidth)
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

extension Color {
    /// Initialize a Color from a hex string (e.g., "#FF0000")
    init?(hex: String) {
        let r, g, b: Double
        
        // Remove the '#' if present.
        let hexColor = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hexColor.count == 6, let intVal = Int(hexColor, radix: 16) else {
            return nil
        }
        r = Double((intVal >> 16) & 0xFF) / 255.0
        g = Double((intVal >> 8) & 0xFF) / 255.0
        b = Double(intVal & 0xFF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    /// Convert a Color to a hex string (ignores alpha)
    func toHex() -> String? {
        #if canImport(UIKit)
        // Convert SwiftUI Color to UIColor
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let rgb: Int = (Int)(r * 255) << 16 | (Int)(g * 255) << 8 | (Int)(b * 255)
        return String(format: "#%06x", rgb)
        #else
        return nil
        #endif
    }
}

struct ColorPickerSheet: View {
    @Binding var accentColor: Color
    @Environment(\.presentationMode) var presentationMode
    let evm: ExerciseViewModel
    let exercise: Exercise

    var body: some View {
        Form {
                ColorPicker("Select a Color", selection: $accentColor)
                    .padding()
            }
            .navigationTitle("Pick Accent Color")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Convert the selected Color to a hex string.
                        if let newHex = accentColor.toHex(), let recordID = exercise.recordID {
                            evm.updateExercise(recordID: recordID, newAccentColor: newHex)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
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
                
                var newCompletions = exercise.setCompletions
                newCompletions[index].toggle()
                if let recordID = exercise.recordID {
                    evm.updateExercise(recordID: recordID, newCompletions: newCompletions)
                }
            } label: {
                if index < exercise.setCompletions.count {
                    Image(systemName: exercise.setCompletions[index] ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(exercise.setCompletions[index] ? .green : .white)
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

            }
            .presentationDetents([.fraction(0.5)])
            .presentationDragIndicator(.visible)
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
            }
            .presentationDetents([.fraction(0.5)])
            .presentationDragIndicator(.visible)
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
    ExercisesView(workoutID: CKRecord.ID(recordName: "DummyWorkoutID"))
}
