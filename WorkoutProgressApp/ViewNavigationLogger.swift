//
//  ViewNavigationLogger.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 3/20/25.
//

import SwiftUI
import Foundation

// MARK: - ViewNavigationLogger
/// Improved logger for SwiftUI view navigation with nesting support
struct ViewNavigationLogger {
    /// Active navigation stack to track view hierarchy
     static var navigationStack: [String] = []
    
    /// Log entry into a view
    /// - Parameters:
    ///   - viewName: Name of the view being entered
    ///   - file: Source file (automatically captured)
    static func viewAppeared(_ viewName: String, file: String = #file) {
        let filename = (file as NSString).lastPathComponent
        let indentation = String(repeating: "  ", count: navigationStack.count)
        let stackLevel = navigationStack.count
        
        // Add view to navigation stack
        navigationStack.append(viewName)
        
        print("\n\(indentation)┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("\(indentation)┃ 📱 ENTERED: \(viewName) (Level: \(stackLevel))")
        print("\(indentation)┃ ⌚ \(timestamp()) 📄 \(filename)")
        print("\(indentation)┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
    
    /// Log exit from a view
    /// - Parameters:
    ///   - viewName: Name of the view being exited
    ///   - file: Source file (automatically captured)
    static func viewDisappeared(_ viewName: String, file: String = #file) {
        let filename = (file as NSString).lastPathComponent
        
        // Check if this view is in our stack
        if let index = navigationStack.lastIndex(of: viewName) {
            let stackLevel = index
            let indentation = String(repeating: "  ", count: stackLevel)
            
            print("\n\(indentation)┏┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄")
            print("\(indentation)┃ 🚪 EXITED: \(viewName) (Level: \(stackLevel))")
            print("\(indentation)┃ ⌚ \(timestamp()) 📄 \(filename)")
            print("\(indentation)┗┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄\n")
            
            // Remove this view and any child views from the stack
            navigationStack.removeSubrange(index...)
        } else {
            // View wasn't in our stack - unusual case
            print("\n⚠️ UNEXPECTED EXIT: \(viewName) not found in navigation stack")
            print("⌚ \(timestamp()) 📄 \(filename)\n")
        }
    }
    
    /// Get formatted timestamp
    /// - Returns: Current time formatted as HH:mm:ss.SSS
    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
    
    /// Reset the navigation stack (useful for testing or app resets)
    static func resetStack() {
        navigationStack.removeAll()
    }
}



extension ViewNavigationLogger {
    /// Track programmatic dismissals
    static var pendingDismissals = Set<String>()
    
    /// Register a view that will be dismissed programmatically
    static func registerDismissal(for viewName: String) {
        pendingDismissals.insert(viewName)
        print("🔖 Registered pending dismissal for: \(viewName)")
    }
    
    /// Handle a programmatic dismissal
    /// This should be called before dismissing a view
    static func handleDismissal(for viewName: String, file: String = #file) {
        registerDismissal(for: viewName)
        // Force log a dismissal
        forcedViewDisappeared(viewName, file: file)
    }
    
    /// Force log view disappearance even if not in stack
    static func forcedViewDisappeared(_ viewName: String, file: String = #file) {
        let filename = (file as NSString).lastPathComponent
        
        // Determine what level this would be (if it were in the stack)
        let estimatedLevel = navigationStack.count - 1
        let indentation = String(repeating: "  ", count: max(0, estimatedLevel))
        
        print("\n\(indentation)┏┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄")
        print("\(indentation)┃ 🚪 EXITED (DISMISS): \(viewName) (Level: \(estimatedLevel))")
        print("\(indentation)┃ ⌚ \(timestamp()) 📄 \(filename)")
        print("\(indentation)┗┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄\n")
        
        // Make sure the stack is updated
        // Find the view in the stack if it exists
        if let index = navigationStack.lastIndex(of: viewName) {
            navigationStack.removeSubrange(index...)
        }
    }
}
// MARK: - Log section helpers
extension ViewNavigationLogger {
    /// Create a section header in logs to group related statements
    /// - Parameters:
    ///   - title: Section title
    ///   - emoji: Optional emoji prefix
    static func section(_ title: String, emoji: String = "📌") {
        // Calculate indentation based on current stack
        let indentation = String(repeating: "  ", count: navigationStack.count)
        
        print("\n\(indentation)\(emoji) ━━━ \(title) ━━━")
    }
    
    /// Mark the end of a log section
    static func endSection() {
        let indentation = String(repeating: "  ", count: navigationStack.count)
        print("\(indentation)━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
}

// MARK: - ViewLoggingViewModifier
struct ViewLoggingViewModifier: ViewModifier {
    let viewName: String
    
    init(_ viewName: String) {
        self.viewName = viewName
    }
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                ViewNavigationLogger.viewAppeared(viewName)
            }
            .onDisappear {
                ViewNavigationLogger.viewDisappeared(viewName)
            }
    }
}

// MARK: - View Extension
extension View {
    /// Add view navigation logging to any SwiftUI view
    /// - Parameter name: The name of the view to display in logs (defaults to type name)
    /// - Returns: Modified view with logging
    func trackNavigation(_ name: String? = nil) -> some View {
        let viewName = name ?? String(describing: Self.self)
        return self.modifier(ViewLoggingViewModifier(viewName))
    }
}

// MARK: - LogSection ViewModifier
struct LogSectionViewModifier: ViewModifier {
    let sectionTitle: String
    let emoji: String
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                ViewNavigationLogger.section(sectionTitle, emoji: emoji)
            }
            .onDisappear {
                ViewNavigationLogger.endSection()
            }
    }
}

extension View {
    /// Create a logged section within a view
    /// - Parameters:
    ///   - title: Section title
    ///   - emoji: Optional emoji prefix
    /// - Returns: Modified view with section logging
    func logSection(_ title: String, emoji: String = "📌") -> some View {
        return self.modifier(LogSectionViewModifier(sectionTitle: title, emoji: emoji))
    }
}

// MARK: - Standard Log Messages
/// Helper for standardized log messages
struct AppLogger {
    /// Log a fetch operation
    /// - Parameters:
    ///   - message: Description
    ///   - emoji: Status emoji
    static func fetch(_ message: String, emoji: String = "📋") {
        let indentation = String(repeating: "  ", count: ViewNavigationLogger.navigationStack.count)
        print("\(indentation)\(emoji) FETCH: \(message)")
    }
    
    /// Log a success
    /// - Parameter message: Success message
    static func success(_ message: String) {
        let indentation = String(repeating: "  ", count: ViewNavigationLogger.navigationStack.count)
        print("\(indentation)✅ SUCCESS: \(message)")
    }
    
    /// Log an error
    /// - Parameter message: Error message
    static func error(_ message: String) {
        let indentation = String(repeating: "  ", count: ViewNavigationLogger.navigationStack.count)
        print("\(indentation)❌ ERROR: \(message)")
    }
    
    /// Log a warning
    /// - Parameter message: Warning message
    static func warning(_ message: String) {
        let indentation = String(repeating: "  ", count: ViewNavigationLogger.navigationStack.count)
        print("\(indentation)⚠️ WARNING: \(message)")
    }
    
    /// Log an update
    /// - Parameter message: Update message
    static func update(_ message: String) {
        let indentation = String(repeating: "  ", count: ViewNavigationLogger.navigationStack.count)
        print("\(indentation)🔄 UPDATE: \(message)")
    }
    
    /// Log a debug message
    /// - Parameter message: Debug message
    static func debug(_ message: String) {
        let indentation = String(repeating: "  ", count: ViewNavigationLogger.navigationStack.count)
        print("\(indentation)🔍 DEBUG: \(message)")
    }
}

// MARK: - Example Usage
/*
struct MainApp: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
            
            WorkoutListView()
                .tabItem { Label("Workouts", systemImage: "dumbbell") }
        }
        .trackNavigation("Main App View")
    }
}

struct WorkoutListView: View {
    @State private var workouts: [Workout] = []
    
    var body: some View {
        NavigationView {
            List(workouts) { workout in
                NavigationLink(workout.name) {
                    WorkoutDetailView(workout: workout)
                        .trackNavigation("Workout: \(workout.name)")
                }
            }
            .onAppear {
                fetchWorkouts()
            }
        }
        .trackNavigation("Workouts List View")
    }
    
    func fetchWorkouts() {
        ViewNavigationLogger.section("Fetching Workouts", emoji: "🏋️")
        
        // Simulating fetch operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            AppLogger.fetch("Starting workout retrieval")
            
            // More log statements would go here...
            
            AppLogger.success("Retrieved workouts successfully")
            ViewNavigationLogger.endSection()
        }
    }
}
*/
