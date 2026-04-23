#!/usr/bin/env python3
"""
scripts/update-registry.py -- refresh Sojourn/Resources/data/applications/
from the upstream Mackup repo. Re-classifies each entry per
docs/ARCHITECTURE.md section 8.

Human review required before committing the diff. This script does not
auto-merge; it writes candidate TOML files to a staging directory and
prints a diff against the current data.
"""

from __future__ import annotations
import argparse
import pathlib
import sys


MACKUP_REPO = "https://github.com/lra/mackup"
STAGING_DIR = pathlib.Path("build/registry-staging")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--mackup-ref",
        default="master",
        help="Git ref of lra/mackup to pull (default: master).",
    )
    parser.add_argument(
        "--staging-dir",
        default=str(STAGING_DIR),
        help="Where to write candidate TOML files.",
    )
    args = parser.parse_args()

    staging = pathlib.Path(args.staging_dir)
    staging.mkdir(parents=True, exist_ok=True)

    print(
        f"would clone {MACKUP_REPO}@{args.mackup_ref} and re-classify applications/",
        file=sys.stderr,
    )
    print(f"staging dir: {staging}", file=sys.stderr)
    print(
        "stub -- wire up Mackup .cfg -> Sojourn .toml conversion logic",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
