# Milestone (abstract ModuleSet) — a technology- and algorithm-agnostic data contract

← [Overview](overview.md) · [Implementation guide](implementation_guide.md) · [Schemas](schemas.md) · [Extensibility milestone](milestone_extensibility.md) · [Pseudo-bulk milestone](milestone_pseudobulk.md) · [Project home](../README.md)

*Status: planned. Finalizes the `ModuleSet` contract so `run_orchestrator()` is fully backend-, technology-, and algorithm-agnostic. Prerequisite for [milestone_pseudobulk.md](milestone_pseudobulk.md).*

---

## Goal

The extensibility milestone already did the hard decoupling: core tools touch only the `ModuleSet` generics ([modules()], [gene_membership()], [module_scores()], [expression()], [metadata()], [pkg_versions()], [capabilities()]), and there are already three real adapters — `hdWGCNA_ModuleSet` (the only file allowed to touch Seurat/hdWGCNA), the general `components_ModuleSet` (arbitrary matrix + tidy module table), and `gene_list_ModuleSet` (arbitrary named gene vectors, scored on the fly) — plus the `synthetic_ModuleSet` test fixture.

What remains is to **close the gaps that still leak single-cell assumptions**, so the contract honestly describes bulk, single-cell, and spatial data (at any resolution) produced by any module/factor algorithm. Concretely, this milestone:

1. makes the **observation unit explicit** (`data_level` + `aggregated`) instead of silently assuming columns are cells;
2. splits **raw counts** (`counts()`) from the normalized `expression()` layer — the hinge that makes proper pseudo-bulk DE possible downstream;
3. **formally validates** the contract (`validate_moduleset()`);
4. records the **module-generating method** as a free-form string on `dataset_description`;
5. **renames the `clusters` capability to `grouping`** so the vocabulary isn't single-cell-flavored.

No pseudo-bulk machinery lives here — that is [milestone_pseudobulk.md](milestone_pseudobulk.md), which depends on `counts()`, `data_level`/`aggregated`, and `validate_moduleset()` landing first.

## Design principles

- **The contract is the only thing tools trust.** Every extension in this milestone is a property a tool can read off *any* `ModuleSet` via a generic — never a backend probe. Adapters remain the only code that touches source libraries.
- **Describe, don't enumerate.** Technologies and algorithms are open-ended (multi-resolution spatial: cells, spots, FOVs, segments, niches, …; dozens of module/factor methods). Where a fixed vocabulary can't keep up, the contract carries a **free-form user string** rather than an enum it will always be behind.
- **Breaking changes are fine, behavior is not.** No users yet, so renames/signature changes are allowed — but the hdWGCNA path's observable behavior and its tests stay intact.

## Parts (sequenced; one Claude Code session each)

### Part 1 — Observation-unit contract: `data_level` + `aggregated`, and the `clusters` → `grouping` rename *(keystone; first)*

The contract silently assumes `expression()` columns are cells. Make the unit explicit and generic.

- **Add two declared descriptors to every `ModuleSet`:**
  - `data_level` — a **free-form string** naming what one observation (one column of `expression()`) is: `'cell'`, `'spot'`, `'FOV'`, `'segment'`, `'niche'`, `'sample'`, `'pseudobulk'`, or anything a user needs. Purely descriptive; never branched on by a fixed set of values.
  - `aggregated` — a **logical** stating whether observations are independent sample-level units (`TRUE`, e.g. bulk or pseudo-bulk) versus many correlated observations nested within samples (`FALSE`, e.g. cells/spots/FOVs). This is the machine-readable flag statistics and tools reason about (non-independence / pseudoreplication), which the free-form `data_level` label deliberately does *not* encode.
  - Expose both via the object (fields on the adapter) and surface them in `pkg_versions()`-adjacent provenance and in the synthesis prompt, so a fragment's evidence is read as "12 samples" vs "8,000 cells" correctly. Defaults: `hdWGCNA_ModuleSet` / `components_ModuleSet` / `gene_list_ModuleSet` / `synthetic_ModuleSet` → `data_level = 'cell'`, `aggregated = FALSE` unless the caller declares otherwise.
- **Rename the capability `clusters` → `grouping`** across `capabilities()` for every adapter, and rename the corresponding constructor argument `cluster_col` → `group_col` in `components_ModuleSet()` / `gene_list_ModuleSet()`. Document `grouping` generically: "a cell/spot/region/sample **state grouping** column was declared." Update `cluster_dme_tool`'s registered `requires` from `'clusters'` to `'grouping'`; keep the tool's public name (`cluster_dme`) — only the capability vocabulary changes. `has_capability()` is unaffected.
- **Thread the descriptors into the synthesis prompt** (`build_user_prompt()` / `render_dataset_description()`) so the model is told the observation unit and count, and into fragment provenance where `level` / `n_units` are already recorded.

Deliverable: every adapter reports `data_level` + `aggregated`; the capability is `grouping` everywhere; hdWGCNA behavior + tests unchanged; the prompt names the observation unit.

### Part 2 — `counts()` accessor + `counts` capability

`expression()` returns the log-normalized layer (correct for scoring, enrichment background, and signature scoring). Raw counts are a *different* matrix, needed by negative-binomial / voom pseudo-bulk DE downstream.

- **Add a generic `counts(ms)`** returning a genes-by-observations matrix of **raw counts**, and a `counts` entry in the `capabilities()` vocabulary (`TRUE` only when real counts are available).
- **Adapters:** `hdWGCNA_ModuleSet` reads the counts layer of the Seurat object's default assay (`Seurat::GetAssayData(..., layer = 'counts')`); `components_ModuleSet` / `gene_list_ModuleSet` gain an optional `counts =` argument (validated to align with `expression()` and `metadata()`); `synthetic_ModuleSet` / the example fixture report `counts = FALSE` and `counts()` returns `NULL`.
- Tools that don't need counts are untouched; `counts()` is optional and capability-gated exactly like `module_scores`.

Deliverable: `counts()` + `counts` capability across all adapters; hdWGCNA exposes raw counts; `expression()` semantics unchanged.

### Part 3 — `validate_moduleset()` contract checker

Formalize the contract that is currently only documented.

- **Add `validate_moduleset(ms)`** asserting: every required generic dispatches for `class(ms)`; `capabilities()` returns a named logical over the **full vocabulary** `c('gene_weights', 'module_scores', 'expression', 'counts', 'grouping', 'sample_ids', 'pseudobulk')`; `data_level` is a length-1 string and `aggregated` a length-1 logical; and the declared-capability shapes align (`ncol(expression) == nrow(metadata)`; `module_scores` rows align with `expression` columns when present; `counts` dims match `expression` when present). Fail loudly with the specific violated clause.
- **Call it** in `tests/testthat` for all four adapters (and against a deliberately malformed object), and optionally at `run_orchestrator()` entry behind a `validate = TRUE` default so a broken custom adapter fails at the door rather than mid-run.
- `'pseudobulk'` is part of the vocabulary here so the checker is stable across milestones; it is only ever set `TRUE` by [milestone_pseudobulk.md](milestone_pseudobulk.md). Until then every adapter reports `pseudobulk = FALSE`.

Deliverable: `validate_moduleset()` passes for all four adapters, fails a malformed one with a precise message, and (optionally) guards `run_orchestrator()`.

### Part 4 — Record the module-generating method; NMF/factor as a worked custom example

Make the engine algorithm-agnostic *on the record*, without pretending to enumerate methods.

- **Add a free-form `module_method` string to `dataset_description()`** (e.g. `'hdWGCNA co-expression modules'`, `'cNMF factors, k=20'`, `'curated MSigDB gene sets'`), flowing into the synthesis prompt and the run manifest / provenance. No structured algorithm object and no per-method code — one honest string the user writes.
- **Ship an NMF/factor worked example** (a `scripts/` walkthrough and/or a vignette section, not a package adapter): take an NMF/cNMF result (gene-loadings matrix + cell-usage matrix), pick each factor's member genes by a top-k / loading threshold, and build a `components_ModuleSet(gene_table = <loadings→weight>, expression, metadata, scores = <usage matrix>, group_col = ...)`, then run the standard orchestrator. This demonstrates algorithm-agnosticism through the existing general adapter + the custom-tool path, per the decision *not* to add a bespoke `factor_ModuleSet`.

Deliverable: `dataset_description` carries `module_method`; an NMF-from-`components_ModuleSet` example runs offline end-to-end.

## Definition of done (whole milestone)

- Every adapter reports `data_level` (free string) and `aggregated` (logical); both reach the synthesis prompt and provenance.
- The capability vocabulary is `c('gene_weights', 'module_scores', 'expression', 'counts', 'grouping', 'sample_ids', 'pseudobulk')`; `clusters` no longer appears anywhere; `cluster_dme_tool` requires `'grouping'`.
- `counts()` + `counts` capability exist; `hdWGCNA_ModuleSet` exposes raw counts; the generic adapters accept optional counts.
- `validate_moduleset()` passes for hdWGCNA / components / gene-list / synthetic adapters and fails a malformed object with a precise message.
- `dataset_description()` carries a free-form `module_method`; an NMF-via-`components_ModuleSet` example runs offline.
- hdWGCNA behavior + existing tests intact; everything runs offline; `R CMD check` stays clean.

## Out of scope (deferred)

- All pseudo-bulk representation, ingestion, re-scoring, and DE tooling → [milestone_pseudobulk.md](milestone_pseudobulk.md).
- A dedicated `factor_ModuleSet` / NMF adapter (handled as a custom example instead).
- Spatial-resolution-specific tools (niches/FOVs get the same generic treatment for now).
- Additional container adapters (SCE/`.mtx`) beyond what falls out of the generic contract; cross-dataset reconciliation; literature grounding.

## Conventions

- [STYLE.md](../STYLE.md); new **exported** functions get roxygen; run `devtools::document()`; keep `R CMD check` clean.
- Breaking contract changes are allowed this milestone, but the hdWGCNA path's behavior + tests must stay intact.

---

*Last updated: 2026-07-20*
