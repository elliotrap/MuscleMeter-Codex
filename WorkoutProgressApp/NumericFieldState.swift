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
