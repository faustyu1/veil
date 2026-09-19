import SwiftUI
import AppKit

/// The window Veil shows when a newer release is published.
///
/// It is the whole update conversation in one place: what changed, whether to
/// take it now, and whether to keep asking. Nothing here downloads anything
/// until a button is pressed.
///
/// Each phase sizes its own window — the offer needs room for release notes,
/// while "you're up to date" is two lines and two buttons and looks abandoned
/// in a large frame. The scene is `.windowResizability(.contentSize)`, so the
/// frame set here is the window the user sees.
struct UpdateWindow: View {
    @Environment(UpdateChecker.self) private var updater
    @Environment(Loc.self) private var loc
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content
            .windowTitle(windowTitle)
    }

    @ViewBuilder
    private var content: some View {
        switch updater.phase {
        case .available(let release):
            offer(release, staged: false)
        case .readyToInstall(let release):
            offer(release, staged: true)
        case .downloading(let progress):
            downloading(progress)
        case .checking:
            compact {
                HStack(spacing: 14) {
                    ProgressView().controlSize(.small)
                    Text(loc("Checking for updates…")).font(.callout)
                }
            }
        case .upToDate:
            upToDate
        case .installFailed(let reason):
            compact {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 30)).foregroundStyle(.orange)
                    Text(loc("Could not install the update")).font(.headline)
                    Text(String(format: loc("Veil is still running %@."),
                                AppVersion.current))
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(reason)
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(loc("Show Log")) {
                        NSWorkspace.shared.selectFile(
                            UpdateInstaller.logPath,
                            inFileViewerRootedAtPath: "")
                    }
                    .glassButton()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    Button(loc("Close")) { close() }
                        .glassProminentButton()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: 380)
        case .failed(let message):
            compact {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 30)).foregroundStyle(.orange)
                    Text(loc("Could not check for updates")).font(.headline)
                    Text(message).font(.callout).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(loc("Try again")) {
                        Task { await updater.check(userInitiated: true) }
                    }
                    .glassProminentButton()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    Button(loc("Close")) { close() }
                        .glassButton()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                }
            }
        case .idle:
            compact {
                VStack(alignment: .leading, spacing: 10) {
                    Text(loc("No update in progress.")).font(.callout)
                        .foregroundStyle(.secondary)
                    Button(loc("Check now")) {
                        Task { await updater.check(userInitiated: true) }
                    }
                    .glassProminentButton()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var windowTitle: String {
        switch updater.phase {
        case .downloading: return String(format: loc("Updating %@"), "Veil")
        default: return loc("Software Update")
        }
    }

    // MARK: - Nothing to do

    /// Icon, verdict, version, and a way to read what shipped before now.
    private var upToDate: some View {
        compact {
            VStack(alignment: .leading, spacing: 0) {
                appIcon(size: 52)
                Spacer(minLength: 20)
                Text(loc("You're up to date!"))
                    .font(.headline)
                Text(String(format: loc("Veil %@ is currently the newest version available."),
                            AppVersion.current))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                Spacer(minLength: 20)
                Button(loc("OK")) { close() }
                    .glassProminentButton()
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .frame(maxWidth: .infinity)
                Button(loc("Version History")) {
                    NSWorkspace.shared.open(UpdateChecker.releasesURL)
                }
                .glassButton()
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
        }
        .frame(width: 300)
    }

    // MARK: - The offer

    @ViewBuilder
    private func offer(_ release: UpdateChecker.Release, staged: Bool) -> some View {
        @Bindable var updater = updater
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                appIcon(size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc("A new version of Veil is available!"))
                        .font(.headline)
                    Text(verbatim: versionLine(release))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            notes(release)

            Toggle(loc("Automatically download and install updates in the future"),
                   isOn: $updater.automaticallyInstalls)
                .toggleStyle(.checkbox)
                .font(.callout)

            HStack {
                Button(loc("Skip This Version")) {
                    updater.skipPending(); close()
                }
                .glassButton()
                Spacer()
                Button(loc("Remind Me Later")) {
                    updater.remindLater(); close()
                }
                .glassButton()
                Button(staged ? loc("Install and Restart") : loc("Install Update")) {
                    if staged {
                        updater.install()
                    } else {
                        Task { await updater.download() }
                    }
                }
                .glassProminentButton()
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 560, height: 470)
    }

    private func versionLine(_ release: UpdateChecker.Release) -> String {
        let template = loc("Veil %@ is now available — you have %@. Would you like to download it now?")
        return String(format: template, release.version, AppVersion.current)
    }

    private func notes(_ release: UpdateChecker.Release) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: "\(loc("What's New in Veil")) \(release.version)")
                    .font(.title3).bold()
                Text(markdown(release.notes))
                    .font(.callout)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Link(loc("View full changelog"), destination: release.pageURL)
                    .font(.callout)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .updateNotesBackground()
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
    }

    /// Release bodies are Markdown as published on GitHub; anything the parser
    /// rejects is shown as written rather than dropped.
    private func markdown(_ source: String) -> AttributedString {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return AttributedString(loc("No release notes.")) }
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options))
            ?? AttributedString(text)
    }

    // MARK: - Download in progress

    /// Icon, bar, and how many megabytes of how many — a download with no
    /// numbers on it is indistinguishable from one that has stalled.
    private func downloading(_ progress: UpdateChecker.DownloadProgress) -> some View {
        compact {
            HStack(alignment: .top, spacing: 16) {
                appIcon(size: 52)
                VStack(alignment: .leading, spacing: 10) {
                    Text(loc("Downloading update…"))
                        .font(.headline)
                    if let fraction = progress.fraction {
                        ProgressView(value: fraction)
                    } else {
                        ProgressView().progressViewStyle(.linear)
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(byteLine(progress))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            // A byte count that climbs says the transfer is
                            // alive; a rate says whether it is worth waiting
                            // for. The row is kept even while the rate is
                            // still unknown, so the dialog does not resize a
                            // second after it opens.
                            Text(rateLine(progress))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Spacer(minLength: 16)
                        Button(loc("Cancel")) { updater.cancelDownload() }
                            .glassButton()
                            .controlSize(.large)
                    }
                }
            }
        }
        .frame(width: 470)
    }

    private func byteLine(_ progress: UpdateChecker.DownloadProgress) -> String {
        let received = progress.received.formatted(.byteCount(style: .file))
        guard progress.total > 0 else { return received }
        let total = progress.total.formatted(.byteCount(style: .file))
        return String(format: loc("%@ of %@"), received, total)
    }

    /// Speed, and how much longer at that speed. Empty — but present — until
    /// there have been enough readings to mean anything.
    private func rateLine(_ progress: UpdateChecker.DownloadProgress) -> String {
        guard let rate = progress.bytesPerSecond, rate > 0 else { return " " }
        let speed = Int64(rate).formatted(.byteCount(style: .file)) + "/s"
        guard let seconds = progress.secondsRemaining, seconds.isFinite else {
            return speed
        }
        let left = Duration.seconds(max(1, Int(seconds.rounded())))
            .formatted(.units(allowed: [.hours, .minutes, .seconds],
                              width: .narrow, maximumUnitCount: 2))
        return speed + " · " + String(format: loc("%@ left"), left)
    }

    // MARK: - Pieces

    private func appIcon(size: CGFloat) -> some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable().frame(width: size, height: size)
    }

    /// The small-dialog frame: content decides the height, padding is uniform.
    private func compact<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
    }

    private func close() {
        updater.dismiss()
        dismiss()
    }
}

extension View {
    /// Material behind the release notes on macOS 26+, plain background before.
    @ViewBuilder
    func updateNotesBackground() -> some View {
        if #available(macOS 26.0, *) {
            self.background(.regularMaterial)
        } else {
            self.background(Color(nsColor: .textBackgroundColor))
        }
    }
}
