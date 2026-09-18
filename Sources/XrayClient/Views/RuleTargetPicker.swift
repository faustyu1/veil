import SwiftUI

/// Picks where a rule sends its traffic: one of the three built-ins, a specific
/// server, or a group.
///
/// Servers and groups are what make per-process routing worth having — without
/// them every rule can only say "proxy or not". The list is flat with section
/// headers because a rule editor row has no space for a nested menu.
struct RuleTargetPicker: View {
    @Binding var target: RuleTarget
    var servers: [ProxyConfig]
    var groups: [ServerGroup]
    var onChange: () -> Void = {}

    var body: some View {
        Picker("", selection: $target) {
            Text("Proxy").tag(RuleTarget.proxy)
            Text("Direct").tag(RuleTarget.direct)
            Text("Block").tag(RuleTarget.block)
            if !groups.isEmpty {
                Divider()
                ForEach(groups) { group in
                    Text(group.name.isEmpty ? "Group" : group.name)
                        .tag(RuleTarget.group(group.id))
                }
            }
            if !servers.isEmpty {
                Divider()
                ForEach(servers) { server in
                    Text(server.name).tag(RuleTarget.server(server.id))
                }
            }
            // A target whose server or group was deleted would otherwise have
            // no matching tag and the picker would show blank.
            if let orphan = orphanLabel {
                Divider()
                Text(orphan).tag(target)
            }
        }
        .labelsHidden()
        .fixedSize()
        .onChange(of: target) { _, _ in onChange() }
    }

    private var orphanLabel: String? {
        switch target {
        case .server(let id):
            return servers.contains { $0.id == id } ? nil : "Missing server"
        case .group(let id):
            return groups.contains { $0.id == id } ? nil : "Missing group"
        case .proxy, .direct, .block:
            return nil
        }
    }
}

extension RuleTarget {
    /// Display name, resolved against the current servers and groups.
    func title(servers: [ProxyConfig], groups: [ServerGroup]) -> String {
        if let builtIn = builtInTitle { return builtIn }
        switch self {
        case .server(let id):
            return servers.first { $0.id == id }?.name ?? "Missing server"
        case .group(let id):
            return groups.first { $0.id == id }?.name ?? "Missing group"
        default:
            return "Proxy"
        }
    }
}
