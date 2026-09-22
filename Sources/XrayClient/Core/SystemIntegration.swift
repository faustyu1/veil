import Foundation
import UserNotifications

#if os(macOS)
import AppKit
import ServiceManagement

/// Whether Veil appears in the Dock and the ⌘-Tab switcher.
///
/// `.accessory` is the same thing `LSUIElement` buys at launch, except it can
/// be flipped while the app runs. An accessory app keeps its menu bar item and
/// can still show windows — it just stops owning a Dock tile, and stops being
/// the app whose menus sit at the top of the screen, so a window it opens has
/// to be raised explicitly.
@MainActor
enum DockIcon {

    /// Applies the policy. Showing the icon re-activates the app, otherwise
    /// the returning Dock tile belongs to an app that is not in front.
    static func setHidden(_ hidden: Bool) {
        let wanted: NSApplication.ActivationPolicy = hidden ? .accessory : .regular
        guard NSApp.activationPolicy() != wanted else { return }
        NSApp.setActivationPolicy(wanted)
        if !hidden { NSApp.activate(ignoringOtherApps: true) }
    }

    /// Raises the app's windows whatever the current policy is.
    ///
    /// Under `.accessory` `openWindow` alone leaves the window behind whatever
    /// the user was looking at, because the app never becomes frontmost on its
    /// own.
    static func activate() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

/// Manages the "launch at login" state via the modern SMAppService API
/// (macOS 13+). Registering adds the app as a login item; unregistering removes
/// it. Requires the app to be a real bundle (it is, via package-app.sh).
enum LoginItem {

    /// Whether the app is currently registered to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Applies the desired state. Returns true on success. Failures are silent
    /// (e.g. when running an unbundled `swift run` binary, where SMAppService
    /// has nothing to register).
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            return false
        }
    }
}
#endif

/// Thin wrapper around UNUserNotificationCenter for connection status alerts.
@MainActor
enum NotificationManager {

    /// Asks the user for permission (no-op if already decided).
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in }
    }

    /// Posts a local notification. Silently does nothing if not authorized.
    static func notify(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
