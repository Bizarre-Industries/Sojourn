#!/usr/bin/env bash
# publish-homebrew-cask.sh
#
# Publish a new Sojourn release to the Bizarre-Industries/homebrew-sojourn
# Homebrew tap by direct push to `main`.
#
# WHY DIRECT PUSH (not `brew bump-cask-pr`):
#   The tap PAT (HOMEBREW_TAP_TOKEN / TAP_TOKEN) is fine-grained with
#   `Contents: Read and write` but not `Pull requests: Read and write`.
#   bump-cask-pr's PR-creation step and `gh pr create` both fail on
#   fine-grained PATs lacking that permission. Direct push only needs
#   Contents: write, which the PAT has. See council deliberation:
#   .claude/council-logs/2026-05-01-notarize-publish-direct-push.md and
#   GitHub issue #5 for the path back to the upstream-tooling hybrid.
#
# USAGE:
#   publish-homebrew-cask.sh [--dry-run] <dmg-path>
#
#   <dmg-path>    Path to the notarized + stapled Sojourn.dmg whose
#                 sha256 is the new cask sha.
#   --dry-run     Skip the git push (everything else runs: clone, sed,
#                 verify, audit, commit). Use to validate end-to-end
#                 locally without mutating tap main.
#
# REQUIRED ENV:
#   TAP_TOKEN              Fine-grained PAT (Contents: write) for the tap.
#   GITHUB_REF_NAME        Tag name in `vMAJOR.MINOR.PATCH` form.
#
# OPTIONAL ENV (used in commit message; sensible defaults if unset):
#   GITHUB_SERVER_URL      defaults to https://github.com
#   GITHUB_REPOSITORY      defaults to Bizarre-Industries/Sojourn
#   GITHUB_RUN_ID          defaults to "local"
#
# EXIT CODES:
#   0  cask published; tap main now points at the new commit.
#   1  precondition failed (bad args, bad env, bad tag format).
#   2  edit/verification failed (sed substitutions did not match).
#   3  audit failed (style or online).
#   4  push failed or push-landed verification failed.
#
# SAFEGUARDS (council 2026-05-01-notarize-publish-direct-push, re-vote):
#   * tag-format guard before any string interpolation
#   * `::add-mask::` on the PAT (when running under GitHub Actions)
#   * token scrub via `git remote set-url origin <no-token>` post-clone
#   * ephemeral push token via `-c http.extraheader='AUTHORIZATION: bearer …'`
#   * post-edit positive grep: bumped `version` + `sha256` lines match
#   * post-edit negative grep: old `version` + `sha256` strings absent
#   * online audit via `brew audit --cask --online`, wrapped in `gtimeout 180`
#   * push-landed verification via `git ls-remote origin main`, wrapped in
#     `gtimeout 30`
#
# TODO(self-hosted runner migration): the push embeds the token in
# `git -c http.extraheader='AUTHORIZATION: bearer …' push` argv. On
# ephemeral hosted runners the blast radius is one VM. If we ever move
# to self-hosted runners, switch to a credential helper or GitHub App
# token exchange so the token never appears in /proc/<pid>/cmdline.

set -euo pipefail

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

readonly TAP_OWNER="Bizarre-Industries"
readonly TAP_NAME="homebrew-sojourn"
readonly TAP_REMOTE="github.com/${TAP_OWNER}/${TAP_NAME}.git"
readonly CASK_PATH_IN_TAP="Casks/sojourn.rb"
readonly AUDIT_TIMEOUT_SEC=180
readonly PUSH_TIMEOUT_SEC=30

# ------------------------------------------------------------------------------
# Logging
# ------------------------------------------------------------------------------

log() { printf '[publish-cask] %s\n' "$*" >&2; }

# `err` emits a GitHub-Actions-flavored error annotation if running under
# GitHub Actions, otherwise a plain stderr message. Either way, exits.
err() {
  local msg="$1" code="${2:-1}"
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '::error::%s\n' "${msg}" >&2
  else
    printf '[publish-cask] ERROR: %s\n' "${msg}" >&2
  fi
  exit "${code}"
}

# Mask the PAT if running under GitHub Actions so a stray `set -x` or
# echo can't leak it to the run log.
mask_token() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '::add-mask::%s\n' "${TAP_TOKEN}"
  fi
}

# ------------------------------------------------------------------------------
# Preconditions
# ------------------------------------------------------------------------------

usage() {
  sed -n 's/^# \{0,1\}//p' "$0" | head -n 50
  exit 1
}

require_env() {
  local var="$1"
  if [ -z "${!var:-}" ]; then
    err "required env var ${var} is unset" 1
  fi
}

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    err "required command '${cmd}' not found in PATH" 1
  fi
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {
  local dry_run=0
  if [ "${1:-}" = "--dry-run" ]; then
    dry_run=1
    shift
  fi
  if [ "$#" -ne 1 ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
  fi
  local dmg_path="$1"
  if [ "${dry_run}" = "1" ]; then
    log "DRY RUN: will skip the git push"
  fi

  if [ ! -f "${dmg_path}" ]; then
    err "DMG not found at: ${dmg_path}" 1
  fi

  require_env TAP_TOKEN
  require_env GITHUB_REF_NAME
  mask_token

  require_cmd git
  require_cmd brew
  require_cmd shasum
  require_cmd gtimeout
  require_cmd sed
  require_cmd grep
  require_cmd mktemp

  local server_url="${GITHUB_SERVER_URL:-https://github.com}"
  local repo="${GITHUB_REPOSITORY:-Bizarre-Industries/Sojourn}"
  local run_id="${GITHUB_RUN_ID:-local}"

  # Tag-format guard: refuse anything that isn't strict semver.
  local version="${GITHUB_REF_NAME#v}"
  if ! [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    err "tag '${GITHUB_REF_NAME}' is not in vN.N.N form" 1
  fi
  log "version=${version}"

  # Compute sha256 from the locally notarized + stapled DMG. (We do NOT
  # re-fetch from the GitHub release asset; `brew audit --online` below
  # will redownload and compare.)
  local sha
  sha="$(shasum -a 256 "${dmg_path}" | cut -d' ' -f1)"
  log "sha256=${sha}"

  # Clone with token in URL (only until next command, which scrubs it).
  local tap_dir
  tap_dir="$(mktemp -d)/${TAP_NAME}"
  log "cloning tap → ${tap_dir}"
  git clone --depth 1 \
    "https://x-access-token:${TAP_TOKEN}@${TAP_REMOTE}" \
    "${tap_dir}"

  # Token scrub. After this `.git/config` has no credentials.
  git -C "${tap_dir}" remote set-url origin "https://${TAP_REMOTE}"

  # Capture pre-edit values so we can verify both positive (new value
  # present) and negative (old value absent) substitution.
  local old_version old_sha
  old_version="$(grep -oE '^  version "[^"]+"' "${tap_dir}/${CASK_PATH_IN_TAP}" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
  old_sha="$(grep -oE '^  sha256 "[a-f0-9]{64}"' "${tap_dir}/${CASK_PATH_IN_TAP}" | head -1 | sed -E 's/.*"([a-f0-9]+)".*/\1/')"
  log "old version=${old_version} old sha=${old_sha:0:12}…"

  # Anchored sed: only the `version "…"` and `sha256 "…"` lines at
  # column 3 of the cask are touched. Won't match URLs or comments.
  sed -i.bak -E \
    -e "s|^([[:space:]]*version )\".*\"|\1\"${version}\"|" \
    -e "s|^([[:space:]]*sha256 )\".*\"|\1\"${sha}\"|" \
    "${tap_dir}/${CASK_PATH_IN_TAP}"
  rm "${tap_dir}/${CASK_PATH_IN_TAP}.bak"

  # Post-edit positive verification.
  if ! grep -q "^  version \"${version}\"$" "${tap_dir}/${CASK_PATH_IN_TAP}"; then
    cat "${tap_dir}/${CASK_PATH_IN_TAP}"
    err "version substitution did not produce expected line" 2
  fi
  if ! grep -qE "^  sha256 \"${sha}\"$" "${tap_dir}/${CASK_PATH_IN_TAP}"; then
    cat "${tap_dir}/${CASK_PATH_IN_TAP}"
    err "sha256 substitution did not produce expected line" 2
  fi

  # Post-edit negative verification: catches partial sed matches that
  # leave both old + new strings in the file.
  if [ -n "${old_version}" ] && [ "${old_version}" != "${version}" ] && \
     grep -q "^  version \"${old_version}\"$" "${tap_dir}/${CASK_PATH_IN_TAP}"; then
    err "old version ${old_version} still present after sed" 2
  fi
  if [ -n "${old_sha}" ] && [ "${old_sha}" != "${sha}" ] && \
     grep -q "^  sha256 \"${old_sha}\"$" "${tap_dir}/${CASK_PATH_IN_TAP}"; then
    err "old sha ${old_sha} still present after sed" 2
  fi

  # Style + online audit on the bumped cask via brew's tap tree.
  log "running brew style + audit on bumped cask"
  brew tap "${TAP_OWNER}/sojourn"
  local tap_repo
  tap_repo="$(brew --repo "${TAP_OWNER}/sojourn")"
  mkdir -p "${tap_repo}/Casks"
  cp "${tap_dir}/${CASK_PATH_IN_TAP}" "${tap_repo}/${CASK_PATH_IN_TAP}"
  if ! brew style "${tap_repo}/${CASK_PATH_IN_TAP}"; then
    err "brew style failed on bumped cask" 3
  fi
  if ! gtimeout "${AUDIT_TIMEOUT_SEC}" brew audit --cask --online sojourn; then
    err "brew audit --cask --online failed (or timed out at ${AUDIT_TIMEOUT_SEC}s)" 3
  fi

  # Build commit message in a variable so we don't have to embed
  # multi-line strings in any caller's YAML run-block.
  local msg
  msg="$(printf 'release: bump sojourn to v%s\n\nsha256 %s\nsource: %s/%s/releases/tag/%s\nworkflow-run: %s/%s/actions/runs/%s' \
    "${version}" "${sha}" \
    "${server_url}" "${repo}" "${GITHUB_REF_NAME}" \
    "${server_url}" "${repo}" "${run_id}")"

  # Commit + push as the actions bot. DCO sign-off required by org
  # policy (web_commit_signoff_required = true).
  git -C "${tap_dir}" config user.name  "github-actions[bot]"
  git -C "${tap_dir}" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git -C "${tap_dir}" add "${CASK_PATH_IN_TAP}"
  git -C "${tap_dir}" commit -s -m "${msg}"

  local local_sha
  local_sha="$(git -C "${tap_dir}" rev-parse HEAD)"

  if [ "${dry_run}" = "1" ]; then
    log "DRY RUN: skipping push. Local HEAD would have been ${local_sha}."
    log "DRY RUN: tap clone left at ${tap_dir} for inspection."
    return 0
  fi

  log "pushing to tap main (local HEAD ${local_sha})"
  if ! gtimeout "${PUSH_TIMEOUT_SEC}" git -C "${tap_dir}" \
       -c "http.https://github.com/.extraheader=AUTHORIZATION: bearer ${TAP_TOKEN}" \
       push origin main; then
    err "git push failed (or timed out at ${PUSH_TIMEOUT_SEC}s)" 4
  fi

  # Push-landed verification.
  local remote_sha
  remote_sha="$(git -C "${tap_dir}" \
    -c "http.https://github.com/.extraheader=AUTHORIZATION: bearer ${TAP_TOKEN}" \
    ls-remote origin refs/heads/main | cut -f1)"
  if [ "${local_sha}" != "${remote_sha}" ]; then
    err "push exit 0 but remote main is ${remote_sha}, expected ${local_sha}" 4
  fi
  log "tap main is now at ${local_sha}"
}

main "$@"
