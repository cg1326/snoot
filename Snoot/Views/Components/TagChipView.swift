import SwiftUI

// MARK: - Flow layout for wrapping chip grids
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                y += rowH + spacing; x = 0; rowH = 0
            }
            rowH = max(rowH, size.height)
            x += size.width + spacing
        }
        return CGSize(width: maxWidth, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowH + spacing; x = bounds.minX; rowH = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            rowH = max(rowH, size.height)
            x += size.width + spacing
        }
    }
}

struct TagChipView: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.snootOrange : Color.snootDivider)
                .foregroundColor(isSelected ? .white : .snootText2)
                .clipShape(RoundedRectangle(cornerRadius: SnootRadius.small))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct TagChipGrid: View {
    let options: [String]
    @Binding var selected: Set<String>
    var customTag: Binding<String>? = nil
    var onAddCustom: (() -> Void)? = nil

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { tag in
                TagChipView(
                    tag: tag,
                    isSelected: selected.contains(tag)
                ) {
                    if selected.contains(tag) { selected.remove(tag) }
                    else { selected.insert(tag) }
                }
            }
            ForEach(selected.filter { !options.contains($0) }.sorted(), id: \.self) { tag in
                TagChipView(tag: tag, isSelected: true) {
                    selected.remove(tag)
                }
            }
        }

        if let customTag, let onAddCustom {
            HStack(spacing: 8) {
                HighContrastTextField(placeholder: "Add custom…", text: customTag)
                    .font(.system(size: 14))
                    .foregroundColor(.snootText1)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.snootDivider)
                    .clipShape(RoundedRectangle(cornerRadius: SnootRadius.small))
                    .submitLabel(.done)
                    .onSubmit { onAddCustom() }
                if !customTag.wrappedValue.isEmpty {
                    Button(action: onAddCustom) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.snootOrange)
                            .font(.title3)
                    }
                }
            }
            .padding(.top, 6)
        }
    }
}
