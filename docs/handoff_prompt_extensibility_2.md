# Claude Code handoff prompt — extensibility Part 2 (signature_correlation core tool + custom-tool registry)

← [Project home](../README.md) · [Extensibility milestone](milestone_extensibility.md)

Handoff for a fresh Claude Code instance. Paste the block below from the repo root.

*Logged 2026-07-14.*

---

## Prompt

```
You're starting Part 2 of the extensibility milestone for `sentit` (installed
experimental R package). Part 1 is done: three ModuleSet adapters (hdWGCNA,
components, gene-list), a capabilities()/has_capability() system, tools that skip
gracefully on missing capabilities, and UCell/decoupleR scoring used by the gene-list
adapter. Part 2 has TWO threads: (a) add a `signature_correlation` CORE tool, and
(b) build the custom-tool registry with capability requirements.

First read: docs/milestone_extensibility.md (Part 2 — authoritative), CLAUDE.md,
docs/schemas.md (note `signature_correlation` is already a fragment type), R/moduleset.R
(capabilities/has_capability), R/tool_geneset_enrichment.R (the overlap sibling +
GeneOverlap/gmt pattern), R/tool_module_by_metadata.R (graceful-skip + pseudobulk-level
pattern), R/orchestrator.R (how tools are configured + run), and the Part 1 gene-list
scoring util. Follow STYLE.md.

Environment: conda env `hdWGCNA`. UCell/decoupleR are present (Part 1). If something is
missing, STOP and tell me (do not install). It's a package: roxygen new EXPORTED
functions, run devtools::document(), keep R CMD check clean. Everything runs OFFLINE
(signature libraries are local files).

THREAD A — `signature_correlation` CORE tool:
  - General, config-driven sibling of geneset_enrichment. Input: a signature library
    (named gene sets from a local .gmt/.rds; path(s) in config, e.g.
    signatures$library_files). Reuse Part 1's UCell/decoupleR scoring to score each
    signature across cells (or pseudobulk), then correlate each signature's score with
    the module ME (module_scores) across the same units.
  - Emit a `signature_correlation` evidence_fragment: result = full table (signature,
    r, optional p, n); top_findings = top |r| signatures with sign; effect_strength =
    max|r|; direction from the sign of the top correlation.
  - Capability-gated: requires module_scores + expression; if absent, skip gracefully
    (has_capability) and record the skip — do NOT crash.
  - LEVEL / pseudoreplication: report Pearson r as descriptive co-variation by default.
    If you attach a p-value, compute it at the pseudobulk/sample level (cells are not
    independent — the M1.5 lesson) and record the level in provenance. Never hand the
    synthesis layer an inflated cell-level p.
  - Config note (no code): for CSF, point BOTH signature_correlation AND
    geneset_enrichment at FOCUSED MSigDB collections (C8 cell-type, C7 immunologic,
    Hallmark), not the full Human MSigDB (which buries the signal). MSigDB *overlap* is
    already handled by geneset_enrichment with a different .gmt — no new code.

THREAD B — custom-tool registry + capability requirements:
  - register_tool(): a clean, documented public API. A tool spec/object carries: id,
    description, the fragment `type` it emits, and its required ModuleSet capabilities.
  - Register the CORE tools through the SAME mechanism so core and custom are uniform;
    each declares its required capabilities (hub_genes: none; cluster_dme: clusters +
    module_scores; module_by_metadata: module_scores [+ sample_ids for categorical];
    signature_correlation: module_scores + expression).
  - Orchestrator: run the config-selected tools; for each, check required capabilities
    via has_capability; if unmet, SKIP and record the reason in the packet (formalize
    Part 1's ad-hoc skip into declared requirements). Validate every tool's returned
    fragment against the evidence_fragment schema; fail loudly on a malformed fragment.
  - Docs: a documented custom-tool template (write function(ctx) -> evidence_fragment,
    declare capabilities, register) and ONE small worked custom tool in tests to prove
    the API end to end. Note the real motivating custom cases in the docs (SERPENTINE
    cross-lineage T-cell coordination; a TF-regulon tool) but do NOT build those here.

Tests (offline): signature_correlation on the synthetic components + gene-list
ModuleSets with a tiny synthetic signature set; registry: register a custom tool and
run it, confirm a capability-mismatched tool is skipped (not fatal) with a recorded
reason, and confirm a malformed fragment fails schema validation. All M1/M1.5/M2 +
Part 1 tests still pass.

Non-negotiables: core tools depend only on the ModuleSet + evidence_fragment contracts;
capability-gated graceful skips (no crashes); everything offline; roxygen +
devtools::document() for new exports; R CMD check clean; hdWGCNA behavior unchanged;
follow STYLE.md.

Start by restating your plan AND the register_tool()/tool-spec design, and confirm with
me before writing. Then check in (a) once signature_correlation runs on a synthetic
ModuleSet, and (b) once the registry runs core + a custom tool uniformly with a
graceful capability skip, before finalizing.
```

---

## Notes

- `signature_correlation` is **core** (general + config-driven), not custom — the schema already has the fragment type.
- MSigDB *overlap* = the existing `geneset_enrichment` tool + a focused-collection `.gmt`; only *correlation* is new.
- The registry unifies core + custom tools; capability requirements formalize Part 1's graceful skips; malformed fragments fail schema validation.
- Real custom-tool exemplars (SERPENTINE cross-lineage, TF-regulon) are documented as motivation only — not built here.
- Check-ins: after signature_correlation works on a synthetic ModuleSet, and after the registry runs core + custom with a graceful skip.
- Next: Part 3 — evidence ingestion (DEG/DME/enrichment importers with column mapping).

---

*Last updated: 2026-07-14*
