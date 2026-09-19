import SwiftUI

/// Builds the groups a rule can point at.
///
/// A group is one outbound made of several servers — "Europe", "work", "the
/// two nodes that can reach the office". Rules name it instead of naming a
/// node, so replacing the node later does not mean rewriting the rules.
///
/// Membership is expressed one of two ways. A hand-picked group is a list you
/// add to, which suits the three nodes that can reach the office. An automatic
/// group states what it wants instead — this source, that country, that tag —
/// and is answered again on every refresh, which is the only way a group over a
/// subscription of fifty nodes stays correct when the provider adds a node.
struct ServerGroupsEditor: View {
    @Binding var groups: [ServerGroup]
    var servers: [ProxyConfig]
    /// Servers paired with their source, for answering an automatic group's
    /// query live while it is being written.
    var candidates: [GroupResolver.Candidate] = []
    var sources: [ListSource] = []
    var annotations: [UUID: NodeAnnotation] = [:]
    var onChange: () -> Void

    @Environment(Loc.self) private var loc

    var body: some View {
        // The empty state lives outside the form on purpose: a grouped Form
        // lays its rows out in a label/content column pair, which pushed the
        // whole placeholder off to one side instead of centring it.
        if groups.isEmpty {
            emptyState
        } else {
            form
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(loc("No groups yet."), systemImage: "square.stack.3d.up")
        } description: {
            Text(loc("A group behaves like one server: pick a member by hand, or let the fastest one win."))
        } actions: {
            VStack(spacing: 6) {
                Button(loc("Add group")) { addGroup() }
                    .glassProminentButton()
                Button(loc("Fastest of everything")) { addEverythingGroup() }
                    .buttonStyle(.link)
                    .help(loc("One group holding every server, measured and re-measured, with the quickest in use."))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var form: some View {
        Form {
            ForEach($groups) { $group in
                Section {
                    rows($group)
                } header: {
                    header($group)
                }
            }

            Section {
                Button { addGroup() } label: {
                    Label(loc("Add group"), systemImage: "plus")
                }
                .buttonStyle(.borderless)
                Button { addEverythingGroup() } label: {
                    Label(loc("Fastest of everything"), systemImage: "bolt.horizontal")
                }
                .buttonStyle(.borderless)
            } footer: {
                Text(loc("Groups also show up in the control API, so a dashboard — or an assistant — can switch the member without restarting the tunnel."))
                    .font(.caption2)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - One group

    private func header(_ group: Binding<ServerGroup>) -> some View {
        HStack(spacing: 6) {
            Image(systemName: group.wrappedValue.kind == .urltest
                  ? "bolt.horizontal" : "hand.point.up.left")
                .foregroundStyle(.secondary)
            Text(group.wrappedValue.name.isEmpty
                 ? loc("Group") : group.wrappedValue.name)
            Spacer()
            Button(role: .destructive) {
                let id = group.wrappedValue.id
                groups.removeAll { $0.id == id }
                onChange()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(loc("Remove"))
        }
    }

    @ViewBuilder
    private func rows(_ group: Binding<ServerGroup>) -> some View {
        TextField(loc("Name"), text: group.name)
            .onChange(of: group.wrappedValue.name) { _, _ in onChange() }

        Picker(loc("Picks"), selection: group.kind) {
            ForEach(ServerGroup.Kind.allCases) { kind in
                Text(loc(kind.title)).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: group.wrappedValue.kind) { _, _ in onChange() }

        Picker(loc("Members"), selection: membershipBinding(group)) {
            Text(loc("Chosen by hand")).tag(false)
            Text(loc("Everything that matches")).tag(true)
        }
        .pickerStyle(.segmented)

        if let query = group.wrappedValue.query {
            queryRows(group, query)
        } else {
            LabeledContent(loc("Members")) {
                membersColumn(group)
            }
        }

        if group.wrappedValue.kind == .selector, !members(of: group.wrappedValue).isEmpty {
            Picker(loc("Active member"), selection: group.selectedID) {
                Text(loc("First member")).tag(UUID?.none)
                ForEach(members(of: group.wrappedValue)) { server in
                    Text(server.name).tag(UUID?.some(server.id))
                }
            }
            .onChange(of: group.wrappedValue.selectedID) { _, _ in onChange() }
        }

        if group.wrappedValue.kind == .urltest {
            TextField(loc("Test URL"), text: group.testURL)
                .onChange(of: group.wrappedValue.testURL) { _, _ in onChange() }
            TextField(loc("Every"), text: group.interval, prompt: Text(verbatim: "3m"))
                .onChange(of: group.wrappedValue.interval) { _, _ in onChange() }
            TextField(loc("Tolerance, ms"), value: group.tolerance, format: .number)
                .onChange(of: group.wrappedValue.tolerance) { _, _ in onChange() }
        }
    }

    // MARK: - An automatic group

    /// Switching membership mode, without losing the hand-picked list: turning
    /// the query off restores whatever was there, because the resolver only
    /// ever rewrites `memberIDs` while a query exists.
    private func membershipBinding(_ group: Binding<ServerGroup>) -> Binding<Bool> {
        Binding(get: { group.wrappedValue.query != nil },
                set: { isAutomatic in
                    group.wrappedValue.query = isAutomatic ? GroupQuery() : nil
                    if !isAutomatic { group.wrappedValue.memberIDs = [] }
                    onChange()
                })
    }

    @ViewBuilder
    private func queryRows(_ group: Binding<ServerGroup>, _ query: GroupQuery) -> some View {
        let bound = Binding(get: { group.wrappedValue.query ?? GroupQuery() },
                            set: { group.wrappedValue.query = $0; onChange() })

        LabeledContent(loc("From")) {
            pickerMenu(title: sourcesLabel(query),
                       options: sources.map { ($0.id.uuidString, $0.name) },
                       chosen: Set(query.sourceIDs.map(\.uuidString))) { id in
                toggle(id, in: bound.sourceIDs.wrappedValue.map(\.uuidString)) { values in
                    bound.wrappedValue.sourceIDs = values.compactMap(UUID.init(uuidString:))
                }
            }
        }

        if !countriesInUse.isEmpty {
            LabeledContent(loc("Country")) {
                pickerMenu(title: query.countries.isEmpty
                           ? loc("Any") : query.countries.joined(separator: ", "),
                           options: countriesInUse.map { ($0, NodeFacets.flag(for: $0) + " " + NodeFacets.countryName(for: $0)) },
                           chosen: Set(query.countries)) { code in
                    toggle(code, in: bound.countries.wrappedValue) { bound.wrappedValue.countries = $0 }
                }
            }
        }

        if !tagsInUse.isEmpty {
            LabeledContent(loc("Tags")) {
                pickerMenu(title: query.tags.isEmpty
                           ? loc("Any") : query.tags.joined(separator: ", "),
                           options: tagsInUse.map { ($0, $0) },
                           chosen: Set(query.tags)) { tag in
                    toggle(tag, in: bound.tags.wrappedValue) { bound.wrappedValue.tags = $0 }
                }
            }
        }

        LabeledContent(loc("Protocol")) {
            pickerMenu(title: query.protocols.isEmpty
                       ? loc("Any")
                       : query.protocols.map(\.rawValue).joined(separator: ", "),
                       options: protocolsInUse.map { ($0.rawValue, $0.rawValue.uppercased()) },
                       chosen: Set(query.protocols.map(\.rawValue))) { raw in
                toggle(raw, in: bound.protocols.wrappedValue.map(\.rawValue)) { values in
                    bound.wrappedValue.protocols = values.compactMap(ProxyProtocol.init(rawValue:))
                }
            }
        }

        TextField(loc("Name contains"), text: bound.nameContains,
                  prompt: Text(loc("Any")))

        Toggle(loc("Include hidden servers"),
               isOn: Binding(get: { !bound.wrappedValue.excludeHidden },
                             set: { bound.wrappedValue.excludeHidden = !$0 }))

        let matched = matches(query)
        VStack(alignment: .leading, spacing: 2) {
            Text(String(format: loc("%d servers match right now"), matched.count))
                .font(.caption)
                .foregroundStyle(matched.isEmpty ? .red : .secondary)
            if !matched.isEmpty {
                Text(matched.prefix(6).map(\.name).joined(separator: " · ")
                     + (matched.count > 6 ? " …" : ""))
                    .font(.caption2).foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
    }

    /// A menu of checkable values. Everything an automatic group filters on is
    /// the same shape — several alternatives, none of them required — so they
    /// share one control rather than four that drift apart.
    private func pickerMenu(title: String,
                            options: [(String, String)],
                            chosen: Set<String>,
                            toggle: @escaping (String) -> Void) -> some View {
        Menu(title) {
            ForEach(options, id: \.0) { value, label in
                Button {
                    toggle(value)
                } label: {
                    Label(label, systemImage: chosen.contains(value) ? "checkmark" : "")
                }
            }
        }
        .menuStyle(.button)
        .glassButton()
        .controlSize(.small)
        .fixedSize()
    }

    private func toggle(_ value: String, in current: [String],
                        write: ([String]) -> Void) {
        var next = current
        if let index = next.firstIndex(of: value) {
            next.remove(at: index)
        } else {
            next.append(value)
        }
        write(next)
    }

    private func sourcesLabel(_ query: GroupQuery) -> String {
        guard !query.sourceIDs.isEmpty else { return loc("Every source") }
        let names = query.sourceIDs.compactMap { id in
            sources.first { $0.id == id }?.name
        }
        return names.isEmpty ? loc("Every source") : names.joined(separator: ", ")
    }

    private func matches(_ query: GroupQuery) -> [ProxyConfig] {
        let ids = Set(GroupResolver.members(of: query, in: candidates,
                                            annotations: annotations))
        return candidates.map(\.server).filter { ids.contains($0.id) }
    }

    private var countriesInUse: [String] {
        var seen: [String] = []
        for candidate in candidates {
            let name = annotations[candidate.server.id]?.nameOverride ?? candidate.server.name
            guard let code = NodeFacets.country(in: name, proto: candidate.server.proto),
                  !seen.contains(code) else { continue }
            seen.append(code)
        }
        return seen.sorted()
    }

    private var tagsInUse: [String] {
        Array(Set(annotations.values.flatMap(\.tags))).sorted()
    }

    private var protocolsInUse: [ProxyProtocol] {
        var seen: [ProxyProtocol] = []
        for candidate in candidates where !seen.contains(candidate.server.proto) {
            seen.append(candidate.server.proto)
        }
        return seen
    }

    /// The member list plus the menu that grows it. Members keep their order,
    /// which is what a URL-test group falls back to when every probe fails.
    @ViewBuilder
    private func membersColumn(_ group: Binding<ServerGroup>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            let chosen = members(of: group.wrappedValue)
            if chosen.isEmpty {
                Text(servers.isEmpty ? loc("Add a server first.") : loc("No members yet."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(chosen) { server in
                HStack(spacing: 6) {
                    Text(server.name).lineLimit(1)
                    Spacer(minLength: 8)
                    Button {
                        let id = server.id
                        group.wrappedValue.memberIDs.removeAll { $0 == id }
                        if group.wrappedValue.selectedID == id {
                            group.wrappedValue.selectedID = nil
                        }
                        onChange()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(loc("Remove"))
                }
            }

            let available = servers.filter { !group.wrappedValue.memberIDs.contains($0.id) }
            Menu {
                if available.isEmpty {
                    Text(loc("Every server is already a member."))
                } else {
                    Button(loc("Add all")) {
                        group.wrappedValue.memberIDs.append(contentsOf: available.map(\.id))
                        onChange()
                    }
                    Divider()
                    ForEach(available) { server in
                        Button(server.name) {
                            group.wrappedValue.memberIDs.append(server.id)
                            onChange()
                        }
                    }
                }
            } label: {
                Label(loc("Add member"), systemImage: "plus")
            }
            .menuStyle(.button)
            .glassButton()
            .controlSize(.small)
            .fixedSize()
            .disabled(servers.isEmpty)
        }
    }

    // MARK: - Helpers

    /// Members in the group's own order; IDs that no longer resolve are skipped
    /// here exactly as they are when the profile is built.
    private func members(of group: ServerGroup) -> [ProxyConfig] {
        group.memberIDs.compactMap { id in servers.first { $0.id == id } }
    }

    private func addGroup() {
        var group = ServerGroup(name: "")
        group.memberIDs = []
        groups.append(group)
        onChange()
    }

    /// The group a sing-box-launcher profile calls `proxy-out`: every node,
    /// measured, the quickest in use. It is what most people want and what
    /// nobody wants to assemble by hand from fifty entries.
    private func addEverythingGroup() {
        var group = ServerGroup(name: loc("Fastest"), kind: .urltest)
        group.query = GroupQuery()
        groups.append(group)
        onChange()
    }
}
