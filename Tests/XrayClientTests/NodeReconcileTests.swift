import XCTest
@testable import XrayClient

/// A subscription refresh used to replace every node with a freshly parsed one,
/// and every fresh parse mints a new id. Anything the user had attached to a
/// node — a group membership, a rule target, the current selection — named an
/// id that no longer existed, and was silently ignored the moment the
/// subscription updated.
///
/// These cover the matching that keeps an id attached to the node it belongs
/// to, including the cases where matching has to guess.
final class NodeReconcileTests: XCTestCase {

    // MARK: - Identity

    func testTwoParsesOfTheSameLinkAgreeOnIdentity() {
        let link = "vless://11111111-2222-3333-4444-555555555555@1.2.3.4:443"
            + "?encryption=none&security=reality&sni=example.com&type=tcp#NL"
        guard case .servers(let first, _) = AddInputClassifier.classify(link),
              case .servers(let second, _) = AddInputClassifier.classify(link) else {
            return XCTFail("expected the link to parse")
        }
        XCTAssertNotEqual(first[0].id, second[0].id,
                          "each parse mints its own id — that is the problem being solved")
        XCTAssertEqual(NodeIdentity.key(for: first[0]),
                       NodeIdentity.key(for: second[0]))
    }

    func testIdentityFollowsTheCredentialNotTheName() {
        var node = vless(name: "NL-01")
        let original = NodeIdentity.key(for: node)
        node.name = "Netherlands"
        XCTAssertEqual(NodeIdentity.key(for: node), original)
        node.uuid = "99999999-9999-9999-9999-999999999999"
        XCTAssertNotEqual(NodeIdentity.key(for: node), original,
                          "a rotated credential is a different node")
    }

    func testIdentityDistinguishesProtocolsOnTheSameAddress() {
        var trojan = ProxyConfig(name: "same host", proto: .trojan,
                                 address: "1.2.3.4", port: 443)
        trojan.password = "secret"
        var anytls = ProxyConfig(name: "same host", proto: .anytls,
                                 address: "1.2.3.4", port: 443)
        anytls.password = "secret"
        XCTAssertNotEqual(NodeIdentity.key(for: trojan), NodeIdentity.key(for: anytls))
    }

    // MARK: - Reconciliation

    func testARenamedNodeKeepsItsIdentity() {
        let stored = vless(name: "NL-01")
        var incoming = vless(name: "Netherlands · Amsterdam")
        incoming.id = UUID()

        let result = NodeReconciler.reconcile(incoming: [incoming], existing: [stored]).servers

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, stored.id)
        XCTAssertEqual(result[0].name, "Netherlands · Amsterdam",
                       "the panel still owns the name")
    }

    func testANodeThatMovedAddressIsMatchedByName() {
        let stored = vless(name: "NL-01", address: "1.2.3.4")
        var incoming = vless(name: "NL-01", address: "5.6.7.8")
        incoming.id = UUID()

        let result = NodeReconciler.reconcile(incoming: [incoming], existing: [stored]).servers

        XCTAssertEqual(result[0].id, stored.id)
        XCTAssertEqual(result[0].address, "5.6.7.8")
    }

    func testAGenuinelyNewNodeGetsANewIdentity() {
        let stored = vless(name: "NL-01", address: "1.2.3.4")
        var incoming = vless(name: "DE-01", address: "5.6.7.8")
        incoming.uuid = "77777777-7777-7777-7777-777777777777"
        let mintedID = incoming.id

        let result = NodeReconciler.reconcile(incoming: [incoming], existing: [stored]).servers

        XCTAssertEqual(result[0].id, mintedID)
        XCTAssertNotEqual(result[0].id, stored.id)
    }

    func testANodeTheProviderDroppedIsGone() {
        let kept = vless(name: "NL-01", address: "1.2.3.4")
        let dropped = vless(name: "DE-01", address: "5.6.7.8")
        var incoming = vless(name: "NL-01", address: "1.2.3.4")
        incoming.id = UUID()

        let result = NodeReconciler.reconcile(incoming: [incoming],
                                              existing: [kept, dropped]).servers

        XCTAssertEqual(result.map(\.id), [kept.id])
    }

    func testAStoredNodeIsClaimedOnlyOnce() {
        // Two nodes arrive under one name where only one was stored: the first
        // inherits the id, the second must not inherit the same one.
        let stored = vless(name: "NL", address: "1.2.3.4")
        var first = vless(name: "NL", address: "5.6.7.8")
        first.uuid = "88888888-8888-8888-8888-888888888888"
        var second = vless(name: "NL", address: "9.9.9.9")
        second.uuid = "99999999-9999-9999-9999-999999999999"

        let result = NodeReconciler.reconcile(incoming: [first, second],
                                              existing: [stored]).servers

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].id, stored.id)
        XCTAssertNotEqual(result[1].id, stored.id)
    }

    func testAnExactMatchWinsOverANameMatch() {
        // The node that still has the same address and credential must keep its
        // own id even though another stored node shares its name.
        let byName = vless(name: "NL", address: "1.1.1.1")
        let exact = vless(name: "NL", address: "2.2.2.2")
        var incoming = vless(name: "NL", address: "2.2.2.2")
        incoming.id = UUID()

        let result = NodeReconciler.reconcile(incoming: [incoming],
                                              existing: [byName, exact]).servers

        XCTAssertEqual(result[0].id, exact.id)
    }

    func testTheOrderTheProviderSentIsKept() {
        let stored = [vless(name: "A", address: "1.1.1.1"),
                      vless(name: "B", address: "2.2.2.2")]
        var b = vless(name: "B", address: "2.2.2.2"); b.id = UUID()
        var a = vless(name: "A", address: "1.1.1.1"); a.id = UUID()

        let result = NodeReconciler.reconcile(incoming: [b, a], existing: stored).servers

        XCTAssertEqual(result.map(\.name), ["B", "A"])
        XCTAssertEqual(result.map(\.id), [stored[1].id, stored[0].id])
    }

    // MARK: - The panel's own groups

    func testAGroupsMembersFollowTheNodesTheyName() {
        let stored = vless(name: "NL-01")
        var incoming = vless(name: "NL-01")
        incoming.id = UUID()
        let group = ServerGroup(name: "auto", memberIDs: [incoming.id],
                                selectedID: incoming.id)

        let result = NodeReconciler.reconcile(incoming: [incoming], groups: [group],
                                              existing: [stored])

        XCTAssertEqual(result.groups[0].memberIDs, [stored.id])
        XCTAssertEqual(result.groups[0].selectedID, stored.id)
    }

    func testAGroupTheProviderResendsKeepsItsIdentity() {
        let storedGroup = ServerGroup(name: "auto")
        let incomingGroup = ServerGroup(name: "auto")
        XCTAssertNotEqual(storedGroup.id, incomingGroup.id)

        let result = NodeReconciler.reconcile(incoming: [], groups: [incomingGroup],
                                              existing: [], existingGroups: [storedGroup])

        XCTAssertEqual(result.groups[0].id, storedGroup.id,
                       "a rule naming this group must keep matching after a refresh")
    }

    func testAGroupTheProviderRenamedIsTreatedAsNew() {
        let storedGroup = ServerGroup(name: "auto")
        let incomingGroup = ServerGroup(name: "fastest")

        let result = NodeReconciler.reconcile(incoming: [], groups: [incomingGroup],
                                              existing: [], existingGroups: [storedGroup])

        XCTAssertEqual(result.groups[0].id, incomingGroup.id)
    }

    // MARK: - Helpers

    private func vless(name: String, address: String = "1.2.3.4") -> ProxyConfig {
        var node = ProxyConfig(name: name, proto: .vless, address: address, port: 443)
        node.uuid = "11111111-2222-3333-4444-555555555555"
        node.security = .reality
        return node
    }
}
