# llegir 0.0.0.9000

* Added `pseudobulk_ModuleSet()`: builds a `ModuleSet` from a user-supplied
  pseudo-bulk counts matrix + metadata, or a `SummarizedExperiment`
  (`SummarizedExperiment` is a `Suggests` dependency), re-scoring module
  definitions directly on the pseudo-bulk matrix via `decoupleR::run_ulm()`
  (kME-style gene weights map to `mor` when present, else a uniform
  `mor = 1`). Realized as a `data_level = 'pseudobulk'`, `aggregated = TRUE`
  `components_ModuleSet`; `validate_moduleset()` passes. Added the
  attachment API -- `with_pseudobulk()`, `pseudobulk()`, `pseudobulk_view()`
  -- so a pseudo-bulk view can ride alongside a cell-level `ModuleSet`
  (`run_orchestrator()`) or be run standalone.
* Removed `module_by_metadata_tool()` (and its registry entry) along with
  `aggregate_by_sample()`, `is_sample_constant()`, and
  `continuous_correlation_test()` from `stats_utils.R`. Sample-level
  inference on module activity now belongs to the pseudo-bulk `ModuleSet`
  layer rather than averaging correlated per-cell scores; its
  categorical-association role is replaced by
  `differential_module_activity_tool()` (below), run on the pseudo-bulk view.
* `signature_correlation_tool()` no longer aggregates per-cell scores to the
  sample level itself. It now resolves a pseudo-bulk view via
  `pseudobulk_view(ms)`: when one is attached (or `ms` is itself a
  `pseudobulk_ModuleSet`), the signature library is re-scored on that view's
  own expression and correlated against its own re-scored module activity,
  with a real p-value from independent pseudo-bulk units. With no pseudo-bulk
  view available, it reports the same descriptive cell-level Pearson *r* as
  before, without a p-value. Sample-level `signature_correlation` numbers
  will differ from prior runs by design.
* Added `differential_module_activity_tool()`, the module-level DME
  successor: tests whether a module's re-scored pseudo-bulk activity differs
  across a declared `contrast_col`, on independent pseudo-bulk samples via
  `pseudobulk_view()`. Emits a `cross_condition_delta` fragment for a
  two-level contrast, or `categorical_association` for a multi-level factor.
  `method = 'limma'` (default) fits `limma::lmFit()`/`eBayes()` once over the
  full module-score matrix -- so variance moderation borrows strength across
  every module -- caching the fit across the per-module orchestrator loop;
  `method = 'nonparametric'` reuses `categorical_group_test()` per module.
  Skips gracefully (with a logged reason) when no pseudo-bulk view resolves
  or `contrast_col` isn't usable. Registered in the tool registry.
* Added `pseudobulk_de_limma_tool()`, the gene-level complement: runs
  limma-voom on a module's own genes within the pseudo-bulk raw counts
  (`counts(pseudobulk_view(ms))`), for a two-level `contrast_col` plus
  optional `covariates` and low-count gene filtering. Emits a
  `cross_condition_delta` fragment (one row per gene). Skips gracefully when
  no pseudo-bulk view resolves, the view lacks the `counts` capability, or no
  gene survives the filter. Registered in the tool registry.
* Packaged the deterministic evidence core and synthesis layer as an
  installable, documented R package. No behavior change from the
  pre-package sourced-functions codebase (Milestones 1-2): same inputs
  produce the same evidence packets, interpretations, and rendered
  paragraphs.
* Experimental: the public API is not yet stable. The `ModuleSet` adapter
  contract and custom-tool registry are expected to evolve before a 1.0
  release.
