import SwiftUI

struct SquareCropView: View {
    let image: UIImage
    var onCrop: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let maskSize: CGFloat = UIScreen.main.bounds.width - 40

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )

                    // Square mask
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .mask(
                            ZStack {
                                Rectangle()
                                Rectangle()
                                    .frame(width: maskSize, height: maskSize)
                                    .blendMode(.destinationOut)
                            }
                        )
                    
                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: maskSize, height: maskSize)
                }
                .frame(width: maskSize, height: maskSize)
                .clipped()
                
                Spacer()
                
                Text("Pinch to zoom · Drag to position")
                    .font(.system(size: 14))
                    .foregroundColor(.snootText2)
                    .padding(.bottom, 40)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Crop Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        crop()
                    }
                    .foregroundColor(.white)
                    .font(.headline)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    @MainActor
    private func crop() {
        let renderer = ImageRenderer(content: 
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: maskSize, height: maskSize)
                .clipped()
        )
        
        // We want a high quality render
        renderer.scale = 3.0 
        
        if let uiImage = renderer.uiImage {
            if let data = uiImage.jpegData(compressionQuality: 0.8) {
                onCrop(data)
                dismiss()
            }
        }
    }
}
