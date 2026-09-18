import AppKit

/// Reports the outcome of a check the user asked for.
///
/// "Nothing to do" is an answer, not a screen: macOS apps say it in a standard
/// alert and get out of the way. A window of our own is only opened when there
/// is a release to read about and decide on.
@MainActor
enum UpdateAlert {

    /// Checks, then either shows the alert or hands over to `showWindow`.
    static func runUserCheck(_ updater: UpdateChecker,
                             loc: Loc,
                             showWindow: @escaping () -> Void) async {
        while true {
            await updater.check(userInitiated: true)
            switch updater.phase {
            case .upToDate:
                updater.dismiss()
                upToDate(loc: loc)
                return
            case .failed(let message):
                updater.dismiss()
                guard retryAfterFailure(message, loc: loc) else { return }
            default:
                showWindow()
                return
            }
        }
    }

    /// "You're up to date!", with a way to read what changed in past releases.
    static func upToDate(loc: Loc) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.icon = NSApplication.shared.applicationIconImage
        alert.messageText = loc("You're up to date!")
        alert.informativeText = String(
            format: loc("Veil %@ is currently the newest version available."),
            AppVersion.current)
        alert.addButton(withTitle: loc("OK"))
        alert.addButton(withTitle: loc("Version History"))
        if alert.runModal() == .alertSecondButtonReturn {
            NSWorkspace.shared.open(UpdateChecker.releasesURL)
        }
    }

    /// True when the user wants the check run again.
    static func retryAfterFailure(_ message: String, loc: Loc) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.icon = NSApplication.shared.applicationIconImage
        alert.messageText = loc("Could not check for updates")
        alert.informativeText = message
        alert.addButton(withTitle: loc("Try again"))
        alert.addButton(withTitle: loc("Close"))
        return alert.runModal() == .alertFirstButtonReturn
    }
}
