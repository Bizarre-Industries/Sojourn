# Threat model

What Sojourn protects against, what it doesn't, and where each mitigation
lives. The disclosure policy is at the repo-root [SECURITY.md](../../SECURITY.md);
this page is the engineering rationale.

## Assets

In rough order of value to the attacker:

1. **Credentials inside dotfiles** — AWS keys in `~/.aws/credentials`,
   GitHub PATs in `~/.gitconfig`, OpenAI / Stripe / Slack tokens in shell
   profile, kubeconfig contexts, SSH private keys. Sojourn's data repo
   would be the highest-leverage exfiltration target.
2. **The user's machine state** — packages installed, dotfiles applied,
   preferences set. An attacker who controls Sojourn's data repo can
   effectively remote-execute install scripts on every Mac the user
   onboards.
3. **The user's GitHub account** — Sojourn's optional Device Flow OAuth
   token (Keychain-stored, `repo` scope only) is a capability against the
   data repo; not Sojourn's admin surface but a pivot.
4. **The data repo itself** — git history of system state. Lower value
   on its own but high contextual leverage (which packages, which
   versions, which hosts).

## Adversaries

| Adversary | Capability assumed | In scope? |
|---|---|---|
| Compromised upstream registry (npm, PyPI, Cask) | Publish malicious version of a package the user has installed | **Yes** |
| Compromised git remote (GitHub account takeover, MITM on HTTPS) | Push arbitrary commits to the user's data repo | **Yes** |
| Local user-mode malware on a peer Mac | Read process memory, observe `Process` invocations, read `~/Library/Application Support/Sojourn/` | Partial — Sojourn cannot defend against same-uid malware in a meaningful way; it minimizes attack surface but is not a sandbox |
| Network attacker | TLS-downgrade / DNS hijack against `api.osv.dev`, `github.com`, package registries | Mostly upstream's problem; Sojourn pins to HTTPS, fails closed on missing OSV data |
| Kernel-level / physical attacker | Bypass System Integrity Protection, full-disk read, evil-maid | **No** — out of scope |
| Apple ID / iCloud takeover | Pull arbitrary content from iCloud, modify system | **No** — pre-empts every defence; Sojourn assumes the user owns the device's Apple ID |

## Exposure surfaces

Two surfaces matter.

### 1. The user's git remote

Sojourn reads from and writes to a repo the user owns. If the remote is
compromised, a pull lands an attacker-chosen `packages.toml` and chezmoi
source tree, including `run_*` scripts ([reference/backends/chezmoi.md](../reference/backends/chezmoi.md)).

Mitigations:

- **Pull preview**: every conflict, every `chezmoi diff`, every
  `mpm restore` plan is shown before any subprocess runs. Defer to
  [reference/sync-model.md](../reference/sync-model.md) for the flow.
- **Pre-op snapshot**: every destructive op writes
  `~/Library/Application Support/Sojourn/backups/<ts>-<op>/` first, 30-day
  retention. See [reference/cleanup.md](../reference/cleanup.md).
- **`apply --dry-run` first**: `chezmoi apply --force` is gated behind a
  successful dry-run (audit §2.2.3 promotes this further with `chezmoi
  merge` for text dotfiles).
- **No script lifecycle without consent**: `npm preinstall`,
  `pip` build hooks, `cargo build.rs`, Homebrew cask `installer`
  fragments require an explicit user click, regardless of cooldown
  state ([reference/cooldown-policy.md](../reference/cooldown-policy.md)).

### 2. Upstream package registries

`mpm restore` shells out to `brew install X`, `npm install -g X`, etc.
Trust is delegated to each registry. The 2024–2026 supply-chain incident
list ([reference/cooldown-policy.md "Evidence base"](../reference/cooldown-policy.md#evidence-base--incidents-20242026-a-7-day-gate-blocks-outright))
documents what cooldown blocks.

Mitigations:

- **7-day default cooldown** with per-tier overrides ([decisions/0003-cooldown-7-days.md](../decisions/0003-cooldown-7-days.md)).
- **OSV / GHSA bypass**: published advisories on the *currently
  installed* version skip cooldown and update immediately. Daily refresh
  via `NSBackgroundActivityScheduler`.
- **Tier E (global npm) never silent-updates**: 14-day cooldown plus
  per-version user approval.
- **Pre-commit secret scan**: every auto-commit runs
  `gitleaks dir --staged` first ([decisions/0006-gitleaks-bundled.md](../decisions/0006-gitleaks-bundled.md)).
  High-confidence provider-key findings (AWS, GitHub PAT, OpenAI, Stripe
  live, Anthropic, Slack token) lock the *Commit anyway* button for 5
  seconds — forces the user to read the match before bypassing.
- **Bundled-binary provenance**: `gitleaks` and `age` ship in
  `Contents/Resources/bin/`, downloaded via authenticated
  `gh release download`, re-signed with Sojourn's Developer ID under
  `--options=runtime`, covered by `.app` notarization. `spctl --assess`
  must pass on every release ([decisions/0009-bundle-binary-policy.md](../decisions/0009-bundle-binary-policy.md)).
- **Signed-`.pkg` install for Homebrew** instead of `curl | bash` ([decisions/0008-no-curl-bash-for-brew.md](../decisions/0008-no-curl-bash-for-brew.md)).

What cooldown does **not** block: multi-year maintainer infiltration
(the xz backdoor, CVE-2024-3094, is the flagship case). User-facing copy
must say so explicitly to prevent false confidence.

## Secrets handling

Sojourn refuses to commit plaintext secrets by default. The secret-broker
abstraction ([decisions/0011-secret-broker-abstraction.md](../decisions/0011-secret-broker-abstraction.md))
delegates storage to 1Password, Bitwarden, Keychain, or `age`-encrypted
files. The full provider matrix is in
[reference/secret-brokers.md](../reference/secret-brokers.md).

Sojourn never:

- Stores the user's git credentials in its own Keychain (defers to
  `git-credential-osxkeychain`).
- Embeds an OAuth `client_secret`. Device Flow uses `client_id` only.
- Sends telemetry, crash dumps, or install events anywhere. No
  Sojourn-operated server exists.
- Requests Full Disk Access except for explicit sandboxed-app preference
  sync (opt-in per app).

## Out of scope

- Defending against same-uid malware on the user's own Mac. Sojourn runs
  as the user. A keylogger or process-injection rootkit at the same
  privilege bypasses every Sojourn check.
- Defending against a kernel-level attacker. SIP defeat or
  signed-kext malware are out of scope.
- Defending against physical access (evil-maid, cold-boot). FileVault is
  the user's job.
- Defending against compromise of the user's iCloud / Apple ID.
- Sandboxing the package code that the underlying managers install.
  `npm install left-pad` runs whatever left-pad's maintainer publishes;
  Sojourn doesn't add a second layer (the package manager's own
  isolation, if any, is what it is).

## See also

- [SECURITY.md](../../SECURITY.md) — disclosure policy + report channels.
- [reference/cooldown-policy.md](../reference/cooldown-policy.md) — full
  tier ladder + evidence base.
- [reference/secret-brokers.md](../reference/secret-brokers.md) —
  provider matrix.
- [reference/architecture.md](../reference/architecture.md) — how the
  layers enforce these mitigations structurally.
- [decisions/0006-gitleaks-bundled.md](../decisions/0006-gitleaks-bundled.md),
  [decisions/0008-no-curl-bash-for-brew.md](../decisions/0008-no-curl-bash-for-brew.md),
  [decisions/0009-bundle-binary-policy.md](../decisions/0009-bundle-binary-policy.md),
  [decisions/0011-secret-broker-abstraction.md](../decisions/0011-secret-broker-abstraction.md).
