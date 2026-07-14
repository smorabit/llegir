# Claude Code handoff prompt — extensibility Part 1 (ModuleSet generalization)

← [Project home](../README.md) · [Extensibility milestone](milestone_extensibility.md)

Handoff for a fresh Claude Code instance: generalize the `ModuleSet` contract beyond hdWGCNA. Paste the block below from the repo root.

*Logged 2026-07-12.*

---

## Prompt

```
You're starting Part 1 of the extensibility milestone for `sentit` (an installed,
experimental R package with a pkgdown site). Goal: make the module source pluggable
by generalizing the ModuleSet contract beyond hdWGCNA. The engine currently works
end to end on hdWGCNA modules; nothing about the evidence tools, synthesis, or
guardrails should change in behavior.

First, read: docs/milestone_extensibility.md (this is the task, authoritative),
CLAUDE.md, docs/schemas.md, docs/implementation_guide.md (the ModuleSet section),
and STYLE.md.

Environment: activate the conda env `hdWGCNA`. No API keys needed. If the gene-list
adapter needs a scoring package (UCell and/or decoupleR) and it's missing, STOP and
tell me (do not install). It IS now an R package, so document new EXPORTED functions
with roxygen, run devtools::document(), and keep R CMD check clean.

Important context: there are no users and the package is experimental, so you MAY
refactor the ModuleSet contract as these use-cases demand — breaking changes are
fine. The one thing that must NOT change is the hdWGCNA path's behavior: its existing
tests must still pass and produce identical evidence.

Tasks:
  0. Audit + propose (STOP for my confirmation before refactoring). Enumerate the
     current ModuleSet interface (R/moduleset.R) and every hdWGCNA/Seurat-ism in
     hdWGCNA_ModuleSet (R/moduleset_hdwgcna.R) and the tools (kME weights, MEs,
     GetModules, the underlying Seurat object, cluster columns, sample ids). Separate
     what's genuinely required by the tools from what's hdWGCNA-specific. Propose the
     revised contract + a capabilities() design. --> CHECK IN with me.

  1. Add capabilities() to the ModuleSet contract. It reports which of a fixed
     vocabulary the source provides, e.g. gene_weights, module_scores, expression,
     clusters, sample_ids. Tools and (later) the registry consult it.

  2. Generic components ModuleSet (the general substrate). A constructor taking tidy
     components directly: a module<->gene table (optional weight column), an optional
     scores matrix (modules x cells/samples), an expression matrix (genes x cells), a
     metadata data.frame, and the cluster / sample column names. Implements the full
     interface + capabilities(). This becomes the target other adapters build on.

  3. Refactor hdWGCNA_ModuleSet to conform to the (possibly revised) interface +
     capabilities() — ideally by extracting components and delegating to the generic
     ModuleSet. Behavior identical; its tests must still pass unchanged.

  4. Gene-list ModuleSet. A constructor taking named gene lists (the modules) +
     expression + metadata (+ optional clusters), that computes module scores on the
     fly (UCell or decoupleR — pick one, expose the method + a pass-through options
     arg). gene_weights capability = FALSE (weights absent / 1); module_scores,
     expression, clusters (if given) = TRUE.

  5. Make the core tools capability-aware enough to run on the new adapters: a tool
     whose required capability is absent (e.g. cluster_dme with no clusters) must
     skip gracefully with an informative note, not crash. (The full tool-requirement
     declaration + orchestrator skip logic is Part 2 — here, just don't hard-fail.)

  6. Fixtures + tests. Add a synthetic components ModuleSet and a synthetic gene-list
     ModuleSet; run the evidence pipeline offline on each and confirm valid packets;
     confirm the hdWGCNA path is byte-unchanged. Keep everything offline.

Non-negotiables: only adapters import hdWGCNA/Seurat — the generic + gene-list
adapters, the tools, and synthesis depend ONLY on the ModuleSet + evidence_fragment
contracts; hdWGCNA behavior/tests unchanged; everything runs offline; roxygen +
devtools::document() for new exports; R CMD check stays clean; follow STYLE.md.

Start with task 0 (audit + proposed contract/capabilities design) and STOP for my
confirmation before refactoring. Then check in again once the generic components
ModuleSet runs the pipeline end to end, before building the gene-list adapter.
```

---

## Notes

- Package is `sentit`; it's now a real R package — new exported functions need roxygen + `devtools::document()`, and `R CMD check` must stay clean.
- The keystone risk is the contract refactor — hence task 0 is an audit + proposal with a mandatory check-in before any refactoring.
- `capabilities()` introduced here seeds Part 2's tool-requirement / graceful-skip system.
- Gene-list scoring: UCell or decoupleR (whichever is in the env); if missing, stop and flag — don't install.
- Deliberate check-ins: after the audit/proposal, and after the generic components ModuleSet works end to end.
- Next: Part 2 (custom-tool registry + capabilities) and Part 3 (evidence ingestion).

---

*Last updated: 2026-07-12*
