import SwiftUI

/// The resolver: which servers answer, which names go where, and what leaks.
///
/// DNS is where a tunnel usually leaks: the traffic goes through the proxy but
/// the lookup that preceded it went to the ISP in clear text. The defaults here
/// resolve proxied names through the tunnel and keep only the bootstrap lookup
/// — the one that turns the proxy's own hostname into an address — outside it.
struct DNSEditor: View {
    @Binding var dns: DNSSettings
    var servers: [ProxyConfig]
    var groups: [ServerGroup]
    var onChange: () -> Void

    @Environment(Loc.self) private var loc

    var body: some View {
        Form {
            generalSection
            serversSection
            rulesSection
        }
        .formStyle(.grouped)
    }

    // MARK: - General

    private var generalSection: some View {
        Section {
            Toggle(loc("Handle DNS in the tunnel"), isOn: $dns.enabled)
                .onChange(of: dns.enabled) { _, _ in onChange() }

            Picker(loc("Answer with"), selection: $dns.finalTag) {
                ForEach(dns.servers) { server in
                    Text(server.tag).tag(server.tag)
                }
            }
            .onChange(of: dns.finalTag) { _, _ in onChange() }

            Picker(loc("Address family"), selection: $dns.strategy) {
                Text(loc("Prefer IPv4")).tag("prefer_ipv4")
                Text(loc("Prefer IPv6")).tag("prefer_ipv6")
                Text(loc("IPv4 only")).tag("ipv4_only")
                Text(loc("IPv6 only")).tag("ipv6_only")
            }
            .onChange(of: dns.strategy) { _, _ in onChange() }

            Toggle(loc("Serve stale answers while refreshing"), isOn: $dns.optimistic)
                .onChange(of: dns.optimistic) { _, _ in onChange() }

            Toggle(loc("FakeIP"), isOn: $dns.fakeIPEnabled)
                .onChange(of: dns.fakeIPEnabled) { _, _ in onChange() }
            if dns.fakeIPEnabled {
                Text(loc("Answers instantly from a private range and keeps the domain visible to rules. Breaks software that resolves names itself."))
                    .font(.caption2).foregroundStyle(.secondary)
                HStack {
                    TextField("198.18.0.0/15", text: $dns.fakeIPv4Range)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: dns.fakeIPv4Range) { _, _ in onChange() }
                    TextField("fc00::/18", text: $dns.fakeIPv6Range)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: dns.fakeIPv6Range) { _, _ in onChange() }
                }
                .font(.system(.caption, design: .monospaced))
            }
        } header: {
            Text(loc("Resolver"))
        } footer: {
            Text(loc("Used by the sing-box core. The Xray path uses the plain server list in Settings."))
                .font(.caption2)
        }
    }

    // MARK: - Servers

    private var serversSection: some View {
        Section {
            ForEach($dns.servers) { $server in
                serverCard($server)
            }
            Button {
                dns.servers.append(DNSServerEntry(tag: uniqueTag(), kind: .https,
                                                  server: "", path: "/dns-query"))
                onChange()
            } label: {
                Label(loc("Add resolver"), systemImage: "plus.circle")
            }
        } header: {
            Text(loc("Servers"))
        }
    }

    private func serverCard(_ server: Binding<DNSServerEntry>) -> some View {
        let id = server.wrappedValue.id
        let kind = server.wrappedValue.kind
        let isBuiltin = DNSEditor.builtinTags.contains(server.wrappedValue.tag)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField(loc("Name"), text: server.tag)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 130)
                    // Renaming a built-in would orphan the rules and the
                    // bootstrap lookup that name it.
                    .disabled(isBuiltin)
                    .onChange(of: server.wrappedValue.tag) { _, _ in onChange() }
                Picker("", selection: server.kind) {
                    ForEach(DNSServerEntry.Kind.allCases) { k in
                        Text(loc(k.title)).tag(k)
                    }
                }
                .labelsHidden().fixedSize()
                .onChange(of: server.wrappedValue.kind) { _, _ in onChange() }
                if !isBuiltin {
                    Spacer()
                    Button(role: .destructive) {
                        dns.servers.removeAll { $0.id == id }
                        onChange()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
            if kind.needsServer {
                HStack(spacing: 8) {
                    TextField(loc("Host or IP"), text: server.server)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                        .onChange(of: server.wrappedValue.server) { _, _ in onChange() }
                    if kind.needsPath {
                        TextField("/dns-query", text: server.path)
                            .textFieldStyle(.roundedBorder).frame(width: 110)
                            .font(.system(.caption, design: .monospaced))
                            .onChange(of: server.wrappedValue.path) { _, _ in onChange() }
                    }
                }
            }
            if kind != .fakeip && kind != .local {
                HStack {
                    Text(loc("Queries go through")).font(.caption2)
                        .foregroundStyle(.secondary)
                    detourPicker(server.detour)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Outbound a resolver's own queries take. Any outbound in the graph is
    /// valid, which is what makes "this resolver only over that server"
    /// expressible.
    private func detourPicker(_ selection: Binding<String>) -> some View {
        Picker("", selection: selection) {
            Text(loc("Default route")).tag("")
            Text(loc("Proxy")).tag(ProfileTags.defaultSelector)
            Text(loc("Direct")).tag(ProfileTags.direct)
            if !groups.isEmpty {
                Divider()
                ForEach(groups) { group in
                    Text(group.name.isEmpty ? loc("Group") : group.name)
                        .tag(ProfileTags.group(group.id))
                }
            }
            if !servers.isEmpty {
                Divider()
                ForEach(servers) { server in
                    Text(server.name).tag(ProfileTags.server(server.id))
                }
            }
            if !knownDetours.contains(selection.wrappedValue) {
                Divider()
                Text(loc("Missing outbound")).tag(selection.wrappedValue)
            }
        }
        .labelsHidden().fixedSize()
        .onChange(of: selection.wrappedValue) { _, _ in onChange() }
    }

    private var knownDetours: Set<String> {
        var tags: Set<String> = ["", ProfileTags.defaultSelector, ProfileTags.direct]
        tags.formUnion(groups.map { ProfileTags.group($0.id) })
        tags.formUnion(servers.map { ProfileTags.server($0.id) })
        return tags
    }

    // MARK: - Rules

    private var rulesSection: some View {
        Section {
            ForEach($dns.rules) { $rule in
                ruleCard($rule)
            }
            Button {
                dns.rules.append(DNSRule(name: "", serverTag: dns.servers.first?.tag ?? ""))
                onChange()
            } label: {
                Label(loc("Add DNS rule"), systemImage: "plus.circle")
            }
        } header: {
            Text(loc("DNS rules — first match wins"))
        } footer: {
            Text(loc("Same matchers as a routing rule, minus the ones that need an address: a name is being resolved, so there is no destination IP yet."))
                .font(.caption2)
        }
    }

    private func ruleCard(_ rule: Binding<DNSRule>) -> some View {
        let id = rule.wrappedValue.id
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Toggle("", isOn: rule.enabled)
                    .labelsHidden()
                    .onChange(of: rule.wrappedValue.enabled) { _, _ in onChange() }
                TextField(loc("Rule name"), text: rule.name)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: rule.wrappedValue.name) { _, _ in onChange() }
                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                if rule.wrappedValue.reject {
                    Text(loc("Refused")).font(.caption).foregroundStyle(.secondary)
                } else {
                    Picker("", selection: rule.serverTag) {
                        ForEach(dns.servers) { server in
                            Text(server.tag).tag(server.tag)
                        }
                    }
                    .labelsHidden().fixedSize()
                    .onChange(of: rule.wrappedValue.serverTag) { _, _ in onChange() }
                }
                Button(role: .destructive) {
                    dns.rules.removeAll { $0.id == id }
                    onChange()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(loc("Domains")).font(.caption2).foregroundStyle(.secondary)
                TokenChips(values: rule.domains,
                           placeholder: "example.com, geosite:google",
                           monospaced: true, onChange: onChange)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(loc("Apps")).font(.caption2).foregroundStyle(.secondary)
                TokenChips(values: rule.processNames,
                           placeholder: loc("Executable name"),
                           onChange: onChange)
            }
            HStack {
                Toggle(loc("Refuse these names"), isOn: rule.reject)
                    .toggleStyle(.checkbox)
                    .onChange(of: rule.wrappedValue.reject) { _, _ in onChange() }
                Spacer()
                Toggle(loc("Invert"), isOn: rule.invert)
                    .toggleStyle(.checkbox)
                    .onChange(of: rule.wrappedValue.invert) { _, _ in onChange() }
            }
        }
        .padding(.vertical, 4)
        .opacity(rule.wrappedValue.enabled ? 1 : 0.5)
    }

    // MARK: - Helpers

    private static let builtinTags: Set<String> = [
        DNSSettings.Builtin.remote,
        DNSSettings.Builtin.local,
        DNSSettings.Builtin.bootstrap,
        DNSSettings.Builtin.fakeIP
    ]

    private func uniqueTag() -> String {
        var index = 1
        while dns.servers.contains(where: { $0.tag == "dns-\(index)" }) { index += 1 }
        return "dns-\(index)"
    }
}
