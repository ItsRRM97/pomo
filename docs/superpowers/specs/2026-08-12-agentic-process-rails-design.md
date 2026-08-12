# Design: Agentic process rails (Approach 1)

**Date:** 2026-08-12  
**Status:** Approved (Approach C overall goal; Approach 1 process rails first)  
**Scope:** Docs and agent entry only. No product feature code in this change.  
**Repo:** `github.com/recoskyler/pomo`

## Context

The product already ships much of `DESIGN.md` (2026-07-13). Remaining work is a mix of open product gaps (see gap matrix) and weak agent process rails (no superpowers specs path, AGENTS entry not aligned with light agent-friendly-repo norms).

**Approach C (overall):** Align agent process and close DESIGN-vs-shipped gaps deliberately, rather than ad-hoc feature churn.

**Approach 1 (this change):** Process rails first: polish agent entry docs, add superpowers design + gap matrix, document the workflow. Product implementations (battery Settings UI, notification QA, etc.) stay out of scope until a later writing-plans / TDD cycle.

## Goals

1. Fast agent orientation via root `AGENTS.md` (≤ ~100 lines) with layout, commands, constraints, workflow.
2. Clear sources of truth: `AGENTS.md` (operating rules), `CLAUDE.md` (topology), `ARCHITECTURE.md` (system design), `DESIGN.md` (approved product design).
3. Durable DESIGN-vs-shipped gap matrix for prioritization.
4. Documented workflow: brainstorming → writing-plans → TDD → implement → `./scripts/verify.sh` → review/ship as needed.

## Non-goals (this change)

- Battery-opt Settings UI wiring
- Persistent notification action QA / product changes
- Adding `fl_chart` or analytics library swaps
- Any Flutter/Dart feature implementation
- Committing or opening a PR unless the user asks

## Design decisions

| Decision | Choice |
|----------|--------|
| Agent entry | Rewrite `AGENTS.md` to light template; keep `CLAUDE.md` as detailed topology (no clobber / no symlink overwrite) |
| Cursor rules | Keep existing `.cursor/rules/agent-guidance.mdc`; no new rules (light mode) |
| Gap matrix | Separate `docs/superpowers/DESIGN-GAP-MATRIX.md` for reuse |
| Env template | Keep tracked `sample.env`; `.gitignore` already covers `.env` / `.env.*`; add `!.env.example` for convention without requiring rename |
| Em dashes | Forbidden (`U+2014`) in all new docs |

## Agent workflow (repo standard)

1. **Brainstorm** scope against `DESIGN.md` + gap matrix (office-hours / brainstorming skill as needed).
2. **writing-plans** for any non-trivial product change; link the plan from a dated spec under `docs/superpowers/specs/` when useful.
3. **TDD** for logic in `lib/helpers/` and Cubit behavior; prefer failing tests first.
4. **Implement** within hard constraints (`AGENTS.md` / `CLAUDE.md`).
5. **Verify** with `./scripts/verify.sh` (analyze, format, tests).
6. **Review / ship** via project review and ship skills only when the user asks to land work.

## Deliverables (Approach 1)

- [x] Updated root `AGENTS.md`
- [x] README one-line Agents pointer
- [x] `.gitignore` env exception note (`!.env.example`)
- [x] This design doc
- [x] `docs/superpowers/DESIGN-GAP-MATRIX.md`
- [x] agent-friendly-repo skill changelog entry

## Follow-ups (out of scope here)

Product gaps listed in the gap matrix, especially:

1. Battery optimization Settings UI
2. Persistent 1-tap notification actions QA
3. Analytics charting approach (custom UI vs `fl_chart`) if DESIGN still expects charts

Next product work should start with writing-plans against the highest-priority OPEN rows in the gap matrix.
