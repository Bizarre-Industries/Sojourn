# Sojourn docs policy

Rules for writing, moving, and retiring documentation. Every contributor —
human or AI — should read this before adding a markdown file under `docs/`.

## One quadrant per page

Every page lives in exactly one of:

- `docs/start/` — tutorials (learning by doing).
- `docs/how-to/` — task-oriented guides (solve a specific problem).
- `docs/reference/` — information-oriented spec (look up exact facts).
- `docs/explain/` — understanding-oriented rationale (why we chose X).

Plus three Sojourn-specific siblings:

- `docs/decisions/` — ADRs. Immutable post-Accepted (see below).
- `docs/process/` — contributor/maintainer process docs. High churn allowed.
- `docs/design/` — visual design artifacts (PDFs, screens, identity).

If a doc spans two quadrants, split it. Cross-link.

## Naming

| Element | Rule | Example |
|---|---|---|
| File | `kebab-case.md` | `resolve-conflict.md` |
| Directory | `kebab-case/` | `package-managers/` |
| ADR file | `NNNN-kebab-case.md` (4 digits) | `0001-ipc-not-linking.md` |
| ADR number | Sequential, never reused, never reordered | — |
| Tutorial step prefix | `NN-` (2 digits) | `01-install.md` |
| Heading | Sentence case | `## How chezmoi externals work` |
| Page title | `# Sojourn — <Topic>` for top-level, `# <Topic>` for nested | — |

## Internal links

- Use repo-relative paths: `[architecture](../reference/architecture.md)`.
- Preserve heading anchors when splitting docs (so external blog posts that
  cite `ARCHITECTURE.md#section-name` keep working through redirects).
- Mermaid diagrams inline first; PNG in `assets/diagrams/` only when mermaid
  cannot represent the diagram.

## Frontmatter

None for v1. Avoids Jekyll/Hugo coupling. If a static site generator is later
adopted, frontmatter can be added uniformly via script.

## Last-updated stamps

Git history is the source of truth. No per-file `Last updated: YYYY-MM-DD`
stamps. Stamps rot; `git log -1 --format=%ai <file>` does not.

## ADR rules

ADRs in `docs/decisions/` follow [MADR](https://adr.github.io/madr/) reduced
to one page or less. The template is at `docs/decisions/_template.md`.

**ADRs are never edited after merge with `Status: Accepted`** except to change
the `Status` line to `Superseded by NNNN`. If reality changes, write a new
ADR that supersedes the old. The historical reasoning stays intact.

Allowed `Status` values:

- `Proposed` — decision drafted but not yet implemented in code.
- `Accepted` — decision implemented; this is the current state.
- `Superseded by NNNN` — replaced by a later ADR.
- `Deprecated` — no longer applies; nothing replaces it.

CI flags edits to existing ADRs (`Status` line is the only allowed change).

## Redirect stub rules

When moving a doc, leave a stub at the old path:

```
# Moved

This page moved to [docs/<quadrant>/<new>.md](../<quadrant>/<new>.md).

The redirect will be removed in **vX.Y**. See
[docs/process/DOCS_POLICY.md](DOCS_POLICY.md).
```

Three lines body (the `# Moved` heading + 2 sentences). Exception: pages with
heavy external link traffic (e.g., the original `docs/ARCHITECTURE.md`) may
include an anchor map so external `#section` links keep resolving.

Every redirect is recorded in `docs/redirects.toml` with `sunset_version`
metadata. CI uses the file as a markdown-link-check allowlist.

## Stub sunset cadence

| Stub | Sunset |
|---|---|
| Most stubs created in restructure Phases 2/3/7 | v0.3 (one minor after rework lands) |
| `docs/ARCHITECTURE.md` stub (high inbound link density) | v0.4 |

`docs/process/release.md` includes a "remove expired stubs" checklist item.
The release pipeline reads `docs/redirects.toml` and lists any whose
`sunset_version <= release_version` for removal.

## Content split rules

When splitting a long doc:

1. `git mv` the original to `docs/_legacy_<name>.md` first.
2. `git checkout` + line-range copy into the new files.

This preserves `git log --follow` blame walks. A naive `cat > newfile` loses
history.

## Adding a doc

1. Pick the right quadrant (one of `start/ how-to/ reference/ explain/`) or
   the right sibling (`decisions/ process/ design/`).
2. Use `kebab-case.md`. Sentence-case headings.
3. Cross-link from at least one other page (the index page in the quadrant
   plus any topic neighbour).
4. If the doc captures a decision: write an ADR instead (or in addition).
5. Run markdown-link-check locally before opening the PR.

## Adding an ADR

1. Pick the next number (max existing ADR + 1, never reused).
2. Copy `docs/decisions/_template.md` to `docs/decisions/NNNN-kebab-case.md`.
3. Fill in Context, Decision, Consequences, Alternatives.
4. Status seed: `Proposed` if code not yet merged; `Accepted` if landing this
   PR.
5. Add a row to `docs/decisions/README.md` index.
6. Cross-link from the source-content reference page.
