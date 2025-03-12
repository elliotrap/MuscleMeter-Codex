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

    /// Toggles whether we’re showing the “delete” UI or the normal title.
    @State private var isEditing = false
    

    // Simplified rotation angle calculation with caching potential
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
                  Text("No blocks available")
                      .font(.headline)
                      .foregroundColor(.gray)
                      .padding()
                      .frame(height: 340)
              } else {
                  GeometryReader { outerGeometry in
                      TabView {
                          ForEach(blockManager.blocks) { block in
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
                      .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                      
                  }
                  .frame(width: 400, height: 400)
              }
            
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                .fill(Color.gray.opacity(0.12))
                .frame(maxWidth: 500)
                .frame(height: 60)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                
            Button(action: {
                showAddBlockSheet = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                    
                    Text("Add Block")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                        .underline(false)
                        
                }
                .padding(.horizontal, 100)
                .padding(.vertical, 12)
                .background(
 
                        RoundedRectangle(cornerRadius: 17)
                            .fill(Color.green.opacity(0.5))

                )
                .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
            }
            .buttonStyle(.borderless)
                
      
            }
            .padding(16)
            .offset(x: 0, y: 5)
        }
        
        .navigationTitle("Blocks")
        .sheet(isPresented: $showAddBlockSheet) {
            AddBlockView(blockManager: blockManager)
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            blockManager.fetchBlocks()
        }
    }
}


struct BlockCardView: View {
    @EnvironmentObject var blockManager: WorkoutBlockManager
    let block: WorkoutBlock
    
    /// Toggles whether we show the "Delete" UI or the navigation link.
    @State private var isEditing = false
    
    /// A pre-calculated rotation angle if you still want the 3D effect in a TabView.
    let rotationAngle: Double
    
    init(block: WorkoutBlock, blockManager: WorkoutBlockManager, rotationAngle: Double = 0) {
        self.block = block
        self.rotationAngle = rotationAngle
    }
    
    var body: some View {
        ZStack {
            if isEditing {
                // In editing mode, the entire card displays a "Delete Block" button.
                BlockCustomRoundedRectangle()
                    .overlay(
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
                    )
                 
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

struct AddBlockView_Previews: PreviewProvider {
    static var previews: some View {
        // For preview purposes, we'll inject a dummy manager with sample blocks.
        let dummyManager = WorkoutBlockManager()
        dummyManager.blocks = [
            WorkoutBlock(title: "Upper Body"),
            WorkoutBlock(title: "Lower Body")
        ]
        return AddBlockView(blockManager: dummyManager)
    }
}

//struct BlocksTabView_Previews: PreviewProvider {
//    static var previews: some View {
//        // Create a dummy manager with sample blocks for the preview.
//        let dummyManager = WorkoutBlockManager()
//        dummyManager.blocks = [
//            WorkoutBlock(title: "Heavy"),
//            WorkoutBlock(title: "Moderate"),
//            WorkoutBlock(title: "Light")
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
