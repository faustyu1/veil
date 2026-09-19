# Veil for agents

Veil exposes a local HTTP API so another program — an assistant, a script, a
menu-bar helper — can read how traffic is routed and change it. This page is
the contract that API keeps. `GET /v1/schema` is the machine-readable half;
this is the half that explains what the words mean.

## Reaching it

Turn it on in **Settings → Advanced → Let other programs configure Veil**. The
server listens on `127.0.0.1` only and never on a public interface.

```
Base URL:  http://127.0.0.1:9091      (the port is configurable)
Header:    Authorization: Bearer <token>
```

The token is shown in the same section, and **New token** replaces it. Requests
carrying a browser `Origin` header are refused with `403`, so a web page cannot
use a token it happens to discover. A missing or wrong token is `401`.

Start every session with `GET /v1/schema`. It lists the endpoints this build
actually has, which is the authority when this page and the binary disagree.

## What the API will never tell you

- **Subscription URLs.** The path of one *is* the access token for a provider's
  panel. `/v1/sources` says that a URL is stored, never what it is.
- **The device identifier.** It is sent to panels as `X-Hwid` and nowhere else.
- **Unredacted logs.** `/v1/logs` and `/v1/diagnostics` run everything through
  the same redaction the Export diagnostics button uses.

The API also cannot add a server or a subscription. Routing is what it is for,
and an interface that cannot read a secret cannot leak one.

## The model

```
sources  →  nodes  →  groups  →  rules  →  the profile a core runs
```

- A **source** is a subscription or the servers added by hand. `GET /v1/sources`
  reports how many nodes each produced and what the last fetch had to skip —
  that is the answer to "the provider lists a server I cannot see".
- A **node** is one server. `GET /v1/servers` gives its id and the `tag` a rule
  uses to name it. What the *user* attached to it — labels, a pin, a rename, a
  hide — lives separately in `GET /v1/nodes`, keyed by node id.
- A **group** behaves like one outbound: a selector the user picks from, or a
  urltest that takes the quickest member. A group with a `query` is automatic:
  it states what it wants (source, country, tag, protocol, name fragment) and
  is answered again whenever the list changes, so new nodes join it by
  themselves. `memberIDs` on such a group is the last answer, not an input.
- A **rule** matches traffic and names a target. Rules are ordered and the
  first match wins.
- The **profile** is what a core is actually given. `GET /v1/config` renders it
  from the current settings without connecting, which is the cheapest way to
  check an edit.

### Rule targets

| Target | Meaning |
| --- | --- |
| `proxy` | the server that is connected |
| `direct` | out of the tunnel, straight to the network |
| `block` | refused |
| `server:<uuid>` | that specific node |
| `group:<uuid>` | that group's current choice |

`server:` and `group:` need the full profile, which Veil builds in System Proxy
mode and in TUN mode with the native core. In TUN mode with the native inbound
switched off there is one proxy outbound and those targets collapse onto it.
`GET /v1/state` reports `nativeCore`; the editor in the app says so too rather
than looking configured.

### Matching an application

`processNames` matches the **executable**, not the name on the icon — Visual
Studio Code is `Electron`. Look it up with `GET /v1/apps?q=code`. Application
rules are enforced only when the core owns the interface: check
`processRoutingAvailable` in `GET /v1/state` before writing one.

## Endpoints

| Method and path | What it does |
| --- | --- |
| `GET /v1/schema` | every endpoint, machine-readable |
| `GET /v1/state` | connection, mode, counts, what can be enforced |
| `GET /v1/servers` | nodes with the tag a rule names them by |
| `GET /v1/sources` | where nodes came from, and what a fetch skipped |
| `POST /v1/sources/refresh` | re-download every source |
| `GET` / `PUT /v1/nodes` | the user's labels, pins, hides and renames |
| `GET /v1/apps?q=&limit=` | applications, with executable names |
| `GET` / `PUT /v1/rules` | the ordered rules |
| `GET` / `PUT /v1/groups` | groups, including automatic ones |
| `GET` / `PUT /v1/dns` | resolver settings |
| `GET` / `PUT /v1/preset` | the preset, and the ones available |
| `GET /v1/config` | the profile the current settings would produce |
| `GET /v1/logs?limit=&level=&q=` | the tail of the core's log, redacted |
| `GET /v1/diagnostics` | the redacted diagnostics report |
| `POST /v1/apply` | push the current settings into a live connection |
| `POST /v1/connect` | `{"serverID": "<uuid>"}` |
| `POST /v1/disconnect` | stop the tunnel |

Every `PUT` replaces the whole collection. Read, edit the array you were given,
put it back — there is no partial update, and inventing one would race with the
user editing the same list in the window.

## Recipes

**Send one application through a specific node.**

```bash
TOKEN=...                       # Settings → Advanced → Control API
API=http://127.0.0.1:9091
H="Authorization: Bearer $TOKEN"

curl -s -H "$H" "$API/v1/apps?q=slack"        # → processName
curl -s -H "$H" "$API/v1/servers"             # → the node's uuid
curl -s -H "$H" "$API/v1/rules" > rules.json  # edit, keeping the order
curl -s -X PUT -H "$H" --data @rules.json "$API/v1/rules"
curl -s -X POST -H "$H" "$API/v1/apply"       # or it waits for the next connect
```

A rule looks like this:

```json
{"name": "Work", "target": "server:3B1F…", "processNames": ["Slack"],
 "enabled": true}
```

**Explain a server the user cannot find.**

```bash
curl -s -H "$H" "$API/v1/sources"
```

The `skipped` notes say what the last fetch dropped and why — an outbound type
this build does not speak, a link scheme it does not parse. A node missing from
the list is usually there.

**Say why a domain is still going direct.**

```bash
curl -s -H "$H" "$API/v1/rules"                      # first match wins
curl -s -H "$H" "$API/v1/config" | jq '.route.rules' # what the core was given
curl -s -H "$H" "$API/v1/logs?level=warning&limit=50"
```

## Statuses

| Code | Meaning |
| --- | --- |
| `400` | the body could not be read, or a value is not one that exists |
| `401` | missing or wrong token |
| `403` | the request came from a web page |
| `404` | no such endpoint, or no server with that id |
| `500` | the profile could not be rendered — the message says why |

A rejected write changes nothing.

## Behaviour to rely on

- Writes are saved immediately and reach a **running** connection only on the
  next connect or on `POST /v1/apply`. `GET /v1/config` always reflects the
  settings, connected or not.
- A rule naming a group that currently matches nothing is not an error: the
  profile falls back to the default outbound rather than refusing to start.
- Ordering is meaningful everywhere it exists — rules, and a group's members.
  Preserve it when you write a collection back.
