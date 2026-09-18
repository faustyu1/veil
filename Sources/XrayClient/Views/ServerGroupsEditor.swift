import SwiftUI

/// Builds the groups a rule can point at.
///
/// A group is one outbound made of several servers — "Europe", "work", "the
/// two nodes that can reach the office". Rules name it instead of naming a
/// node, so replacing the node later does not mean rewriting the rules.
///
/// Membership is expressed as a list you add to, not as a checklist of every
/// server that exists: a subscription can hold a hundred nodes, and a group
/// usually holds three.
struct ServerGroupsEditor: View {
    @Binding var groups: [ServerGroup]
    var servers: [ProxyConfig]
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
            Button(loc("Add group")) { addGroup() }
                .glassProminentButton()
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

        LabeledContent(loc("Members")) {
            membersColumn(group)
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
}
