import SwiftUI

/// The small "i" next to a setting whose name does not explain it.
///
/// Settings pages drift into one of two failures: a bare switch nobody dares
/// touch, or a paragraph under every row that turns the page into an essay.
/// A hint is the middle — the row stays one line, and the explanation is one
/// click away for the person who needs it.
struct InfoHint: View {
    @Environment(Loc.self) private var loc

    let text: String
    @State private var shown = false

    init(_ text: String) { self.text = text }

    var body: some View {
        Button { shown.toggle() } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(shown ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .help(text)
        .accessibilityLabel(loc("What this means"))
        .popover(isPresented: $shown, arrowEdge: .bottom) {
            Text(text)
                .font(.callout)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 280, alignment: .leading)
                .padding(14)
        }
    }
}

/// A row label with its hint beside it: `Toggle(isOn:) { HintLabel(…) }`.
struct HintLabel: View {
    let title: String
    let hint: String

    init(_ title: String, _ hint: String) {
        self.title = title
        self.hint = hint
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            InfoHint(hint)
        }
    }
}
