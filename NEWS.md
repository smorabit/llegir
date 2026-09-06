# llegir 0.0.0.9000

* Fix: a fragment read back from disk kept `top_findings` as a data.frame
  (jsonlite's `simplifyDataFrame` collapses the uniform JSON array on read),
  where every tool and the HTML report's `findings_table()` expect a list
  with one named-list entry per finding. `fragment_from_json()`,
  `read_evidence_packet()`, `dataset_fragment_from_json()` and
  `read_dataset_context()` now restore the list-of-lists shape; a ragged or
  empty `top_findings` is unaffected. The report's `findings_table()` also
  passes a data.frame straight through as a safety net. Without this, a
  report rendered from a re-read packet transposed every evidence table
  (genes became column headers).

* The deterministic fused evidence score is shelved
  (`docs/prompts/handoff_prompt_serpentine_tcell.md` Part 4.5). Two known
  flaws made the blended number misleading: a non-significant dynamics
  fragment dragged down a genuinely stable module, and `top_genes`' top-kME
  magnitude stood in for interpretation confidence when it only measures hub
  tightness. Changes: `PROMPT_TEMPLATE_VERSION` bumped to `0.9`;
  `build_user_prompt()` no longer injects the EVIDENCE CONFIDENCE MATRIX (its
  `fusion`/`user_weights` arguments are now ignored) and the internal
  `.render_confidence_matrix()` is removed; `build_system_prompt()` drops the
  rules constraining `confidence.score` to `E_evidence` and asks the model
  for its own calibrated certainty instead. `fuse_confidence()` no longer
  blends or overwrites `confidence$score` -- it keeps the model's own value
  and only unions the deterministic `possible_artifact` flag;
  `enforce_faithfulness()` still sets `needs_human_review`. `calculate_fusion_score()`
  and `compute_evidence_signals()` are retained (unused) for a future
  redesign. The HTML summary report drops the Evidence Confidence Matrix
  section and shows the model's own confidence.

* `cluster_expression_profile_tool()` now carries mean raw module activity
  (eigengene) per state: the `result` column is `mean_activity` (was
  `mean_score`), and it is also surfaced in `top_findings` and the
  `compact_summary` alongside `mean_decile`/`pct_high`, so an absolute
  activity difference between states is legible next to the rank-based
  decile.

* New exported `housekeeping_composition_note()`: the fraction of a module's
  top hub genes that are cytoplasmic ribosomal (`RPS*`/`RPL*`) or
  mitochondrially encoded (`MT-*`). `render_packet_compact()` appends it to
  the `ranked_genes` block so a part-housekeeping hub list is visible to
  synthesis as a co-occurring program rather than quietly diluting the call.
  Deterministic and packet-only; unlike the IEG artifact pattern it never
  sets a flag.

* The HTML summary report renders `cross_condition_delta` fragments as the
  full per-state limma table (effect log2FC, raw and BH-adjusted p, moderated
  t) pulled from the fragment `result`, with a one-line method caption,
  instead of the 3-column `top_findings` preview.

* New core evidence tool `cluster_expression_profile_tool()` (registered as
  `'cluster_expression_profile'`), the non-differential companion to
  `cluster_dme_tool()`. Instead of a one-vs-all winner, it bins every cell's
  module score into deciles of the module's own global score distribution
  (all cells in the `ModuleSet`, not re-binned per state) and reports, per
  cell state, the mean/median decile its cells occupy and the share of its
  cells in the top bin -- so a state that expresses a module at a medium
  intensity stays visible instead of being collapsed away by `cluster_dme`'s
  winner-take-all contrast. Emits a `'state_expression'` fragment with
  `direction = 'na'` (a graded profile, not a signed effect) and
  `effect_strength` set to the top state's mean global decile scaled by the
  realized bin count, so it stays comparable across modules even when heavy
  ties in the score distribution collapse the requested `n_deciles` to fewer
  realized bins. Requires the `grouping` and `module_scores` `ModuleSet`
  capabilities, same as `cluster_dme`; skips gracefully when either is
  unmet.

* `import_fragment()` gained normalizers for `'signature_correlation'` and
  `'continuous_correlation'` (`docs/milestones/milestone_serpentine_tcell.md`
  Part 3), closing a gap where the two schema types existed in the controlled
  vocab and had a native tool (`signature_correlation_tool()`) but no import
  path. `signature_correlation` normalizes a many-rows-per-module table (one
  row per named signature, e.g. a cGEP/program library), with `top_findings`
  using the same `signature`/`r` field names `signature_correlation_tool()`
  itself produces; `continuous_correlation` normalizes a module's correlation
  with a single continuous variable (`variable_col` optional, since the
  common shape -- one row per module -- is already scoped to one variable).
  Both follow the existing importer contract: configurable column names via
  `params`, `effect_strength = max(abs(r))`, direction from the top |r| row's
  sign, `provenance$source = 'user_supplied'`.
* Plot ingestion (`docs/milestones/milestone_plot_ingestion.md` Parts 1-2):
  both `evidence_fragment()` and `dataset_fragment()` gained an optional
  `plots` slot -- a named list of pre-rendered figure specs (a live
  `plot_obj` and/or a persisted `image_path`, plus `legend`/`placement`
  hints). `llegir` ships no plotting functions and stays strictly an asset
  container; a fragment with no plots validates, serializes, and hashes
  exactly as before. New exported `attach_plots(frag, plots)` decorates an
  existing fragment and re-validates at attach time. A raw `plot_obj` never
  reaches `jsonlite::toJSON()` or `digest::digest()`: the new internal
  `.strip_plot_objs()` guardrail runs before every existing `unclass()` in
  `.fragment_hashable()`/`fragment_to_json()`/`packet_to_json()` and their
  `dataset_fragment` siblings, so `packet_hash` stays reproducible across
  sessions while legends (text, not pixels) still serialize and count toward
  the hash. New exported `write_fragment_figures(packet, figures_dir)`
  renders each fragment's live plots to
  `<figures_dir>/<module_id>/<fragment_id>__<plot_id>.png` and records the
  path back onto the spec as `image_path`, the graphical sibling of
  `write_fragment_tables()`. `ggplot2` added to `Suggests` (not `Imports`);
  the core pipeline runs without it.
* `export_agent_workspace()` v0.2 hardening (`docs/milestones/milestone_agent_workspace.md`
  Part 4): the serialized `ModuleSet` is now split into a lite/full pair --
  `artifacts/moduleset_lite.qs2` (default load; a new internal
  `.make_moduleset_lite()` reduction with the backing expression/counts
  matrices dropped, built on `components_ModuleSet()`) and
  `artifacts/moduleset_full.qs2` (the original object, for the rare
  `expression()`/`counts()` query). Workspace artifacts (moduleset lite/full,
  `dataset_context`, `packets`, `interpretations`) now serialize via `qs2`
  (`qs2::qs_save()`/`qs2::qs_read()`) instead of `saveRDS()`/`readRDS()`; `qs2`
  added to `Imports`. `export_agent_workspace()` gained an `interps = NULL`
  argument -- when supplied, writes `artifacts/interpretations.qs2` plus
  per-module JSON mirrors and records them in the manifest; when omitted, the
  manifest explicitly states no interpretations shipped so a guest agent does
  not mock-synthesize one. Every cheat-sheet row, tool-registry row, and
  recipe rung is tagged `(full object only)` when it needs a capability the
  lite object dropped. Fixed two bugs found reviewing a real exported
  workspace: the "Aggregate-then-summarize" recipe and the `cluster_dme`
  example invocation used to hardcode `'cell_state'` as the grouping column
  regardless of what the `ModuleSet` actually declared (now reads the real
  declared column via new internal `.ms_group_col()`/`.ms_sample_col()`,
  omitting the rung when none is declared); the "delegate to a registered
  tool" recipe used to grab `packet$fragments[[1]]` positionally (now filters
  by `fragment_id`). Front matter now emits `aggregated: false` (lowercase)
  and quotes `generated_at` unambiguously. `components_ModuleSet()` gained an
  optional `pkg_versions` override argument and now accepts `expression =
  NULL` (dropping the backing matrix entirely) to support the lite object.
  `synthetic_ModuleSet()` (and the shared `llegir_example_moduleset()`
  fixture) now delegates `group_col`/`sample_col` from its wrapped base.
* Added `export_agent_workspace()`: serializes a completed run's
  `ModuleSet`, dataset context, and evidence packets to `out_dir/artifacts/`
  (`.rds` authoritative, `.json` portable mirror) and renders
  `.llegir_agent_manifest.md` -- a static launchpad an external terminal
  coding agent (Claude Code, Aider, ...) points at to run open-ended,
  read-only queries against the analysis. The manifest's ModuleSet API and
  Tool Registry cheat-sheets are generated from the live registry and this
  `ModuleSet`'s `capabilities()` at export time, so a custom
  `register_tool()` call propagates into the next export with no manual
  edits. Pure exporter -- writes files and returns a path, never calls
  `ellmer` or spends budget. Added `read_agent_manifest()`, the inverse that
  parses a manifest's YAML front matter back into an R list. New packaged
  templates `inst/templates/agent_manifest.md` (rendered via `whisker`, now
  an Imports dependency) and `inst/templates/query_example.R` (the vanilla
  bootstrap script, copied into every exported workspace). See
  `docs/agent_workspace.md` and `tests/testthat/test-agent_workspace.R`.
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
