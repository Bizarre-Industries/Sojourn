#!/usr/bin/env python3
"""
check-expiry.py — Sojourn maintainer-setup Phase 12.

Reads .github/expiry-tracking.yml, queries live expiry where possible,
and opens/updates/closes GitHub issues at threshold crossings.

Modes:
  python check-expiry.py             # run the check (CI mode)
  python check-expiry.py --validate  # schema-validate the YAML, exit 0/1

Environment (required for `run` mode):
  APPSTORE_API_KEY_ID
  APPSTORE_API_ISSUER_ID
  APPSTORE_API_KEY_P8        # full .p8 PEM contents
  HOMEBREW_TAP_TOKEN         # PAT being tracked
  GH_TOKEN                   # repo-scoped token for issues:write
  GITHUB_REPOSITORY          # owner/repo

Issue-state model:
  * One open issue per item id. Title pattern:
    "[rotation] <description> — expires in N days"
  * Labels escalate as expiry approaches. Body re-renders on every run.
  * Closed when item expiry is past all thresholds, or when item is
    removed from the YAML.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml


# --------------------------------------------------------------------------- #
# Constants                                                                   #
# --------------------------------------------------------------------------- #

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
CONFIG_PATH = REPO_ROOT / ".github" / "expiry-tracking.yml"

DEFAULT_THRESHOLDS = [60, 30, 14, 7, 0]
ISSUE_LABEL_BASE = "rotation-needed"
ISSUE_LABEL_EXPIRED = "rotation-expired"
APPSTORE_BASE = "https://api.appstoreconnect.apple.com"
GITHUB_BASE = "https://api.github.com"
ISSUE_TITLE_PREFIX = "[rotation]"


VALID_QUERIES = {"apple_cert", "github_pat", "manual"}
VALID_APPLE_CERT_TYPES = {
    "DEVELOPMENT",
    "DISTRIBUTION",
    "DEVELOPER_ID_APPLICATION",
    "DEVELOPER_ID_KEXT",
    "MAC_APP_DISTRIBUTION",
    "MAC_INSTALLER_DISTRIBUTION",
    "MAC_APP_DEVELOPMENT",
    "PASS_TYPE_ID",
}


# --------------------------------------------------------------------------- #
# Models                                                                      #
# --------------------------------------------------------------------------- #


@dataclass
class Item:
    id: str
    description: str
    query: str
    apple_cert_type: str | None
    manual_expiry: dt.date | None
    thresholds: list[int]
    rotation_notes: str

    @property
    def issue_title_root(self) -> str:
        return f"{ISSUE_TITLE_PREFIX} {self.description}"


@dataclass
class Result:
    item: Item
    expiry: dt.date | None
    days_left: int | None
    error: str | None


# --------------------------------------------------------------------------- #
# Config loading + validation                                                 #
# --------------------------------------------------------------------------- #


def load_config(strict: bool = False) -> tuple[list[Item], int]:
    raw = yaml.safe_load(CONFIG_PATH.read_text())

    if not isinstance(raw, dict) or "items" not in raw:
        raise ValueError("config missing top-level `items:` key")

    grace = int(raw.get("last_rotation_grace_days", 7))

    items: list[Item] = []
    seen_ids: set[str] = set()

    for i, raw_item in enumerate(raw["items"]):
        if not isinstance(raw_item, dict):
            raise ValueError(f"items[{i}] is not a mapping")

        for required in ("id", "description", "query"):
            if required not in raw_item:
                raise ValueError(f"items[{i}] missing required key `{required}`")

        item_id = raw_item["id"]
        if not isinstance(item_id, str) or not item_id.replace("_", "").isalnum():
            raise ValueError(f"items[{i}].id must be snake_case alnum, got {item_id!r}")
        if item_id in seen_ids:
            raise ValueError(f"items[{i}].id duplicate: {item_id!r}")
        seen_ids.add(item_id)

        query = raw_item["query"]
        if query not in VALID_QUERIES:
            raise ValueError(f"items[{i}].query must be one of {VALID_QUERIES}, got {query!r}")

        apple_cert_type = raw_item.get("apple_cert_type")
        if query == "apple_cert":
            if apple_cert_type not in VALID_APPLE_CERT_TYPES:
                raise ValueError(
                    f"items[{i}].apple_cert_type must be one of {VALID_APPLE_CERT_TYPES}"
                )

        manual_expiry: dt.date | None = None
        if query == "manual":
            raw_exp = raw_item.get("manual_expiry")
            if not raw_exp:
                raise ValueError(f"items[{i}].manual_expiry required when query=manual")
            try:
                # YAML parses ISO dates as date objects already; accept str too
                manual_expiry = (
                    raw_exp if isinstance(raw_exp, dt.date) else dt.date.fromisoformat(str(raw_exp))
                )
            except ValueError as exc:
                raise ValueError(f"items[{i}].manual_expiry not ISO-8601 YYYY-MM-DD: {exc}")

        thresholds = raw_item.get("thresholds", DEFAULT_THRESHOLDS)
        if not isinstance(thresholds, list) or not all(isinstance(t, int) for t in thresholds):
            raise ValueError(f"items[{i}].thresholds must be list[int]")
        thresholds = sorted(set(thresholds), reverse=True)
        if 0 not in thresholds:
            thresholds.append(0)  # always include the at-expiry threshold

        items.append(
            Item(
                id=item_id,
                description=raw_item["description"],
                query=query,
                apple_cert_type=apple_cert_type,
                manual_expiry=manual_expiry,
                thresholds=thresholds,
                rotation_notes=raw_item.get("rotation_notes", "(no notes)"),
            )
        )

    return items, grace


# --------------------------------------------------------------------------- #
# Apple Store Connect — query certificate expiry                              #
# --------------------------------------------------------------------------- #


def appstore_jwt() -> str:
    key_id = os.environ["APPSTORE_API_KEY_ID"]
    issuer_id = os.environ["APPSTORE_API_ISSUER_ID"]
    p8_pem = os.environ["APPSTORE_API_KEY_P8"]

    now = int(time.time())
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + 60 * 19,  # max 20m per Apple; use 19 for clock skew
        "aud": "appstoreconnect-v1",
    }
    import jwt

    return jwt.encode(
        payload,
        p8_pem,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def appstore_query_cert_expiry(cert_type: str) -> dt.date:
    """Most recent (latest expirationDate) cert of the given type."""
    token = appstore_jwt()
    url = f"{APPSTORE_BASE}/v1/certificates"
    params = {
        "filter[certificateType]": cert_type,
        "limit": 200,
        "sort": "-expirationDate",
    }
    import requests

    resp = requests.get(
        url, params=params, headers={"Authorization": f"Bearer {token}"}, timeout=30
    )
    resp.raise_for_status()
    data = resp.json().get("data", [])
    if not data:
        raise RuntimeError(f"no certs of type {cert_type} found")

    # data is sorted desc by expirationDate; first is most recent
    iso = data[0]["attributes"]["expirationDate"]
    # Apple returns "2031-04-30T12:34:56.000+0000" — parse only the date part
    return dt.datetime.fromisoformat(iso.replace("Z", "+00:00")).date()


# --------------------------------------------------------------------------- #
# GitHub PAT — query expiry from response header                              #
# --------------------------------------------------------------------------- #


def github_pat_expiry(token: str) -> dt.date:
    """
    Query GitHub API with the token; read the
    `github-authentication-token-expiration` response header.
    Available for fine-grained PATs since 2022.
    """
    import requests

    resp = requests.get(
        f"{GITHUB_BASE}/user",
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
        },
        timeout=15,
    )
    resp.raise_for_status()

    header = resp.headers.get("github-authentication-token-expiration")
    if not header:
        raise RuntimeError(
            "GitHub did not return github-authentication-token-expiration header. "
            "Either the token is a classic PAT (use fine-grained), or the token "
            "doesn't have an expiration set."
        )
    # Header format: "2027-04-30 09:00:00 UTC"
    return dt.datetime.strptime(header, "%Y-%m-%d %H:%M:%S %Z").date()


# --------------------------------------------------------------------------- #
# Per-item resolution                                                         #
# --------------------------------------------------------------------------- #


def resolve(item: Item, today: dt.date) -> Result:
    try:
        if item.query == "apple_cert":
            assert item.apple_cert_type
            expiry = appstore_query_cert_expiry(item.apple_cert_type)
        elif item.query == "github_pat":
            token = os.environ.get("HOMEBREW_TAP_TOKEN")
            if not token:
                raise RuntimeError("HOMEBREW_TAP_TOKEN not set in env")
            expiry = github_pat_expiry(token)
        elif item.query == "manual":
            assert item.manual_expiry
            expiry = item.manual_expiry
        else:
            raise RuntimeError(f"unknown query: {item.query}")

        days_left = (expiry - today).days
        return Result(item=item, expiry=expiry, days_left=days_left, error=None)

    except Exception as exc:  # noqa: BLE001 — top-level in a runner
        return Result(item=item, expiry=None, days_left=None, error=str(exc))


# --------------------------------------------------------------------------- #
# GitHub issue management                                                     #
# --------------------------------------------------------------------------- #


def gh_session() -> requests.Session:
    import requests

    sess = requests.Session()
    sess.headers.update(
        {
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {os.environ['GH_TOKEN']}",
            "X-GitHub-Api-Version": "2022-11-28",
        }
    )
    return sess


def all_rotation_issues(sess: requests.Session, repo: str) -> list[dict[str, Any]]:
    url = f"{GITHUB_BASE}/repos/{repo}/issues"
    out: list[dict[str, Any]] = []
    page = 1
    while True:
        resp = sess.get(
            url,
            params={"state": "open", "labels": ISSUE_LABEL_BASE, "per_page": 100, "page": page},
            timeout=30,
        )
        resp.raise_for_status()
        chunk = resp.json()
        if not chunk:
            break
        out.extend(chunk)
        page += 1
    return out


def find_issue_for_item(issues: list[dict[str, Any]], item: Item) -> dict[str, Any] | None:
    for issue in issues:
        if issue["title"].startswith(item.issue_title_root):
            return issue
    return None


def label_for_days(days: int, thresholds: list[int]) -> str:
    if days <= 0:
        return ISSUE_LABEL_EXPIRED
    for t in thresholds:
        if days <= t and t > 0:
            # rotation-needed-30d, rotation-needed-14d, etc.
            # for the broadest threshold, drop the suffix so the base
            # label is used
            if t == max(t for t in thresholds if t > 0):
                return ISSUE_LABEL_BASE
            return f"{ISSUE_LABEL_BASE}-{t}d"
    return ISSUE_LABEL_BASE


def render_body(result: Result, *, severity: str) -> str:
    item = result.item
    parts = [
        f"**{severity}**",
        "",
        f"- **Item**: `{item.id}`",
        f"- **Query**: `{item.query}`",
        f"- **Expires**: {result.expiry.isoformat() if result.expiry else 'unknown'}",
        f"- **Days left**: {result.days_left if result.days_left is not None else 'unknown'}",
        "",
        "## Rotation steps",
        "",
        item.rotation_notes,
        "",
        "---",
        "",
        "_This issue is auto-managed by `.github/workflows/expiry-check.yml`._",
        "_It will auto-close once the live expiry is past all thresholds._",
        "_For manual items, update `.github/expiry-tracking.yml` after rotating._",
    ]
    return "\n".join(parts)


def severity_for(days: int | None) -> str:
    if days is None:
        return "ERROR — could not determine expiry"
    if days <= 0:
        return f"⛔️ EXPIRED {-days} days ago"
    if days <= 7:
        return f"🚨 Expires in {days} days — rotate now"
    if days <= 14:
        return f"⚠️ Expires in {days} days"
    if days <= 30:
        return f"⚠️ Expires in {days} days"
    return f"ℹ️ Expires in {days} days"


def upsert_issue(
    sess: requests.Session,
    repo: str,
    result: Result,
    existing: dict[str, Any] | None,
) -> None:
    item = result.item
    days = result.days_left
    severity = severity_for(days)
    title = f"{item.issue_title_root} — {severity.split('—')[0].strip()}"

    # Determine target label set
    if days is None:
        target_labels = {ISSUE_LABEL_BASE, "rotation-system-failure"}
    else:
        target_labels = {label_for_days(days, item.thresholds)}

    body = render_body(result, severity=severity)

    if existing is None:
        sess.post(
            f"{GITHUB_BASE}/repos/{repo}/issues",
            json={"title": title, "body": body, "labels": sorted(target_labels)},
            timeout=30,
        ).raise_for_status()
        print(f"opened: {title}")
        return

    # Update existing
    existing_labels = {l["name"] for l in existing["labels"]}
    rotation_labels = {l for l in existing_labels if l.startswith("rotation-")}

    needs_update = (
        existing["title"] != title
        or existing["body"] != body
        or rotation_labels != target_labels
    )
    if not needs_update:
        print(f"unchanged: #{existing['number']} ({item.id})")
        return

    new_labels = (existing_labels - rotation_labels) | target_labels
    sess.patch(
        f"{GITHUB_BASE}/repos/{repo}/issues/{existing['number']}",
        json={"title": title, "body": body, "labels": sorted(new_labels)},
        timeout=30,
    ).raise_for_status()
    print(f"updated: #{existing['number']} ({item.id}) — {severity}")


def close_issue(sess: requests.Session, repo: str, issue: dict[str, Any], reason: str) -> None:
    sess.post(
        f"{GITHUB_BASE}/repos/{repo}/issues/{issue['number']}/comments",
        json={"body": f"Auto-closed: {reason}"},
        timeout=30,
    ).raise_for_status()
    sess.patch(
        f"{GITHUB_BASE}/repos/{repo}/issues/{issue['number']}",
        json={"state": "closed", "state_reason": "completed"},
        timeout=30,
    ).raise_for_status()
    print(f"closed: #{issue['number']} — {reason}")


# --------------------------------------------------------------------------- #
# Main                                                                        #
# --------------------------------------------------------------------------- #


def run_check() -> int:
    items, grace = load_config()
    today = dt.date.today()
    repo = os.environ["GITHUB_REPOSITORY"]

    sess = gh_session()
    open_issues = all_rotation_issues(sess, repo)

    exit_code = 0
    item_ids_with_issues: set[str] = set()

    for item in items:
        result = resolve(item, today)
        existing = find_issue_for_item(open_issues, item)

        if result.error:
            print(f"ERROR resolving {item.id}: {result.error}", file=sys.stderr)
            exit_code = 1
            # Open or update with an error issue so it's visible
            upsert_issue(sess, repo, result, existing)
            if existing:
                item_ids_with_issues.add(item.id)
            continue

        assert result.days_left is not None
        max_threshold = max(item.thresholds)

        if result.days_left > max_threshold:
            # Within healthy zone — close any existing issue
            if existing:
                close_issue(
                    sess,
                    repo,
                    existing,
                    f"expiry now {result.expiry.isoformat()} "
                    f"({result.days_left} days), past all thresholds",
                )
            else:
                print(f"healthy: {item.id} ({result.days_left} days)")
            continue

        upsert_issue(sess, repo, result, existing)
        item_ids_with_issues.add(item.id)

    # Anything in open_issues that doesn't correspond to a current item:
    # the item was removed from the YAML. Close it.
    for issue in open_issues:
        # Reverse-match: which item, if any, owns this issue?
        match = next(
            (i for i in items if issue["title"].startswith(i.issue_title_root)),
            None,
        )
        if match is None:
            close_issue(
                sess,
                repo,
                issue,
                "tracking item was removed from .github/expiry-tracking.yml",
            )

    return exit_code


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--validate", action="store_true", help="schema-validate config and exit")
    args = parser.parse_args()

    if args.validate:
        try:
            items, grace = load_config()
            print(f"OK — {len(items)} items, grace={grace} days")
            return 0
        except Exception as exc:  # noqa: BLE001
            print(f"INVALID: {exc}", file=sys.stderr)
            return 1

    return run_check()


if __name__ == "__main__":
    sys.exit(main())
