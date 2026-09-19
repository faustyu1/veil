import SwiftUI

/// The header of a subscription's section: what the source is called, what it
/// has left, and everything that can be done to the source itself — collapse,
/// pin, reorder, refresh, remove.
struct SubscriptionHeader: View {
    @Environment(ServerStore.self) private var store
    @Environment(ConnectionManager.self) private var connection
    @Environment(PingTester.self) private var pinger
    @Environment(Loc.self) private var loc

    let subscription: Subscription
    /// How many of its servers the current filter left visible.
    var count: Int

    private var isPinned: Bool { subscription.pinned == true }

    var body: some View {
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
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2).foregroundStyle(.secondary)
                            .help(loc("Pinned to the top of the list"))
                    }
                    Text(subscription.name).font(.headline)
                    Text(verbatim: "\(count)")
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
            menu
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { store.toggleCollapsed(id: subscription.id) }
        // Sources are dragged by their header, which is the only part of a
        // section that is always on screen.
        .draggable(subscription.id.uuidString) {
            Label(subscription.name, systemImage: "square.stack.3d.up").padding(6)
        }
        .dropDestination(for: String.self) { items, _ in
            move(items.compactMap(UUID.init(uuidString:)))
        }
    }

    private var menu: some View {
        Menu {
            Button {
                pinger.test(subscription.servers, tunActive: tunActive)
            } label: {
                Label(loc("Test ping (group)"), systemImage: "bolt.horizontal")
            }
            Button {
                store.toggleCollapsed(id: subscription.id)
            } label: {
                Label(subscription.isCollapsed ? loc("Expand") : loc("Collapse"),
                      systemImage: subscription.isCollapsed ? "chevron.down" : "chevron.right")
            }
            Button {
                store.togglePinned(subscriptionID: subscription.id)
            } label: {
                Label(isPinned ? loc("Unpin") : loc("Pin"),
                      systemImage: isPinned ? "pin.slash" : "pin")
            }
            Divider()
            Button {
                moveBy(-1)
            } label: {
                Label(loc("Move up"), systemImage: "arrow.up")
            }
            .disabled(index == 0)
            Button {
                moveBy(1)
            } label: {
                Label(loc("Move down"), systemImage: "arrow.down")
            }
            .disabled(index == store.subscriptions.count - 1)
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

    // MARK: - Order

    private var index: Int {
        store.subscriptions.firstIndex { $0.id == subscription.id } ?? 0
    }

    private func moveBy(_ delta: Int) {
        let target = index + delta
        guard store.subscriptions.indices.contains(target) else { return }
        // `move(fromOffsets:toOffset:)` counts the destination before the
        // removal, so moving down is one further than it looks.
        store.moveSubscriptions(fromOffsets: IndexSet(integer: index),
                                toOffset: delta > 0 ? target + 1 : target)
    }

    private func move(_ dragged: [UUID]) -> Bool {
        guard let from = dragged.first,
              from != subscription.id,
              let source = store.subscriptions.firstIndex(where: { $0.id == from }) else {
            return false
        }
        let destination = index
        store.moveSubscriptions(fromOffsets: IndexSet(integer: source),
                                toOffset: source < destination ? destination + 1 : destination)
        return true
    }

    private var tunActive: Bool {
        connection.mode == .tun && connection.isConnected
    }

    // MARK: - Traffic

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
