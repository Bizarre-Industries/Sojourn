# Plugin protocol

Out-of-process plugin host for Sojourn. Decision recorded in
[decisions/0013-out-of-process-plugins.md](../decisions/0013-out-of-process-plugins.md).
Trust model in
[decisions/0015-keyless-cosign-plugin-trust.md](../decisions/0015-keyless-cosign-plugin-trust.md).
Audit driver:
[process/audit-2026-04.md §2.7](../process/audit-2026-04.md#27-plugin-protocol).

## Layout

```
~/Library/Application Support/Sojourn/plugins/
└── <name>.sojourn-plugin/
    ├── manifest.toml        # name, version, capabilities, tier default, signature
    ├── plugin               # executable (any language)
    └── plugin.cosign.bundle  # cosign verification material (keyless mode)
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

# Keyless Sigstore signing (default; recommended).
# Verifier checks that `plugin.cosign.bundle` was signed by the OIDC
# identity below at the OIDC issuer below.
[signature]
mode             = "keyless"
cert_identity    = "https://github.com/sojourn-plugins/mise/.github/workflows/release.yml@refs/tags/v*"
cert_oidc_issuer = "https://token.actions.githubusercontent.com"

# OR static-key signing (offline / private plugins).
# [signature]
# mode       = "key"
# public_key = "<base64-encoded ed25519 public key>"
```

Per ADR-0015, `mode = "keyless"` is the default. `mode = "key"` is the
fallback for plugins that can't or don't sign via a Sigstore-compatible
OIDC provider — typically offline / private plugins.

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
```

```json
{"jsonrpc":"2.0","method":"progress","params":{
  "stage":"download","completed":42,"total":100,"text":"Downloading node…"
}}
```

The host renders these in the live log pane.

## Trust model

v1 plugin host is **signature-required** and uses **keyless Sigstore
verification by default**, per ADR-0015. Static-key verification is the
fallback for offline / private plugins.

### Keyless verification (default)

1. Plugin manifest declares
   `signature.mode = "keyless"` + `cert_identity` + `cert_oidc_issuer`.
2. Plugin author signs the executable + manifest in CI via `cosign
   sign-blob` against the manifest's declared OIDC identity.
   Verification material lands in `plugin.cosign.bundle` shipped
   alongside the plugin.
3. Host verifies on first load + on every plugin update via
   `cosign verify-blob --bundle plugin.cosign.bundle
   --certificate-identity <pattern> --certificate-oidc-issuer <issuer>`.
4. Identity-pattern match supports glob/regex (e.g. `@refs/tags/v*` to
   accept any tagged release; `@refs/heads/main` rejected by default).
5. Failed verification → plugin disabled, user notified, red banner in
   Settings → Plugins.

Trust list lives at
`~/Library/Application Support/Sojourn/plugins/trust.toml`. Entries are
`(cert_identity_pattern, cert_oidc_issuer)` pairs. Editable in
Settings → Plugins → Trust list.

### Static-key verification (fallback)

1. Plugin manifest declares `signature.mode = "key"` + `public_key`.
2. Plugin author signs via `cosign sign-blob --key cosign.key`.
3. Host verifies via `cosign verify-blob --key <pubkey>`.
4. Trust list entry is the pubkey fingerprint.

### Override

User can override the signature requirement per-plugin via Settings →
Plugins → [plugin] → "Allow unsigned" (red banner). Override is
**per-version** — re-prompts on every plugin update. This blocks the
downgrade-to-malicious-version case where an updated bundle ships an
unsigned binary the user previously trusted.

## Reference plugins

Validation set for the protocol:

1. **mise** — clean JSON CLI (`mise ls --json`). First reference plugin.
   Phase 14 deliverable.
2. **gh extension** — different shape (extensions, not packages). Tests
   the protocol's flexibility.
3. **krew** / **helm-plugin** — k8s users. Validates per-cluster context.

Native cargo / mas are **not** plugin-protocol validators — they would
conform to `PackageBackend` (Phase 10), an in-process Swift protocol that
shares no code with the plugin host. See
[process/open-questions.md](../process/open-questions.md) §1.

## Out of process — why

Per [decisions/0013-out-of-process-plugins.md](../decisions/0013-out-of-process-plugins.md):

- Crash isolation.
- License firewall (matches the IPC-not-linking invariant).
- Language-agnostic: Swift, Go, shell, anything that can read JSON.
- Signable per plugin via cosign (keyless or static-key per ADR-0015).

In-process Swift bundles considered and rejected.

## How-to

See [how-to/development/add-package-manager.md](../how-to/development/add-package-manager.md)
for adding a manager that mpm doesn't cover; the same flow covers writing
a Sojourn plugin.
