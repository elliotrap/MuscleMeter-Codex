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
        VStack {
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
                  .frame(height: 360)
              }
            
            // Button to add a new block
            Button(action: {
                showAddBlockSheet = true
            }) {
                Text("Add Block")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color("NeomorphBG2").opacity(1),
                                Color("NeomorphBG2").opacity(0.5)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
        }
        
        .navigationTitle("Blocks")
        .sheet(isPresented: $showAddBlockSheet) {
            AddBlockView(blockManager: blockManager)
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
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.blue)
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
                            }
                        )
                }                // Use a plain button style so the entire rectangle is clickable.
                .buttonStyle(.plain)
            }
            
            // Gear icon in the top-right corner
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            isEditing.toggle()
                        }
                    }) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.white)
                            .padding(10)
                    }
                }
                Spacer()
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
    var blockManager: WorkoutBlockManager

    var body: some View {
            VStack(spacing: 20) {
                TextField("Enter block name", text: $blockTitle)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                Button(action: {
                    // Only save if the title isn't empty.
                    if !blockTitle.isEmpty {
                        blockManager.addBlock(title: blockTitle)
                        dismiss()
                    }
                }) {
                    Text("Save Block")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(blockTitle.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(10)
                }
                .disabled(blockTitle.isEmpty)
                
                Spacer()
            }
            .navigationBarTitle("New Block", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
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
            WorkoutBlock(title: "Heavy"),
            WorkoutBlock(title: "Moderate"),
            WorkoutBlock(title: "Light")
        ]
        return BlocksTabView()
            .environmentObject(dummyManager)

    }
}

//#Preview {
//    MainMenuView()
//}
