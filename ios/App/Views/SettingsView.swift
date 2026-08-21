import SwiftUI

struct SettingsView: View {
    @Environment(ServerStore.self) private var store
    @Environment(TunnelController.self) private var tunnel
    @Environment(Loc.self) private var loc
    @Environment(\.dismiss) private var dismiss

    @State private var dnsText = ""
    @State private var showRemoveConfirm = false

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            Form {
                Section {
                    // No mode picker: iOS has exactly one way to capture
                    // traffic, and it is the one this app uses.
                    LabeledContent(loc("Mode"), value: loc("Network Extension (all apps)"))
                    Picker(loc("Log level"), selection: $store.settings.logLevel) {
                        ForEach(LogLevel.allCases) { Text(loc($0.title)).tag($0) }
                    }
                    Toggle(loc("IPv6 inside tunnel"), isOn: $store.settings.ipv6Enabled)
                    Stepper(value: $store.settings.tunnelMTU, in: 1280...1500, step: 20) {
                        LabeledContent("MTU", value: "\(store.settings.tunnelMTU)")
                    }
                    LabeledContent("DNS") {
                        TextField("1.1.1.1, 8.8.8.8", text: $dnsText)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit(commitDNS)
                    }
                } header: {
                    Text(loc("Tunnel"))
                } footer: {
                    Text(loc("Changes apply the next time you connect or switch servers."))
                }

                Section(loc("Routing")) {
                    NavigationLink {
                        RoutingView()
                    } label: {
                        LabeledContent(loc("Rules"), value: loc(store.settings.routingPreset.title))
                    }
                }

                Section(loc("Startup")) {
                    Toggle(loc("Auto-connect on launch"), isOn: $store.settings.autoConnectOnLaunch)
                    Toggle(loc("Notify on connect"), isOn: $store.settings.notifyOnConnect)
                        .onChange(of: store.settings.notifyOnConnect) { _, on in
                            tunnel.notifyOnConnect = on
                            if on { NotificationManager.requestAuthorization() }
                        }
                }

                Section(loc("Subscriptions")) {
                    Toggle(loc("Auto-update subscriptions"),
                           isOn: $store.settings.autoUpdateSubscriptions)
                    if store.settings.autoUpdateSubscriptions {
                        Stepper(value: $store.settings.autoUpdateIntervalHours, in: 1...168) {
                            LabeledContent(loc("Every"),
                                           value: "\(store.settings.autoUpdateIntervalHours) h")
                        }
                    }
                    Toggle(loc("Send device ID (HWID)"), isOn: $store.settings.sendHwid)
                }

                Section(loc("Appearance")) {
                    Picker(loc("Theme"), selection: $store.settings.appearance) {
                        ForEach(AppAppearance.allCases) { Text(loc($0.title)).tag($0) }
                    }
                    Picker(loc("Language"), selection: $store.settings.language) {
                        ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                    }
                    .onChange(of: store.settings.language) { _, language in
                        loc.language = language
                    }
                }

                Section {
                    LabeledContent(loc("Status"),
                                   value: tunnel.isInstalled ? loc("Installed") : loc("Not installed"))
                    if tunnel.isInstalled {
                        Button(loc("Remove VPN profile"), role: .destructive) {
                            showRemoveConfirm = true
                        }
                    }
                } header: {
                    Text(loc("VPN profile"))
                } footer: {
                    Text(loc("iOS asks you to allow the VPN configuration the first time you connect."))
                }

                Section(loc("About")) {
                    LabeledContent(loc("App version"), value: appVersion)
                    LabeledContent(loc("Xray core"),
                                   value: tunnel.coreVersion.isEmpty ? "—" : tunnel.coreVersion)
                    LabeledContent(loc("Device ID"), value: DeviceID.hwid)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }
            .navigationTitle(loc("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("Done")) {
                        commitDNS()
                        store.save()
                        dismiss()
                    }
                }
            }
            .onAppear { dnsText = store.settings.effectiveDNSServers.joined(separator: ", ") }
            .onDisappear { store.save() }
            .confirmationDialog(loc("Remove VPN profile?"),
                                isPresented: $showRemoveConfirm, titleVisibility: .visible) {
                Button(loc("Remove"), role: .destructive) {
                    Task { await tunnel.removeProfile() }
                }
                Button(loc("Cancel"), role: .cancel) {}
            }
        }
    }

    private func commitDNS() {
        let servers = dnsText
            .split(whereSeparator: { $0 == "," || $0 == " " })
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        store.settings.dnsServers = servers
        dnsText = store.settings.effectiveDNSServers.joined(separator: ", ")
    }

    private var appVersion: String {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(AppVersion.current) (\(build))"
    }
}
