import SwiftUI
import AppKit

/// App settings: tunnel mode, appearance, updates, routing, ports, privacy.
///
/// This is a window of its own rather than a sheet. A sheet is sized by its
/// content and happily grows past the edges of the window it is attached to,
/// which is exactly what a long settings form does; a window is resizable,
/// scrolls, and remembers where it was.
struct SettingsView: View {
    @Environment(ServerStore.self) private var store
    @Environment(ConnectionManager.self) private var connection
    @Environment(UpdateChecker.self) private var updater
    @Environment(Loc.self) private var loc
    @Environment(\.openWindow) private var openWindow

    // Asking the helper whether it is there is an XPC round trip, so the view
    // starts pessimistic and refreshes off the main thread.
    @State private var helperInstalled = false
    /// Files are in place but the daemon refuses this build: the client is
    /// pinned by code hash, and that hash changes on every app update.
    @State private var helperStale = false
    @State private var helperBusy = false
    @State private var helperError: String?
    @State private var diagnosticsCopied = false
    @State private var hwidCopied = false
    /// The identifier on screen. `DeviceID` is a static store SwiftUI cannot
    /// observe, so the view keeps its own copy and updates it on every change.
    @State private var hwid = DeviceID.hwid
    /// What is typed into the manual field, empty unless it is being edited.
    @State private var hwidDraft = ""

    /// Sections, one per toolbar tab. A single scrolling form of everything is
    /// what made this window taller than the screen in the first place.
    private enum Tab: String, CaseIterable, Identifiable {
        case general, tunnel, routing, subscriptions, advanced
        var id: String { rawValue }

        var title: String {
            switch self {
            case .general:       return "General"
            case .tunnel:        return "Tunnel"
            case .routing:       return "Routing"
            case .subscriptions: return "Subscriptions"
            case .advanced:      return "Advanced"
            }
        }

        var icon: String {
            switch self {
            case .general:       return "gearshape"
            case .tunnel:        return "shield.lefthalf.filled"
            case .routing:       return "arrow.triangle.branch"
            case .subscriptions: return "arrow.down.circle"
            case .advanced:      return "wrench.and.screwdriver"
            }
        }
    }

    @State private var tab: Tab = .general

    var body: some View {
        // No NavigationStack: it gives the window a large title on a row of
        // its own and pushes the tab switcher below it. A plain view with a
        // toolbar keeps the switcher on the titlebar line.
        form(for: tab)
            .frame(minWidth: 560, idealWidth: 620,
                   minHeight: 440, idealHeight: 640)
            .windowTitle(loc("Settings"))
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $tab) {
                        ForEach(Tab.allCases) { item in
                            Label(loc(item.title), systemImage: item.icon)
                                .tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            }
            .task { await refreshHelperStatus() }
    }

    @ViewBuilder
    private func form(for tab: Tab) -> some View {
        Form {
            switch tab {
            case .general:       generalSections
            case .tunnel:        tunnelSections
            case .routing:       routingSections
            case .subscriptions: subscriptionSections
            case .advanced:      advancedSections
            }
        }
        .formStyle(.grouped)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - General

    @ViewBuilder
    private var generalSections: some View {
        @Bindable var store = store
        @Bindable var updater = updater

        Section(loc("Appearance")) {
            Picker(loc("Theme"), selection: $store.settings.appearance) {
                ForEach(AppAppearance.allCases) { a in Text(loc(a.title)).tag(a) }
            }
            .onChange(of: store.settings.appearance) { _, _ in store.save() }

            Picker(loc("Language"), selection: $store.settings.language) {
                ForEach(AppLanguage.allCases) { l in
                    Text(l == .system ? loc("System") : l.displayName).tag(l)
                }
            }
            .onChange(of: store.settings.language) { _, newLang in
                loc.language = newLang; store.save()
            }
        }

        Section(loc("Window")) {
            Toggle(loc("Close button hides to menu bar"), isOn: $store.settings.closeToTray)
                .onChange(of: store.settings.closeToTray) { _, _ in store.save() }
            Toggle(loc("Launch at login"), isOn: $store.settings.launchAtLogin)
                .onChange(of: store.settings.launchAtLogin) { _, on in
                    LoginItem.setEnabled(on); store.save()
                }
            Toggle(loc("Auto-connect on launch"), isOn: $store.settings.autoConnectOnLaunch)
                .onChange(of: store.settings.autoConnectOnLaunch) { _, _ in store.save() }
            Toggle(loc("Notify on connect / disconnect"), isOn: $store.settings.notifyOnConnect)
                .onChange(of: store.settings.notifyOnConnect) { _, on in
                    connection.notifyOnConnect = on
                    if on { NotificationManager.requestAuthorization() }
                    store.save()
                }
        }

        Section {
            Toggle(loc("Check for updates automatically"),
                   isOn: $updater.automaticallyChecks)
            Toggle(loc("Download and install them without asking"),
                   isOn: $updater.automaticallyInstalls)
                .disabled(!updater.automaticallyChecks)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "Veil \(AppVersion.current)")
                    if let last = updater.lastCheck {
                        Text(verbatim: "\(loc("Last checked")) \(last.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(loc("Check Now")) {
                    Task {
                        await UpdateAlert.runUserCheck(updater, loc: loc) {
                            openWindow(id: WindowID.update)
                        }
                    }
                }
                .glassButton()
            }
        } header: {
            Text(loc("Updates"))
        } footer: {
            Text(loc("Updates come from the project's GitHub releases."))
                .font(.caption2)
        }
    }

    // MARK: - Tunnel

    @ViewBuilder
    private var tunnelSections: some View {
        @Bindable var store = store

        Section(loc("Mode")) {
            Picker(loc("Mode"), selection: $store.settings.mode) {
                ForEach(TunnelMode.allCases) { m in Text(loc(m.title)).tag(m) }
            }
            .onChange(of: store.settings.mode) { _, m in
                connection.mode = m; store.save()
            }
            Text(loc(store.settings.mode.subtitle))
                .font(.caption).foregroundStyle(.secondary)
        }

        if store.settings.mode == .tun {
            Section(loc("TUN")) {
                Toggle(loc("Let the core own the interface"),
                       isOn: $store.settings.useNativeTun)
                    .onChange(of: store.settings.useNativeTun) { _, _ in store.save() }
                Text(loc("sing-box handles the tunnel itself, which is what lets a rule match an application. Turn this off to fall back to tun2socks."))
                    .font(.caption).foregroundStyle(.secondary)

                if store.settings.useNativeTun {
                    Toggle(loc("Strict route"), isOn: $store.settings.tunStrictRoute)
                        .onChange(of: store.settings.tunStrictRoute) { _, _ in store.save() }
                    Text(loc("Stops traffic from leaving around the tunnel. Can break local network access."))
                        .font(.caption2).foregroundStyle(.secondary)
                    Picker(loc("Stack"), selection: $store.settings.tunStack) {
                        Text(loc("Automatic")).tag("")
                        Text(verbatim: "system").tag("system")
                        Text(verbatim: "gvisor").tag("gvisor")
                        Text(verbatim: "mixed").tag("mixed")
                    }
                    .onChange(of: store.settings.tunStack) { _, _ in store.save() }
                }
            }
        }

        Section {
            HStack {
                Image(systemName: helperInstalled ? "checkmark.shield.fill"
                      : (helperStale ? "exclamationmark.shield.fill" : "shield.slash"))
                    .foregroundStyle(helperInstalled ? .green
                                     : (helperStale ? .orange : .secondary))
                VStack(alignment: .leading, spacing: 2) {
                    Text(helperInstalled ? loc("Helper installed")
                         : (helperStale ? loc("Helper needs reinstalling")
                            : loc("Helper not installed")))
                    Text(helperInstalled
                         ? loc("TUN switches servers without asking for a password.")
                         : (helperStale
                            ? loc("The installed helper was pinned to an older build of Veil and refuses this one, so TUN cannot start.")
                            : loc("Install once to stop password prompts on every switch.")))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if helperBusy {
                    ProgressView().controlSize(.small)
                } else if helperInstalled {
                    Button(loc("Remove")) {
                        runHelperTask { TunManager.uninstallHelper() }
                    }
                    .glassButton().tint(.red)
                } else {
                    Button(helperStale ? loc("Reinstall") : loc("Install")) {
                        runHelperTask { try TunManager.installHelper() }
                    }
                    .glassProminentButton()
                }
            }
            // An install can fail for reasons the user can act on — a
            // cancelled password prompt, an unsigned bundle — so say so
            // instead of leaving the button looking inert.
            if let helperError {
                Text(helperError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        } header: {
            Text(loc("TUN helper"))
        }

        Section(loc("Ports")) {
            LabeledContent(loc("SOCKS port")) {
                TextField("", value: $store.settings.socksPort, format: .number.grouping(.never))
                    .frame(width: 80).multilineTextAlignment(.trailing)
            }
            LabeledContent(loc("HTTP port")) {
                TextField("", value: $store.settings.httpPort, format: .number.grouping(.never))
                    .frame(width: 80).multilineTextAlignment(.trailing)
            }
            Picker(loc("Log level"), selection: $store.settings.logLevel) {
                ForEach(LogLevel.allCases) { l in Text(loc(l.title)).tag(l) }
            }
            .onChange(of: store.settings.logLevel) { _, l in
                connection.logLevel = l; store.save()
            }
        }
        .onChange(of: store.settings.socksPort) { _, p in
            connection.ports.socks = p; store.save()
        }
        .onChange(of: store.settings.httpPort) { _, p in
            connection.ports.http = p; store.save()
        }
    }

    // MARK: - Routing

    @ViewBuilder
    private var routingSections: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc(store.settings.routingPreset.title))
                    Text(loc(store.settings.routingPreset.subtitle))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button(loc("Configure…")) { openWindow(id: WindowID.routing) }
                    .glassButton()
            }
        } header: {
            Text(loc("Routing"))
        } footer: {
            Text(loc("Rules, groups, the resolver and the rule lists all live in the routing window."))
                .font(.caption2)
        }

        ControlAPISection()
    }

    // MARK: - Subscriptions

    @ViewBuilder
    private var subscriptionSections: some View {
        @Bindable var store = store

        Section(loc("Updates")) {
            Toggle(loc("Auto-update subscriptions"), isOn: $store.settings.autoUpdateSubscriptions)
                .onChange(of: store.settings.autoUpdateSubscriptions) { _, _ in store.save() }
            // Hidden rather than disabled: with the toggle off the interval
            // governs nothing, and a greyed row still reads as a setting.
            if store.settings.autoUpdateSubscriptions {
                Picker(loc("Check every"), selection: $store.settings.autoUpdateIntervalHours) {
                    ForEach(AppSettings.autoUpdateIntervalChoices(
                        including: store.settings.autoUpdateIntervalHours), id: \.self) { hours in
                        Text(verbatim: "\(hours) \(loc("h"))").tag(hours)
                    }
                }
                .onChange(of: store.settings.autoUpdateIntervalHours) { _, _ in store.save() }
            }
        }

        Section {
            Toggle(loc("Send HWID with subscription requests"), isOn: $store.settings.sendHwid)
                .onChange(of: store.settings.sendHwid) { _, _ in store.save() }
            Text(loc("Identifies this device to providers that require it."))
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc("Device ID"))
                    // Held in state rather than read from `DeviceID` on every
                    // draw: that is a static store SwiftUI cannot observe, so
                    // a rotated ID used to stay on screen until some unrelated
                    // change happened to redraw the row.
                    Text(verbatim: hwid)
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                Button(hwidCopied ? loc("Copied") : loc("Copy")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(hwid, forType: .string)
                    hwidCopied = true
                }
                .glassButton()
                Button(loc("Regenerate")) {
                    hwid = DeviceID.regenerate()
                    hwidDraft = ""
                    hwidCopied = false
                }
                .glassButton()
            }
            Text(loc("A new ID looks like a new device to your provider and may use up a device slot."))
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                TextField(loc("Set the ID by hand"), text: $hwidDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption.monospaced())
                    .onSubmit { applyManualHwid() }
                Button(loc("Apply")) { applyManualHwid() }
                    .glassButton()
                    .disabled(DeviceID.normalizedManual(hwidDraft) == nil)
            }
            Text(loc("Use the ID your provider issued. Stored exactly as typed."))
                .font(.caption).foregroundStyle(.secondary)
        } header: {
            Text(loc("Device"))
        }

        Section {
            TextField(loc("User-Agent (optional)"),
                      text: $store.settings.userAgentOverride)
                .textFieldStyle(.roundedBorder)
                .onSubmit { store.save() }
            Text(verbatim: "\(loc("Sent as")): \(DeviceInfo.userAgent(override: store.settings.userAgentOverride))")
                .font(.caption.monospaced()).foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text(loc("Leave empty unless your provider's rules expect a particular client."))
                .font(.caption).foregroundStyle(.secondary)
        } header: {
            Text(loc("Identification"))
        }
    }

    // MARK: - Advanced

    @ViewBuilder
    private var advancedSections: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc("Export diagnostics"))
                    Text(loc("Copies a report with subscription URLs, tokens and IDs removed."))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button(diagnosticsCopied ? loc("Copied") : loc("Copy")) {
                    let report = Diagnostics.report(store: store,
                                                    logText: connection.logs)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(report, forType: .string)
                    diagnosticsCopied = true
                }
                .glassButton()
            }
        } header: {
            Text(loc("Privacy"))
        }
    }

    // MARK: - Helper plumbing

    /// Adopts whatever is in the manual field, then clears it. A blank field
    /// is not an identifier, so the button is disabled and this does nothing.
    private func applyManualHwid() {
        guard let applied = DeviceID.setManual(hwidDraft) else { return }
        hwid = applied
        hwidDraft = ""
        hwidCopied = false
    }

    /// Runs an install or removal off the main thread — both wait on the admin
    /// prompt and on an XPC round trip, and neither may freeze the window.
    private func runHelperTask(_ work: @escaping @Sendable () throws -> Void) {
        helperBusy = true
        helperError = nil
        Task.detached(priority: .userInitiated) {
            var failure: String?
            do { try work() } catch { failure = error.localizedDescription }
            let installed = TunManager.isHelperInstalled
            let stale = !installed && PrivilegedHelper.isInstalled
            await MainActor.run {
                helperError = failure
                helperInstalled = installed
                helperStale = stale
                helperBusy = false
            }
        }
    }

    private func refreshHelperStatus() async {
        let status = await Task.detached(priority: .utility) {
            let ready = TunManager.isHelperInstalled
            return (ready: ready, stale: !ready && PrivilegedHelper.isInstalled)
        }.value
        helperInstalled = status.ready
        helperStale = status.stale
    }
}
