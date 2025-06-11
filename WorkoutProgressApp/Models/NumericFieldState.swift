//
//  Untitled.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 3/19/25.
//
import SwiftUI
import Combine
import CloudKit



// State container that persists across view updates
class TextFieldState: ObservableObject {
    @Published var text: String = ""
    private var updateWorkItem: DispatchWorkItem?
    
    // Schedule an update with debouncing to prevent frequent CloudKit calls
    func scheduleUpdate(newText: String, exercise: Exercise, evm: ExerciseViewModel) {
        // Cancel any pending update
        updateWorkItem?.cancel()
        
        // Create a new update with the current text value
        let workItem = DispatchWorkItem { [weak self, newText] in
            guard let self = self else { return }
            
            if let recordID = exercise.recordID, newText != exercise.name {
                // Use a specialized version of updateExercise that won't refresh views
                evm.updateExerciseWithoutRefresh(recordID: recordID, newName: newText)
            }
        }
        
        // Store and schedule the work item
        updateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }
}

// A stable state manager for numeric fields
class NumericFieldState: ObservableObject {
    @Published var text: String = ""
    @Published var errorMessage: String? = nil
    private var updateWorkItem: DispatchWorkItem?
    
    func validate(
        value: String,
        minValue: Int,
        maxValue: Int,
        exercise: Exercise,
        evm: ExerciseViewModel,
        updateField: @escaping (ExerciseViewModel, CKRecord.ID, Int) -> Void
    ) {
        // Cancel any pending update
        updateWorkItem?.cancel()
        
        // Clear error if empty
        if value.isEmpty {
            errorMessage = nil
            return
        }
        
        // Create a new validation and update work item
        let workItem = DispatchWorkItem { [weak self, value] in
            guard let self = self else { return }
            
            // Validate input is an integer
            if let numericValue = Int(value) {
                // Check minimum
                if numericValue < minValue {
                    self.errorMessage = "Minimum allowed is \(minValue)"
                    return
                }
                // Check maximum
                if numericValue > maxValue {
                    self.errorMessage = "Maximum allowed is \(maxValue)"
                    return
                }
                
                // Valid input - clear any error
                self.errorMessage = nil
                
                // Update if needed and if we have a record ID
                if let recordID = exercise.recordID {
                    updateField(evm, recordID, numericValue)
                }
            } else {
                // Not a valid number
                self.errorMessage = "Please enter a valid number"
            }
        }
        
        // Store and schedule the work item
        updateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
    }
}


// A persistent state container for the weight field
class WeightFieldState: ObservableObject {
    @Published var text: String = ""
    @Published var hasInitialized: Bool = false
    var lastSubmittedValue: String = ""
    private var updateWorkItem: DispatchWorkItem?
    
    // Schedule a debounced update
    func scheduleUpdate(newValue: String, exercise: Exercise, index: Int, evm: ExerciseViewModel) {
        // Cancel any pending update
        updateWorkItem?.cancel()
        
        // Skip if no change from last submitted value
        if newValue == lastSubmittedValue {
            return
        }
        
        // Create a new work item
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            self.updateWeight(newValue: newValue, exercise: exercise, index: index, evm: evm)
        }
        
        updateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
    
    // Submit the current value immediately
    func submitImmediate(exercise: Exercise, index: Int, evm: ExerciseViewModel) {
        // Cancel any pending update
        updateWorkItem?.cancel()
        updateWorkItem = nil
        
        // Skip if no change from last submitted value
        if text == lastSubmittedValue {
            return
        }
        
        // Update now
        updateWeight(newValue: text, exercise: exercise, index: index, evm: evm)
    }
    
    // Update the weight value
    private func updateWeight(newValue: String, exercise: Exercise, index: Int, evm: ExerciseViewModel) {
        guard let recordID = exercise.recordID else { return }
        
        // Convert the value
        let weightValue: Double
        if newValue.isEmpty {
            weightValue = 0
        } else if let parsed = Double(newValue) {
            weightValue = parsed
        } else {
            return // Invalid input
        }
        
        // Track that we're submitting this value
        lastSubmittedValue = newValue
        
        // Only update if the value actually changed
        if index < exercise.setWeights.count && exercise.setWeights[index] != weightValue {
            // Make a copy of the weights array
            var newWeights = exercise.setWeights
            newWeights[index] = weightValue
            
            // Use the silent update method to avoid UI refreshes
            evm.updateExerciseWithoutRefresh(
                recordID: recordID,
                newWeights: newWeights
            )
        }
    }
}


// State container for the actual reps field
class ActualRepsFieldState: ObservableObject {
    @Published var text: String = ""
    @Published var hasInitialized: Bool = false
    var lastSubmittedValue: String = ""
    private var updateWorkItem: DispatchWorkItem?
    
    // Schedule a debounced update
    func scheduleUpdate(newValue: String, exercise: Exercise, index: Int, evm: ExerciseViewModel) {
        // Cancel any pending update
        updateWorkItem?.cancel()
        
        // Skip if no change from last submitted value
        if newValue == lastSubmittedValue {
            return
        }
        
        // Create a new work item
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            self.updateActualReps(newValue: newValue, exercise: exercise, index: index, evm: evm)
        }
        
        updateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
    
    // Submit the current value immediately and return whether field should remain visible
    func submitImmediate(exercise: Exercise, index: Int, evm: ExerciseViewModel) -> Bool {
        // Cancel any pending update
        updateWorkItem?.cancel()
        updateWorkItem = nil
        
        // Skip if no change from last submitted value
        if text == lastSubmittedValue {
            // Return whether the field should remain visible
            return !text.isEmpty
        }
        
        // Update now
        updateActualReps(newValue: text, exercise: exercise, index: index, evm: evm)
        
        // Return whether the field should remain visible
        return !text.isEmpty
    }
    
    // Update the actual reps value
    private func updateActualReps(newValue: String, exercise: Exercise, index: Int, evm: ExerciseViewModel) {
        guard let recordID = exercise.recordID else { return }
        
        // Convert the value
        let repsValue: Int
        if newValue.isEmpty {
            repsValue = 0
        } else if let parsed = Int(newValue) {
            repsValue = parsed
        } else {
            return // Invalid input
        }
        
        // Track that we're submitting this value
        lastSubmittedValue = newValue
        
        // Only update if the value actually changed
        if index < exercise.setActualReps.count && exercise.setActualReps[index] != repsValue {
            // Make a copy of the actual reps array
            var updatedReps = exercise.setActualReps
            updatedReps[index] = repsValue
            
            // Use the silent update method to avoid UI refreshes
            evm.updateExerciseWithoutRefresh(
                recordID: recordID,
                newActualReps: updatedReps
            )
        }
    }
}
