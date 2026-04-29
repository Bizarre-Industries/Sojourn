# Plugin protocol

Out-of-process plugin host for Sojourn. Decision recorded in
[decisions/0013-out-of-process-plugins.md](../decisions/0013-out-of-process-plugins.md).
Audit driver:
[process/audit-2026-04.md §2.7](../process/audit-2026-04.md#27-plugin-protocol).

## Layout

```
~/Library/Application Support/Sojourn/plugins/
└── <name>.sojourn-plugin/
    ├── manifest.toml        # name, version, capabilities, tier default, signature
    └── plugin               # executable (any language)
```

The host spawns `plugin` as a subprocess and communicates via JSON-RPC 2.0
over stdio.

## Manifest schema

```toml
[plugin]
name = "mise"
version = "0.1.0"
description = "Tool version manager via mise"
homepage = "https://github.com/sojourn-plugins/mise"

[capabilities]
installed = true
outdated = true
install = true
remove = true
upgrade = true
search = false                  # optional capability

[defaults]
tier = "C"                      # cooldown tier (A–E per cooldown-policy.md)
cooldown_days = 7

[signature]
type = "cosign"
public_key = "<base64-encoded cosign public key>"
```

## JSON-RPC methods

All methods are JSON-RPC 2.0. The host sends a `request` with `method`,
`params`, `id`. Plugin responds with `result` or `error`.

### `manifest`

```json
// request
{"jsonrpc":"2.0","method":"manifest","id":1}

// response
{"jsonrpc":"2.0","result":{
  "name":"mise",
  "version":"0.1.0",
  "capabilities":["installed","outdated","install","remove","upgrade"]
},"id":1}
```

### `installed`

```json
// request
{"jsonrpc":"2.0","method":"installed","id":2}

// response
{"jsonrpc":"2.0","result":{
  "packages":[
    {"id":"node@22.13.0","version":"22.13.0","name":"Node.js"},
    {"id":"python@3.13.1","version":"3.13.1","name":"Python"}
  ]
},"id":2}
```

### `outdated`

```json
// response
{"jsonrpc":"2.0","result":{
  "packages":[
    {"id":"node","installed":"22.13.0","latest":"22.13.1"}
  ]
},"id":3}
```

### `install`, `remove`, `upgrade`

```json
// request
{"jsonrpc":"2.0","method":"install","params":{"packages":["node@22.13.1"]},"id":4}

// response
{"jsonrpc":"2.0","result":{
  "installed":["node@22.13.1"],
  "errors":[]
},"id":4}
```

`errors` is the partial-failure channel (matches mpm's per-manager error
shape).

## Streaming output

Plugins may stream progress via JSON-RPC notifications (no `id`):

```json
{"jsonrpc":"2.0","method":"progress","params":{
  "stage":"download","completed":42,"total":100,"text":"Downloading node…"
}}
```

The host renders these in the live log pane.

## Trust model

v1 plugin host is **signature-required** (subject to maintainer decision
per audit §8 Q2). cosign signature verification per plugin:

1. Plugin manifest declares `signature.public_key`.
2. Plugin executable + manifest are signed with the corresponding private
   key via `cosign sign-blob`.
3. Host verifies on first load + on every plugin update.
4. Failed verification → plugin disabled, user notified.

User can override the signature requirement per-plugin via Settings →
Plugins → [plugin] → "Allow unsigned" (advisory: red banner).

## Reference plugins

Validation set for the protocol:

1. **mise** — clean JSON CLI (`mise ls --json`). First reference plugin.
2. **gh extension** — different shape (extensions, not packages). Tests
   the protocol's flexibility.
3. **krew** / **helm-plugin** — k8s users. Validates per-cluster context.

## Out of process — why

Per [decisions/0013-out-of-process-plugins.md](../decisions/0013-out-of-process-plugins.md):

- Crash isolation.
- License firewall (matches the IPC-not-linking invariant).
- Language-agnostic: Swift, Go, shell, anything that can read JSON.
- Signable per plugin via cosign.

In-process Swift bundles considered and rejected.

## How-to

See [how-to/development/add-package-manager.md](../how-to/development/add-package-manager.md)
for adding a manager that mpm doesn't cover; the same flow covers writing
a Sojourn plugin.
