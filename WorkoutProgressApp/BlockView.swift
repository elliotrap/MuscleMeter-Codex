//
//  BlockView.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/27/25.
//

import SwiftUI



struct BlocksTabView: View {
    @EnvironmentObject var blockManager: WorkoutBlockManager
    @State private var showAddBlockSheet = false
    @State private var isEditing = false
    
    func getRotationAngle(geometry: GeometryProxy) -> Double {
        let screenMid = UIScreen.main.bounds.width / 2
        let currentMid = geometry.frame(in: .global).midX
        
        // Limit rotation angle to improve performance
        let percentage = Double(1 - (currentMid / screenMid))
        let maxAngle = 30.0 // Reduced from 40 to ease computation
        
        return percentage * maxAngle
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if blockManager.blocks.isEmpty {
                emptyStateView
            } else {
                contentView
            }
        }
        .navigationTitle("Blocks")
        .sheet(isPresented: $showAddBlockSheet) {
            AddBlockView(blockManager: blockManager)
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            
            // Centered button for empty state
            VStack(spacing: 20) {
                // Add Block Button
                AddBlockCardView(
                    showAddBlockSheet: $showAddBlockSheet,
                    outerGeometryWidth: 400,
                    rotationAngle: 0
                )
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(30)
            
            Spacer()
        }
    }
    
    private var contentView: some View {
        GeometryReader { outerGeometry in
            TabView {
                // Add Block Card as first item
                addBlockCardView(outerGeometry: outerGeometry)
                
                // Existing blocks
                ForEach(blockManager.blocks) { block in
                    blockView(for: block)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
        }
        .frame(width: 400, height: 400)
    }
    
    private func addBlockCardView(outerGeometry: GeometryProxy) -> some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    // Using new dedicated component
                    AddBlockCardView(
                        showAddBlockSheet: $showAddBlockSheet,
                        outerGeometryWidth: outerGeometry.size.width,
                        rotationAngle: getRotationAngle(geometry: geometry)
                    )
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
    }
    
    private func blockView(for block: WorkoutBlock) -> some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    BlockCardView(
                        block: block,
                        blockManager: blockManager,
                        rotationAngle: getRotationAngle(geometry: geometry)
                    )
                    Spacer()
                }
                
                Spacer()
            }
        }
        .id(block.id)
    }
}

struct AddBlockCardView: View {
    @Binding var showAddBlockSheet: Bool
    let outerGeometryWidth: CGFloat
    let rotationAngle: Double
    
    var body: some View {
        Button(action: {
            showAddBlockSheet = true
        }) {
            ZStack {
                // Card background with dashed border
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.green.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.gray.opacity(0.05))
                    )
                    .frame(width: min(outerGeometryWidth * 0.85, 300), height: 300)
                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                
                VStack(spacing: 16) {
                    // Plus circle icon
                    Circle()
                        .fill(Color.green.opacity(0.7))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        )
                    
                    // Text label
                    Text("Add New Block")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .rotation3DEffect(
            Angle(degrees: rotationAngle),
            axis: (x: 0.0, y: 1.0, z: 0.0)
        )
        .frame(width: 300, height: 300)
        .padding()
    }
}





struct BlockCardView: View {
    @EnvironmentObject var blockManager: WorkoutBlockManager
    var block: WorkoutBlock
    
    /// Toggles whether we show the "Delete" UI or the navigation link.
    @State private var isEditing = false
    
    /// State to control sheet presentation
    @State private var showReorderSheet = false

    /// Temporary title used when renaming a block
    @State private var editedTitle: String = ""
    
    /// A pre-calculated rotation angle if you still want the 3D effect in a TabView.
    let rotationAngle: Double
    
    // Callback for requesting to move a block
    var onRequestMoveBlock: ((WorkoutBlock) -> Void)?
    
    init(block: WorkoutBlock, blockManager: WorkoutBlockManager, rotationAngle: Double = 0, onRequestMoveBlock: ((WorkoutBlock) -> Void)? = nil) {
        self.block = block
        self.rotationAngle = rotationAngle
        self.onRequestMoveBlock = onRequestMoveBlock
    }
    
    var body: some View {
        ZStack {
            if isEditing {
                // In editing mode, the entire card displays controls
                BlockCustomRoundedRectangle()
                    .overlay(
                        VStack(spacing: 16) {
                            TextField("Block Name", text: $editedTitle)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)

                            Button("Save Name") {
                                let newName = editedTitle.trimmingCharacters(in: .whitespaces)
                                guard !newName.isEmpty else { return }
                                blockManager.updateBlock(block: block, newTitle: newName)
                                isEditing = false
                            }
                            .disabled(editedTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                            .padding(.bottom, 8)

                            Button(action: {
                                withAnimation {
                                    blockManager.deleteBlock(block: block)
                                    isEditing = false
                                }
                            }) {
                                Text("Delete Block")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                            }

                            Button(action: {
                                showReorderSheet = true
                                isEditing = false // Close editing mode when moving
                            }) {
                                Text("Reorder Blocks")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                            }
                        }
                    )
                    .onAppear { editedTitle = block.title }
            } else {
                
                // If NOT editing, the entire card is a NavigationLink.
                NavigationLink(
                    destination: BlockWorkoutsListView(blockTitle: block.title)
                ) {
                    BlockCustomRoundedRectangle()
                        .overlay(
                            ZStack {
                                Text(block.title)
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .frame(width: 200) // Set your desired maximum width
                                    .lineLimit(3) // Allow up to 3 lines (adjust as needed)
                                    .multilineTextAlignment(.center) // Center the text
                            }
                        )
                }                // Use a plain button style so the entire rectangle is clickable.
                .buttonStyle(.plain)
            }
            
            // Gear icon in the top-right corner
            VStack {
    

                HStack {
                    Spacer()
                        .frame(width: 200)
                    Button(action: {
                        withAnimation {
                            isEditing.toggle()
                        }
                    }) {
                        Image(systemName: isEditing ? "x.circle" : "gearshape")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .opacity(0.7)
                            .foregroundColor(.white)                            .padding(10)
                        
                    }
                    .buttonStyle(.borderless)
                }
                Spacer()
                    .frame(height: 200)
            }
        }
        .rotation3DEffect(
            Angle(degrees: rotationAngle),
            axis: (x: 0.0, y: 1.0, z: 0.0)
        )
        .frame(width: 300, height: 300)
        .padding()
        .contextMenu {
            Button(action: {
                withAnimation {
                    isEditing.toggle()
                }
            }) {
                Label("Edit Block", systemImage: "pencil")
            }
        }
        .onTapGesture {
            if isEditing {
                isEditing = false
            } else {
                // Navigate to block detail
                // Your existing navigation code
            }
        }
        .sheet(isPresented: $showReorderSheet) {
            BlockReorderSheet(blockManager: blockManager, isPresented: $showReorderSheet)
        }

    }
}

// Theme colors - customize these to match your app's color scheme
var primaryColor = Color("NeomorphBG3") // Cannot infer contextual base in reference to member 'blue' // Extra argument 'default' in call
var accentColor = Color("NeomorphBG3") // Cannot infer contextual base in reference to member 'purple' // Extra argument 'default' in call
var backgroundColor = Color("NeomorphBG3") // Cannot infer contextual base in reference to member 'white' // Extra argument 'default' in call



struct BlockReorderSheet: View {
    // MARK: - Properties
    @ObservedObject var blockManager: WorkoutBlockManager
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    
    // Theme colors - customize these to match your app's color scheme
    var primaryColor = Color("NeomorphBG3")
    
    var accentColor = Color("NeomorphBG3")
    
    var backgroundColor = Color("NeomorphBG3")
    
    // Keep track of the reordered blocks locally before saving
       @State private var reorderedBlocks: [WorkoutBlock]
       
       // Animation properties
       @State private var showSaveAnimation = false
       @State private var draggedItem: WorkoutBlock?
       @State private var headerScale: CGFloat = 1.0
       
       // MARK: - Initialization
       init(blockManager: WorkoutBlockManager, isPresented: Binding<Bool>) {
           self.blockManager = blockManager
           self._isPresented = isPresented
           // Initialize with current blocks order
           self._reorderedBlocks = State(initialValue: blockManager.blocks)
           
           print("🔄 REORDER: Initialized sheet with \(blockManager.blocks.count) blocks")
       }
       
       // MARK: - Body
       var body: some View {
           ZStack {
               // Custom background
               backgroundView
                   .ignoresSafeArea()
               
               VStack(spacing: 0) {
                   // Header
                   headerView
                       .scaleEffect(headerScale)
                       .onAppear {
                           withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                               headerScale = 1.0
                           }
                       }
                   
                   // Block list container
                   blocksContainerView
                   
                   // Action buttons
                   actionButtonsView
               }
               .padding(.horizontal)
           }
           .transition(.move(edge: .bottom))
       }
       
       // MARK: - UI Components
       // Custom animated background
       var backgroundView: some View {
           ZStack {
               // Base layer
               colorScheme == .dark ? Color.black : Color(white: 0.95)
               
               // Gradient overlay
               LinearGradient(
                   gradient: Gradient(colors: [
                       primaryColor.opacity(0.05),
                       accentColor.opacity(0.1)
                   ]),
                   startPoint: .topLeading,
                   endPoint: .bottomTrailing
               )
               
               // Subtle pattern overlay
               GeometryReader { geometry in
                   ForEach(0..<5) { i in
                       Circle()
                           .fill(
                               LinearGradient(
                                   gradient: Gradient(colors: [primaryColor, accentColor]),
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing
                               )
                           )
                           .opacity(0.05)
                           .frame(
                               width: geometry.size.width * CGFloat([0.6, 0.5, 0.7, 0.4, 0.5][i % 5]),
                               height: geometry.size.width * CGFloat([0.6, 0.5, 0.7, 0.4, 0.5][i % 5])
                           )
                           .position(
                               x: geometry.size.width * CGFloat([0.1, 0.8, 0.5, 0.2, 0.9][i % 5]),
                               y: geometry.size.height * CGFloat([0.2, 0.1, 0.8, 0.9, 0.5][i % 5])
                           )
                           .blur(radius: 40)
                   }
               }
           }
       }
       
       // Header view
       var headerView: some View {
           VStack(spacing: 12) {
               // Title with animated underline
               Text("REORDER BLOCKS")
                   .font(.system(size: 26, weight: .bold, design: .rounded))
                   .kerning(1.5)
                   .foregroundColor(colorScheme == .dark ? .white : .black)
                   .overlay(
                       Rectangle()
                           .frame(height: 3)
                           .offset(y: 6)
                           .foregroundStyle(
                               LinearGradient(
                                   gradient: Gradient(colors: [primaryColor, accentColor]),
                                   startPoint: .leading,
                                   endPoint: .trailing
                               )
                           )
                           .opacity(0.7)
                           .scaleEffect(x: headerScale)
                       , alignment: .bottom
                   )
               
               // Subtitle
               Text("Drag items to customize your workout sequence")
                   .font(.system(size: 14, weight: .medium, design: .rounded))
                   .multilineTextAlignment(.center)
                   .foregroundColor(Color.gray.opacity(0.8))
           }
           .padding(.top, 20)
           .padding(.bottom, 25)
       }
       
       // Card background with subtle depth
       var cardBackgroundView: some View {
           RoundedRectangle(cornerRadius: 24)
               .fill(colorScheme == .dark ? Color.black.opacity(0.7) : Color.white)
               .shadow(color: Color.black.opacity(0.07), radius: 20, x: 0, y: 5)
               .overlay(
                   RoundedRectangle(cornerRadius: 24)
                       .stroke(
                           LinearGradient(
                               gradient: Gradient(colors: [
                                   primaryColor.opacity(0.3),
                                   accentColor.opacity(0.3)
                               ]),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing
                           ),
                           lineWidth: 1
                       )
               )
       }
       
       // Single draggable block item with drag and drop behavior
       func draggableBlockItem(_ block: WorkoutBlock) -> some View {
           blockItem(block)
               .opacity(draggedItem?.id == block.id ? 0.5 : 1.0)
               .scaleEffect(draggedItem?.id == block.id ? 0.95 : 1.0)
               .animation(.spring(response: 0.3, dampingFraction: 0.7), value: draggedItem?.id)
               .contentShape(Rectangle()) // Ensure the entire area is tappable
               .onDrag {
                   self.draggedItem = block
                   let blockIndex = reorderedBlocks.firstIndex(where: { $0.id == block.id }) ?? 0
                   return NSItemProvider(object: "block-\(blockIndex)" as NSString)
               }
               .onDrop(of: [.text], isTargeted: nil) { providers in
                   handleBlockDrop(for: block)
                   return true
               }
       }
       
       // Blocks list view
       var blocksListView: some View {
           ScrollView {
               LazyVStack(spacing: 12) {
                   ForEach(reorderedBlocks) { block in
                       draggableBlockItem(block)
                   }
               }
               .padding(.vertical, 15)
               .padding(.horizontal, 12)
           }
           .padding(8)
       }
       
       // Handle drop logic for block reordering
       private func handleBlockDrop(for targetBlock: WorkoutBlock) -> Bool {
           // Guard against invalid drags
           guard let draggedItem = self.draggedItem else {
               return false
           }
           
           // Handle drop to reorder
           if let sourceIndex = reorderedBlocks.firstIndex(where: { $0.id == draggedItem.id }),
              let destinationIndex = reorderedBlocks.firstIndex(where: { $0.id == targetBlock.id }) {
               
               // Don't move if dropped on itself
               if sourceIndex != destinationIndex {
                   // Create haptic feedback for successful drop
                   let generator = UIImpactFeedbackGenerator(style: .medium)
                   generator.impactOccurred()
                   
                   print("🔄 REORDER: Moving block from index \(sourceIndex) to index \(destinationIndex)")
                   
                   // Perform the move with animation
                   withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                       let item = reorderedBlocks.remove(at: sourceIndex)
                       reorderedBlocks.insert(item, at: destinationIndex)
                   }
               }
           }
           
           // Always clear the dragged item reference
           DispatchQueue.main.async {
               self.draggedItem = nil
           }
           
           return true
       }
       
       // Container for the blocks list
       var blocksContainerView: some View {
           ZStack {
               cardBackgroundView
               blocksListView
           }
           .frame(maxHeight: 420)
       }
       
       // Individual block item
       func blockItem(_ block: WorkoutBlock) -> some View {
           HStack(spacing: 12) {
               // Block color indicator
               RoundedRectangle(cornerRadius: 4)
                   .fill(
                       LinearGradient(
                           gradient: Gradient(colors: [primaryColor, accentColor]),
                           startPoint: .top,
                           endPoint: .bottom
                       )
                   )
                   .frame(width: 4, height: 36)
               
               // Block info
               VStack(alignment: .leading, spacing: 4) {
                   Text(block.title)
                       .font(.system(size: 16, weight: .semibold, design: .rounded))
                       .foregroundColor(colorScheme == .dark ? .white : .black)
               }
               
               Spacer()
               
               // Drag handle with subtle animation
               Image(systemName: "line.3.horizontal")
                   .font(.system(size: 16, weight: .bold))
                   .foregroundColor(Color.gray.opacity(0.7))
                   .frame(width: 32, height: 32)
                   .contentShape(Rectangle())
           }
           .padding(.vertical, 14)
           .padding(.horizontal, 16)
           .background(
               RoundedRectangle(cornerRadius: 16)
                   .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.98))
                   .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
           )
           // Make the entire item a tap/drop target
           .contentShape(Rectangle())
       }
       
       // Action buttons
       var actionButtonsView: some View {
           HStack(spacing: 20) {
               // Cancel button
               Button(action: {
                   print("🔄 REORDER: Cancelled - discarding changes")
                   withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                       isPresented = false
                   }
               }) {
                   Text("Cancel")
                       .font(.system(size: 16, weight: .semibold, design: .rounded))
                       .foregroundColor(colorScheme == .dark ? .white : .black)
                       .frame(maxWidth: .infinity)
                       .frame(height: 54)
                       .background(
                           RoundedRectangle(cornerRadius: 18)
                               .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                               .overlay(
                                   RoundedRectangle(cornerRadius: 18)
                                       .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1)
                               )
                       )
               }
               .buttonStyle(ScaleButtonStyle())
               
               // Save button
               Button(action: saveChanges) {
                   ZStack {
                       // Button background
                       RoundedRectangle(cornerRadius: 18)
                           .fill(
                               LinearGradient(
                                   gradient: Gradient(colors: [primaryColor, accentColor]),
                                   startPoint: .leading,
                                   endPoint: .trailing
                               )
                           )
                           .shadow(color: accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
                       
                       // Button text
                       Text("Save Order")
                           .font(.system(size: 16, weight: .bold, design: .rounded))
                           .foregroundColor(.white)
                           .opacity(showSaveAnimation ? 0 : 1)
                       
                       // Success checkmark animation
                       Image(systemName: "checkmark")
                           .font(.system(size: 20, weight: .bold))
                           .foregroundColor(.white)
                           .opacity(showSaveAnimation ? 1 : 0)
                           .scaleEffect(showSaveAnimation ? 1 : 0.5)
                           .rotationEffect(showSaveAnimation ? .degrees(0) : .degrees(-90))
                   }
                   .frame(maxWidth: .infinity)
                   .frame(height: 54)
               }
               .buttonStyle(ScaleButtonStyle())
           }
           .padding(.horizontal, 2)
           .padding(.vertical, 30)
       }
       
       // MARK: - Actions
       private func saveChanges() {
           print("💾 REORDER: Saving block order changes")
           
           // Show the save animation
           withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
               showSaveAnimation = true
           }
           
           // Create new array with updated order values
           var updatedBlocks: [WorkoutBlock] = []
           
           for (index, var block) in reorderedBlocks.enumerated() {
               print("📋 REORDER: Block '\(block.title)' was at order \(block.order), setting to \(index)")
               block.order = index  // Set the order property to match its position
               updatedBlocks.append(block)
           }
           
           // Update the blocks in the manager and save to CloudKit
           print("📤 REORDER: Calling updateBlocksOrder with \(updatedBlocks.count) blocks")
           blockManager.updateBlocksOrder(updatedBlocks)
           
           // Haptic feedback on save (optional)
           let generator = UINotificationFeedbackGenerator()
           generator.notificationOccurred(.success)
           
           // Delay dismissal to show animation
           DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
               // Close the sheet
               withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                   isPresented = false
               }
               
               // Reset animation state
               DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                   showSaveAnimation = false
               }
           }
       }
   }

// Custom scale animation for buttons
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// For preview purposes (mock data)
struct CustomBlockReorderSheet_Previews: PreviewProvider {
    static var previews: some View {
        // Mock data for preview
        let mockManager = WorkoutBlockManager()
        
        return BlockReorderSheet(
            blockManager: mockManager,
            isPresented: .constant(true)
        )
        .preferredColorScheme(.light)
    }
}





struct AddBlockView: View {
    @Environment(\.dismiss) var dismiss
    @State private var blockTitle: String = ""
    @FocusState private var isTextFieldFocused: Bool
    var blockManager: WorkoutBlockManager

    var body: some View {
        VStack(spacing: 0) {
            // Title area with proper spacing
            Text("New Block")
                .font(.title)
                .padding(.top, 30)
                .padding(.bottom, 20)
            
            // Form area
            VStack(alignment: .leading, spacing: 10) {
                Text("Block Details")
                    .font(.headline)
                    .padding(.leading, 5)
                
                TextField("Enter block name", text: $blockTitle)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .focused($isTextFieldFocused)
            }
            .padding(.horizontal, 20)
            
            Spacer().frame(height: 40)
            
            // Save button
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.gray.opacity(0.12))
                    .frame(maxWidth: 350)
                    .frame(height: 60)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                
                Button(action: {
                    if !blockTitle.isEmpty {
                        blockManager.addBlock(title: blockTitle)
                        dismiss()
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                        
                        Text("Save Block")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 100)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 17)
                            .fill(blockTitle.isEmpty ? Color.gray.opacity(0.5) : Color.blue.opacity(0.5))
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
                }
                .buttonStyle(.borderless)
                .disabled(blockTitle.isEmpty)
            }
            
            Spacer()
        }
        .padding(.bottom, 20)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .keyboard) {
                Button("Done") {
                    isTextFieldFocused = false
                }
            }
        }
        .ignoresSafeArea(.keyboard)
    }
}

//struct AddBlockView_Previews: PreviewProvider {
//    static var previews: some View {
//        // For preview purposes, we'll inject a dummy manager with sample blocks.
//        let dummyManager = WorkoutBlockManager()
//        dummyManager.blocks = [
//            WorkoutBlock(title: "Upper Body"),
//            WorkoutBlock(title: "Lower Body")
//        ]
//        return AddBlockView(blockManager: dummyManager)
//    }
//}

struct BlocksTabView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a dummy manager with sample blocks for the preview.
        let dummyManager = WorkoutBlockManager()
        dummyManager.blocks = [
//            WorkoutBlock(title: "Heavy"),
//            WorkoutBlock(title: "Moderate"),
//            WorkoutBlock(title: "Light")
        ]
        return BlocksTabView()
            .environmentObject(dummyManager)

    }
}

#Preview {
    NavigationView {
        MainMenuView()
            .environmentObject(WorkoutViewModel())
            .environmentObject(WorkoutBlockManager.withSampleData())
    }
}
