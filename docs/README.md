# Sojourn docs

This tree follows [Diátaxis](https://diataxis.fr) for the four reader modes,
with three Sojourn-specific siblings (`decisions/`, `process/`, `design/`) for
artifacts Diátaxis does not cover.

## Reader-mode quadrants

| Quadrant | Goal | Path |
|---|---|---|
| **Start** | Learn by doing | [start/](start/) |
| **How-to** | Solve a specific task | [how-to/](how-to/) |
| **Reference** | Look up exact facts | [reference/](reference/) |
| **Explain** | Understand the why | [explain/](explain/) |

## Sojourn-specific siblings

| Tree | Stability | Audience |
|---|---|---|
| [decisions/](decisions/) | Immutable ADRs | Contributors, maintainers |
| [process/](process/) | High churn | Contributors, maintainers |
| [design/](design/) | Release-cadence | Designers, maintainers |
| [assets/](assets/) | Per-doc | Docs build |

## Top-level entry points

- [Start: install Sojourn](start/) — first-run tutorials.
- [Reference: architecture](reference/architecture.md) — top-down system spec.
- [Decisions: ADR log](decisions/README.md) — every architectural choice on record.
- [Process: implementation plan](process/implementation-plan.md) — phased delivery.
- [Process: docs policy](process/DOCS_POLICY.md) — redirect rules, ADR immutability, naming.

## Conventions

- File names: `kebab-case.md`.
- Headings: sentence case.
- Internal links: repo-relative paths.
- Mermaid first; PNG only when mermaid cannot represent.
- ADRs: `NNNN-kebab-case.md`, sequentially numbered, never reused, never reordered.

See [process/doc-style.md](process/doc-style.md) for the full style rules.
