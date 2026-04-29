# chezmoi

chezmoi v2.70.2, MIT, single static Go binary.
[https://github.com/twpayne/chezmoi](https://github.com/twpayne/chezmoi).

## Machine-readable output

- `chezmoi managed --format=json` — stable JSON. Use this for the file tree
  UI.
- `chezmoi data --format=json` — full template data dict, useful to populate
  the per-machine template-variable editor.
- `chezmoi dump --format=json` — target state for a set of files.
- `chezmoi dump-config --format=json` — effective merged config. Note:
  `cat-config` has no JSON mode (use `dump-config`).
- `chezmoi status` — **not JSON, git-status-style plaintext**. Parse with
  `^([ ADMR])([ ADMR]) (.+)$`. The `MM` vs `M ` distinction is
  under-documented (issues #2635, #4180); treat as advisory.
- `chezmoi diff` — **not JSON, hybrid unified-diff + pseudo-shell commands**
  (symlinks, scripts, dir modes). Issue #677 still open. Sojourn renders it
  verbatim in a terminal-style pane; it does not attempt structured diff.
  Always pass `--no-pager --color=false` when capturing.
- `chezmoi execute-template` — useful for previewing templated output in the
  editor.
- `chezmoi verify` — exit code signal only. Good for a green/red status-bar
  dot.

## Behaviours that will bite the UI

- `chezmoi apply` is **interactive by default** if the target was modified
  since last write. Sojourn runs `status` + `diff` first, shows the user a
  diff-and-resolve pane, then invokes `apply --force` with explicit consent.
- `diff`/`status`/`verify` take a read lock. Serialize polling.
- Age builtin does not support passphrases, symmetric, or SSH keys — those
  need the external `age` binary. Sojourn bundles the external `age` binary;
  it's a tiny Go executable with MIT license.

## Encryption

chezmoi's age integration is the right answer for secrets. Config snippet
committed by Sojourn:

```toml
encryption = "age"
[age]
identity = "~/.config/chezmoi/key.txt"
recipient = "age1..."
```

The key is *not* committed to the repo. Bootstrap on a new machine: Sojourn
prompts for the recipient public key, generates the identity locally via
`chezmoi age-keygen`, and walks the user through adding the new recipient
to the repo so the old Mac can re-encrypt for the new one on next push.
v1 allows only one active writer at a time; multi-recipient support defers
to v2.

chezmoi v2.70.2 switched to `betterleaks` for internal secret detection on
`chezmoi add`. It warns but does not auto-encrypt. Sojourn layers its own
gitleaks scan on top (see [reference/secret-scanning.md](../secret-scanning.md))
because betterleaks is embedded and the user has no control over rules from
the app layer.

## Latency

Sub-second for status/managed/data; 1–5s for diff; `apply` is dominated by
user scripts and can take minutes. Off-main-thread always.

## Audit-flagged unwrapped surface

[process/audit-2026-04.md §2.2](../../process/audit-2026-04.md#22-chezmoi-features-not-surfaced)
calls out features Sojourn does not yet wrap: externals, run scripts
lifecycle, `chezmoi merge`, password-manager template functions,
`chezmoi unmanaged`, `chezmoi forget`, `chezmoi doctor`, `chezmoi state`,
`promptOnce`, `.chezmoitemplates`, `chezmoi update`, `chezmoi git`. These
land in implementation-plan phase 12.
