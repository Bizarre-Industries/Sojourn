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

## Moves and renames

When moving a doc, do it cleanly: `git mv` the file, update every inbound
link, commit. **No redirect stubs.** `git log -- docs/<old-path>` is the
redirect — it tells future readers where the content went.

This rule replaces the v0.1 redirect-window policy (Phases 2/3/7 sunset at
v0.3, ARCHITECTURE.md sunset at v0.4) per the v0.2 pivot
(`docs/process/plans/v0.2-plan.md`). All redirect stubs from the prior
restructure were deleted in the v0.2 docs purge; `docs/redirects.toml` is
historical record only and may itself be removed once external link
traffic decays.

If a future move has external link traffic that justifies a transition
window, write a one-page ADR proposing the exception, list the affected
URLs, and commit to a hard-coded removal date — not a "soon" promise.

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
