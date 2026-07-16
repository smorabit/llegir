# Claude Code handoff prompt — Milestone 1.5

← [Project home](../README.md) · [Milestone 1.5](milestone_1_5.md)

The prompt to kick off Milestone 1.5 (rigor & reproducibility hardening) with a fresh Claude Code instance. Paste the block below from the repo root.

*Logged 2026-07-11.*

---

## Prompt

```
You're picking up the Module Interpretation Engine at Milestone 1.5 — a short
rigor-and-reproducibility hardening pass on the existing deterministic core.
Milestone 1 (adapter + evidence-fragment contract + core tools + orchestrator +
spike-in tests, 14 CSF modules) is already implemented and passing.

First, read: CLAUDE.md, docs/milestone_1_5.md (this is the task, and it is
authoritative), docs/milestone_1.md (context on what already exists),
docs/schemas.md, and STYLE.md.

Environment: activate the conda env `hdWGCNA` before running any R
(`conda activate hdWGCNA`). GeneOverlap and fgsea are already installed there.
Do NOT install packages — if something is missing, stop and tell me.

Scope: Milestone 1.5 ONLY. No LLM/synthesis (that's M2), no new ModuleSet
adapters, no NetRep, no packaging. Plain sourced functions, same as M1.

The four tasks (full detail in docs/milestone_1_5.md):
  1. Fix pseudoreplication in module_by_metadata (highest priority): for
     sample-level variables (e.g. diagnosis), aggregate the module eigengene to
     Sample.ID first, then test at the SAMPLE level (not cell level). Record which
     level was used in provenance. Sample.ID itself is the aggregation unit
     (descriptive: which samples express the module), not a group test.
  2. Swap geneset_enrichment to the OFFLINE GeneOverlap approach recycled from
     SERPENTINE's run_geneoverlap.R — the exact loop is embedded in
     docs/milestone_1_5.md task 2, so you don't need the SERPENTINE repo. Load the
     local GMT library at data/GO_Biological_Process_2026.txt via
     fgsea::gmtPathways() (it's GMT-format despite the .txt extension), run
     GeneOverlap::newGOM with the module's hub genes vs. a background of all genes
     in the ModuleSet, flatten to the tidy table, BH-adjust to fdr, emit as a
     geneset_enrichment evidence_fragment. Put the GMT path(s) in the project
     config. No network at runtime.
  3. import_fragment: let a user inject an already-computed result table as an
     evidence_fragment, tagged provenance.source = "user_supplied".
  4. Persist every fragment's result table to output/tables/<module>/<tool>.tsv
     alongside the JSON packets.

Non-negotiables: core tools depend only on the ModuleSet adapter (never
hdWGCNA/Seurat directly); every tool returns a validated evidence_fragment;
hash packets + log provenance; keep everything runnable offline (the GMT library
is local — no runtime network); follow STYLE.md; NO formal R package yet; all
existing M1 tests must still pass.

Start by reading the docs and restating your plan for tasks 1 and 2 for my
confirmation before you change any result-producing code. Then check in with me
after the pseudoreplication fix (1) and after the GeneOverlap swap (2) — those two
change the evidence itself — before doing the mechanical tasks (3, 4).
```

---

## Notes

- Env: `hdWGCNA`; `GeneOverlap`, `fgsea` already installed; do not install.
- Local GMT library: `data/GO_Biological_Process_2026.txt` (GMT-format, `.txt` ext).
- The recycled GeneOverlap loop is embedded in `milestone_1_5.md` so the SERPENTINE repo isn't required.
- Deliberate check-ins after tasks 1 and 2 (the result-changing ones).
- Next after this: [Milestone 2](milestone_2.md) — synthesis via `ellmer` (needs the dataset-description config + an API key).

---

*Last updated: 2026-07-11*
