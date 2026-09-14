import Foundation
import Observation

/// Holds subscription profiles, the selected server, and app settings.
/// Persists everything to JSON in Application Support.
@MainActor
@Observable
final class ServerStore {
    private(set) var subscriptions: [Subscription] = []
    var settings = AppSettings()
    var selectedServerID: UUID?

    private let fileURL: URL

    init() {
        #if os(iOS)
        // Live in the shared app group so the tunnel extension reads the same
        // servers and settings the app writes.
        let dir = AppGroup.supportDirectory
        #else
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: true)) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("XrayClient", isDirectory: true)
        #endif
        // Application Support is world-readable by default and this file holds
        // server addresses, UUIDs and passwords.
        SecureFile.ensureDirectory(dir)
        self.fileURL = dir.appendingPathComponent("store.json")
        load()
        selectedServerID = settings.lastSelectedServerID
    }

    // MARK: - Derived

    /// All servers across every subscription, flattened.
    var allServers: [ProxyConfig] {
        subscriptions.flatMap(\.servers)
    }

    func server(withID id: UUID?) -> ProxyConfig? {
        guard let id else { return nil }
        return allServers.first { $0.id == id }
    }

    func subscriptionContaining(serverID: UUID?) -> Subscription? {
        guard let id = serverID else { return nil }
        return subscriptions.first { $0.servers.contains(where: { $0.id == id }) }
    }

    // MARK: - Manual servers

    private func ensureManualGroup() -> Int {
        if let idx = subscriptions.firstIndex(where: { $0.isManual }) { return idx }
        subscriptions.insert(Subscription(name: "Manual"), at: 0)
        return 0
    }

    func addManualServers(_ servers: [ProxyConfig]) {
        let idx = ensureManualGroup()
        subscriptions[idx].servers.append(contentsOf: servers)
        save()
    }

    /// Removes specific servers (by id) from any subscription group. Empties the
    /// Manual group if it becomes empty.
    func removeServers(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        for i in subscriptions.indices {
            subscriptions[i].servers.removeAll { ids.contains($0.id) }
        }
        // Drop an emptied Manual group to keep the list tidy.
        subscriptions.removeAll { $0.isManual && $0.servers.isEmpty }
        if let sel = selectedServerID, !ids.contains(sel) {} else { selectedServerID = nil }
        save()
    }

    /// Removes a single server by id.
    func removeServer(id: UUID) {
        removeServers(ids: [id])
    }

    // MARK: - Subscriptions

    /// Adds or refreshes a subscription; everything the panel reported in its
    /// response headers lands on the profile.
    func addOrUpdateSubscription(name: String, url: String,
                                 servers: [ProxyConfig],
                                 metadata: SubscriptionMetadata,
                                 format: SubscriptionPayload.Format?) {
        let idx = subscriptions.firstIndex { $0.url == url }
        if let idx {
            // Preserve UI state and identity, refresh the contents.
            subscriptions[idx].name = name
            subscriptions[idx].servers = servers
            subscriptions[idx].lastUpdated = Date()
            subscriptions[idx].lastFormat = format
            subscriptions[idx].apply(metadata)
        } else {
            var sub = Subscription(name: name, url: url)
            sub.servers = servers
            sub.lastUpdated = Date()
            sub.lastFormat = format
            sub.apply(metadata)
            subscriptions.append(sub)
        }
        save()
    }

    /// Applies an in-place edit to one subscription and persists it.
    func mutateSubscription(id: UUID, _ body: (inout Subscription) -> Void) {
        guard let idx = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        body(&subscriptions[idx])
        save()
    }

    func removeSubscription(id: UUID) {
        subscriptions.removeAll { $0.id == id }
        Keychain.remove(account: KeychainAccount.subscriptionURL(id))
        DeviceID.clearOverride(for: id)
        save()
    }

    func toggleCollapsed(id: UUID) {
        guard let idx = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        subscriptions[idx].isCollapsed.toggle()
        save()
    }

    func setAutoUpdate(_ on: Bool, id: UUID) {
        guard let idx = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        subscriptions[idx].autoUpdate = on
        save()
    }

    func setNote(_ note: String, id: UUID) {
        guard let idx = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        subscriptions[idx].note = note.isEmpty ? nil : note
        save()
    }

    func select(_ serverID: UUID) {
        selectedServerID = serverID
        settings.lastSelectedServerID = serverID
        save()
    }

    // MARK: - Disk

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let decoded = try? JSONDecoder().decode(Persisted.self, from: data) else { return }
        settings = decoded.settings ?? AppSettings()
        subscriptions = decoded.subscriptions.map { sub in
            guard sub.url == nil, sub.hasStoredURL == true else { return sub }
            var restored = sub
            restored.url = Keychain.get(account: KeychainAccount.subscriptionURL(sub.id))
            return restored
        }
    }

    func save() {
        // Subscription URLs are bearer credentials: the Keychain holds them,
        // `store.json` only records that it did. A build where the Keychain is
        // unavailable keeps the URL in the (0600) file rather than losing it.
        let persisted = subscriptions.map { sub -> Subscription in
            guard let url = sub.url, !url.isEmpty else { return sub }
            var copy = sub
            if Keychain.set(url, account: KeychainAccount.subscriptionURL(sub.id)) {
                copy.url = nil
                copy.hasStoredURL = true
            } else {
                copy.hasStoredURL = false
            }
            return copy
        }
        let payload = Persisted(subscriptions: persisted, settings: settings)
        if let data = try? JSONEncoder().encode(payload) {
            SecureFile.write(data, to: fileURL)
        }
    }

    private struct Persisted: Codable {
        var subscriptions: [Subscription]
        var settings: AppSettings?
    }
}
