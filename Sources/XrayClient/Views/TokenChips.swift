import SwiftUI

/// Lays children out left to right, wrapping to a new line when the row is full.
///
/// Rule matchers are lists of short strings — application names, domains, ports.
/// A `VStack` wastes the whole width on each of them and an `HStack` runs off
/// the edge, so the chips wrap.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews, width: width)
        let height = rows.reduce(0) { $0 + $1.height } +
            CGFloat(max(0, rows.count - 1)) * spacing
        let widest = rows.map(\.width).max() ?? 0
        return CGSize(width: min(width, max(widest, 1)), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(index)
                current.width = needed
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// A removable list of short strings, with a free-text field to add more.
///
/// Typing is the fallback, not the main path: a value that is hard to remember
/// exactly — an executable name, a rule-set tag — should arrive from a picker,
/// and `accessory` is where that picker's button goes.
struct TokenChips<Accessory: View>: View {
    @Binding var values: [String]
    var placeholder: String = ""
    var monospaced: Bool = false
    var onChange: () -> Void = {}
    @ViewBuilder var accessory: () -> Accessory

    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !values.isEmpty {
                FlowLayout {
                    ForEach(values, id: \.self) { value in
                        chip(value)
                    }
                }
            }
            HStack(spacing: 6) {
                TextField(placeholder, text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
                    .onSubmit(commitDraft)
                accessory()
            }
        }
    }

    private func chip(_ value: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(monospaced ? .system(.caption2, design: .monospaced) : .caption2)
                .lineLimit(1)
            Button {
                // Remove by value, not by the binding being read mid-mutation:
                // reading `$values` inside `removeAll` trips exclusive access.
                values.removeAll { $0 == value }
                onChange()
            } label: {
                Image(systemName: "xmark.circle.fill").font(.caption2)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Color.secondary.opacity(0.15), in: Capsule())
    }

    /// Accepts a comma- or space-separated paste as several chips at once.
    private func commitDraft() {
        let parts = draft
            .split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == " " })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !values.contains($0) }
        guard !parts.isEmpty else { draft = ""; return }
        values.append(contentsOf: parts)
        draft = ""
        onChange()
    }
}

extension TokenChips where Accessory == EmptyView {
    init(values: Binding<[String]>, placeholder: String = "",
         monospaced: Bool = false, onChange: @escaping () -> Void = {}) {
        self.init(values: values, placeholder: placeholder,
                  monospaced: monospaced, onChange: onChange) { EmptyView() }
    }
}
