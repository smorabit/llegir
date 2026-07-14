# Milestone (extensibility) — general module sources, custom tools, evidence ingestion

← [Overview](overview.md) · [Implementation guide](implementation_guide.md) · [Schemas](schemas.md) · [Project home](../README.md)

*Status: in progress. Turns `sentit` from "hdWGCNA + built-in tools" into a general, pluggable engine.*

---

## Goal

Make the three things that are currently hard-wired **pluggable**: where modules come from, which tools run, and where evidence comes from. Concretely:

1. **Custom module sets** — module sources beyond hdWGCNA (tidy components, gene lists, later NMF/etc.).
2. **Custom tools** — a documented registry so users add their own `function(ctx) -> evidence_fragment` tools.
3. **Evidence ingestion** — import pre-existing results (DEG / DME / enrichment tables) as evidence fragments.

There are **no users yet and the package is experimental**, so this is the moment to refactor the two core contracts (`ModuleSet`, `evidence_fragment`) as these use-cases demand — breaking changes are fine here and expected.

## Design principles

- **Three orthogonal axes, kept separate:** *module source* (hdWGCNA / gene lists / tidy tables / …) × *data container* (Seurat / SCE / plain matrix) × *scoring method* (kME-derived MEs / UCell / decoupleR / precomputed). Combinations must work.
- **Capability system:** not every tool can run on every module set (a gene-list `ModuleSet` with no clusters can't run `cluster_dme`). A `ModuleSet` advertises capabilities; tools declare what they require; the orchestrator **skips gracefully and records why** instead of erroring.
- **Config-driven everything:** adapter choice, tool selection, imports, and column mappings all live in a per-project config — the actual realization of "flexible per dataset."
- **Only adapters touch source libraries.** hdWGCNA/Seurat imports stay inside their adapter; the generic adapters, tools, importers, and synthesis depend only on the `ModuleSet` + `evidence_fragment` contracts.

## Parts (sequenced; one Claude Code session each)

### Part 1 — `ModuleSet` generalization + contract refactor  *(keystone; first)*

Build the most general adapter (a `ModuleSet` from tidy components) and a gene-list adapter that scores on the fly, and refactor the `ModuleSet` contract to shed hdWGCNA-isms. Introduce `capabilities()`. See **[handoff_prompt_extensibility_1.md](handoff_prompt_extensibility_1.md)**.

### Part 2 — `signature_correlation` core tool + custom-tool registry

Two threads (see [handoff_prompt_extensibility_2.md](handoff_prompt_extensibility_2.md)):

**(a) `signature_correlation` as a *core* tool.** The sibling of `geneset_enrichment`: overlap answers "does this module *contain* the signature's genes?"; correlation answers "does this module's *activity* co-vary with the signature's?" — different questions, both worth having. Score a supplied signature library across cells/pseudobulk (reusing Part 1's UCell/decoupleR scoring) and correlate each signature with the module ME, emitting a `signature_correlation` fragment (the type already exists in the schema). It is **general and config-driven** (a signature-library path, like `enrichment$db_files`), so it is core, not custom — the only dataset-specific thing is *which* library you supply. Capability-gated on `module_scores` + `expression`. Mind the level: report Pearson *r* as descriptive co-variation; if attaching a p-value, correlate at pseudobulk/sample level (cells aren't independent — the M1.5 lesson). For CSF, point both this and `geneset_enrichment` at focused **MSigDB collections (C8 cell-type, C7 immunologic, Hallmark)** — all config, no bespoke code. (MSigDB *overlap* is just `geneset_enrichment` with a different `.gmt`.)

**(b) Custom-tool registry + capability requirements.** Make tool registration a clean, documented public API: `register_tool()` + a tool spec carrying `id`, `description`, the emitted fragment `type`, and its **required `ModuleSet` capabilities**. Register the core tools through the same mechanism so core and custom are uniform. The orchestrator runs the config-selected tools, **skips any whose required capabilities aren't met and records the reason** in the packet (formalizing Part 1's graceful skip), and **validates every tool's output against the `evidence_fragment` schema**. Ship a documented template + one small worked custom tool. Reserve *custom* for genuinely bespoke logic/data — the SERPENTINE cross-lineage T-cell tool is the motivating real case; "same statistic, different gene set" stays a core tool + config.

### Part 3 — Evidence ingestion  *(stub)*

Generalize `import_fragment` (M1.5 seed) into a set of **importers with configurable column mapping** for the formats people actually have: Seurat `FindMarkers` / DESeq2 / edgeR DEG tables → `categorical_association` / `cross_condition_delta`; hdWGCNA DME → `state_expression`; EnrichR / GeneOverlap → `geneset_enrichment`. Sensible per-format defaults + a column-map override; record the source file + mapping in provenance; tag `source = user_supplied`. Only produces fragments (doesn't touch the `ModuleSet`), so it can proceed in parallel with Part 2.

## Definition of done (whole milestone)

- A packet can be built from at least **three** module sources (hdWGCNA, tidy-components, gene-list) with the same tools and orchestrator.
- `signature_correlation` is a **core** tool; module identity can be scored against a config-supplied signature library (e.g. MSigDB C8/C7/Hallmark).
- A user can register a custom tool and run it; core tools go through the same registry; tools whose capabilities aren't met are skipped (reason recorded), not fatal; malformed tool output fails schema validation.
- DEG / DME / enrichment tables can be ingested into valid fragments via config.
- hdWGCNA behavior is unchanged; everything runs offline; `R CMD check` stays clean.

## Out of scope (later)

NMF/cNMF/Hotspot adapters, SCE/`.mtx` container support beyond what falls out naturally, literature/PubMed, cross-module reconciliation, the fuller eval/calibration harness, CRAN. All additive after this.

## Conventions

- [STYLE.md](../STYLE.md); it is now a package, so new **exported** functions get roxygen; run `devtools::document()`; keep `R CMD check` clean.
- Breaking contract changes are allowed this milestone, but the hdWGCNA path's behavior + tests must stay intact.

---

*Last updated: 2026-07-12*
