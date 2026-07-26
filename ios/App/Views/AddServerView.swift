import SwiftUI
import PhotosUI

/// Paste one or more share links, scan a QR code, or pick a QR image from the
/// photo library. Parsing is the same `LinkParser` the desktop app uses.
struct AddServerView: View {
    @Environment(ServerStore.self) private var store
    @Environment(Loc.self) private var loc
    @Environment(\.dismiss) private var dismiss

    @State private var linkText = ""
    @State private var errorMessage: String?
    @State private var showScanner = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        // PhotosPicker's label builder is @Sendable, so the localized title has
        // to be resolved here rather than inside the closure.
        let fromImageTitle = loc("From image…")

        return NavigationStack {
            Form {
                Section {
                    TextEditor(text: $linkText)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 140)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text(loc("One link per line"))
                } footer: {
                    Text("vless:// · vmess:// · trojan:// · ss:// · wireguard://")
                        .font(.caption2)
                }

                Section {
                    Button {
                        showScanner = true
                    } label: {
                        Label(loc("Scan camera"), systemImage: "qrcode.viewfinder")
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(fromImageTitle, systemImage: "photo")
                    }
                    Button {
                        if let clipboard = UIPasteboard.general.string {
                            append(clipboard)
                        }
                    } label: {
                        Label(loc("Paste from clipboard"), systemImage: "doc.on.clipboard")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle(loc("Add Link"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("Add")) { addServers() }
                        .disabled(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showScanner) {
                QRScannerView { payload in
                    showScanner = false
                    append(payload)
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await decode(item) }
            }
        }
    }

    private func append(_ payload: String) {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        linkText += linkText.isEmpty ? trimmed : "\n" + trimmed
    }

    private func decode(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = loc("Could not read that image.")
            return
        }
        guard let payload = QRCode.decode(from: image) else {
            errorMessage = loc("No QR code found in that image.")
            return
        }
        append(payload)
    }

    private func addServers() {
        let text = linkText.trimmingCharacters(in: .whitespacesAndNewlines)

        // A pasted wg-quick profile isn't a share link — detect it first.
        if text.lowercased().contains("[interface]"),
           let wg = LinkParser.parseWireGuardConf(text) {
            store.addManualServers([wg])
            dismiss()
            return
        }

        let servers = BalancerGrouper.group(LinkParser.parseMany(text))
        guard !servers.isEmpty else {
            errorMessage = loc("No valid links found.")
            return
        }
        store.addManualServers(servers)
        dismiss()
    }
}
