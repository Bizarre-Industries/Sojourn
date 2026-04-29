# 0013 — Plugin protocol is JSON-RPC over stdio; plugins are out-of-process

- **Status**: Proposed (lands in implementation-plan phase 14)
- **Date**: 2026-04-28
- **Deciders**: Sojourn maintainer

## Context

[process/audit-2026-04.md §2.7](../process/audit-2026-04.md#27-plugin-protocol)
promotes a plugin host as the only thing that makes "support as much as
possible" actually safe. Sojourn cannot natively wrap every package
manager + tool-version manager that exists; the long tail (mise, asdf,
rustup, sdkman, volta, gh extensions, krew, helm plugins, cursor
extensions) needs a community-maintainable extension surface.

Two implementation approaches:

1. **In-process Swift bundles** loaded via dynamic linking — fast, but
   plugin crashes take down Sojourn, plugin licensing concerns infect
   the main app, and Apple's notarization story for unsigned dynamic
   bundles is hostile.
2. **Out-of-process JSON-RPC over stdio** — slower per call, but
   crash-isolated, license-firewalled (matches
   [0001-ipc-not-linking.md](0001-ipc-not-linking.md)), and signable per
   plugin via cosign.

## Decision

Plugins are **out-of-process executables** (Swift, Go, shell scripts —
anything that can read JSON on stdin and write JSON on stdout). The host
spawns the plugin executable and communicates via JSON-RPC over stdio.

Layout:

```
~/Library/Application Support/Sojourn/plugins/
└── <name>.sojourn-plugin/
    ├── manifest.toml        # name, version, capabilities, tier default, signature
    └── plugin                # executable
```

Protocol surface:

- `manifest` → returns capability flags
- `installed` → `{packages: [{id, version, name?}]}`
- `outdated` → `{packages: [{id, installed, latest}]}`
- `install`, `remove`, `upgrade`

Trust model: cosign signature verification per plugin. v1 plugin host is
**signature-required** (subject to maintainer decision per audit §8 Q2).

## Consequences

### Positive

- Crash isolation: a plugin OOM does not crash Sojourn.
- License firewall: GPL-3 / AGPL plugins coexist with Sojourn's
  IPC-not-linking invariant.
- Language-agnostic: plugin authors aren't forced into Swift.
- Signable: cosign per plugin gives users a trust trail.

### Negative

- Per-call subprocess overhead (typically 30–100ms; acceptable because
  every operation wraps a much longer package operation).
- Plugin authoring requires implementing the JSON-RPC contract; higher
  bar than a Swift API.

### Neutral

- Reference plugins to validate the protocol: `mise`, `gh extension`,
  `krew` / `helm-plugin` for k8s users.

## Alternatives considered

- **In-process Swift bundles** — rejected. License + crash + signing
  problems above.
- **WebExtensions-style sandboxed scripts** — rejected. Sandbox would
  block subprocess invocation, defeating the point.
- **No plugins; native everything** — rejected. The long tail is too
  large; community-maintainable extensions are the only sustainable
  answer.
