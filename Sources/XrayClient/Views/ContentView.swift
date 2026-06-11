import SwiftUI

struct ContentView: View {
    @Environment(ServerStore.self) private var store
    @Environment(ConnectionManager.self) private var connection
    @Environment(PingTester.self) private var pinger
    @Environment(Loc.self) private var loc

    @State private var showAddSheet = false
    @State private var showSubSheet = false
    @State private var showSettings = false
    @State private var showLog = false
    @State private var isRefreshing = false
    @State private var searchText = ""
    @State private var aliveOnly = false
    @State private var sortByPing = false
    /// IDs selected for multi-delete in the Manual group.
    @State private var selectedForDeletion: Set<UUID> = []
    @State private var selectionMode = false

    /// True when the active tunnel is TUN — ping probes need host-routes then.
    private var tunActive: Bool {
        connection.mode == .tun && connection.isConnected
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            serverList
            if showLog {
                Divider()
                LogPane(text: connection.logs)
                    .frame(height: 140)
            }
            Divider()
            footer
        }
        .sheet(isPresented: $showAddSheet) { AddServerSheet() }
        .sheet(isPresented: $showSubSheet) { SubscriptionSheet() }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
    }

    // MARK: - Search & filter

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search servers…", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
            Divider().frame(height: 16)
            Toggle("Alive", isOn: $aliveOnly)
                .toggleStyle(.button).controlSize(.small)
                .help("Show only servers that responded to the last ping test")
            Toggle("By ping", isOn: $sortByPing)
                .toggleStyle(.button).controlSize(.small)
                .help("Sort servers by latency within each group")
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
    }

    // MARK: - Header (status + connect)

    private var header: some View {
        let selected = store.server(withID: store.selectedServerID)
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(statusColor.opacity(0.18)).frame(width: 44, height: 44)
                Image(systemName: connection.isConnected ? "shield.lefthalf.filled" : "shield.slash")
                    .font(.system(size: 20))
                    .foregroundStyle(statusColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.state.label)
                    .font(.headline)
                    .foregroundStyle(statusColor)
                if connection.isConnected {
                    Text("\(connection.activeServerName) · \(connection.uptimeText)")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else if let selected {
                    Text(selected.name).font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("Select a server").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            modePicker
            connectButton(selected: selected)
        }
        .padding(14)
    }

    private var modePicker: some View {
        @Bindable var conn = connection
        return Picker("", selection: $conn.mode) {
            ForEach(TunnelMode.allCases) { m in
                Text(m == .systemProxy ? "Proxy" : "TUN").tag(m)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize()
        .onChange(of: connection.mode) { _, newMode in
            store.settings.mode = newMode
            store.save()
        }
        .disabled(connection.isConnected)
        .help(connection.mode.subtitle)
    }

    @ViewBuilder
    private func connectButton(selected: ProxyConfig?) -> some View {
        if connection.isConnected || connection.state == .connecting {
            Button(role: .destructive) { connection.disconnect() } label: {
                Label("Disconnect", systemImage: "stop.fill").frame(minWidth: 96)
            }
            .controlSize(.large).buttonStyle(.borderedProminent).tint(.red)
        } else {
            Button {
                if let s = selected { connection.connect(to: s) }
            } label: {
                Label("Connect", systemImage: "bolt.fill").frame(minWidth: 96)
            }
            .controlSize(.large).buttonStyle(.borderedProminent)
            .disabled(selected == nil)
        }
    }

    // MARK: - Server list (collapsible groups)

    private var serverList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if store.subscriptions.isEmpty {
                    emptyState
                }
                ForEach(store.subscriptions) { sub in
                    SubscriptionGroupView(
                        subscription: sub,
                        searchText: searchText,
                        aliveOnly: aliveOnly,
                        sortByPing: sortByPing,
                        selectionMode: selectionMode && sub.isManual,
                        selectedForDeletion: $selectedForDeletion
                    )
                }
            }
            .padding(12)
        }
        .frame(minHeight: 240)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray").font(.system(size: 34)).foregroundStyle(.secondary)
            Text(loc("No servers yet")).font(.headline)
            Text(loc("Add a subscription or paste a link to get started."))
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(loc("Add Subscription")) { showSubSheet = true }
                Button(loc("Paste Link")) { showAddSheet = true }
            }.padding(.top, 4)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    // MARK: - Footer (toolbar)

    private var hasManualServers: Bool {
        store.subscriptions.contains { $0.isManual && !$0.servers.isEmpty }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if selectionMode { deletionBar }
            HStack(spacing: 12) {
                Button { showSubSheet = true } label: {
                    Label(loc("Subscription"), systemImage: "arrow.down.circle")
                }
                Button { showAddSheet = true } label: {
                    Label(loc("Add Link"), systemImage: "plus")
                }
                Button {
                    Task { isRefreshing = true; await SubscriptionService.refreshAll(store); isRefreshing = false }
                } label: {
                    if isRefreshing { ProgressView().controlSize(.small) }
                    else { Label(loc("Refresh"), systemImage: "arrow.clockwise") }
                }
                .disabled(isRefreshing)

                Button {
                    pinger.test(store.allServers, tunActive: tunActive)
                } label: {
                    Label(loc("Test Ping"), systemImage: "speedometer")
                }
                .disabled(store.allServers.isEmpty)

                if hasManualServers {
                    Button {
                        selectionMode.toggle()
                        selectedForDeletion.removeAll()
                    } label: {
                        Label(loc("Select"), systemImage: selectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                }

                Spacer()

                Toggle(isOn: $showLog) { Label(loc("Log"), systemImage: "text.alignleft") }
                    .toggleStyle(.button)
                Button { showSettings = true } label: {
                    Label(loc("Settings"), systemImage: "gearshape")
                }
            }
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    /// Bar shown in multi-select mode: select-all / delete-selected / cancel.
    private var deletionBar: some View {
        // The active server can't be deleted while connected.
        let activeID = connection.isConnected ? connection.activeServerID : nil
        let manualIDs = Set(store.subscriptions.filter(\.isManual)
            .flatMap { $0.servers.map(\.id) })
            .subtracting(activeID.map { [$0] } ?? [])
        let allSelected = !manualIDs.isEmpty && selectedForDeletion == manualIDs
        return HStack(spacing: 12) {
            Button(allSelected ? loc("Deselect All") : loc("Select All")) {
                selectedForDeletion = allSelected ? [] : manualIDs
            }
            Text("\(selectedForDeletion.count)")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button(role: .destructive) {
                // Never delete the active server even if somehow selected.
                store.removeServers(ids: selectedForDeletion.subtracting(activeID.map { [$0] } ?? []))
                selectedForDeletion.removeAll()
                selectionMode = false
            } label: {
                Label(loc("Delete Selected"), systemImage: "trash")
            }
            .disabled(selectedForDeletion.isEmpty)
            Button(loc("Cancel")) {
                selectionMode = false
                selectedForDeletion.removeAll()
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Color.primary.opacity(0.04))
    }

    private var statusColor: Color {
        switch connection.state {
        case .connected:  return .green
        case .connecting: return .orange
        case .failed:     return .red
        case .disconnected: return .secondary
        }
    }
}

// MARK: - Subscription group (collapsible)

struct SubscriptionGroupView: View {
    @Environment(ServerStore.self) private var store
    @Environment(ConnectionManager.self) private var connection
    @Environment(PingTester.self) private var pinger
    @Environment(Loc.self) private var loc
    let subscription: Subscription
    var searchText: String = ""
    var aliveOnly: Bool = false
    var sortByPing: Bool = false
    var selectionMode: Bool = false
    var selectedForDeletion: Binding<Set<UUID>> = .constant([])

    /// Servers after applying search text, alive filter, and ping sort.
    private var visibleServers: [ProxyConfig] {
        var list = subscription.servers
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter { $0.name.lowercased().contains(q)
                || $0.address.lowercased().contains(q) }
        }
        if aliveOnly {
            list = list.filter {
                if let outer = pinger.latency(for: $0.id), outer != nil { return true }
                return false
            }
        }
        if sortByPing {
            list.sort { a, b in
                let la = (pinger.latency(for: a.id) ?? nil) ?? Int.max
                let lb = (pinger.latency(for: b.id) ?? nil) ?? Int.max
                return la < lb
            }
        }
        return list
    }

    /// Hide groups entirely filtered out by an active search/alive filter.
    private var isHidden: Bool {
        (!searchText.isEmpty || aliveOnly) && visibleServers.isEmpty
    }

    var body: some View {
        if isHidden {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                groupHeader
                if !subscription.isCollapsed {
                    ForEach(visibleServers) { server in
                        let isActive = connection.activeServerID == server.id
                        let isLocked = isActive && connection.isConnected
                        HStack(spacing: 8) {
                            if selectionMode {
                                Image(systemName: isLocked ? "lock.fill"
                                      : (selectedForDeletion.wrappedValue.contains(server.id)
                                         ? "checkmark.circle.fill" : "circle"))
                                    .foregroundStyle(isLocked ? .secondary
                                                     : (selectedForDeletion.wrappedValue.contains(server.id)
                                                        ? Color.accentColor : .secondary))
                                    .padding(.leading, 14)
                            }
                            ServerRow(
                                server: server,
                                isSelected: store.selectedServerID == server.id,
                                isActive: isActive,
                                latency: pinger.latency(for: server.id),
                                isTesting: pinger.isTesting(server.id)
                            )
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectionMode {
                                if !isLocked { toggleSelection(server.id) }
                            } else { handleTap(server) }
                        }
                        .contextMenu {
                            Button(connection.isConnected ? loc("Switch here") : loc("Connect")) {
                                store.select(server.id); connection.connect(to: server)
                            }
                            Button(loc("Test ping")) { pinger.test([server], tunActive: connection.mode == .tun && connection.isConnected) }
                            if subscription.isManual && !isLocked {
                                Divider()
                                Button(loc("Delete"), role: .destructive) {
                                    store.removeServer(id: server.id)
                                }
                            }
                        }
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedForDeletion.wrappedValue.contains(id) {
            selectedForDeletion.wrappedValue.remove(id)
        } else {
            selectedForDeletion.wrappedValue.insert(id)
        }
    }

    /// Disconnected: tap = select only. Connected: tap = switch immediately.
    private func handleTap(_ server: ProxyConfig) {
        store.select(server.id)
        if connection.isConnected {
            connection.connect(to: server)
        }
    }

    private var groupHeader: some View {
        HStack(spacing: 10) {
            // Larger chevron hit target with its own background.
            Button {
                store.toggleCollapsed(id: subscription.id)
            } label: {
                Image(systemName: subscription.isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.secondary.opacity(0.12)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(subscription.name).font(.headline)
                    Text("\(subscription.servers.count)")
                        .font(.caption2).foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                }
                if let note = subscription.note, !note.isEmpty {
                    Text(note)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                trafficLine
            }
            Spacer()
            Menu {
                Button("Test ping (group)") { pinger.test(subscription.servers, tunActive: connection.mode == .tun && connection.isConnected) }
                if !subscription.isManual {
                    Divider()
                    Button("Refresh now") {
                        Task { await SubscriptionService.refresh(subscription, into: store) }
                    }
                    Toggle("Auto-update", isOn: Binding(
                        get: { subscription.autoUpdate },
                        set: { store.setAutoUpdate($0, id: subscription.id) }
                    ))
                    Divider()
                    // Can't remove a subscription that holds the active server.
                    let holdsActive = connection.isConnected
                        && subscription.servers.contains { $0.id == connection.activeServerID }
                    Button("Remove", role: .destructive) {
                        store.removeSubscription(id: subscription.id)
                    }
                    .disabled(holdsActive)
                }
            } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 16))
            }
            .menuStyle(.borderlessButton).fixedSize().frame(width: 28)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { store.toggleCollapsed(id: subscription.id) }
    }

    @ViewBuilder
    private var trafficLine: some View {
        if let used = subscription.usedBytes, let total = subscription.totalBytes {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(ByteFormat.string(used)) / \(ByteFormat.string(total))")
                    if let exp = subscription.expiresAt {
                        Text("· until \(exp.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                .font(.caption2).foregroundStyle(.secondary)
                if let frac = subscription.usageFraction {
                    ProgressView(value: frac)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 220)
                        .tint(frac > 0.9 ? .red : .accentColor)
                }
            }
        } else if let exp = subscription.expiresAt {
            Text("Expires \(exp.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Server row

struct ServerRow: View {
    let server: ProxyConfig
    let isSelected: Bool
    let isActive: Bool
    let latency: Int??     // outer nil = untested; inner nil = unreachable
    let isTesting: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isActive ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 7, height: 7)
            Text(server.name).lineLimit(1)
            Spacer()
            latencyBadge
            Text(server.proto.rawValue.uppercased())
                .font(.caption2).foregroundStyle(.secondary)
            if isActive {
                Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .padding(.leading, 18)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
    }

    @ViewBuilder
    private var latencyBadge: some View {
        if isTesting {
            ProgressView().controlSize(.mini)
        } else if let outer = latency {
            if let ms = outer {
                Text("\(ms) ms")
                    .font(.caption2).monospacedDigit()
                    .foregroundStyle(latencyColor(ms))
            } else {
                Text("timeout")
                    .font(.caption2).foregroundStyle(.red)
            }
        }
    }

    private func latencyColor(_ ms: Int) -> Color {
        switch ms {
        case ..<150:  return .green
        case ..<350:  return .orange
        default:      return .red
        }
    }
}

// MARK: - Compact log pane

struct LogPane: View {
    let text: String
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(text.isEmpty ? "No logs yet." : text)
                    .font(.system(.caption2, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
                    .id("bottom")
            }
            .onChange(of: text) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}
