# Sources configurator, stable node identity and tags

Design for sub-projects **A** (sources configurator) and **B** (tags, groups and
display prefixes) of the Veil overhaul agreed on 2026-09-19. The remaining
sub-projects — auto-balancers (C), settings information architecture (D), the
routing rule editor (E), diagnostics (F) and the control API with its agent
contracts (H) — are out of scope here and get their own specs. They are listed
at the end so their dependencies on this work are visible.

## The problem

Three separate complaints, one cause between them.

**Nothing about a source can be inspected or edited.** A WireGuard entry parsed
out of a pasted `.conf` shows up as a name and nothing else; there is no way to
read the sing-box outbound it produces, no way to change a peer, no way to see
the body a subscription actually returned or the base64 it was wrapped in. When
a node is skipped during parsing, it is skipped silently, which is
indistinguishable from a node that does not exist.

**The list cannot be arranged.** Servers cannot be reordered, pinned or hidden,
and subscriptions cannot be merged into one list. A subscription of fifty nodes
of which five are ever used looks the same as one of five.

**Anything pinned to a node does not survive a refresh.** This is the one that
has to be fixed first, and it is not visible from the UI.
`ServerStore.addOrUpdateSubscription` replaces a subscription's nodes wholesale
on every refresh:

```swift
subscriptions[idx].servers = servers
```

Every `ProxyConfig` in that array is freshly parsed, so every id is new — the
code says as much: *"they name servers by id, and the refresh just minted new
ones"*. Consequently, after any subscription refresh:

- a user group (`AppSettings.serverGroups`) silently loses the members it named,
  because `ProfileAssembler` skips ids it cannot resolve rather than failing;
- a routing rule targeting `.server(id)` or `.group(id)` stops matching;
- `lastSelectedServerID` no longer resolves, so the selection is lost.

sing-box-launcher documents the same hazard from the other side: a rule points
at a Direction rather than at a node tag, *because provider tags are regenerated
on every subscription update*. Veil has the identical problem expressed as
UUIDs. Tags, pinning and manual ordering are all node-attached state, so none of
them can work until node identity survives a refresh.

## Decisions taken before this design

1. **Tags are a second dimension, not a replacement.** Subscriptions stay as
   collapsible sections; a grouping switcher offers other arrangements.
2. **Node identity is derived from address, port, protocol and auth key**, with
   the name as a fallback match.
3. **Tags come from both** automatic parsing of node names and manual labels on
   top of it.
4. **The configurator is a second mode of the main window**, not a fifth window
   and not another Settings tab.

## Data model

### Stable identity

New `Core/NodeIdentity.swift`:

```swift
enum NodeIdentity {
    /// `proto|address|port|authKey` — what makes two parses of the same node
    /// the same node.
    static func key(for server: ProxyConfig) -> String
}
```

The auth key is the UUID for VLESS/VMess, the password for
Trojan/Shadowsocks/Hysteria2/TUIC/AnyTLS, and the peer public key for
WireGuard. `BalancerGrouper.authKey(for:)` already computes exactly this and is
moved here; `BalancerGrouper` calls the shared version rather than keeping a
copy, so the two can never drift.

### Reconciliation on refresh

`ServerStore.addOrUpdateSubscription` stops assigning `servers` wholesale.
Incoming nodes are matched against the ones already stored **in that same
subscription**, in two passes:

1. by identity key;
2. by name, among the nodes that found no partner in pass 1.

Each stored node can be claimed once. Where several candidates tie — two stored
nodes with the same name, which providers do produce — the earliest in stored
order wins, so the result does not depend on dictionary ordering.

A matched node keeps the stored node's `id` and takes the incoming node's
connection details. An unmatched incoming node keeps its freshly minted id. A
stored node that nothing matched is dropped, as it is today.

This is the whole fix for the lost-members, lost-selection and broken-rule
symptoms above, and it has to land before anything else in this spec.

The panel's own declared groups (`Subscription.groups`) continue to be replaced
wholesale — they are the panel's, and they name the nodes the panel just sent.
They resolve correctly because the ids those nodes carry are now the stable ones.

### User annotations

New `Models/NodeAnnotation.swift`, stored in `AppSettings` as
`[UUID: NodeAnnotation]` and therefore saved with the rest of the store:

```swift
struct NodeAnnotation: Codable, Equatable {
    var tags: [String] = []
    var pinned: Bool = false
    var hidden: Bool = false
    var nameOverride: String?
    var sortIndex: Int?
}
```

Keyed by the node id, which reconciliation has now made stable. An annotation
whose node is gone resolves to nothing and is ignored, and it is **kept** rather
than collected: an entry is a handful of bytes, a provider that drops a node for
a day and restores it is ordinary, and a refresh that fails is not proof that
anything disappeared. Annotations are only removed when the user removes the
source they belonged to.

`AppSettings.init(from:)` is already written so that every key falls back to its
default, so a `store.json` from an older build decodes with an empty annotation
map and no migration step.

### Automatic facets

New `Core/NodeFacets.swift`:

```swift
struct NodeFacets {
    var country: String?      // from a flag emoji, an ISO code, or a known city
    var proto: ProxyProtocol
    var engine: CoreEngine
    var transport: TransportNetwork
    var balancerIndex: Int?   // the trailing number BalancerGrouper strips
}
```

Facets are computed on demand and never stored. A node renamed by its provider
simply produces different facets on the next draw, so there is nothing that can
fall out of sync and nothing to migrate. The name parsing reuses the suffix
handling already in `BalancerGrouper.baseName`.

In the interface a tag is either a facet or a manual label, and the two are
visually distinct: facets are neutral, manual labels are tinted.

### Known limitation

A node whose provider changes both its address and its name in one refresh
matches nothing and is treated as new, losing its annotations. The two passes
cannot distinguish that case from a genuinely new node, and neither can any
other client.

## The list

### Grouping

New `ListGrouping` enum stored in `AppSettings`: `subscription` (the default and
current behaviour), `tag`, `country`, `none`. A switcher sits in the list header
next to the search field.

### Section building

New `Core/ServerListBuilder.swift`:

```swift
enum ServerListBuilder {
    static func sections(servers: [ProxyConfig],
                         groups: [ServerGroup],
                         annotations: [UUID: NodeAnnotation],
                         grouping: ListGrouping,
                         filter: ListFilter) -> [ListSection]
}
```

`ListFilter` carries what the header offers: the search text, the alive-only
toggle, the ping sort, the selected tag chips, and whether hidden nodes are
shown. All of it already exists as loose `@State` in `ContentView`.

Under `tag` and `country` grouping, nodes that produce no such facet land in a
final section named "Other" rather than being dropped — a node with no country
in its name is still a node the user can connect to.

This is a pure function and is where the ordering rules live, so they can be
tested without SwiftUI. It replaces the logic currently spread across
`ContentView.filterServers`, `SubscriptionGroupView.visibleServers` and
`SubscriptionGroupView.visibleGroups`.

Order within a section: pinned nodes first, then `sortIndex` where one is set,
then the existing sort (by latency when the ping sort is on, otherwise the order
the source supplied).

`ContentView.swift` is 1012 lines today and every remaining sub-project touches
it. The list moves into a file of its own as part of this work. This is the only
restructuring in scope; nothing else is refactored.

### Reordering, pinning, hiding

Dragging a row writes `sortIndex` and works only within a section — moving a
node between tag sections is meaningless, since its tags are what put it there.
Hidden nodes leave the list but not the store; each section ends with a
"3 hidden" row that expands.

### Filtering by tag

A wrapping row of chips under the search field, built on the existing
`FlowLayout` from `Views/TokenChips.swift`. Selections within one facet kind are
OR-ed (`NL` or `DE`); across kinds they are AND-ed (`NL` and `vless`). Search
applies on top of any grouping.

### Subscription metadata

Traffic and expiry stay in the section header only under `subscription`
grouping. Under the others a section is a tag, which has no traffic of its own;
that information lives on the sources page instead.

### Balancer groups

Groups — both those a panel declared and the user's own — remain single rows, as
they are today. Under `subscription` grouping they sit in their subscription;
under `tag` grouping they appear in the sections their members' tags produce.

## The sources page

The main window gains a mode switcher: **Connection** and **Sources**. The
sources mode is a two-pane layout: sources on the left, the selected one on the
right.

### Per source

A source is a subscription with a URL, or the manual set — which is how the
store already models it: `Subscription.isManual` is the one without a URL, and a
pasted link joins it. That is kept. Each manual node is listed under the manual
source and is individually editable, renameable and removable, which is what
having one row per pasted WireGuard config amounts to in practice; turning every
pasted link into a source of its own would change the shape of the store for a
presentational difference, and is not part of this work.

A source's header carries: name, auto-update and interval, when it last updated,
node count, traffic and expiry, and the detected body format —
`SubscriptionPayload.Format` already distinguishes XRAY_JSON, base64, sing-box,
Mihomo YAML and plain share links. Actions: reorder by dragging, enable/disable,
refresh, delete.

### Raw configuration

The rule is that what Veil owns is editable and what a provider owns is not.

**Manual nodes** are editable in full, in whichever representation suits them,
with the others recomputed on each edit:

- WireGuard as wg-quick text with `[Interface]` and `[Peer]` — `LinkParser`
  already has `parseWireGuardConf`;
- everything else as the outbound JSON of its own core;
- plus the share link, through the existing `Core/LinkBuilder.swift`.

**Subscription nodes** show the same representations read-only, along with the
body exactly as it arrived and its decoded base64 where that applies. Writing
there would be overwritten by the next refresh. A "duplicate and edit" action
copies the node into the manual source, marked with where it came from. Name,
tags, pinning and hiding remain editable in place on a subscription node,
because those live in `NodeAnnotation` and survive the refresh.

### Validation

An edited configuration is checked by the real core before it is saved:
`xray run -test -config <file>` or `sing-box check -c <file>`, the same
invocations `CLAUDE.md` documents. The core's own message is shown verbatim, so
a typo is caught before it becomes a connection that never comes up.

### Source diagnostics

On the same pane: the last HTTP status, the format recognised, how many nodes
were accepted, and how many were skipped with the reason. Parsing currently
drops what it cannot use without saying so, which is why a WireGuard entry can
simply fail to appear.

## Testing

Everything load-bearing here is a pure function, and is tested as one:

- `NodeIdentity.key(for:)` — one case per protocol family, and that two parses of
  the same share link agree.
- Reconciliation — a refresh that renames a node keeps its id; one that changes
  its address keeps its id by name; a genuinely new node gets a new id; a
  vanished node is dropped; a user group's members still resolve afterwards.
- `NodeFacets` — flag emoji, ISO code, city name, trailing balancer index.
- `ServerListBuilder.sections` — one test per ordering rule (pinned, sortIndex,
  ping sort, hidden), and one per grouping.
- Tag filtering — OR within a facet kind, AND across kinds.
- Raw round trips — WireGuard `.conf` and each protocol's share link parse,
  render and parse back to the same `ProxyConfig`.

The validation step shells out to a real core binary; it is covered the way
`CoreConfigGuardTests` already covers generated configs.

## Compatibility

No migration step. `AppSettings.init(from:)` and `RoutingRule.init(from:)` both
already fall back per key, and the new fields follow that pattern. A store
written by this build stays readable by it and by anything newer; a store from
1.7.0 loads with no annotations, `subscription` grouping and nothing hidden,
which is exactly today's behaviour.

## What this enables, and what it does not cover

- **C, auto-balancers** needs stable ids to name members; this spec provides
  them. Folding a whole subscription into one selector or auto-select group is
  C's work, not this one's.
- **E, the routing rule editor** needs `.server` / `.group` targets to keep
  matching across refreshes, which reconciliation fixes. Multiple targets per
  rule, per-list targets and explaining presets remain E's.
- **D, settings information architecture** inherits the Connection/Sources split
  introduced here and decides what else moves out of the Settings window.
- **F** and **H** are untouched by this work.

One thing worth carrying into E: a rule that names a specific node or group is
only honoured when sing-box owns the profile. With `useNativeTun` off,
`ConnectionManager.connectLegacy` runs the Xray path, where `RuleTarget.xrayTag`
collapses `.server` and `.group` onto `proxy` — the rule still appears to be
configured but sends traffic through the default outbound.
