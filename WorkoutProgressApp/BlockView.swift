//
//  BlockView.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/27/25.
//

import SwiftUI



struct BlocksTabView: View {
    @EnvironmentObject var workoutViewModel: WorkoutViewModel

    @EnvironmentObject var blockManager: WorkoutBlockManager
    @State private var showAddBlockSheet = false
    @State private var isEditing = false
    
    @State private var currentPage: Int = 0
    
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
    
    // MARK: - Pages
    private var contentView: some View {
        GeometryReader { outer in
            TabView(selection: $currentPage) {

                // ── 0. Add‑Block card ────────────────────────────────
                addBlockCardView(outerGeometry: outer)
                    .tag(0)     // ← keep it first so a left‑swipe reveals it

                // ── 1…N. Real blocks ────────────────────────────────
                ForEach(Array(blockManager.blocks.enumerated()), id: \.1.id) { idx, block in
                    blockView(for: block)
                        .tag(idx + 1)              // pages: 1, 2, 3…
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .id(workoutViewModel.refreshTrigger)    // keep your refresh logic
            .onAppear {
                // Show first real block if it exists, else stay on add card
                currentPage = blockManager.blocks.isEmpty ? 0 : 1
            }
            // If user deletes their only block, snap back to add card
            .onChange(of: blockManager.blocks.count) { count in
                if count == 0 { currentPage = 0 }
            }
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
    let blockId: String
    
    // Keep the original block property for compatibility
    var block: WorkoutBlock
    
    // Use a computed property to always get the latest block data
    var currentBlock: WorkoutBlock {
        blockManager.blocks.first(where: { $0.id == blockId }) ??
        WorkoutBlock(title: "Missing Block", accentColorHex: "#1E88E5")
    }
    
    /// Toggles whether we show the "Delete" UI or the navigation link.
    @State private var isEditing = false
    
    /// State to control sheet presentation
    @State private var showReorderSheet = false
    
    /// A pre-calculated rotation angle if you still want the 3D effect in a TabView.
    let rotationAngle: Double
    
    // Callback for requesting to move a block
    var onRequestMoveBlock: ((WorkoutBlock) -> Void)?
    
    @State private var selectedColor: Color = .blue
    @State private var accentColor: Color
    @State private var showColorPicker = false
    
    init(
        block: WorkoutBlock,
        blockManager: WorkoutBlockManager? = nil,
        rotationAngle: Double = 0,
        onRequestMoveBlock: ((WorkoutBlock) -> Void)? = nil
    ) {
        self.block              = block
        self.blockId            = block.id
        self.rotationAngle      = rotationAngle
        self.onRequestMoveBlock = onRequestMoveBlock

        // Use the hex string, not the computed Color
        _accentColor   = State(initialValue: Color(hex: block.accentColorHex) ?? .blue)
        _selectedColor = State(initialValue: Color(hex: block.accentColorHex) ?? .blue)
    }

    
    var body: some View {
        let displayBlock = currentBlock
        let displayColor = displayBlock.accentColor
        ZStack {
            if isEditing {
                     // In editing mode, the entire card displays buttons
                BlockCustomRoundedRectangle(accentColor: displayColor)
                         .overlay(
                             VStack(spacing: 16) {
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
                                 
                                 Button(action: {
                          
                                     selectedColor = displayBlock.accentColor           // ✅ no hex‑to‑Color needed
                                     showColorPicker = true
                                   }) {
                                       Label("Change Color", systemImage: "paintpalette")
                                           .padding()
                                           .background(Color.white.opacity(0.2))
                                           .cornerRadius(10)
                                   }
                                 
                             }
                         )
                 } else {
                
                     NavigationLink(
                         destination:
                             BlockWorkoutsListView(blockTitle: block.title)
                             .navigationBarBackButtonHidden(true)
                             .trackNavigation("Block Workouts List View")
                     ) {
                         BlockCustomRoundedRectangle(accentColor: displayColor)
                             .overlay(
                                 Text(block.title)
                                     .font(.system(size: 28, weight: .medium))
                                     .foregroundColor(.white)
                                     .frame(width: 196)
                                     .lineLimit(3)
                                     .multilineTextAlignment(.center)
                                     .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 1)
                             )
                             .padding(.vertical, 8)
                             .padding(.horizontal, 2)
                     }
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
                            .foregroundColor(.white)
                            .padding(10)
                        
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
        .sheet(isPresented: $showColorPicker) {
            ColorPickerSheet(
                accentColor: $selectedColor,
                onDone: { newColor in
                    if let hex = newColor.toHex(),
                       hex != block.accentColorHex {
                        blockManager.updateColor(of: block, to: hex)
                    }
                }
            )
            .presentationDetents([.fraction(0.75)])
            .presentationDragIndicator(.visible)
        }
        .id("\(blockId)-\(currentBlock.accentColor)") // Ensure view refreshes when color changes


    }
}

// Theme colors - customize these to match your app's color scheme
var primaryColor = Color("NeomorphBG3")
var accentColor = Color("NeomorphBG3")
var backgroundColor = Color("NeomorphBG3")






struct BlockReorderSheet: View {
    // MARK: – Dependencies
    @ObservedObject var blockManager: WorkoutBlockManager
    @Binding var isPresented: Bool

    // MARK: – Local State
    @State private var reorderedBlocks: [WorkoutBlock]
    @State private var editMode: EditMode = .active

    // MARK: – Init
    init(blockManager: WorkoutBlockManager, isPresented: Binding<Bool>) {
        self.blockManager = blockManager
        self._isPresented = isPresented
        self._reorderedBlocks = State(initialValue: blockManager.blocks)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header bar with background color & thin divider
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.clear)
                        .frame(height: 8)
                    HStack {
                        Text("Reorder Blocks")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.leading, 8)
                        Spacer()
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color(red: 35/255, green: 36/255, blue: 49/255).opacity(0.95))
                .padding(.top, 10)

                // Scrollable reorderable list
                List {
                    ForEach(reorderedBlocks) { block in
                        HStack(spacing: 14) {
                            // Left glowing accent stripe
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color(hex: block.accentColorHex) ?? .blue)
                                .frame(width: 6, height: 38)
                            
                            // Block "card"
                            HStack(spacing: 12) {
                                Text(block.title)
                                    .font(.headline.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                // Subtle handle
                                Image(systemName: "line.horizontal.3")
                                    .foregroundColor(.gray.opacity(0.45))
                                    .padding(.trailing, 2)
                            }
                            .padding(.vertical, 18)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(red: 46/255, green: 46/255, blue: 58/255).opacity(0.97))
                                    .shadow(color: Color.black.opacity(0.17), radius: 8, x: 0, y: 4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color(hex: block.accentColorHex)?.opacity(0.18) ?? Color.clear, lineWidth: 2)
                                    )
                            )
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 2)
                    }
                    .onMove(perform: move)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(red: 35/255, green: 36/255, blue: 49/255).opacity(0.99))
                
                // Save button at the bottom, floating effect
                HStack(spacing: 18) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 46/255, green: 46/255, blue: 58/255).opacity(0.92))
                            .cornerRadius(18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    
                    Button(action: {
                        saveOrder()
                    }) {
                        Text("Save")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(18)
                    }
                }
                .padding(.top, 12)
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .background(Color(red: 35/255, green: 36/255, blue: 49/255).ignoresSafeArea())
        }
        .navigationViewStyle(.stack)
        .environment(\.editMode, $editMode)
    }

    // MARK: – Move Logic
    private func move(from source: IndexSet, to destination: Int) {
        reorderedBlocks.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: – Save
    private func saveOrder() {
        for (idx, var block) in reorderedBlocks.enumerated() {
            block.order = idx
        }
        blockManager.updateBlocksOrder(reorderedBlocks)
        isPresented = false
    }
}

// MARK: – Helper for hex colors
extension Color {
    init?(bex: String) {
        var hexSanitized = bex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255

        self.init(red: r, green: g, blue: b)
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

// For preview purposes (mock data)
//struct CustomBlockReorderSheet_Previews: PreviewProvider {
//    static var previews: some View {
//        // Mock data for preview
//        let mockManager = WorkoutBlockManager()
//        
//        return BlockReorderSheet(
//            blockManager: mockManager,
//            isPresented: .constant(true)
//        )
//        .preferredColorScheme(.light)
//    }
//}

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

//struct BlocksTabView_Previews: PreviewProvider {
//    static var previews: some View {
//        // Create a dummy manager with sample blocks for the preview.
//        let dummyManager = WorkoutBlockManager()
//        dummyManager.blocks = [
////            WorkoutBlock(title: "Heavy"),
////            WorkoutBlock(title: "Moderate"),
////            WorkoutBlock(title: "Light")
//        ]
//        return BlocksTabView()
//            .environmentObject(dummyManager)
//
//    }
//}

#Preview {
    NavigationView {
        MainMenuView()
            .environmentObject(WorkoutViewModel())
            .environmentObject(WorkoutBlockManager.withSampleData())
    }
}
