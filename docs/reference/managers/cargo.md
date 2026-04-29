# cargo

Rust's package + binary installer. Backend: `mpm`. Tier **B** (auto, 7d).
Curated `crates.io` reduces supply-chain exposure vs npm/PyPI.

## Binary

`~/.cargo/bin/cargo`.

## Key invocations

- `cargo install --list` — installed binaries.
- No native `outdated`; mpm uses the index API to detect updates.

## Known issues

- `cargo install --list` doesn't include version mismatches against
  upstream. mpm cross-references with the index.
- `~/.cargo/config.toml` lives in the dotfile sync, not here. Sojourn
  syncs the manifest, not the toolchain.
