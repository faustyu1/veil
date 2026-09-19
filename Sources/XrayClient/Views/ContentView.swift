import SwiftUI

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(ServerStore.self) private var store
    @Environment(ConnectionManager.self) private var connection
    @Environment(PingTester.self) private var pinger
    @Environment(Loc.self) private var loc

    @State private var showAddSheet = false
    @State private var showLog = false
    @State private var isRefreshing = false
    @State private var searchText = ""
    @State private var aliveOnly = false
    @State private var sortByPing = false
    /// IDs selected for multi-delete in the Manual group.
    @State private var selectedForDeletion: Set<UUID> = []
    @State private var selectionMode = false
    /// True when a helper is installed but pinned to a different build of Veil.
    @State private var helperStale = false
    @State private var helperBusy = false

    /// True when the active tunnel is TUN — ping probes need host-routes then.
    private var tunActive: Bool {
        connection.mode == .tun && connection.isConnected
    }

    /// Drives keyboard focus so arrow keys / Enter target the server list.
    @FocusState private var listFocused: Bool

    /// Servers in on-screen order across all groups, honouring collapse state,
    /// search text, the alive filter, and ping sort. This is the order the
    /// up/down arrow keys walk through.
    private var navigableServers: [ProxyConfig] {
        store.subscriptions.flatMap { sub -> [ProxyConfig] in
            sub.isCollapsed ? [] : Self.filterServers(
                sub.servers, search: searchText, aliveOnly: aliveOnly,
                sortByPing: sortByPing, pinger: pinger)
        }
    }

    /// Shared filter/sort used by both the keyboard navigation order and the
    /// per-group views, so the two never drift apart.
    static func filterServers(_ servers: [ProxyConfig], search: String,
                              aliveOnly: Bool, sortByPing: Bool,
                              pinger: PingTester) -> [ProxyConfig] {
        var list = servers
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
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

    /// Moves the selection up or down the visible list. Selecting a server while
    /// connected switches to it immediately (matching tap behaviour); while
    /// disconnected it just highlights, and Enter connects.
    private func moveSelection(by delta: Int) {
        let list = navigableServers
        guard !list.isEmpty else { return }
        let currentIdx = list.firstIndex { $0.id == store.selectedServerID }
        let nextIdx: Int
        if let currentIdx {
            nextIdx = min(max(currentIdx + delta, 0), list.count - 1)
        } else {
            // No selection yet: down picks the first, up picks the last.
            nextIdx = delta > 0 ? 0 : list.count - 1
        }
        store.select(list[nextIdx].id)
    }

    /// Connects to the currently-selected server (Enter / Return).
    private func connectSelected() {
        if let s = store.server(withID: store.selectedServerID) {
            connection.connect(to: s)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            staleHelperBanner
            searchBar
            serverList
            if showLog {
                LogPane(text: connection.logs, onClear: { connection.clearLogs() })
                    .frame(minHeight: 80, maxHeight: 168)
            }
            Divider()
            footer
        }
        .sheet(isPresented: $showAddSheet) { AddServerSheet() }
        // Measure once on the first appearance, so the list carries latencies
        // without the user having to know a Test Ping button exists.
        .task { pingAllIfUntested() }
        .task { await refreshHelperStaleness() }
    }

    // MARK: - Stale helper

    /// Says so when the helper refuses this build, and offers the one fix.
    ///
    /// The helper pins its client by ad-hoc code hash, which changes with every
    /// build — including the one an in-app update installs. TUN then cannot
    /// start at all, and the only clue is a connection that never comes up, so
    /// this cannot wait for the user to open Settings and read the helper row.
    @ViewBuilder
    private var staleHelperBanner: some View {
        if helperStale, store.settings.mode == .tun {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc("Helper needs reinstalling"))
                        .font(.callout)
                    Text(loc("The installed helper was pinned to an older build of Veil and refuses this one, so TUN cannot start."))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if helperBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Button(loc("Reinstall")) { reinstallHelper() }
                        .glassProminentButton()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.orange.opacity(0.12))
            Divider()
        }
    }

    private func refreshHelperStaleness() async {
        // Both calls block on an XPC round trip, so they stay off the main
        // thread — this runs while the window is drawing itself.
        helperStale = await Task.detached(priority: .utility) {
            !TunManager.isHelperInstalled && PrivilegedHelper.isInstalled
        }.value
    }

    private func reinstallHelper() {
        helperBusy = true
        Task.detached(priority: .userInitiated) {
            try? TunManager.installHelper()
            let stale = !TunManager.isHelperInstalled && PrivilegedHelper.isInstalled
            await MainActor.run {
                helperStale = stale
                helperBusy = false
            }
        }
    }

    // MARK: - Search & filter

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(loc("Search servers…"), text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
            Divider().frame(height: 16)
            Toggle(loc("Alive"), isOn: $aliveOnly)
                .glassToggle().controlSize(.small)
                .help(loc("Show only servers that answered a ping. Turning this on measures them first."))
                // Without this the filter empties the whole list on a fresh
                // launch: nothing has been measured yet, so nothing is "alive".
                .onChange(of: aliveOnly) { _, on in
                    if on { pingAllIfUntested() }
                }
            Toggle(loc("By ping"), isOn: $sortByPing)
                .glassToggle().controlSize(.small)
                .help(loc("Sort servers by latency within each group"))
                .onChange(of: sortByPing) { _, on in
                    if on { pingAllIfUntested() }
                }
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
    }

    /// Measures every server, unless a measurement is already there or running.
    /// Both list filters are meaningless without one, so they ask for it rather
    /// than showing an empty list and leaving the user to guess why.
    private func pingAllIfUntested() {
        guard !pinger.hasResults, !pinger.isBusy else { return }
        pinger.test(store.allServers, tunActive: tunActive)
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
                Text(statusLabel)
                    .font(.headline)
                    .foregroundStyle(statusColor)
                if connection.isConnected {
                    Text(verbatim: "\(connection.activeServerName) · \(connection.uptimeText)")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else if let selected {
                    Text(selected.name).font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text(loc("Select a server")).font(.subheadline).foregroundStyle(.secondary)
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
        return ModeGlassSwitch(
            mode: $conn.mode,
            isDisabled: connection.isConnected
        ) { newMode in
            store.settings.mode = newMode
            store.save()
        }
        .help(connection.mode.subtitle)
    }

    @ViewBuilder
    private func connectButton(selected: ProxyConfig?) -> some View {
        if connection.isConnected || connection.state == .connecting {
            Button(role: .destructive) { connection.disconnect() } label: {
                Label(loc("Disconnect"), systemImage: "stop.fill").frame(minWidth: 96)
            }
            .controlSize(.large).glassProminentButton().tint(.red)
        } else {
            Button {
                if let s = selected { connection.connect(to: s) }
            } label: {
                Label(loc("Connect"), systemImage: "bolt.fill").frame(minWidth: 96)
            }
            .controlSize(.large).glassProminentButton()
            .disabled(selected == nil)
        }
    }

    // MARK: - Server list (collapsible groups)

    private var serverList: some View {
        ScrollViewReader { proxy in
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
            .frame(minHeight: 80, maxHeight: .infinity)
            // Keep the keyboard-selected row visible as it moves.
            .onChange(of: store.selectedServerID) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
        // Make the list the keyboard focus target and wire arrow keys + Enter.
        .focusable()
        .focusEffectDisabled()
        .focused($listFocused)
        .onKeyPress(.upArrow) { moveSelection(by: -1); return .handled }
        .onKeyPress(.downArrow) { moveSelection(by: 1); return .handled }
        .onKeyPress(.return) { connectSelected(); return .handled }
        .onAppear { listFocused = true }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray").font(.system(size: 34)).foregroundStyle(.secondary)
            Text(loc("No servers yet")).font(.headline)
            Text(loc("Add a subscription or paste a link to get started."))
                .font(.caption).foregroundStyle(.secondary)
            Button(loc("Add")) { showAddSheet = true }
                .glassProminentButton()
                .padding(.top, 4)
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
                Button { showAddSheet = true } label: {
                    Label(loc("Add"), systemImage: "plus")
                }
                .glassButton()
                Button {
                    Task {
                        isRefreshing = true
                        await SubscriptionService.refreshAll(store)
                        isRefreshing = false
                        // A refresh can replace every node, so the latencies on
                        // screen now belong to servers that may be gone.
                        pinger.clear()
                        pinger.test(store.allServers, tunActive: tunActive)
                    }
                } label: {
                    if isRefreshing { ProgressView().controlSize(.small) }
                    else { Label(loc("Refresh"), systemImage: "arrow.clockwise") }
                }
                .glassButton()
                .disabled(isRefreshing)

                Button {
                    pinger.test(store.allServers, tunActive: tunActive)
                } label: {
                    Label(loc("Test Ping"), systemImage: "speedometer")
                }
                .glassButton()
                .disabled(store.allServers.isEmpty)

                if hasManualServers {
                    Button {
                        selectionMode.toggle()
                        selectedForDeletion.removeAll()
                    } label: {
                        Label(loc("Select"), systemImage: selectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                    .glassButton()
                }

                Spacer()

                Toggle(isOn: $showLog) { Label(loc("Log"), systemImage: "text.alignleft") }
                    .glassToggle()
                // Settings is a scene now, so this opens the same window ⌘,
                // does instead of a second, sheet-shaped copy of it.
                Button {
                    openWindow(id: WindowID.settings)
                } label: {
                    Label(loc("Settings"), systemImage: "gearshape")
                }
                .glassButton()
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
            .glassButton()
            Text(verbatim: "\(selectedForDeletion.count)")
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
            .glassProminentButton().tint(.red)
            .disabled(selectedForDeletion.isEmpty)
            Button(loc("Cancel")) {
                selectionMode = false
                selectedForDeletion.removeAll()
            }
            .glassButton()
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Color.primary.opacity(0.04))
    }

    /// The connection state, translated. `failed` carries the core's own
    /// message, which is not ours to translate, so only the label around it is.
    private var statusLabel: String {
        switch connection.state {
        case .disconnected:  return loc("Disconnected")
        case .connecting:    return loc("Connecting…")
        case .connected:     return loc("Connected")
        case .failed(let m): return "\(loc("Failed")): \(m)"
        }
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

    /// Server whose QR code is currently being shown (drives the QR sheet).
    @State private var qrServer: ProxyConfig?

    /// Servers after applying search text, alive filter, and ping sort.
    private var visibleServers: [ProxyConfig] {
        ContentView.filterServers(subscription.servers, search: searchText,
                                  aliveOnly: aliveOnly, sortByPing: sortByPing,
                                  pinger: pinger)
    }

    /// The groups this subscription's panel declared, each as one row.
    ///
    /// They sit above the nodes because that is what the provider means them
    /// to be: the entry you pick, with the individual servers underneath for
    /// anyone who wants to choose by hand.
    private var visibleGroups: [ProxyConfig] {
        let rows = subscription.declaredGroups.compactMap { store.representative(for: $0) }
        guard !searchText.isEmpty else { return rows }
        return rows.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// Hide groups entirely filtered out by an active search/alive filter.
    private var isHidden: Bool {
        (!searchText.isEmpty || aliveOnly) && visibleServers.isEmpty && visibleGroups.isEmpty
    }

    var body: some View {
        if isHidden {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                groupHeader
                if !subscription.isCollapsed {
                    ForEach(visibleGroups) { group in
                        ServerRow(
                            server: group,
                            isSelected: store.selectedServerID == group.id,
                            isActive: connection.activeServerID == group.id,
                            latency: nil,
                            isTesting: false
                        )
                        .contentShape(Rectangle())
                        .id(group.id)
                        .onTapGesture { if !selectionMode { handleTap(group) } }
                        .contextMenu {
                            Button(connection.isConnected ? loc("Switch here") : loc("Connect")) {
                                store.select(group.id); connection.connect(to: group)
                            }
                            // No latency of its own: the group is whichever
                            // member the core finds quickest, so the useful
                            // measurement is the members'.
                            Button(loc("Test ping")) {
                                let members = subscription.declaredGroups
                                    .first { $0.id == group.id }?.memberIDs ?? []
                                pinger.test(store.allServers.filter { members.contains($0.id) },
                                            tunActive: connection.mode == .tun && connection.isConnected)
                            }
                        }
                    }
                    ForEach(visibleServers) { server in
                        let isActive = connection.activeServerID == server.id
                        let isLocked = isActive && connection.isConnected
                        HStack(spacing: 8) {
                            if selectionMode {
                                // A real checkbox, so selection looks and
                                // behaves the way it does everywhere else on
                                // the Mac. The active server cannot be picked.
                                if isLocked {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(.secondary)
                                        .help(loc("Connected"))
                                        .padding(.leading, 14)
                                } else {
                                    Toggle("", isOn: Binding(
                                        get: { selectedForDeletion.wrappedValue.contains(server.id) },
                                        set: { _ in toggleSelection(server.id) }
                                    ))
                                    .toggleStyle(.checkbox)
                                    .labelsHidden()
                                    .padding(.leading, 14)
                                }
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
                        .id(server.id)
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
                            Divider()
                            Button(loc("Copy link")) {
                                let link = LinkBuilder.link(for: server)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(link, forType: .string)
                            }
                            Button(loc("Show QR code")) { qrServer = server }
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
            .sheet(item: $qrServer) { server in
                QRDisplaySheet(server: server)
            }
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
            // The standard disclosure chevron: no invented affordance, and it
            // turns rather than swapping glyphs.
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(subscription.isCollapsed ? 0 : 90))
                .animation(.snappy(duration: 0.18), value: subscription.isCollapsed)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(subscription.name).font(.headline)
                    Text(verbatim: "\(subscription.servers.count)")
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
                Button {
                    pinger.test(subscription.servers,
                                tunActive: connection.mode == .tun && connection.isConnected)
                } label: {
                    Label(loc("Test ping (group)"), systemImage: "bolt.horizontal")
                }
                Button {
                    store.toggleCollapsed(id: subscription.id)
                } label: {
                    Label(subscription.isCollapsed ? loc("Expand") : loc("Collapse"),
                          systemImage: subscription.isCollapsed
                            ? "chevron.down" : "chevron.right")
                }
                if !subscription.isManual {
                    Divider()
                    Button {
                        Task { await SubscriptionService.refresh(subscription, into: store) }
                    } label: {
                        Label(loc("Refresh now"), systemImage: "arrow.clockwise")
                    }
                    Toggle(loc("Auto-update"), isOn: Binding(
                        get: { subscription.autoUpdate },
                        set: { store.setAutoUpdate($0, id: subscription.id) }
                    ))
                    Divider()
                    // Can't remove a subscription that holds the active server.
                    let holdsActive = connection.isConnected
                        && subscription.servers.contains { $0.id == connection.activeServerID }
                    Button(role: .destructive) {
                        store.removeSubscription(id: subscription.id)
                    } label: {
                        Label(loc("Remove"), systemImage: "trash")
                    }
                    .disabled(holdsActive)
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.button)
            .buttonStyle(.accessoryBar)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { store.toggleCollapsed(id: subscription.id) }
    }

    @ViewBuilder
    private var trafficLine: some View {
        if let used = subscription.usedBytes {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    // An uncapped plan gets the amount used and nothing else:
                    // there is no denominator, so there is no ratio to draw.
                    if subscription.isUnlimitedTraffic || subscription.totalBytes == nil {
                        Text(verbatim: ByteFormat.string(used))
                        Text(loc("Unlimited"))
                            .foregroundStyle(.tertiary)
                    } else if let total = subscription.totalBytes {
                        Text(verbatim: "\(ByteFormat.string(used)) / \(ByteFormat.string(total))")
                    }
                    if let exp = subscription.expiresAt {
                        Text(verbatim: "· \(loc("until")) \(exp.formatted(date: .abbreviated, time: .omitted))")
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
            Text(verbatim: "\(loc("Expires")) \(exp.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Server row

struct ServerRow: View {
    @Environment(Loc.self) private var loc
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
            if server.isBalancer {
                Text(verbatim: "\((server.alternates?.count ?? 0) + 1)")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
            }
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
                Text(verbatim: "\(ms) ms")
                    .font(.caption2).monospacedDigit()
                    .foregroundStyle(latencyColor(ms))
            } else {
                Text(loc("timeout"))
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
    @Environment(Loc.self) private var loc
    let text: String
    var onClear: (() -> Void)? = nil

    private var lineCount: Int {
        text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header toolbar.
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(loc("Logs"))
                    .font(.system(size: 12, weight: .semibold))
                Text(verbatim: "\(lineCount)")
                    .font(.system(size: 10, weight: .medium)).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc").font(.system(size: 11))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .help(loc("Copy all logs"))
                .disabled(text.isEmpty)
                Button {
                    onClear?()
                } label: {
                    Image(systemName: "trash").font(.system(size: 11))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .help(loc("Clear logs"))
                .disabled(text.isEmpty)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .logHeaderBackground()

            Divider().opacity(0.5)

            // Scrollable monospaced body.
            ScrollViewReader { proxy in
                ScrollView {
                    Text(text.isEmpty ? loc("No logs yet.") : text)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(text.isEmpty ? Color.secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(10)
                        .id("bottom")
                }
                .onChange(of: text) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
        .logPaneBackground()
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 12).padding(.vertical, 8)
    }
}

extension View {
    /// Glass material behind the log panel on macOS 26+, with a solid
    /// text-background fallback on earlier systems.
    @ViewBuilder
    func logPaneBackground() -> some View {
        if #available(macOS 26.0, *) {
            self.background(.regularMaterial)
        } else {
            self.background(Color(nsColor: .textBackgroundColor))
        }
    }

    /// Slightly tinted header strip so the toolbar reads above the body.
    @ViewBuilder
    func logHeaderBackground() -> some View {
        if #available(macOS 26.0, *) {
            self.background(.thinMaterial)
        } else {
            self.background(Color.primary.opacity(0.05))
        }
    }
}

// MARK: - Liquid Glass styling (macOS 26+) with graceful fallback

extension View {
    /// Applies the Liquid Glass button style on macOS 26+, falling back to the
    /// bordered style on earlier releases so the app still builds and runs on
    /// the .macOS(.v14) deployment target.
    @ViewBuilder
    func glassButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// Prominent Liquid Glass variant for primary actions (e.g. Connect).
    @ViewBuilder
    func glassProminentButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    /// Keeps the window title on the titlebar line instead of letting it take
    /// a row of its own above the toolbar, which is what pushed the Settings
    /// tab switcher onto a second line.
    @ViewBuilder
    func inlineWindowTitle() -> some View {
        if #available(macOS 15.0, *) {
            self.toolbarTitleDisplayMode(.inline)
        } else {
            self
        }
    }

    /// Liquid Glass toggle (a button-style toggle that picks up the glass
    /// material when selected on macOS 26+), with a bordered-button fallback.
    @ViewBuilder
    func glassToggle() -> some View {
        if #available(macOS 26.0, *) {
            self.toggleStyle(.button).buttonStyle(.glass)
        } else {
            self.toggleStyle(.button)
        }
    }
}

// MARK: - Draggable Liquid Glass mode switch (Proxy / TUN)

/// A two-position switch styled with Liquid Glass. The glass thumb can be
/// tapped on either side or grabbed and dragged across to flip between System
/// Proxy and TUN. Falls back to a plain segmented look on pre-macOS 26.
private struct ModeGlassSwitch: View {
    @Binding var mode: TunnelMode
    var isDisabled: Bool
    var onChange: (TunnelMode) -> Void

    /// Live horizontal offset of the thumb while dragging (nil = snapped).
    @State private var dragX: CGFloat? = nil

    private let labels: [(TunnelMode, String)] = [
        (.systemProxy, "Proxy"), (.tun, "TUN"),
    ]
    private let height: CGFloat = 28
    private let segWidth: CGFloat = 66

    private var trackWidth: CGFloat { segWidth * 2 }
    private var selectedIndex: Int { mode == .systemProxy ? 0 : 1 }

    var body: some View {
        ZStack(alignment: .leading) {
            // Track.
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.08))

            // Sliding glass thumb.
            thumb
                .frame(width: segWidth, height: height - 4)
                .offset(x: thumbOffset + 2)
                .animation(dragX == nil ? .spring(response: 0.28, dampingFraction: 0.8) : nil,
                           value: selectedIndex)

            // Labels on top.
            HStack(spacing: 0) {
                ForEach(Array(labels.enumerated()), id: \.offset) { idx, item in
                    Text(item.1)
                        .font(.system(size: 12, weight: idx == selectedIndex ? .semibold : .regular))
                        .foregroundStyle(idx == selectedIndex ? Color.primary : .secondary)
                        .frame(width: segWidth, height: height)
                        .contentShape(Rectangle())
                        .onTapGesture { select(labels[idx].0) }
                }
            }
        }
        .frame(width: trackWidth, height: height)
        .clipShape(Capsule(style: .continuous))
        .opacity(isDisabled ? 0.5 : 1)
        .allowsHitTesting(!isDisabled)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { v in
                    // Centre the thumb under the finger, clamped to the track.
                    let half = segWidth / 2
                    dragX = min(max(v.location.x - half, 0), trackWidth - segWidth)
                }
                .onEnded { v in
                    let target: TunnelMode = v.location.x > trackWidth / 2 ? .tun : .systemProxy
                    dragX = nil
                    select(target)
                }
        )
    }

    /// Where the thumb sits: follows the finger mid-drag, else snaps to segment.
    private var thumbOffset: CGFloat {
        if let dragX { return dragX }
        return CGFloat(selectedIndex) * segWidth
    }

    @ViewBuilder
    private var thumb: some View {
        if #available(macOS 26.0, *) {
            Capsule(style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        } else {
            Capsule(style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        }
    }

    private func select(_ newMode: TunnelMode) {
        guard newMode != mode else { return }
        mode = newMode
        onChange(newMode)
    }
}
