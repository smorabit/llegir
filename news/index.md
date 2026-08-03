# Changelog

## llegir 0.0.0.9000

- Plot ingestion (`docs/milestones/milestone_plot_ingestion.md` Parts
  1-2): both
  [`evidence_fragment()`](https://smorabit.github.io/llegir/reference/evidence_fragment.md)
  and
  [`dataset_fragment()`](https://smorabit.github.io/llegir/reference/dataset_fragment.md)
  gained an optional `plots` slot – a named list of pre-rendered figure
  specs (a live `plot_obj` and/or a persisted `image_path`, plus
  `legend`/`placement` hints). `llegir` ships no plotting functions and
  stays strictly an asset container; a fragment with no plots validates,
  serializes, and hashes exactly as before. New exported
  `attach_plots(frag, plots)` decorates an existing fragment and
  re-validates at attach time. A raw `plot_obj` never reaches
  [`jsonlite::toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
  or
  [`digest::digest()`](https://eddelbuettel.github.io/digest/man/digest.html):
  the new internal `.strip_plot_objs()` guardrail runs before every
  existing [`unclass()`](https://rdrr.io/r/base/class.html) in
  `.fragment_hashable()`/[`fragment_to_json()`](https://smorabit.github.io/llegir/reference/fragment_to_json.md)/[`packet_to_json()`](https://smorabit.github.io/llegir/reference/packet_to_json.md)
  and their `dataset_fragment` siblings, so `packet_hash` stays
  reproducible across sessions while legends (text, not pixels) still
  serialize and count toward the hash. New exported
  `write_fragment_figures(packet, figures_dir)` renders each fragment’s
  live plots to `<figures_dir>/<module_id>/<fragment_id>__<plot_id>.png`
  and records the path back onto the spec as `image_path`, the graphical
  sibling of
  [`write_fragment_tables()`](https://smorabit.github.io/llegir/reference/write_fragment_tables.md).
  `ggplot2` added to `Suggests` (not `Imports`); the core pipeline runs
  without it.
- [`export_agent_workspace()`](https://smorabit.github.io/llegir/reference/export_agent_workspace.md)
  v0.2 hardening (`docs/milestones/milestone_agent_workspace.md` Part
  4): the serialized `ModuleSet` is now split into a lite/full pair –
  `artifacts/moduleset_lite.qs2` (default load; a new internal
  [`.make_moduleset_lite()`](https://smorabit.github.io/llegir/reference/dot-make_moduleset_lite.md)
  reduction with the backing expression/counts matrices dropped, built
  on
  [`components_ModuleSet()`](https://smorabit.github.io/llegir/reference/components_ModuleSet.md))
  and `artifacts/moduleset_full.qs2` (the original object, for the rare
  [`expression()`](https://smorabit.github.io/llegir/reference/expression.md)/[`counts()`](https://smorabit.github.io/llegir/reference/counts.md)
  query). Workspace artifacts (moduleset lite/full, `dataset_context`,
  `packets`, `interpretations`) now serialize via `qs2`
  ([`qs2::qs_save()`](https://rdrr.io/pkg/qs2/man/qs_save.html)/[`qs2::qs_read()`](https://rdrr.io/pkg/qs2/man/qs_read.html))
  instead of
  [`saveRDS()`](https://rdrr.io/r/base/readRDS.html)/[`readRDS()`](https://rdrr.io/r/base/readRDS.html);
  `qs2` added to `Imports`.
  [`export_agent_workspace()`](https://smorabit.github.io/llegir/reference/export_agent_workspace.md)
  gained an `interps = NULL` argument – when supplied, writes
  `artifacts/interpretations.qs2` plus per-module JSON mirrors and
  records them in the manifest; when omitted, the manifest explicitly
  states no interpretations shipped so a guest agent does not
  mock-synthesize one. Every cheat-sheet row, tool-registry row, and
  recipe rung is tagged `(full object only)` when it needs a capability
  the lite object dropped. Fixed two bugs found reviewing a real
  exported workspace: the “Aggregate-then-summarize” recipe and the
  `cluster_dme` example invocation used to hardcode `'cell_state'` as
  the grouping column regardless of what the `ModuleSet` actually
  declared (now reads the real declared column via new internal
  `.ms_group_col()`/`.ms_sample_col()`, omitting the rung when none is
  declared); the “delegate to a registered tool” recipe used to grab
  `packet$fragments[[1]]` positionally (now filters by `fragment_id`).
  Front matter now emits `aggregated: false` (lowercase) and quotes
  `generated_at` unambiguously.
  [`components_ModuleSet()`](https://smorabit.github.io/llegir/reference/components_ModuleSet.md)
  gained an optional `pkg_versions` override argument and now accepts
  `expression = NULL` (dropping the backing matrix entirely) to support
  the lite object.
  [`synthetic_ModuleSet()`](https://smorabit.github.io/llegir/reference/synthetic_ModuleSet.md)
  (and the shared
  [`llegir_example_moduleset()`](https://smorabit.github.io/llegir/reference/llegir_example_moduleset.md)
  fixture) now delegates `group_col`/`sample_col` from its wrapped base.
- Added
  [`export_agent_workspace()`](https://smorabit.github.io/llegir/reference/export_agent_workspace.md):
  serializes a completed run’s `ModuleSet`, dataset context, and
  evidence packets to `out_dir/artifacts/` (`.rds` authoritative,
  `.json` portable mirror) and renders `.llegir_agent_manifest.md` – a
  static launchpad an external terminal coding agent (Claude Code,
  Aider, …) points at to run open-ended, read-only queries against the
  analysis. The manifest’s ModuleSet API and Tool Registry cheat-sheets
  are generated from the live registry and this `ModuleSet`’s
  [`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)
  at export time, so a custom
  [`register_tool()`](https://smorabit.github.io/llegir/reference/register_tool.md)
  call propagates into the next export with no manual edits. Pure
  exporter – writes files and returns a path, never calls `ellmer` or
  spends budget. Added
  [`read_agent_manifest()`](https://smorabit.github.io/llegir/reference/read_agent_manifest.md),
  the inverse that parses a manifest’s YAML front matter back into an R
  list. New packaged templates `inst/templates/agent_manifest.md`
  (rendered via `whisker`, now an Imports dependency) and
  `inst/templates/query_example.R` (the vanilla bootstrap script, copied
  into every exported workspace). See `docs/agent_workspace.md` and
  `tests/testthat/test-agent_workspace.R`.
- Added
  [`pseudobulk_ModuleSet()`](https://smorabit.github.io/llegir/reference/pseudobulk_ModuleSet.md):
  builds a `ModuleSet` from a user-supplied pseudo-bulk counts matrix +
  metadata, or a `SummarizedExperiment` (`SummarizedExperiment` is a
  `Suggests` dependency), re-scoring module definitions directly on the
  pseudo-bulk matrix via
  [`decoupleR::run_ulm()`](https://saezlab.github.io/decoupleR/reference/run_ulm.html)
  (kME-style gene weights map to `mor` when present, else a uniform
  `mor = 1`). Realized as a `data_level = 'pseudobulk'`,
  `aggregated = TRUE` `components_ModuleSet`;
  [`validate_moduleset()`](https://smorabit.github.io/llegir/reference/validate_moduleset.md)
  passes. Added the attachment API –
  [`with_pseudobulk()`](https://smorabit.github.io/llegir/reference/with_pseudobulk.md),
  [`pseudobulk()`](https://smorabit.github.io/llegir/reference/pseudobulk.md),
  [`pseudobulk_view()`](https://smorabit.github.io/llegir/reference/pseudobulk_view.md)
  – so a pseudo-bulk view can ride alongside a cell-level `ModuleSet`
  ([`run_orchestrator()`](https://smorabit.github.io/llegir/reference/run_orchestrator.md))
  or be run standalone.
- Removed `module_by_metadata_tool()` (and its registry entry) along
  with `aggregate_by_sample()`, `is_sample_constant()`, and
  `continuous_correlation_test()` from `stats_utils.R`. Sample-level
  inference on module activity now belongs to the pseudo-bulk
  `ModuleSet` layer rather than averaging correlated per-cell scores;
  its categorical-association role is replaced by
  [`differential_module_activity_tool()`](https://smorabit.github.io/llegir/reference/differential_module_activity_tool.md)
  (below), run on the pseudo-bulk view.
- [`signature_correlation_tool()`](https://smorabit.github.io/llegir/reference/signature_correlation_tool.md)
  no longer aggregates per-cell scores to the sample level itself. It
  now resolves a pseudo-bulk view via `pseudobulk_view(ms)`: when one is
  attached (or `ms` is itself a `pseudobulk_ModuleSet`), the signature
  library is re-scored on that view’s own expression and correlated
  against its own re-scored module activity, with a real p-value from
  independent pseudo-bulk units. With no pseudo-bulk view available, it
  reports the same descriptive cell-level Pearson *r* as before, without
  a p-value. Sample-level `signature_correlation` numbers will differ
  from prior runs by design.
- Added
  [`differential_module_activity_tool()`](https://smorabit.github.io/llegir/reference/differential_module_activity_tool.md),
  the module-level DME successor: tests whether a module’s re-scored
  pseudo-bulk activity differs across a declared `contrast_col`, on
  independent pseudo-bulk samples via
  [`pseudobulk_view()`](https://smorabit.github.io/llegir/reference/pseudobulk_view.md).
  Emits a `cross_condition_delta` fragment for a two-level contrast, or
  `categorical_association` for a multi-level factor. `method = 'limma'`
  (default) fits
  [`limma::lmFit()`](https://rdrr.io/pkg/limma/man/lmFit.html)/`eBayes()`
  once over the full module-score matrix – so variance moderation
  borrows strength across every module – caching the fit across the
  per-module orchestrator loop; `method = 'nonparametric'` reuses
  [`categorical_group_test()`](https://smorabit.github.io/llegir/reference/categorical_group_test.md)
  per module. Skips gracefully (with a logged reason) when no
  pseudo-bulk view resolves or `contrast_col` isn’t usable. Registered
  in the tool registry.
- Added
  [`pseudobulk_de_limma_tool()`](https://smorabit.github.io/llegir/reference/pseudobulk_de_limma_tool.md),
  the gene-level complement: runs limma-voom on a module’s own genes
  within the pseudo-bulk raw counts (`counts(pseudobulk_view(ms))`), for
  a two-level `contrast_col` plus optional `covariates` and low-count
  gene filtering. Emits a `cross_condition_delta` fragment (one row per
  gene). Skips gracefully when no pseudo-bulk view resolves, the view
  lacks the `counts` capability, or no gene survives the filter.
  Registered in the tool registry.
- Packaged the deterministic evidence core and synthesis layer as an
  installable, documented R package. No behavior change from the
  pre-package sourced-functions codebase (Milestones 1-2): same inputs
  produce the same evidence packets, interpretations, and rendered
  paragraphs.
- Experimental: the public API is not yet stable. The `ModuleSet`
  adapter contract and custom-tool registry are expected to evolve
  before a 1.0 release.
