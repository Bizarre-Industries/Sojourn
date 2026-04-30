# 0015 — Keyless Sigstore as default for plugin trust; static-key as fallback

- **Status**: Accepted (lands in implementation-plan phase 14)
- **Date**: 2026-04-30
- **Deciders**: Sojourn maintainer
- **Supplements**: [0013-out-of-process-plugins.md](0013-out-of-process-plugins.md)

## Context

[0013-out-of-process-plugins.md](0013-out-of-process-plugins.md) established
that plugins are signature-required and verified via cosign. The Q2 audit
question
([process/open-questions.md](../process/open-questions.md) §1 / audit §8 Q2)
deferred the trust-model details to the maintainer, and ADR-0013's Decision
section + the v0.1 [reference/plugin-protocol.md](../reference/plugin-protocol.md)
manifest schema both assumed `cosign sign-blob --key`-style signing with a
per-plugin static `public_key` baked into the manifest.

That is the pre-Cosign-v3 model. Cosign v3.0 (released 2025) defaults to
**keyless signing via Fulcio + Rekor**: signatures bind to an OIDC identity
(e.g. a GitHub Actions workflow URL), short-lived Fulcio certificates encode
that identity, and every signature lands in the public Rekor transparency
log. Verification requires `--certificate-identity` and
`--certificate-oidc-issuer`, not a key file. Static-key signing still works
but is now the secondary path.

For Sojourn's plugin host, the consequences of the static-key model are real:

- Author key rotation is user-disruptive — every key change requires every
  user to update the trust list.
- Stolen static keys sign forever and silently. Keyless signing leaves a
  Rekor log entry that anyone monitoring the log can detect.
- A trust list of pubkeys grows linearly with every author and every
  rotation. A trust list of `(identity_pattern, oidc_issuer)` pairs is
  small (5–20 entries typical), stable across signing-key rotation.

## Decision

v1 plugin host is **signature-required**. Verification uses **keyless
Sigstore** by default. Static-key verification is supported as a fallback
for offline / private plugins.

Plugin manifest declares one of two signature modes:

```toml
# Keyless (default; recommended)
[signature]
mode             = "keyless"
cert_identity    = "https://github.com/sojourn-plugins/mise/.github/workflows/release.yml@refs/tags/v*"
cert_oidc_issuer = "https://token.actions.githubusercontent.com"

# OR static-key (offline / private)
[signature]
mode       = "key"
public_key = "<base64-encoded ed25519 public key>"
```

Trust list lives at
`~/Library/Application Support/Sojourn/plugins/trust.toml` and is editable
in Settings → Plugins → Trust list. For keyless plugins, entries are
`(cert_identity_pattern, cert_oidc_issuer)` pairs. For static-key plugins,
entries are pubkey fingerprints.

Verification runs on first load **and** on every plugin update (not just
first-load — that gates downgrade-to-malicious-version where an updated
plugin bundle ships an unsigned binary the user previously trusted via a
different version).

User can override per-plugin via Settings → Plugins → [plugin] → "Allow
unsigned" (red banner). Override is per-version, not per-plugin-name —
re-prompts on every update.

Implementation: bundled `cosign` binary (per
[0009-bundle-binary-policy.md](0009-bundle-binary-policy.md)) handles
verification via `cosign verify-blob --bundle <path> --certificate-identity ...`.
Or sigstore-go embedded if bundle size is a concern; deferred to the
implementer.

## Consequences

### Positive

- Author key rotation no longer breaks user trust lists.
- Compromise detectable post-hoc via public Rekor log.
- Trust list is small and stable.
- Aligns with the 2026 default in the Cosign / Sigstore ecosystem.
- Fallback static-key path covers the offline-plugin and private-plugin
  cases that keyless can't serve.

### Negative

- One more bundled binary (`cosign`) or one more embedded library
  (`sigstore-go`).
- Verification requires network access to Fulcio / Rekor on first verify
  (offline-bundle verification with embedded TUF root mitigates;
  `cosign verify-blob --bundle` supports `--offline` once the bundle is
  cached).
- Plugin authors need to set up Sigstore signing in their CI. Lower bar
  than custom PKI; non-zero.

### Neutral

- ADR-0013's "signature-required, JSON-RPC over stdio, out-of-process"
  decision is unchanged. This ADR specifies the *how* of signature
  verification only.

## Alternatives considered

- **Static-key only (ADR-0013 v0.1 spec)** — rejected. Misses the whole
  Sigstore identity-binding story; fragile to author key rotation; no
  transparency log.
- **Keyless only (no static-key fallback)** — rejected. Cuts off offline
  plugins and users who can't or won't set up OIDC-based CI signing.
- **Notation / OCI signing instead of cosign** — rejected. Sojourn already
  bundles cosign-compatible tooling; Notation adds an enterprise-PKI
  workflow Sojourn's audience doesn't need.
- **Trust on first use (TOFU)** — rejected. Acceptable for SSH host keys
  where the user has out-of-band verification; not acceptable for
  package-installer plugins where a first-use compromise is silent and
  full-root.
