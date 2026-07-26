import SwiftUI

struct ContentView: View {
    @Environment(ServerStore.self) private var store
    @Environment(TunnelController.self) private var tunnel
    @Environment(PingTester.self) private var pinger
    @Environment(Loc.self) private var loc

    @State private var showAddSheet = false
    @State private var showSettings = false
    @State private var showLog = false
    @State private var isRefreshing = false
    @State private var searchText = ""
    @State private var aliveOnly = false
    @State private var sortByPing = false
    @State private var qrServer: ProxyConfig?

    var body: some View {
        NavigationStack {
            List {
                Section { StatusCard() .listRowInsets(EdgeInsets()) }

                if !store.allServers.isEmpty {
                    Section { filterRow }
                }

                if store.subscriptions.isEmpty {
                    Section { emptyState }
                } else {
                    ForEach(store.subscriptions) { sub in
                        SubscriptionSection(subscription: sub,
                                            searchText: searchText,
                                            aliveOnly: aliveOnly,
                                            sortByPing: sortByPing,
                                            qrServer: $qrServer)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Veil")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: loc("Search servers…"))
            .refreshable { await refreshAll() }
            .toolbar { toolbarContent }
            .sheet(isPresented: $showAddSheet) { AddView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showLog) { LogView() }
            .sheet(item: $qrServer) { QRDisplayView(server: $0) }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showAddSheet = true } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel(loc("Add"))
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    Task { await refreshAll() }
                } label: {
                    Label(loc("Refresh"), systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)

                Button {
                    pinger.test(store.allServers)
                } label: {
                    Label(loc("Test Ping"), systemImage: "speedometer")
                }
                .disabled(store.allServers.isEmpty)

                Divider()

                Button { showLog = true } label: {
                    Label(loc("Log"), systemImage: "text.alignleft")
                }
                Button { showSettings = true } label: {
                    Label(loc("Settings"), systemImage: "gearshape")
                }
            } label: {
                if isRefreshing {
                    ProgressView()
                } else {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: - Pieces

    private var filterRow: some View {
        HStack(spacing: 10) {
            Toggle(loc("Alive"), isOn: $aliveOnly)
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .font(.footnote)
            Toggle(loc("By ping"), isOn: $sortByPing)
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .font(.footnote)
            Spacer()
            Button {
                pinger.test(store.allServers)
            } label: {
                // An HStack rather than a Label: the button style lays a Label
                // out on a fixed icon column, which leaves a gap here.
                HStack(spacing: 5) {
                    Image(systemName: "speedometer")
                    Text(loc("Test Ping"))
                }
                .font(.footnote)
            }
            .buttonStyle(.bordered)
            .disabled(store.allServers.isEmpty)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(loc("No servers yet")).font(.headline)
            Text(loc("Paste a server link or a subscription URL to get started."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showAddSheet = true
            } label: {
                // Without an explicit label style the button drops the icon and
                // shows a bare word.
                Label(loc("Add"), systemImage: "plus")
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .listRowBackground(Color.clear)
    }

    private func refreshAll() async {
        isRefreshing = true
        await SubscriptionService.refreshAll(store)
        isRefreshing = false
    }

    /// Shared filter/sort so every list on screen agrees on the ordering.
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
}

// MARK: - Status card

/// The connect/disconnect hero at the top of the list: state, active server,
/// uptime and live traffic counters read back from the tunnel provider.
struct StatusCard: View {
    @Environment(ServerStore.self) private var store
    @Environment(TunnelController.self) private var tunnel
    @Environment(Loc.self) private var loc

    @State private var holdProgress: CGFloat = 0
    @State private var isHolding = false

    private var selected: ProxyConfig? { store.server(withID: store.selectedServerID) }

    var body: some View {
        // Kept compact on purpose: this sits above the server list, and every
        // point it takes is a row the user has to scroll for.
        VStack(spacing: 12) {
            shieldControl

            VStack(spacing: 2) {
                Text(stateLabel)
                    .font(.headline)
                    .foregroundStyle(statusColor)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if tunnel.isConnected {
                HStack(spacing: 20) {
                    trafficLabel(icon: "arrow.up", bytes: tunnel.uplinkBytes)
                    trafficLabel(icon: "arrow.down", bytes: tunnel.downlinkBytes)
                    Label(tunnel.uptimeText, systemImage: "clock")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Text(holdHint)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    /// The shield *is* the connect control — hold it to toggle the tunnel.
    /// A deliberate press beats a button you can hit by accident, since
    /// dropping the VPN mid-session is disruptive.
    private var shieldControl: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.16))
                .frame(width: 104, height: 104)

            // Fills while held; completing the ring is what fires the action.
            Circle()
                .trim(from: 0, to: holdProgress)
                .stroke(statusColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 104, height: 104)

            Image(systemName: tunnel.isConnected ? "shield.lefthalf.filled" : "shield.slash")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(statusColor)
        }
        .opacity(canToggle ? 1 : 0.4)
        .scaleEffect(isHolding ? 0.93 : 1)
        .animation(.easeOut(duration: 0.15), value: isHolding)
        .contentShape(Circle())
        .onLongPressGesture(minimumDuration: Self.holdDuration) {
            toggle()
        } onPressingChanged: { pressing in
            guard canToggle else { return }
            isHolding = pressing
            withAnimation(.linear(duration: pressing ? Self.holdDuration : 0.2)) {
                holdProgress = pressing ? 1 : 0
            }
        }
        .accessibilityLabel(holdHint)
    }

    private static let holdDuration: TimeInterval = 0.6

    /// False while a connect is already in flight, or when the selected server
    /// is one the Xray-only build cannot run.
    private var canToggle: Bool {
        if tunnel.isConnected { return true }
        guard tunnel.state != .connecting else { return false }
        return selected?.xraySupported ?? false
    }

    private var holdHint: String {
        if !canToggle && !tunnel.isConnected { return " " }
        return tunnel.isConnected ? loc("Hold to disconnect") : loc("Hold to connect")
    }

    private func toggle() {
        guard canToggle else { return }
        withAnimation(.easeOut(duration: 0.2)) { holdProgress = 0 }
        isHolding = false
        if tunnel.isConnected {
            tunnel.disconnect()
        } else if let server = selected {
            Task { await tunnel.connect(to: server, settings: store.settings) }
        }
    }

    private func trafficLabel(icon: String, bytes: Int64) -> some View {
        Label(ByteFormat.string(bytes), systemImage: icon)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    private var stateLabel: String {
        switch tunnel.state {
        case .disconnected: return loc("Disconnected")
        case .connecting:   return loc("Connecting…")
        case .connected:    return loc("Connected")
        case .failed:       return loc("Failed")
        }
    }

    private var subtitle: String {
        if case .failed(let message) = tunnel.state { return message }
        if tunnel.isConnected { return tunnel.activeServerName }
        if let selected {
            return selected.xraySupported
                ? selected.name
                : "\(selected.name) — \(loc("not supported on iOS"))"
        }
        return loc("Select a server")
    }

    private var statusColor: Color {
        switch tunnel.state {
        case .connected:    return .green
        case .connecting:   return .orange
        case .failed:       return .red
        case .disconnected: return .secondary
        }
    }
}

// MARK: - Subscription section

struct SubscriptionSection: View {
    @Environment(ServerStore.self) private var store
    @Environment(TunnelController.self) private var tunnel
    @Environment(PingTester.self) private var pinger
    @Environment(Loc.self) private var loc

    let subscription: Subscription
    let searchText: String
    let aliveOnly: Bool
    let sortByPing: Bool
    @Binding var qrServer: ProxyConfig?

    private var visibleServers: [ProxyConfig] {
        ContentView.filterServers(subscription.servers, search: searchText,
                                  aliveOnly: aliveOnly, sortByPing: sortByPing,
                                  pinger: pinger)
    }

    /// Hide a group that an active filter has emptied out.
    private var isHidden: Bool {
        (!searchText.isEmpty || aliveOnly) && visibleServers.isEmpty
    }

    var body: some View {
        if !isHidden {
            Section {
                if !subscription.isCollapsed {
                    ForEach(visibleServers) { server in
                        row(for: server)
                    }
                }
            } header: {
                header
            }
        }
    }

    @ViewBuilder
    private func row(for server: ProxyConfig) -> some View {
        let isActive = tunnel.activeServerID == server.id && tunnel.isConnected
        ServerRow(server: server,
                  isSelected: store.selectedServerID == server.id,
                  isActive: isActive,
                  latency: pinger.latency(for: server.id),
                  isTesting: pinger.isTesting(server.id))
            .contentShape(Rectangle())
            .onTapGesture { handleTap(server) }
            .contextMenu {
                Button(tunnel.isConnected ? loc("Switch here") : loc("Connect")) {
                    store.select(server.id)
                    Task { await tunnel.connect(to: server, settings: store.settings) }
                }
                .disabled(!server.xraySupported)
                Button(loc("Test ping")) { pinger.test([server]) }
                Divider()
                Button(loc("Copy link")) {
                    UIPasteboard.general.string = LinkBuilder.link(for: server)
                }
                Button(loc("Show QR code")) { qrServer = server }
            }
            .swipeActions(edge: .trailing) {
                if subscription.isManual && !isActive {
                    Button(role: .destructive) {
                        store.removeServer(id: server.id)
                    } label: {
                        Label(loc("Delete"), systemImage: "trash")
                    }
                }
            }
    }

    /// Name, note, traffic and expiry all sit above the servers: a description
    /// under the last row reads as if it belonged to that row. The whole block
    /// gets the same card treatment as the rows so it reads as one group.
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleRow
            details
        }
        .textCase(nil)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 6, trailing: 0))
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            // Tapping anywhere across the name collapses the group, but the
            // menu keeps its own hit area.
            HStack(spacing: 8) {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    // Rotating one glyph animates; swapping two would not.
                    .rotationEffect(.degrees(subscription.isCollapsed ? -90 : 0))
                    .frame(width: 20)

                Text(subscription.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(subscription.servers.count)")
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(Color.secondary.opacity(0.18)))

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { toggleCollapsed() }

            Menu {
                Button(loc("Test ping")) { pinger.test(subscription.servers) }
                if !subscription.isManual {
                    Divider()
                    Button(loc("Refresh now")) {
                        Task { await SubscriptionService.refresh(subscription, into: store) }
                    }
                    Toggle(loc("Auto-update"), isOn: Binding(
                        get: { subscription.autoUpdate },
                        set: { store.setAutoUpdate($0, id: subscription.id) }
                    ))
                    Divider()
                    let holdsActive = tunnel.isConnected
                        && subscription.servers.contains { $0.id == tunnel.activeServerID }
                    Button(loc("Remove"), role: .destructive) {
                        store.removeSubscription(id: subscription.id)
                    }
                    .disabled(holdsActive)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let note = subscription.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let used = subscription.usedBytes, let total = subscription.totalBytes {
                HStack(spacing: 6) {
                    Text("\(ByteFormat.string(used)) / \(ByteFormat.string(total))")
                    if let expiry = subscription.expiresAt {
                        Text("· \(expiry.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let fraction = subscription.usageFraction {
                    ProgressView(value: fraction)
                        .tint(fraction > 0.9 ? .red : .accentColor)
                }
            } else if let expiry = subscription.expiresAt {
                Text("\(loc("Expires")) \(expiry.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func toggleCollapsed() {
        withAnimation(.snappy(duration: 0.28)) {
            store.toggleCollapsed(id: subscription.id)
        }
    }

    /// Disconnected: tap selects. Connected: tap switches straight away, which
    /// only restarts the core inside the extension — the tunnel never drops.
    private func handleTap(_ server: ProxyConfig) {
        store.select(server.id)
        guard tunnel.isConnected else { return }
        Task { await tunnel.connect(to: server, settings: store.settings) }
    }
}
