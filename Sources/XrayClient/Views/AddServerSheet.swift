import SwiftUI

/// Sheet for adding one or more servers by pasting share links (into Manual group).
struct AddServerSheet: View {
    @Environment(ServerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var linkText = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Server(s)").font(.title2).bold()
            Text("Paste one or more links (vless://, vmess://, trojan://, ss://). One per line.")
                .font(.caption).foregroundStyle(.secondary)

            TextEditor(text: $linkText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.3)))

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") { addServers() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding().frame(width: 480)
    }

    private func addServers() {
        let parsed = LinkParser.parseMany(linkText)
        guard !parsed.isEmpty else {
            errorMessage = "No valid links found. Check the format."
            return
        }
        store.addManualServers(parsed)
        dismiss()
    }
}

/// Sheet for importing a subscription URL as a new profile.
struct SubscriptionSheet: View {
    @Environment(ServerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var nameText = ""
    @State private var urlText = ""
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Subscription").font(.title2).bold()
            Text("Each subscription becomes its own profile group.")
                .font(.caption).foregroundStyle(.secondary)

            TextField("Name (optional)", text: $nameText)
                .textFieldStyle(.roundedBorder)
            TextField("https://example.com/sub", text: $urlText)
                .textFieldStyle(.roundedBorder)

            if let message {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                if isLoading { ProgressView().controlSize(.small) }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Fetch") { Task { await fetch() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(urlText.isEmpty || isLoading)
            }
        }
        .padding().frame(width: 480)
    }

    private func fetch() async {
        isLoading = true
        message = "Fetching…"
        defer { isLoading = false }
        do {
            let result = try await SubscriptionFetcher.fetch(urlText)
            guard !result.servers.isEmpty else {
                message = "Subscription returned no valid servers."
                return
            }
            let name = nameText.isEmpty
                ? (result.profileTitle ?? defaultName(from: urlText))
                : nameText
            store.addOrUpdateSubscription(name: name, url: urlText,
                                          servers: result.servers,
                                          userinfo: result.userinfo,
                                          announce: result.announce)
            dismiss()
        } catch {
            message = "Error: \(error.localizedDescription)"
        }
    }

    private func defaultName(from url: String) -> String {
        URL(string: url)?.host ?? "Subscription"
    }
}
