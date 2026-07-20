# Milestone (pseudo-bulk) — a first-class pseudo-bulk representation in the adapter layer

← [Overview](overview.md) · [Implementation guide](implementation_guide.md) · [Schemas](schemas.md) · [Abstract ModuleSet milestone](milestone_abstract_moduleset.md) · [Extensibility milestone](milestone_extensibility.md) · [Project home](../README.md)

*Status: planned. Depends on [milestone_abstract_moduleset.md](milestone_abstract_moduleset.md) (needs `counts()`, `data_level`/`aggregated`, and `validate_moduleset()`).*

---

## Goal

Give aggregated pseudo-bulk matrices (counts/CPM summed by sample, or by sample × cluster/region) a clean home in the `ModuleSet` layer, so pseudo-bulk-specific evidence tools can run downstream and sample-level inference stops relying on averaging cell scores.

The key architectural decision: **a pseudo-bulk view is itself a `ModuleSet`** (`data_level = 'pseudobulk'`, `aggregated = TRUE`, raw `counts()` present). One mechanism gives both usage modes the user asked for:

- **Standalone** — build a `pseudobulk_ModuleSet` and hand it straight to `run_orchestrator()`. The whole analysis runs on pseudo-bulk; single-cell-only tools skip via capabilities.
- **Alongside** — attach the pseudo-bulk view to a cell-level `ModuleSet` via `with_pseudobulk()`. Cell-level tools use the primary view, pseudo-bulk tools pull `pseudobulk(ms)`, and **both write into one evidence packet per module**, so synthesis sees cell- and sample-level evidence together.

This milestone also **retires `module_by_metadata` and `aggregate_by_sample()` outright**. Their only statistically-defensible job — a **module-level differential test** (does the module's *activity* differ across a condition — the differential-module-eigengene / DME question) — is reintroduced properly, on the pseudo-bulk view, at the correct level. Two constraints from project scope:

- **llegir does not build pseudo-bulk.** Aggregating cells into pseudo-bulk is out of mission; the **user supplies** the pseudo-bulk data (a counts matrix + metadata, or an hdWGCNA-style pseudo-bulk `SummarizedExperiment`). llegir only *ingests, re-scores, and analyzes* it.
- **Module scores on pseudo-bulk are re-computed, not averaged.** `aggregate_by_sample()` (averaging per-cell module scores to sample level) is removed; modules are re-scored directly on the pseudo-bulk matrix with decoupleR.

## Design principles

- **Pseudo-bulk is not a special case, it's a coarser `ModuleSet`.** It reuses the whole generic contract and the `components_ModuleSet` substrate; nothing in the tool/orchestrator/synthesis layers needs a pseudo-bulk branch beyond capability gating.
- **The user owns the aggregation; llegir owns the scoring and the stats.** We accept whatever pseudo-bulk the user produced (any strategy, any tool) and take responsibility only from ingestion onward.
- **Correct sample-level inference is structural, not a helper.** Independent sample-level units come from *running on the pseudo-bulk view*, whose re-scored `module_scores()` are per-sample — not from a post-hoc averaging step inside a cell-level tool. Because sample-level tests only exist where inference is valid, there is **no cell-level fallback and no pseudoreplication flag** to maintain.
- **Module-level first, gene-level alongside.** The primary condition test is at the **module level** (differential module activity); a **gene-level** pseudo-bulk DE tool complements it (which of the module's genes drive the shift). Other DE engines stay user-extensible via custom tools + evidence ingestion.

## Parts (sequenced; one Claude Code session each)

### Part 1 — `pseudobulk_ModuleSet()`: ingest + re-score; attach or stand alone *(keystone; first)*

- **Constructor `pseudobulk_ModuleSet(...)`** accepting **either** input the user already has:
  - a raw-**counts matrix** (genes × pseudo-bulk units) **+ a metadata data.frame** (one row per unit: sample id, condition/group, `n_cells`, library size, …), **or**
  - a **`SummarizedExperiment`** (default assay `'counts'`, `colData` → metadata, `rownames` → genes) — matching hdWGCNA's pseudo-bulk-SE output. `SummarizedExperiment` is a `Suggests` dependency; an SE trivially decomposes to matrix + `colData` internally.
  - plus the **module definitions** to score — normally the *same* modules found at cell level, passed as a tidy `gene_table` (`module`, `gene_name`, optional `weight`) or a named list of gene vectors.
- **Re-score modules on the pseudo-bulk matrix with decoupleR** (`run_ulm`), reusing the existing `.score_gene_sets()` scoring path: build the decoupleR network from the module memberships, using each gene's `weight` as the mode-of-regulation (`mor`) when the modules carry weights (e.g. hdWGCNA kME), and a uniform `mor = 1` otherwise. Scoring runs on a CPM/logCPM normalization of the supplied counts. This *is* the sample-level module activity; no averaging of cell scores anywhere.
- **Realize it as a `components_ModuleSet` under the hood** (like `gene_list_ModuleSet`): set `data_level = 'pseudobulk'` (overridable, e.g. `'pseudobulk_sample_x_cluster'`), `aggregated = TRUE`, raw counts wired into `counts()` so `capabilities()$counts` is `TRUE`, and `group_col` / `sample_col` as declared. `validate_moduleset()` must pass.
- **Attachment API:** `with_pseudobulk(cell_ms, pb_ms)` stores `pb_ms` on a cell-level `ModuleSet` and flips its `pseudobulk` capability to `TRUE`; `pseudobulk(ms)` returns the attached view; **`pseudobulk_view(ms)`** is the resolver every pseudo-bulk tool uses — it returns `ms` itself when `aggregated` / `data_level == 'pseudobulk'`, else `pseudobulk(ms)` when one is attached, else `NULL` (skip).

Deliverable: a `pseudobulk_ModuleSet` builds from both a matrix+metadata and an SE, with modules re-scored via decoupleR; `validate_moduleset()` passes; standalone (`run_orchestrator(pb_ms, ...)`) and attached (`with_pseudobulk()`) modes both work; a `pseudobulk` capability exists and is advertised.

### Part 2 — Retire `module_by_metadata` + `aggregate_by_sample`; move `signature_correlation` onto the pseudo-bulk view

Clear out the pseudoreplicated / redundant machinery before adding the clean replacements.

- **Remove `module_by_metadata_tool` entirely** (its registry entry, tests, and prompt references). Its three jobs are covered elsewhere: cell-level categorical association was already `cluster_dme`'s engine (`categorical_group_test`); sample-level categorical is superseded by Part 3; the continuous-covariate branch is unused today (CSF never exercises it) and can return later as a small dedicated tool if a dataset needs it.
- **Remove `aggregate_by_sample()`** from `stats_utils.R`. **Prune now-orphaned helpers**: drop `is_sample_constant()` and `continuous_correlation_test()` if nothing else references them after the removal; **keep `categorical_group_test()`** (used by `cluster_dme` and Part 3's non-parametric path).
- **Refactor `signature_correlation_tool`** to source its sample-level correlation from `pseudobulk_view(ms)`: score the signature library and read module activity on the **pseudo-bulk** matrix, correlate per-sample (with a p-value). With no pseudo-bulk view available, keep the existing descriptive cell-level Pearson *r* (no p-value) — which was never pseudoreplicated. Remove its `aggregate_by_sample()` call. No flag, no fallback branch beyond descriptive-vs-inferential.
- `cluster_dme_tool` is unchanged — "which cell states express the module" is a legitimately cell-level, descriptive question.

Deliverable: `module_by_metadata` and `aggregate_by_sample()` are gone with their orphaned helpers; `signature_correlation` gets sample-level inference from the pseudo-bulk view; no `pseudoreplicated` flag or fallback machinery exists; existing cell-level behavior of the remaining tools is intact (any sample-level numbers change by design — note in `NEWS.md`).

### Part 3 — Module-level differential activity tool (the DME successor) *(flagship)*

The primary condition test: does the module's *activity* differ across a condition, on independent pseudo-bulk samples. *(Working name `differential_module_activity_tool`; final name TBD.)*

- **Runs on `pseudobulk_view(ms)`**, over the module's re-scored per-sample activity vs a declared metadata column (`ctx$params$contrast_col`, optional `covariates`). Emits a **`cross_condition_delta`** fragment for a two-level contrast, or **`categorical_association`** for a multi-level factor.
- **Configurable statistic (`method = c('limma', 'nonparametric')`, default `'limma'`):**
  - **`'limma'`** — `limma`/`eBayes` on the **module-score matrix** (modules × pseudo-bulk samples), giving moderated variance + covariate adjustment, which matter at pseudo-bulk's small sample counts. *Design note:* moderation borrows strength **across modules**, so although the orchestrator invokes tools per-module, the limma fit must be done over the **full** module-score matrix (`module_scores(pb_view)`) once and the current module's contrast row extracted — cache the fit across the per-module loop rather than refitting per module.
  - **`'nonparametric'`** — `categorical_group_test()` (Kruskal–Wallis + one-vs-rest Wilcoxon, rank-biserial) on the module's pseudo-bulk scores; per-module, no cross-module dependency, no new machinery.
- **Capability-gated** on the pseudo-bulk view existing plus `module_scores` + the contrast column; **skips gracefully** (reason recorded) otherwise. Registered via `register_tool()` with the appropriate `requires`, and its output schema-validated like every other tool.

Deliverable: a module-level differential-activity tool emitting a valid `cross_condition_delta` / `categorical_association` from either the limma or non-parametric path, correctly resolving the pseudo-bulk view, skipping cleanly when unavailable, with an offline deterministic test.

### Part 4 — Gene-level pseudo-bulk limma-voom DE tool *(secondary)*

Complements Part 3 by reporting *which of the module's genes* drive the condition shift.

- **`pseudobulk_de_limma_tool(ctx)`** runs **limma-voom** on the pseudo-bulk **raw counts** for the declared contrast (`contrast_col`, optional `covariates`, optional `min_count` / low-information filtering), restricted to the module's genes. Emits a **`cross_condition_delta`** fragment: `logFC` effect, `adj.P.Val` significance, direction from the module-gene aggregate / top gene. Per-module is fine here — voom's moderation operates across the module's genes.
- **Resolves data via `pseudobulk_view(ms)`** and gates on `counts` + `sample_ids` + the contrast column; **skips gracefully** otherwise. Registered like the core tools.
- **limma only.** DESeq2 / edgeR are intentionally *not* built; a user who wants them registers a custom tool or ingests a precomputed table via the existing `import_fragment` / `import_seurat_markers` importers (which already normalize DESeq2/edgeR columns to `cross_condition_delta`).
- **Test fixture:** add a small synthetic pseudo-bulk fixture (a handful of samples across two conditions, with counts) — extending the example-moduleset machinery — so Parts 3 and 4 both have offline, deterministic tests.

Deliverable: `pseudobulk_de_limma_tool` emits a valid gene-level `cross_condition_delta` from limma-voom, is registered + capability-gated, skips cleanly without counts/pseudo-bulk, and has an offline test.

## Definition of done (whole milestone)

- `pseudobulk_ModuleSet()` builds from **both** a counts matrix + metadata **and** a `SummarizedExperiment`; modules are re-scored via decoupleR (weights → `mor` when present); `data_level = 'pseudobulk'`, `aggregated = TRUE`, `counts` capability `TRUE`; `validate_moduleset()` passes.
- **Standalone** (`run_orchestrator()` directly on the pseudo-bulk set) and **alongside** (`with_pseudobulk()` → one packet per module mixing cell- and sample-level fragments) both work, resolved through `pseudobulk_view()`.
- `module_by_metadata` and `aggregate_by_sample()` are removed along with orphaned helpers; no pseudoreplication flag or cell-level fallback exists; `signature_correlation` sources sample-level correlation from the pseudo-bulk view.
- The **module-level** differential-activity tool works from both the limma (cross-module moderated) and non-parametric paths; the **gene-level** `pseudobulk_de_limma_tool` complements it; both skip gracefully when their capabilities aren't met.
- hdWGCNA cell-level behavior + tests intact (sample-level numbers change by design; migration noted in `NEWS.md`); everything runs offline; `R CMD check` stays clean.

## Out of scope (deferred)

- **Any function that *creates* pseudo-bulk from cells** — the user supplies it (via hdWGCNA's pseudo-bulk SE builder or their own aggregation).
- DESeq2 / edgeR (and other DE engines) as built-in tools — custom tools + evidence ingestion cover them.
- Re-introducing a module-score-vs-continuous-covariate tool (the retired continuous branch) — additive later if a dataset needs it.
- Spatial multi-resolution aggregation (niches/FOVs as pseudo-bulk units work through the same generic path, but no resolution-specific tooling here); cross-dataset reconciliation.

## Conventions

- [STYLE.md](../STYLE.md); new **exported** functions get roxygen; run `devtools::document()`; keep `R CMD check` clean.
- Breaking contract changes are allowed, but the hdWGCNA cell-level path's behavior + remaining tests must stay intact; document the removals and the sample-level migration in `NEWS.md`.

---

*Last updated: 2026-07-20*
