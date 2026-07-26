import SwiftUI

/// Shows a server as a QR code so it can be moved to another device, plus the
/// raw share link for copy/paste.
struct QRDisplayView: View {
    @Environment(Loc.self) private var loc
    @Environment(\.dismiss) private var dismiss

    let server: ProxyConfig

    private var link: String { LinkBuilder.link(for: server) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let image = QRCode.image(from: link, size: 260) {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 260, height: 260)
                            .padding(12)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        Text(loc("Could not render a QR code for this server."))
                            .foregroundStyle(.secondary)
                    }

                    Text(link)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.secondary.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 10))

                    HStack {
                        Button {
                            UIPasteboard.general.string = link
                        } label: {
                            Label(loc("Copy link"), systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        ShareLink(item: link) {
                            Label(loc("Share"), systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationTitle(server.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("Done")) { dismiss() }
                }
            }
        }
    }
}
