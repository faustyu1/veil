import SwiftUI
import AppKit

/// The About box. Replaces the standard AppKit panel so the version, the build
/// and the links people actually follow sit in one small window.
struct AboutWindow: View {
    @Environment(Loc.self) private var loc

    private var build: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "—"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable().frame(width: 96, height: 96)
                .padding(.top, 18)

            Text(verbatim: "Veil").font(.title2).bold()

            Text(verbatim: "\(loc("Version")) \(AppVersion.current) (\(build))")
                .font(.callout).foregroundStyle(.secondary)

            HStack(spacing: 10) {
                link(loc("GitHub"), "https://github.com/\(UpdateChecker.repository)")
                separator
                link(loc("Donate"), "https://github.com/\(UpdateChecker.repository)/blob/main/README.md#why-there-is-no-ios-build-to-download-yet")
                separator
                link(loc("Changelog"), "https://github.com/\(UpdateChecker.repository)/blob/main/CHANGELOG.md")
                separator
                link(loc("Report an issue"), "https://github.com/\(UpdateChecker.repository)/issues")
            }
            .font(.callout)
            .padding(.top, 2)

            Text(verbatim: "MIT · Xray-core · sing-box")
                .font(.caption2).foregroundStyle(.tertiary)
                .padding(.bottom, 18)
        }
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var separator: some View {
        Text(verbatim: "|").foregroundStyle(.tertiary)
    }

    private func link(_ title: String, _ url: String) -> some View {
        Link(title, destination: URL(string: url)!)
    }
}
