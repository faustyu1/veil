import SwiftUI
import AppKit

@main
struct XrayClientApp: App {
    @State private var store = ServerStore()
    @State private var connection = ConnectionManager()
    @State private var pinger = PingTester()
    @State private var loc = Loc()
    @State private var control = ControlServer()
    @State private var updater = UpdateChecker()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Veil", id: WindowID.main) {
            ContentView()
                .veilEnvironment(store: store, connection: connection,
                                 pinger: pinger, loc: loc, control: control,
                                 updater: updater)
                .frame(minWidth: 760, minHeight: 520)
                .onAppear { startUp() }
        }
        .windowResizability(.contentSize)
        .commands {
            VeilCommands(loc: loc, updater: updater)
        }

        // Settings is a window of its own rather than a sheet: a long form no
        // longer hangs off the edges of a main window the user made small.
        //
        // It is a `Window` and not the `Settings` scene because that scene
        // insists on a title row of its own above the toolbar, which pushed the
        // tab switcher onto a second line. ⌘, is wired up in `VeilCommands`.
        Window(loc("Settings"), id: WindowID.settings) {
            SettingsView()
                .veilEnvironment(store: store, connection: connection,
                                 pinger: pinger, loc: loc, control: control,
                                 updater: updater)
        }
        .defaultSize(width: 620, height: 640)

        Window(loc("Routing"), id: WindowID.routing) {
            RoutingSheet()
                .veilEnvironment(store: store, connection: connection,
                                 pinger: pinger, loc: loc, control: control,
                                 updater: updater)
        }
        .defaultSize(width: 780, height: 700)

        Window(loc("About Veil"), id: WindowID.about) {
            AboutWindow()
                .veilEnvironment(store: store, connection: connection,
                                 pinger: pinger, loc: loc, control: control,
                                 updater: updater)
        }
        .windowResizability(.contentSize)

        Window(loc("Software Update"), id: WindowID.update) {
            UpdateWindow()
                .veilEnvironment(store: store, connection: connection,
                                 pinger: pinger, loc: loc, control: control,
                                 updater: updater)
        }
        .windowResizability(.contentSize)

        // Menu bar control: switch servers / disconnect without opening the window.
        MenuBarExtra {
            MenuBarContent()
                .environment(store)
                .environment(connection)
                .environment(loc)
        } label: {
            Image(systemName: connection.isConnected ? "shield.lefthalf.filled" : "shield.slash")
        }
        .menuBarExtraStyle(.menu)
    }

    /// Everything that has to happen once, when the main window first appears.
    private func startUp() {
        loc.language = store.settings.language
        connection.bind(store)
        control.onLog = { [weak connection] line in
            connection?.appendLog(line)
        }
        control.sync(settings: store.settings, store: store, connection: connection)
        appDelegate.closeToTray = store.settings.closeToTray
        appDelegate.connection = connection
        // Keep the login-item registration in sync with the setting.
        LoginItem.setEnabled(store.settings.launchAtLogin)
        if store.settings.notifyOnConnect {
            NotificationManager.requestAuthorization()
        }
        // Recover from a previous crash/force-quit that left the tunnel routes
        // in place (which kills internet).
        TunManager.emergencyCleanup()
        Task { await SubscriptionService.refreshDue(store) }
        // Warm the process catalog so the control API's /v1/apps has data
        // before the picker is ever opened.
        Task { await ProcessCatalog.shared.reload() }
        // Auto-download geo .dat files if the active preset needs them and
        // they're missing (first launch).
        if store.settings.routingPreset.needsGeoAssets,
           !GeoAssetManager.shared.hasAssets {
            Task {
                await GeoAssetManager.shared.download(
                    source: store.settings.geoSource,
                    customGeoip: store.settings.customGeoipURL,
                    customGeosite: store.settings.customGeositeURL)
            }
        }
        // Keep the community rule lists fresh in the background.
        Task { await CommunityListManager.shared.refreshDue(store.settings) }
        updater.checkInBackgroundIfDue()
        // Auto-connect to the last server on launch, if enabled.
        if store.settings.autoConnectOnLaunch,
           let server = store.server(withID: store.selectedServerID) {
            connection.connect(to: server)
        }
    }
}

/// Injects the app-wide observable objects and the appearance/writing-direction
/// settings every window needs, so a new window is one modifier away from
/// behaving like the main one.
private struct VeilEnvironment: ViewModifier {
    let store: ServerStore
    let connection: ConnectionManager
    let pinger: PingTester
    let loc: Loc
    let control: ControlServer
    let updater: UpdateChecker

    func body(content: Content) -> some View {
        content
            .environment(store)
            .environment(connection)
            .environment(pinger)
            .environment(loc)
            .environment(control)
            .environment(updater)
            .preferredColorScheme(colorScheme)
            .environment(\.layoutDirection, loc.isRTL ? .rightToLeft : .leftToRight)
    }

    private var colorScheme: ColorScheme? {
        switch store.settings.appearance {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

extension View {
    func veilEnvironment(store: ServerStore, connection: ConnectionManager,
                         pinger: PingTester, loc: Loc, control: ControlServer,
                         updater: UpdateChecker) -> some View {
        modifier(VeilEnvironment(store: store, connection: connection,
                                 pinger: pinger, loc: loc, control: control,
                                 updater: updater))
    }
}

/// The application menu: About, Check for Updates, Settings.
///
/// The standard About panel is replaced so the version, the build and the
/// project links sit together; everything else in the menu is AppKit's own.
private struct VeilCommands: Commands {
    let loc: Loc
    let updater: UpdateChecker
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(loc("Settings…")) { openWindow(id: WindowID.settings) }
                .keyboardShortcut(",", modifiers: .command)
        }
        CommandGroup(replacing: .appInfo) {
            Button(loc("About Veil")) { openWindow(id: WindowID.about) }
            Button(loc("Check for Updates…")) {
                Task {
                    await UpdateAlert.runUserCheck(updater, loc: loc) {
                        openWindow(id: WindowID.update)
                    }
                }
            }
        }
        CommandGroup(after: .toolbar) {
            Button(loc("Routing…")) { openWindow(id: WindowID.routing) }
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}

/// Handles "close to tray" and clean shutdown of the tunnel on quit so the
/// network is never left routed through a dead tun2socks.
final class AppDelegate: NSObject, NSApplicationDelegate {
    var closeToTray = true
    weak var connection: ConnectionManager?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in the menu bar when close-to-tray is enabled.
        return !closeToTray
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Always restore routes/proxy on quit, even if the user force-quits the
        // window, so the machine isn't left without internet.
        connection?.disconnect()
        // Belt-and-suspenders: ensure any orphaned tunnel is torn down.
        TunManager.emergencyCleanup()
    }
}
