import SwiftUI

/// Routing configuration: the preset, the rule list, the groups a rule can
/// point at, the resolver, and the geo database the older matchers need.
///
/// The four are one sheet because they are one decision — "where does this
/// traffic go" — taken at four levels of detail.
struct RoutingSheet: View {
    @Environment(ServerStore.self) private var store
    @Environment(ConnectionManager.self) private var connection
    @Environment(Loc.self) private var loc
    @Environment(\.dismiss) private var dismiss

    private var geo = GeoAssetManager.shared

    enum Tab: String, CaseIterable, Identifiable {
        case rules, lists, groups, dns, database
        var id: String { rawValue }
        var title: String {
            switch self {
            case .rules:    return "Rules"
            case .lists:    return "Lists"
            case .groups:   return "Groups"
            case .dns:      return "DNS"
            case .database: return "Database"
            }
        }
        var icon: String {
            switch self {
            case .rules:    return "arrow.triangle.branch"
            case .lists:    return "list.bullet.rectangle"
            case .groups:   return "square.stack.3d.up"
            case .dns:      return "globe"
            case .database: return "externaldrive"
            }
        }
    }

    /// Which pane to draw. Routing used to be a window of its own with a tab
    /// strip; it is a group of panes in the Settings sidebar now, and the
    /// sidebar decides which one is on screen.
    var pane: Tab

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content(pane)
            if connection.isConnected {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise.circle")
                    Text(loc("Changes apply on the next connect or reconnect."))
                    Spacer()
                    Button(loc("Apply now")) { applyNow() }
                        .controlSize(.small)
                }
                .font(.caption).foregroundStyle(.orange)
                .padding(.horizontal).padding(.vertical, 7)
            }
        }
    }

    /// Pushes the edited rules into the live connection. Without this they
    /// reach it on the next connect, which is correct but easy to read as
    /// "the rule did nothing".
    private func applyNow() {
        store.save()
        connection.reconnectForRoutingChange()
    }

    @ViewBuilder
    private func content(_ tab: Tab) -> some View {
        @Bindable var store = store
        switch tab {
        case .rules:
            Form {
                presetSection
                rulesSection
            }
            .formStyle(.grouped)
        case .lists:
            CommunityListsEditor(selected: $store.settings.communityLists,
                                 target: $store.settings.communityListTarget,
                                 onChange: { store.save() })
        case .groups:
            ServerGroupsEditor(groups: $store.settings.serverGroups,
                               servers: store.allServers,
                               candidates: store.groupCandidates,
                               sources: store.listSources,
                               annotations: store.settings.nodeAnnotations,
                               onChange: { store.save() })
        case .dns:
            DNSEditor(dns: $store.settings.dns,
                      servers: store.allServers,
                      groups: store.allGroups,
                      onChange: { store.save() })
        case .database:
            Form { geoSection }
                .formStyle(.grouped)
        }
    }

    // MARK: - Preset

    private var presetSection: some View {
        @Bindable var store = store
        return Section {
            Picker(loc("Preset"), selection: $store.settings.routingPreset) {
                ForEach(RoutingPreset.allCases) { p in Text(loc(p.title)).tag(p) }
            }
            .onChange(of: store.settings.routingPreset) { _, _ in store.save() }
            Text(loc(store.settings.routingPreset.subtitle))
                .font(.caption).foregroundStyle(.secondary)
            presetExplainer

            Toggle(isOn: $store.settings.blockAds) {
                HintLabel(loc("Block ads & trackers"), loc("Drops connections to known advertising and tracking domains before your own rules are consulted."))
            }
                .onChange(of: store.settings.blockAds) { _, _ in store.save() }
        } header: {
            Text(loc("Mode"))
        } footer: {
            Text(loc("Your own rules below run under every preset, after the LAN bypass and before the preset's country rules."))
                .font(.caption2)
        }
    }

    /// Whether any rule names something this setup cannot build. `useNativeTun`
    /// only costs anything in TUN mode: system-proxy always builds the full
    /// profile.
    private var unhonouredTargets: Bool {
        store.settings.mode == .tun
            && !store.settings.useNativeTun
            && RoutingRule.needsProfile(store.settings.customRules)
    }

    /// What the chosen preset puts in front of and behind the user's own
    /// rules. A preset that only describes itself in a sentence is a preset
    /// whose effect has to be guessed at.
    @ViewBuilder
    private var presetExplainer: some View {
        let preset = store.settings.routingPreset
        let guards = preset.guardRules(blockAds: store.settings.blockAds)
        let after = preset.presetRules()
        if !guards.isEmpty || !after.isEmpty {
            DisclosureGroup(loc("What this preset does")) {
                VStack(alignment: .leading, spacing: 4) {
                    if !guards.isEmpty {
                        Text(loc("Before your rules")).font(.caption2).foregroundStyle(.secondary)
                        ForEach(guards) { rule in presetLine(rule) }
                    }
                    if !after.isEmpty {
                        Text(loc("After your rules")).font(.caption2).foregroundStyle(.secondary)
                        ForEach(after) { rule in presetLine(rule) }
                    }
                }
                .padding(.top, 2)
            }
            .font(.caption)
        }
    }

    private func presetLine(_ rule: RoutingRule) -> some View {
        let matchers = (rule.domains + rule.ips).joined(separator: ", ")
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(loc(rule.name)).foregroundStyle(.primary)
            Text(verbatim: "→").foregroundStyle(.secondary)
            Text(loc(rule.target.title(servers: store.allServers,
                                       groups: store.allGroups)))
                .foregroundStyle(.secondary)
            Text(verbatim: matchers)
                .font(.caption2).monospaced().foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .font(.caption)
    }

    // MARK: - Rules

    private var rulesSection: some View {
        @Bindable var store = store
        return Section {
            if store.settings.customRules.isEmpty {
                emptyRules
            }
            if unhonouredTargets {
                Label(loc("These rules need sing-box's own tunnel. With it off, TUN mode has a single proxy outbound, so a rule naming a server or a group sends its traffic through the default one instead."),
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach($store.settings.customRules) { $rule in
                RuleCard(rule: $rule,
                         servers: store.allServers,
                         groups: store.allGroups,
                         onChange: { store.save() },
                         onDelete: { id in
                             store.settings.customRules.removeAll { $0.id == id }
                             store.save()
                         },
                         onMove: { id, delta in move(id: id, by: delta) },
                         targetUnreachable: unhonouredTargets && $rule.wrappedValue.target.needsProfile)
            }

            HStack {
                Button {
                    store.settings.customRules.append(RoutingRule(name: ""))
                    store.save()
                } label: {
                    Label(loc("Add rule"), systemImage: "plus.circle")
                }
                Spacer()
                Menu {
                    ForEach(RuleTemplate.all) { template in
                        Button(loc(template.title)) {
                            store.settings.customRules.append(template.rule())
                            store.save()
                        }
                    }
                } label: {
                    Label(loc("From template"), systemImage: "wand.and.stars")
                }
                .fixedSize()
            }
        } header: {
            Text(loc("Rules — top to bottom, first match wins"))
        } footer: {
            Text(loc("A rule matches when every filled-in field matches. Domains: example.com, domain:example.com, keyword:google, geosite:netflix. IPs: 1.2.3.0/24, geoip:cn."))
                .font(.caption2)
        }
    }

    private var emptyRules: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(loc("No rules yet."))
                .font(.callout)
            Text(loc("Add one to send an application, a domain or a network through a particular server."))
                .font(.caption).foregroundStyle(.secondary)
            if !store.settings.useNativeTun {
                Text(loc("Application rules need TUN mode with the native core enabled in Settings."))
                    .font(.caption2).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 6)
    }

    private func move(id: UUID, by delta: Int) {
        guard let index = store.settings.customRules.firstIndex(where: { $0.id == id }) else {
            return
        }
        let target = index + delta
        guard target >= 0, target < store.settings.customRules.count else { return }
        store.settings.customRules.swapAt(index, target)
        store.save()
    }

    // MARK: - Geo assets

    private var geoSection: some View {
        @Bindable var store = store
        let needsGeo = store.settings.routingPreset.needsGeoAssets
            || store.settings.blockAds
            || usesGeoInCustom
        return Section {
            Picker(loc("Rule database"), selection: $store.settings.geoSource) {
                ForEach(GeoAssetSource.allCases) { s in Text(s.title).tag(s) }
            }
            .onChange(of: store.settings.geoSource) { _, _ in store.save() }

            if store.settings.geoSource == .custom {
                TextField("geoip.dat URL", text: $store.settings.customGeoipURL)
                    .onChange(of: store.settings.customGeoipURL) { _, _ in store.save() }
                TextField("geosite.dat URL", text: $store.settings.customGeositeURL)
                    .onChange(of: store.settings.customGeositeURL) { _, _ in store.save() }
            }

            HStack {
                if geo.isDownloading {
                    ProgressView().controlSize(.small)
                    Text(loc("Downloading…")).font(.caption).foregroundStyle(.secondary)
                } else if geo.hasAssets, let updated = geo.lastUpdated {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("\(loc("Updated")) \(updated.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(loc("Not downloaded")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(geo.hasAssets ? loc("Update") : loc("Download")) {
                    Task { await downloadGeo() }
                }
                .glassButton()
                .disabled(geo.isDownloading)
            }
            if let err = geo.lastError {
                Text(err).font(.caption2).foregroundStyle(.red)
            }
            if needsGeo && !geo.hasAssets {
                Text(loc("This preset needs the rule database. Download it to use geosite/geoip rules."))
                    .font(.caption2).foregroundStyle(.orange)
            }
        } header: {
            Text(loc("Rule database (geosite / geoip)"))
        } footer: {
            // The .dat files feed Xray. sing-box reads rule-sets instead, and
            // fetches those itself from the tags the rules mention.
            Text(loc("Used by the Xray core. The sing-box core downloads the matching rule-sets on its own."))
                .font(.caption2)
        }
    }

    private var usesGeoInCustom: Bool {
        store.settings.customRules.contains { r in
            r.domains.contains { $0.hasPrefix("geosite:") }
                || r.ips.contains { $0.hasPrefix("geoip:") }
        }
    }

    // MARK: - Actions

    private func downloadGeo() async {
        await geo.download(source: store.settings.geoSource,
                           customGeoip: store.settings.customGeoipURL,
                           customGeosite: store.settings.customGeositeURL)
    }

}

// MARK: - Starting points

/// Rules people write over and over, pre-filled.
struct RuleTemplate: Identifiable, Sendable {
    var id: String { title }
    var title: String
    var rule: @Sendable () -> RoutingRule

    static let all: [RuleTemplate] = [
        RuleTemplate(title: "An app through a server") {
            RoutingRule(name: "App")
        },
        RuleTemplate(title: "Torrents direct") {
            RoutingRule(name: "Torrents", target: .direct,
                        processNames: ["Transmission", "qbittorrent", "deluge"])
        },
        RuleTemplate(title: "Streaming through the proxy") {
            RoutingRule(name: "Streaming", target: .proxy,
                        domains: ["geosite:netflix", "geosite:youtube",
                                  "geosite:disney", "geosite:spotify"])
        },
        RuleTemplate(title: "Block QUIC (force TLS)") {
            var rule = RoutingRule(name: "Block QUIC", target: .block, port: "443")
            rule.network = "udp"
            return rule
        },
        RuleTemplate(title: "LAN direct") {
            RoutingRule(name: "LAN direct", target: .direct,
                        ips: RoutingPreset.privateCIDRs)
        }
    ]
}

// MARK: - Single rule editor card

private struct RuleCard: View {
    @Binding var rule: RoutingRule
    @Environment(Loc.self) private var loc
    var servers: [ProxyConfig] = []
    var groups: [ServerGroup] = []
    var onChange: () -> Void
    var onDelete: (UUID) -> Void
    var onMove: (UUID, Int) -> Void
    /// Set when the rule names a server or group this setup cannot build, so
    /// the row says so rather than looking configured.
    var targetUnreachable: Bool = false

    @State private var pickingApps = false
    @State private var showAdvanced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            appsRow
            matcherRow(title: loc("Domains"),
                       placeholder: "example.com, geosite:netflix",
                       values: $rule.domains)
            matcherRow(title: loc("IPs / CIDR"),
                       placeholder: "1.2.3.0/24, geoip:cn",
                       values: $rule.ips)
            advanced
        }
        .padding(.vertical, 6)
        .opacity(rule.enabled ? 1 : 0.5)
        .sheet(isPresented: $pickingApps) {
            ProcessPickerSheet(selection: $rule.processNames)
        }
        .onChange(of: rule.processNames) { _, _ in onChange() }
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: $rule.enabled)
                .labelsHidden()
                .onChange(of: rule.enabled) { _, _ in onChange() }
            TextField(loc("Rule name"), text: $rule.name)
                .textFieldStyle(.roundedBorder)
                .onChange(of: rule.name) { _, _ in onChange() }
            Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
            RuleTargetPicker(target: $rule.target,
                             servers: servers,
                             groups: groups,
                             onChange: onChange)
            if targetUnreachable {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(loc("This target is not built in the current setup, so the rule sends its traffic through the default proxy."))
            }
            let ruleID = rule.id
            Button { onMove(ruleID, -1) } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.borderless)
            Button { onMove(ruleID, 1) } label: { Image(systemName: "chevron.down") }
                .buttonStyle(.borderless)
            Button(role: .destructive) { onDelete(ruleID) } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    /// The part the whole feature exists for: naming applications without
    /// having to know what their binary is called.
    private var appsRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(loc("Apps")).font(.caption2).foregroundStyle(.secondary)
            TokenChips(values: $rule.processNames,
                       placeholder: loc("Executable name"),
                       onChange: onChange) {
                Button {
                    pickingApps = true
                } label: {
                    Label(loc("Choose…"), systemImage: "magnifyingglass")
                }
                .glassButton()
            }
        }
    }

    private func matcherRow(title: String, placeholder: String,
                            values: Binding<[String]>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            TokenChips(values: values, placeholder: placeholder,
                       monospaced: true, onChange: onChange)
        }
    }

    private var advanced: some View {
        DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(loc("Port")).font(.caption).foregroundStyle(.secondary)
                    TextField("443, 1000-2000", text: $rule.port)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: rule.port) { _, _ in onChange() }
                    Picker(loc("Network"), selection: $rule.network) {
                        Text(loc("Any")).tag("")
                        Text("TCP").tag("tcp")
                        Text("UDP").tag("udp")
                    }
                    .fixedSize()
                    .onChange(of: rule.network) { _, _ in onChange() }
                }
                HStack {
                    Picker(loc("Addresses are"), selection: $rule.direction) {
                        ForEach(RuleDirection.allCases) { d in
                            Text(loc(d.title)).tag(d)
                        }
                    }
                    .fixedSize()
                    .onChange(of: rule.direction) { _, _ in onChange() }
                    Spacer()
                    Toggle(loc("Invert"), isOn: $rule.invert)
                        .toggleStyle(.checkbox)
                        .onChange(of: rule.invert) { _, _ in onChange() }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(loc("Protocols (sniffed)")).font(.caption2)
                        .foregroundStyle(.secondary)
                    TokenChips(values: $rule.protocols,
                               placeholder: "tls, quic, bittorrent, dns",
                               monospaced: true, onChange: onChange)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(loc("Executable paths")).font(.caption2)
                        .foregroundStyle(.secondary)
                    TokenChips(values: $rule.processPaths,
                               placeholder: "/Applications/Foo.app/Contents/MacOS/Foo",
                               monospaced: true, onChange: onChange)
                }
                if rule.needsProcessMatching {
                    Text(loc("Application matching is enforced by the sing-box core in TUN mode. The Xray path skips these rules rather than widening them."))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        } label: {
            Text(loc("More")).font(.caption)
        }
    }
}
