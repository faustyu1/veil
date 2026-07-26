import SwiftUI
import PhotosUI

/// Adds a subscription profile by URL. The fetch, the HWID headers and the
/// `Subscription-Userinfo` parsing are all shared with the desktop app.
struct SubscriptionView: View {
    @Environment(ServerStore.self) private var store
    @Environment(Loc.self) private var loc
    @Environment(\.dismiss) private var dismiss

    @State private var nameText = ""
    @State private var urlText = ""
    @State private var isLoading = false
    @State private var message: String?
    @State private var showScanner = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        // PhotosPicker's label builder is @Sendable, so the localized title has
        // to be resolved here rather than inside the closure.
        let fromImageTitle = loc("From image…")

        return NavigationStack {
            Form {
                Section(loc("Subscription")) {
                    TextField(loc("Name (optional)"), text: $nameText)
                        .autocorrectionDisabled()
                    TextField("https://example.com/sub", text: $urlText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
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
                }

                if let message {
                    Section {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(loc("Add Subscription"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button(loc("Fetch")) { Task { await fetch() } }
                            .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                QRScannerView { payload in
                    showScanner = false
                    urlText = payload.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await decode(item) }
            }
        }
    }

    private func decode(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let payload = QRCode.decode(from: image) else {
            message = loc("No QR code found in that image.")
            return
        }
        urlText = payload.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fetch() async {
        let url = urlText.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        isLoading = true
        message = nil
        defer { isLoading = false }

        let hwid = store.settings.sendHwid ? DeviceID.hwid : nil
        do {
            let result = try await SubscriptionFetcher.fetch(url, hwid: hwid)
            guard !result.servers.isEmpty else {
                message = loc("The subscription returned no servers.")
                return
            }
            let name = nameText.isEmpty
                ? (result.profileTitle ?? defaultName(from: url))
                : nameText
            store.addOrUpdateSubscription(name: name, url: url,
                                          servers: result.servers,
                                          userinfo: result.userinfo,
                                          announce: result.announce)
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }

    private func defaultName(from url: String) -> String {
        URL(string: url)?.host ?? loc("Subscription")
    }
}
