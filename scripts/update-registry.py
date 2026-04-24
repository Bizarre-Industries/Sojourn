#!/usr/bin/env python3
"""scripts/update-registry.py -- Mackup → Sojourn application registry.

Fetches lra/mackup at a given ref, parses its `applications/*.cfg` files,
and emits Sojourn-flavored TOML under
`Sojourn/Resources/data/applications/<bundle_id>.toml`.

Each Mackup entry looks like:

    [application]
    name = Terminal
    bundle_id = com.apple.Terminal

    [configuration_files]
    Library/Preferences/com.apple.Terminal.plist
    Library/Preferences/com.apple.Terminal.LSSharedFileList.plist

Sojourn's plist-layer model (docs/ARCHITECTURE.md §8) classifies the first
prefs path's domain as the canonical one; anything under the user's
sandboxed container is marked `sandboxed` (deferred to v2).

Usage:
    scripts/update-registry.py --mackup-ref master \\
        --staging-dir staging/mackup --out Sojourn/Resources/data/applications/
"""

from __future__ import annotations

import argparse
import configparser
import subprocess
import sys
from pathlib import Path

REGISTRY_HEADER = """# Sojourn — application preference registry entry
# Upstream source: Mackup (GPL-3.0-or-later),
# https://github.com/lra/mackup/blob/{ref}/mackup/applications/{source}
# Re-classified for Sojourn's plist-layer model per docs/ARCHITECTURE.md §8.

"""


def classify_layer(path: str) -> str:
    lowered = path.lower()
    if "library/containers/" in lowered:
        return "sandboxed"
    if lowered.startswith("library/preferences/") or "/preferences/" in lowered:
        return "user"
    if lowered.startswith("library/application support/"):
        return "user"
    return "user"


def extract_domain(paths: list[str], bundle_id: str) -> str:
    for p in paths:
        if p.endswith(".plist") and bundle_id.lower() in p.lower():
            leaf = p.rsplit("/", 1)[-1]
            return leaf[: -len(".plist")]
    return bundle_id


def derive_bundle_id(prefs: list[str]) -> str | None:
    """Pull a bundle ID out of the first Library/Preferences/*.plist path."""
    for p in prefs:
        if "library/preferences/" in p.lower() and p.endswith(".plist"):
            leaf = p.rsplit("/", 1)[-1][: -len(".plist")]
            # strip .LSSharedFileList and similar per-feature suffixes
            if leaf.count(".") >= 2:
                return leaf
    return None


def convert(cfg_path: Path, out_dir: Path, ref: str) -> Path | None:
    parser = configparser.ConfigParser(allow_no_value=True, strict=False)
    parser.read(cfg_path, encoding="utf-8")

    if "application" not in parser:
        return None
    name = parser["application"].get("name") or cfg_path.stem

    prefs: list[str] = []
    for section in ("configuration_files", "xdg_configuration_files"):
        if section in parser:
            prefs.extend(k.strip() for k in parser[section] if k.strip())

    bundle_id = parser["application"].get("bundle_id") or derive_bundle_id(prefs)
    if not bundle_id:
        return None

    domain = extract_domain(prefs, bundle_id)
    layer = classify_layer(prefs[0]) if prefs else "user"
    syncable = layer != "sandboxed"

    content = REGISTRY_HEADER.format(ref=ref, source=cfg_path.name) + (
        "[application]\n"
        f'bundle_id = "{bundle_id}"\n'
        f'domain = "{domain}"\n'
        f'layer = "{layer}"\n'
        f"syncable = {str(syncable).lower()}\n"
        f'display_name = "{name}"\n'
    )
    target = out_dir / f"{bundle_id}.toml"
    target.write_text(content, encoding="utf-8")
    return target


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--mackup-ref", default="master")
    ap.add_argument("--staging-dir", default="staging/mackup")
    ap.add_argument("--out", default="Sojourn/Resources/data/applications")
    args = ap.parse_args(argv)

    staging = Path(args.staging_dir)
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    if not staging.exists():
        staging.parent.mkdir(parents=True, exist_ok=True)
        print(f"cloning lra/mackup at {args.mackup_ref}...", file=sys.stderr)
        subprocess.run(
            [
                "git", "clone", "--depth", "1", "--branch", args.mackup_ref,
                "https://github.com/lra/mackup.git", str(staging),
            ],
            check=True,
        )

    # Mackup moved its sources from `mackup/applications` to
    # `src/mackup/applications` circa 2024 — check both.
    candidates = [
        staging / "src" / "mackup" / "applications",
        staging / "mackup" / "applications",
    ]
    cfg_root = next((c for c in candidates if c.exists()), None)
    if cfg_root is None:
        joined = ", ".join(str(c) for c in candidates)
        print(f"error: no applications dir found (tried: {joined})", file=sys.stderr)
        return 1

    written = 0
    for cfg in sorted(cfg_root.glob("*.cfg")):
        target = convert(cfg, out_dir, args.mackup_ref)
        if target is not None:
            print(f"wrote {target}")
            written += 1
    print(f"converted {written} applications", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
