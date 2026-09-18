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

    /// One section per resolver.
    ///
    /// Each field is a `LabeledContent` row rather than a `TextField` with a
    /// title: a titled field inside a grouped Form has the label lifted into
    /// the row and the value pushed to the far edge, which is how the name and
    /// the path ended up reading as two separate things.
    @ViewBuilder
    private var serversSection: some View {
        ForEach($dns.servers) { $server in
            Section {
                serverRows($server)
            } header: {
                serverHeader($server)
            }
        }
        Section {
            Button {
                dns.servers.append(DNSServerEntry(tag: uniqueTag(), kind: .https,
                                                  server: "", path: "/dns-query"))
                onChange()
            } label: {
                Label(loc("Add resolver"), systemImage: "plus")
            }
            .buttonStyle(.borderless)
        }
    }

    private func serverHeader(_ server: Binding<DNSServerEntry>) -> some View {
        let id = server.wrappedValue.id
        let isBuiltin = DNSEditor.builtinTags.contains(server.wrappedValue.tag)
        return HStack(spacing: 6) {
            Image(systemName: "globe").foregroundStyle(.secondary)
            Text(server.wrappedValue.tag.isEmpty
                 ? loc("Resolver") : server.wrappedValue.tag)
            Spacer()
            if !isBuiltin {
                Button(role: .destructive) {
                    dns.servers.removeAll { $0.id == id }
                    onChange()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help(loc("Remove"))
            }
        }
    }

    @ViewBuilder
    private func serverRows(_ server: Binding<DNSServerEntry>) -> some View {
        let kind = server.wrappedValue.kind
        let isBuiltin = DNSEditor.builtinTags.contains(server.wrappedValue.tag)

        LabeledContent(loc("Name")) {
            TextField("", text: server.tag)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                // Renaming a built-in would orphan the rules and the bootstrap
                // lookup that name it.
                .disabled(isBuiltin)
                .onChange(of: server.wrappedValue.tag) { _, _ in onChange() }
        }

        Picker(loc("Protocol"), selection: server.kind) {
            ForEach(DNSServerEntry.Kind.allCases) { k in
                Text(loc(k.title)).tag(k)
            }
        }
        .onChange(of: server.wrappedValue.kind) { _, _ in onChange() }

        if kind.needsServer {
            LabeledContent(loc("Host or IP")) {
                TextField("1.1.1.1", text: server.server)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: 240)
                    .onChange(of: server.wrappedValue.server) { _, _ in onChange() }
            }
            if kind.needsPath {
                LabeledContent(loc("Path")) {
                    TextField("/dns-query", text: server.path)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: 160)
                        .onChange(of: server.wrappedValue.path) { _, _ in onChange() }
                }
            }
        }

        if kind != .fakeip && kind != .local {
            LabeledContent(loc("Queries go through")) {
                detourPicker(server.detour)
            }
        }
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

    @ViewBuilder
    private var rulesSection: some View {
        Section {
            EmptyView()
        } header: {
            Text(loc("DNS rules — first match wins"))
        } footer: {
            Text(loc("Same matchers as a routing rule, minus the ones that need an address: a name is being resolved, so there is no destination IP yet."))
                .font(.caption2)
        }
        ForEach($dns.rules) { $rule in
            Section {
                ruleRows($rule)
            } header: {
                ruleHeader($rule)
            }
        }
        Section {
            Button {
                dns.rules.append(DNSRule(name: "", serverTag: dns.servers.first?.tag ?? ""))
                onChange()
            } label: {
                Label(loc("Add DNS rule"), systemImage: "plus")
            }
            .buttonStyle(.borderless)
        }
    }

    private func ruleHeader(_ rule: Binding<DNSRule>) -> some View {
        let id = rule.wrappedValue.id
        return HStack(spacing: 8) {
            Toggle("", isOn: rule.enabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .onChange(of: rule.wrappedValue.enabled) { _, _ in onChange() }
            Text(rule.wrappedValue.name.isEmpty
                 ? loc("Rule name") : rule.wrappedValue.name)
            Spacer()
            Button(role: .destructive) {
                dns.rules.removeAll { $0.id == id }
                onChange()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(loc("Remove"))
        }
    }

    @ViewBuilder
    private func ruleRows(_ rule: Binding<DNSRule>) -> some View {
        LabeledContent(loc("Name")) {
            TextField("", text: rule.name)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)
                .onChange(of: rule.wrappedValue.name) { _, _ in onChange() }
        }

        if rule.wrappedValue.reject {
            LabeledContent(loc("Answer with")) {
                Text(loc("Refused")).foregroundStyle(.secondary)
            }
        } else {
            Picker(loc("Answer with"), selection: rule.serverTag) {
                ForEach(dns.servers) { server in
                    Text(server.tag).tag(server.tag)
                }
            }
            .onChange(of: rule.wrappedValue.serverTag) { _, _ in onChange() }
        }

        LabeledContent(loc("Domains")) {
            TokenChips(values: rule.domains,
                       placeholder: "example.com, geosite:google",
                       monospaced: true, onChange: onChange)
        }
        LabeledContent(loc("Apps")) {
            TokenChips(values: rule.processNames,
                       placeholder: loc("Executable name"),
                       onChange: onChange)
        }

        Toggle(loc("Refuse these names"), isOn: rule.reject)
            .onChange(of: rule.wrappedValue.reject) { _, _ in onChange() }
        Toggle(loc("Invert"), isOn: rule.invert)
            .onChange(of: rule.wrappedValue.invert) { _, _ in onChange() }
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
