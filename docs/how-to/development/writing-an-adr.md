# Writing an ADR

## Goal

Add an Architecture Decision Record to `docs/decisions/` for a
load-bearing choice.

## Prereqs

- The decision is architectural (affects multiple modules, license,
  security posture, or external interface). One-file refactors
  don't need an ADR.
- You've read the existing ADRs in `docs/decisions/` to avoid
  contradicting them.

## Steps

1. **Pick the next number**.

   ```sh
   ls docs/decisions/ | grep '^[0-9]' | sort -n | tail -1
   ```

   Add 1. ADR numbers are **never reused, never reordered**.

2. **Copy the template**:

   ```sh
   cp docs/decisions/_template.md docs/decisions/NNNN-kebab-case-title.md
   ```

   Title is a short imperative phrase: `0015-cache-osv-locally.md`,
   not `0015-OSV-decision.md`.

3. **Fill in the template** ([process/DOCS_POLICY.md](../../process/DOCS_POLICY.md)
   "ADR rules"):

   ```markdown
   # NNNN — <Decision in present tense>

   - **Status**: Proposed | Accepted | Superseded by [NNNN](./NNNN-x.md) | Deprecated
   - **Date**: YYYY-MM-DD
   - **Deciders**: <names or roles>

   ## Context

   What is the issue we're seeing that motivates this decision?
   Two paragraphs max.

   ## Decision

   What we're doing, in plain language. One paragraph.

   ## Consequences

   What becomes easier or harder. List positive, negative, neutral.

   ## Alternatives considered

   - Option A — rejected because …
   - Option B — rejected because …
   ```

4. **Set the `Status`**:

   - `Proposed` — code not yet merged; the ADR is the design
     document.
   - `Accepted` — code lands in the same PR or earlier.
   - `Superseded` / `Deprecated` — only used to retire an existing
     ADR.

5. **Add a row to `docs/decisions/README.md`** index.

6. **Cross-link from at least one reference page** that the ADR
   describes. Reviewers reject ADRs with no inbound link from
   `reference/`.

7. **Open the PR**.

   PR description includes:
   - Why this decision is architectural enough to warrant an ADR.
   - Whether it supersedes any existing ADR (link both).
   - The new index row.

## Editing an ADR after merge

**Don't.** ADRs are immutable once `Accepted`. The only allowed
edit is changing the `Status` line to `Superseded by NNNN`.

If reality changes:

1. Write a new ADR that supersedes the old.
2. Edit the old ADR's `Status` line only.
3. Cross-link both.

This preserves the historical reasoning. Future contributors can read
"we considered X, picked Y for these reasons; later switched to Z
because of these new facts."

## Style rules

- One-page max. Reviewers reject longer ADRs.
- No code blocks longer than 10 lines (reference the implementation
  by file path instead).
- No "we'll revisit later" — the ADR captures the current state. Open
  questions go in `process/open-questions.md`.
- Use present tense for the decision: "Sojourn uses X" not "Sojourn
  will use X".

## Verification

- `markdown-link-check` (CI) passes.
- The new ADR is linked from `decisions/README.md` and at least one
  reference page.
- The PR description explains the architectural impact.

## Troubleshooting

- **"Reviewer asks for shorter ADR"** — split context into linked
  reference docs; keep ADR focused on the decision itself.
- **"Reviewer wants the ADR to also document open questions"** —
  open questions don't go in ADRs. Add to
  `process/open-questions.md` instead.
- **"My ADR contradicts an existing ADR"** — your PR also
  supersedes the existing one. Mark the old ADR's status, write
  yours, link both.

## See also

- [docs/decisions/](../../decisions/) — existing ADR log.
- [docs/decisions/_template.md](../../decisions/_template.md) — the
  template.
- [process/DOCS_POLICY.md](../../process/DOCS_POLICY.md) "ADR rules".
- [MADR template reference](https://adr.github.io/madr/).
