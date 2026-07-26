import SwiftUI

/// Tail of the Xray log. The core runs in the extension, so the log is a file
/// in the shared container that the provider ships back a chunk at a time.
struct LogView: View {
    @Environment(TunnelController.self) private var tunnel
    @Environment(Loc.self) private var loc
    @Environment(\.dismiss) private var dismiss

    private var text: String {
        tunnel.logs.isEmpty ? loc("No logs yet.") : tunnel.logs
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(text)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(tunnel.logs.isEmpty ? Color.secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(12)
                        .id("bottom")
                }
                .onChange(of: tunnel.logs) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
            .navigationTitle(loc("Log"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("Done")) { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = tunnel.logs
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .disabled(tunnel.logs.isEmpty)

                    Button {
                        tunnel.clearLogs()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(tunnel.logs.isEmpty)
                }
            }
            .task {
                // Keep the tail fresh while this screen is open even when the
                // list view's poll loop isn't running.
                while !Task.isCancelled {
                    await tunnel.refreshStatus()
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
    }
}
