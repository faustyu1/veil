import SwiftUI

/// Builds the groups a rule can point at.
///
/// A group is one outbound made of several servers — "Europe", "work", "the
/// two nodes that can reach the office". Rules name it instead of naming a
/// node, so replacing the node later does not mean rewriting the rules.
struct ServerGroupsEditor: View {
    @Binding var groups: [ServerGroup]
    var servers: [ProxyConfig]
    var onChange: () -> Void

    @Environment(Loc.self) private var loc
    @State private var expanded: Set<UUID> = []

    var body: some View {
        Form {
            Section {
                if groups.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc("No groups yet.")).font(.callout)
                        Text(loc("A group behaves like one server: pick a member by hand, or let the fastest one win."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                ForEach($groups) { $group in
                    card($group)
                }
                Button {
                    var group = ServerGroup(name: "")
                    group.memberIDs = []
                    groups.append(group)
                    expanded.insert(group.id)
                    onChange()
                } label: {
                    Label(loc("Add group"), systemImage: "plus.circle")
                }
            } header: {
                Text(loc("Groups"))
            } footer: {
                Text(loc("Groups also show up in the control API, so a dashboard — or an assistant — can switch the member without restarting the tunnel."))
                    .font(.caption2)
            }
        }
        .formStyle(.grouped)
    }

    private func card(_ group: Binding<ServerGroup>) -> some View {
        let id = group.wrappedValue.id
        return DisclosureGroup(isExpanded: Binding(
            get: { expanded.contains(id) },
            set: { open in
                if open { expanded.insert(id) } else { expanded.remove(id) }
            }
        )) {
            VStack(alignment: .leading, spacing: 8) {
                Picker(loc("Picks"), selection: group.kind) {
                    ForEach(ServerGroup.Kind.allCases) { kind in
                        Text(loc(kind.title)).tag(kind)
                    }
                }
                .onChange(of: group.wrappedValue.kind) { _, _ in onChange() }
                Text(loc(group.wrappedValue.kind.subtitle))
                    .font(.caption2).foregroundStyle(.secondary)

                membersList(group)

                if group.wrappedValue.kind == .urltest {
                    HStack {
                        Text(loc("Test URL")).font(.caption).foregroundStyle(.secondary)
                        TextField("", text: group.testURL)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: group.wrappedValue.testURL) { _, _ in onChange() }
                    }
                    HStack {
                        Text(loc("Every")).font(.caption).foregroundStyle(.secondary)
                        TextField("3m", text: group.interval)
                            .textFieldStyle(.roundedBorder).frame(width: 70)
                            .onChange(of: group.wrappedValue.interval) { _, _ in onChange() }
                        Text(loc("Tolerance, ms")).font(.caption).foregroundStyle(.secondary)
                        TextField("50", value: group.tolerance, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 70)
                            .onChange(of: group.wrappedValue.tolerance) { _, _ in onChange() }
                    }
                }
            }
            .padding(.top, 4)
        } label: {
            HStack {
                Image(systemName: group.wrappedValue.kind == .urltest
                      ? "bolt.horizontal" : "hand.point.up.left")
                    .foregroundStyle(.secondary)
                TextField(loc("Group name"), text: group.name)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: group.wrappedValue.name) { _, _ in onChange() }
                Text("\(group.wrappedValue.memberIDs.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Button(role: .destructive) {
                    groups.removeAll { $0.id == id }
                    onChange()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func membersList(_ group: Binding<ServerGroup>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(loc("Members")).font(.caption2).foregroundStyle(.secondary)
            if servers.isEmpty {
                Text(loc("Add a server first.")).font(.caption)
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(servers) { server in
                        memberRow(server, group: group)
                    }
                }
            }
            .frame(maxHeight: 180)
            .overlay(RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1))
        }
    }

    private func memberRow(_ server: ProxyConfig, group: Binding<ServerGroup>) -> some View {
        let isMember = group.wrappedValue.memberIDs.contains(server.id)
        let isSelected = group.wrappedValue.selectedID == server.id
        return HStack(spacing: 8) {
            Button {
                if isMember {
                    let id = server.id
                    group.wrappedValue.memberIDs.removeAll { $0 == id }
                    if group.wrappedValue.selectedID == id {
                        group.wrappedValue.selectedID = nil
                    }
                } else {
                    group.wrappedValue.memberIDs.append(server.id)
                }
                onChange()
            } label: {
                Image(systemName: isMember ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isMember ? Color.accentColor : .secondary)
            }
            .buttonStyle(.borderless)

            Text(server.name).font(.caption).lineLimit(1)
            Spacer()
            // Only a manual group has something to pick.
            if isMember && group.wrappedValue.kind == .selector {
                Button {
                    group.wrappedValue.selectedID = isSelected ? nil : server.id
                    onChange()
                } label: {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                }
                .buttonStyle(.borderless)
                .help(loc("Use this member"))
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
    }
}
