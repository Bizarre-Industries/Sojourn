# rustup

Rust toolchain installer. **Not a service actor**; synced as
dotfile-classified per audit §2.4.8.

## Files synced

- `~/.rustup/settings.toml` — default toolchain, profile, etc.
- `rust-toolchain.toml` — per-project toolchain pin (already in user's
  project repos, not Sojourn's concern).

## Why dotfile-classified

`rustup` reconciles itself on `rustup update` when settings change.
Sojourn syncs the manifest, rustup does the work.

## Tier

n/a.
