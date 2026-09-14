import SwiftUI
import AppKit

/// Basic app settings: tunnel mode, appearance, auto-update, close-to-tray, ports.
struct SettingsSheet: View {
    @Environment(ServerStore.self) private var store
    @Environment(ConnectionManager.self) private var connection
    @Environment(Loc.self) private var loc
    @Environment(\.dismiss) private var dismiss

    // Asking the helper whether it is there is an XPC round trip, so the view
    // starts pessimistic and refreshes off the main thread.
    @State private var helperInstalled = false
    @State private var helperBusy = false
    @State private var helperError: String?
    @State private var showRouting = false
    @State private var hwidFingerprint = Redaction.fingerprint(DeviceID.hwid)
    @State private var diagnosticsCopied = false

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(loc("Settings")).font(.title2).bold()
                Spacer()
                Button(loc("Done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .glassProminentButton()
            }
            .padding()
            Divider()

            Form {
                Section(loc("Tunnel")) {
                    Picker(loc("Mode"), selection: $store.settings.mode) {
                        ForEach(TunnelMode.allCases) { m in Text(m.title).tag(m) }
                    }
                    .onChange(of: store.settings.mode) { _, m in
                        connection.mode = m; store.save()
                    }
                    Text(store.settings.mode.subtitle)
                        .font(.caption).foregroundStyle(.secondary)

                    HStack {
                        Text(loc("SOCKS port"))
                        Spacer()
                        TextField("", value: $store.settings.socksPort, format: .number.grouping(.never))
                            .frame(width: 80).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text(loc("HTTP port"))
                        Spacer()
                        TextField("", value: $store.settings.httpPort, format: .number.grouping(.never))
                            .frame(width: 80).multilineTextAlignment(.trailing)
                    }
                    Picker(loc("Log level"), selection: $store.settings.logLevel) {
                        ForEach(LogLevel.allCases) { l in Text(l.title).tag(l) }
                    }
                    .onChange(of: store.settings.logLevel) { _, l in
                        connection.logLevel = l; store.save()
                    }
                }

                Section(loc("Routing")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.settings.routingPreset.title)
                            Text(store.settings.routingPreset.subtitle)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(loc("Configure…")) { showRouting = true }
                            .glassButton()
                    }
                }

                Section(loc("Appearance")) {
                    Picker(loc("Theme"), selection: $store.settings.appearance) {
                        ForEach(AppAppearance.allCases) { a in Text(a.title).tag(a) }
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

                Section {
                    HStack {
                        Image(systemName: helperInstalled ? "checkmark.shield.fill" : "shield.slash")
                            .foregroundStyle(helperInstalled ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(helperInstalled ? loc("Helper installed") : loc("Helper not installed"))
                            Text(helperInstalled
                                 ? "TUN switches servers without asking for a password."
                                 : "Install once to stop password prompts on every switch.")
                                .font(.caption).foregroundStyle(.secondary)
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
                            Button(loc("Install")) {
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
                    Text("TUN Helper (no-password)")
                }

                Section(loc("Subscriptions")) {
                    Toggle(loc("Auto-update subscriptions"), isOn: $store.settings.autoUpdateSubscriptions)
                        .onChange(of: store.settings.autoUpdateSubscriptions) { _, _ in store.save() }
                    Stepper(value: $store.settings.autoUpdateIntervalHours, in: 1...168) {
                        Text("Every \(store.settings.autoUpdateIntervalHours) h")
                    }
                    .onChange(of: store.settings.autoUpdateIntervalHours) { _, _ in store.save() }
                    Toggle(loc("Send HWID with subscription requests"), isOn: $store.settings.sendHwid)
                        .onChange(of: store.settings.sendHwid) { _, _ in store.save() }
                    Text(loc("Identifies this device to providers that require it."))
                        .font(.caption).foregroundStyle(.secondary)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc("Device ID"))
                            Text(hwidFingerprint)
                                .font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(loc("Regenerate")) {
                            DeviceID.regenerate()
                            hwidFingerprint = Redaction.fingerprint(DeviceID.hwid)
                        }
                        .glassButton()
                    }
                    Text(loc("A new ID looks like a new device to your provider and may use up a device slot."))
                        .font(.caption).foregroundStyle(.secondary)

                    TextField(loc("User-Agent (optional)"),
                              text: $store.settings.userAgentOverride)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { store.save() }
                    Text(loc("Leave empty unless your provider's rules expect a particular client."))
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section(loc("Privacy")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc("Export diagnostics"))
                            Text(loc("Copies a report with subscription URLs, tokens and IDs removed."))
                                .font(.caption).foregroundStyle(.secondary)
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
                }

                Section(loc("Window")) {
                    Toggle(loc("Close button hides to menu bar"), isOn: $store.settings.closeToTray)
                        .onChange(of: store.settings.closeToTray) { _, _ in store.save() }
                    Toggle(loc("Auto-connect on launch"), isOn: $store.settings.autoConnectOnLaunch)
                        .onChange(of: store.settings.autoConnectOnLaunch) { _, _ in store.save() }
                    Toggle(loc("Launch at login"), isOn: $store.settings.launchAtLogin)
                        .onChange(of: store.settings.launchAtLogin) { _, on in
                            LoginItem.setEnabled(on); store.save()
                        }
                    Toggle(loc("Notify on connect / disconnect"), isOn: $store.settings.notifyOnConnect)
                        .onChange(of: store.settings.notifyOnConnect) { _, on in
                            connection.notifyOnConnect = on
                            if on { NotificationManager.requestAuthorization() }
                            store.save()
                        }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 460, height: 560)
        .task { await refreshHelperStatus() }
        .sheet(isPresented: $showRouting) { RoutingSheet() }
        .onChange(of: store.settings.socksPort) { _, p in
            connection.ports.socks = p; store.save()
        }
        .onChange(of: store.settings.httpPort) { _, p in
            connection.ports.http = p; store.save()
        }
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
            await MainActor.run {
                helperError = failure
                helperInstalled = installed
                helperBusy = false
            }
        }
    }

    private func refreshHelperStatus() async {
        let installed = await Task.detached(priority: .utility) {
            TunManager.isHelperInstalled
        }.value
        helperInstalled = installed
    }
}
