# Claude Code handoff prompts — dataset-level tools milestone

← [Project home](../../README.md) · [Dataset tools milestone](../milestones/milestone_dataset_tools.md)

Six handoff prompts, one per milestone part, for fresh Claude Code instances (Sonnet). Run them **in order** — each assumes the previous parts have landed. Paste one block at a time from the repo root.

*Logged 2026-07-22.*

---

## Shared context (every part depends on this)

The milestone `docs/milestones/milestone_dataset_tools.md` is authoritative — each prompt points the instance there first. Core idea it must internalize: **a dataset-level summary is NOT an `evidence_fragment`** (that contract is per-module and feeds fusion/faithfulness). It gets a sibling contract, `dataset_fragment`, bundled into a `dataset_context`, injected into synthesis prompts alongside `dataset_description` — global framing, never citable per-module evidence, never entering the confidence matrix.

---

## Part 1 — the `dataset_fragment` + `dataset_context` contracts

```
You're implementing Part 1 of the dataset-tools milestone for `llegir` (installed
experimental R package, conda env `hdWGCNA`). Goal: a new dataset-level data contract
that is a SIBLING of the existing per-module evidence_fragment contract.

Read first, in order: docs/milestones/milestone_dataset_tools.md (authoritative — read the
whole thing, implement Part 1 only), then CLAUDE.md, STYLE.md, and R/fragment.R. R/fragment.R
is your REFERENCE IMPLEMENTATION — you are building the parallel file the same way. Also read
R/registry.R (you extend register_tool) and inst/schemas/evidence_fragment.schema.json +
inst/schemas/dataset_fragment.schema.json (the stub is already drafted).

Environment: do NOT install packages (base R + already-used deps: jsonlite, digest only).
Everything OFFLINE — no API calls. If something's missing, STOP and tell me.

SCOPE — Part 1 only:

1. New R/dataset_fragment.R, mirroring R/fragment.R exactly:
   - Constants: .dataset_fragment_types <- c('composition_summary','baseline_expression',
     'variance_structure','module_landscape'); .dataset_caveat_vocab <- c(
     'condition_confounded_with_batch','cell_state_imbalanced_across_condition',
     'hub_genes_are_housekeeping','underpowered_contrast').
   - dataset_fragment(fragment_id, tool_id, type, result, compact_summary, top_findings,
     caveats = list(), provenance = list()) — S3 class 'dataset_fragment'. NO module_id,
     NO effect_strength/significance/direction. match.arg(type, .dataset_fragment_types).
   - validate_dataset_fragment(frag) — mirror validate_evidence_fragment(): required fields,
     types, result is a data.frame, every caveat in .dataset_caveat_vocab, provenance has the
     same required fields (tool_version/params/input_hashes/pkg_versions/timestamp).
   - dataset_fragment_to_json()/dataset_fragment_from_json() — mirror the fragment (de)serializers
     (dataframe='rows', auto_unbox=TRUE, na='null').
   - build_dataset_context(dataset_fragments, input_hash = NA_character_, schema_version = '0.1')
     — mirror build_evidence_packet(): validate each, hash content-minus-timestamps with a
     .fragment_hashable-style strip + digest::digest(algo='sha256'), return
     list(dataset_fragments, context_hash, schema_version, provenance).
   - dataset_context_to_json()/write_dataset_context()/read_dataset_context() — mirror the packet
     (de)serializers in R/fragment.R.

2. R/registry.R: add scope = 'module' (default) / 'dataset' arg to register_tool(), stored on
   the tool_spec; validate it's one of the two. Add a scope filter arg to list_tools()
   (default returns all, or 'module'/'dataset' filters). Document that `tier` is ignored when
   scope=='dataset'. This must be non-breaking — run_module() takes an explicit tool_config and
   never scans the registry, so nothing downstream changes.

3. inst/schemas/dataset_fragment.schema.json: it's stubbed — reconcile its enums with your R
   constants (keep schema_version in lockstep). docs/schemas.md: add a "3. Dataset fragment"
   section mirroring the evidence-fragment table.

4. tests/testthat/test-dataset_fragment.R (offline), mirroring test-fragment.R: construct/validate,
   JSON round-trip, reproducible hashing, caveat-vocab rejection, registry scope filter.

Non-negotiables: no new deps; core logic depends only on the contract (no hdWGCNA/Seurat);
roxygen on exported fns + run devtools::document(); R CMD check clean; STYLE.md exactly
(snake_case, single quotes, 4-space indent, `<-`, `%>%`, intent-based comments, no aligned
assignments, no over-defensive stopifnot walls). Commit per CLAUDE.md git rules (Conventional
Commits, NO self-attribution, body lists new functions / changed contracts / test files).

Start by restating the exact signatures of dataset_fragment(), validate_dataset_fragment(),
build_dataset_context(), and the register_tool() scope change, and confirm with me before
writing. Then run devtools::test() and report before committing.
```

---

## Part 2 — orchestration + prompt injection (the spine)

```
You're implementing Part 2 of the dataset-tools milestone for `llegir` (installed R package,
conda env `hdWGCNA`). Part 1 (dataset_fragment/dataset_context contracts + registry scope) is
DONE and committed. Part 2 wires the (still tool-less) contract through the pipeline so a tool
built in Part 3 lights up end-to-end.

Read first: docs/milestones/milestone_dataset_tools.md (Part 2), then CLAUDE.md, STYLE.md,
R/dataset_fragment.R (Part 1's output), R/orchestrator.R (run_module/run_orchestrator +
synthesize_module/run_synthesis_orchestrator — you mirror and extend these), R/prompt.R
(build_user_prompt/build_system_prompt/render_packet_compact/.render_fragment_compact/
PROMPT_TEMPLATE_VERSION), R/dataset_description.R (the existing global-context object whose
prompt slot you're joining), and R/registry.R (.tool_spec_requires/has_capability skip pattern).

Environment: no new packages; OFFLINE only; mock backend for any synthesis check (mock_backend()).
Iterate on ONE module. If something's missing, STOP and tell me.

SCOPE — Part 2 only:

1. R/orchestrator.R: new run_dataset_context(ms, dataset_tool_config, input_hash = NA_character_,
   module_method = NA_character_, validate = TRUE) — the dataset analog of run_orchestrator(), run
   ONCE per dataset. Mirror run_module()'s spec handling: list(id, params) => registry lookup +
   capability skip via .tool_spec_requires()/has_capability() with a provenance$skipped audit;
   list(fn, params) => direct. ctx here is list(ms = ms, params = spec$params,
   module_method = module_method) — NO module_id. Bundle via build_dataset_context().

2. R/prompt.R:
   - render_dataset_context_compact(dataset_context, max_findings = 8) — mirror
     render_packet_compact()/.render_fragment_compact(); render each dataset_fragment's
     compact_summary + top_findings + caveats as a `DATASET CONTEXT` block. NEVER render result tables.
   - build_user_prompt(): add dataset_context = NULL param. Render the block AFTER
     render_dataset_description() and BEFORE render_packet_compact(). NULL => omit entirely
     (backward compatible).
   - build_system_prompt(): add one rule — treat the DATASET CONTEXT block as global framing /
     confounder awareness; do NOT cite it as a per-module fragment.
   - Bump PROMPT_TEMPLATE_VERSION.

3. R/orchestrator.R synthesis path: add dataset_context = NULL to synthesize_module() and
   run_synthesis_orchestrator(), threaded into build_user_prompt(). In the batch orchestrator,
   accept one dataset_context and pass the SAME object to every module. DO NOT touch
   calculate_fusion_score(), fuse_confidence(), or enforce_faithfulness() — the dataset_context
   never enters fusion or faithfulness.

4. tests/testthat/test-dataset_orchestrator.R (offline): run_dataset_context() builds a valid
   context (use a trivial hand-built dataset_fragment or a fn=identity-style stub since no real
   tool exists yet); build_user_prompt(dataset_context=dc) emits the block in the right position;
   build_user_prompt(dataset_context=NULL) is unchanged; synthesize_module() threads it on the
   mock backend for one module. Confirm existing prompt/synthesis tests still pass.

Non-negotiables as in Part 1 (no new deps, contract-only deps, offline, roxygen + document(),
R CMD check clean, STYLE.md exactly, CLAUDE.md commit rules). Note the PROMPT_TEMPLATE_VERSION
bump in the commit body.

Start by restating run_dataset_context()'s signature, the build_user_prompt() change, and where
exactly the DATASET CONTEXT block lands in the rendered prompt; confirm before writing. Check in
once run_dataset_context() + the prompt block are wired and the suite is green.
```

---

## Part 3 — `dataset_composition_tool` (compute path, flagship tool)

```
You're implementing Part 3 of the dataset-tools milestone for `llegir` (installed R package,
conda env `hdWGCNA`). Parts 1 (contracts) and 2 (orchestration + prompt injection) are DONE.
Part 3 is the first real dataset tool: a cell-state census + covariate-balance summary that
catches compositional confounding.

Read first: docs/milestones/milestone_dataset_tools.md (Part 3), then CLAUDE.md, STYLE.md,
R/dataset_fragment.R (the contract you emit), R/tool_cluster_dme.R (the closest existing tool —
copy its capability-gated graceful-skip pattern and its use of metadata()/grouping), R/moduleset.R
(the generics: metadata(), capabilities()/has_capability(), ms$data_level, ms$aggregated),
R/registry.R (.onLoad core registration + the scope='dataset' field from Part 1), and
R/orchestrator.R::run_dataset_context (how ctx is shaped — list(ms, params, module_method),
NO module_id).

Environment: no new packages (base R + already-present deps); OFFLINE; iterate on the example
moduleset (llegir_example_moduleset()). If something's missing, STOP and tell me.

SCOPE — Part 3 only:

1. New R/dataset_tools.R (home for all compute dataset tools) with dataset_composition_tool(ctx):
   - Consumes metadata(ms) ONLY, plus ctx$params$group_col (cell-state/cluster column) and
     ctx$params$condition_col (optional). Capability-gate on 'grouping'; on absence, message + return
     NULL (graceful skip, mirror cluster_dme_tool). No hdWGCNA/Seurat.
   - result (tidy df): n cells per group_col level; proportion of each group within each
     condition_col level; the group x condition cross-tab; a skew statistic (Shannon entropy of the
     group distribution, and/or chi-square standardized residuals flagging over/under-represented
     cells); samples-per-condition count when has_capability(ms,'sample_ids').
   - caveats: 'cell_state_imbalanced_across_condition' when residuals exceed a threshold;
     'underpowered_contrast' when a condition has fewer than N samples/cells (pick a sane default,
     make it a param).
   - compact_summary self-describes the unit via ms$data_level/ms$aggregated (e.g. "across 12,431
     cells" vs "8 pseudobulk samples"). top_findings: the most over/under-represented cell states.
   - Emit via dataset_fragment(type='composition_summary', ...), provenance via make_provenance()
     (source defaults 'computed').

2. Register in .onLoad() (R/registry.R): register_tool('composition', dataset_composition_tool,
   type='composition_summary', description=..., requires='grouping', scope='dataset').

3. tests/testthat/test-dataset_composition.R (offline): valid composition_summary fragment from the
   example moduleset; graceful skip when grouping absent; caveats fire correctly on a small
   imbalanced fixture (build one where a cell state is skewed across conditions).

Non-negotiables as before (no new deps, contract/ModuleSet-only deps, offline, roxygen +
document(), R CMD check clean, STYLE.md exactly, CLAUDE.md commit rules).

Start by restating dataset_composition_tool()'s params, the exact columns of its result df, and the
caveat thresholds; confirm before writing. Run devtools::test() and report before committing.
```

---

## Part 4 — composition **import** path (miloR / propeller / sccomp)

```
You're implementing Part 4 of the dataset-tools milestone for `llegir` (installed R package,
conda env `hdWGCNA`). Parts 1-3 are DONE. Part 4 adds the COMMON real-world path: the user brings
their own differential-abundance result (miloR/propeller/sccomp) and we normalize it into a
composition_summary dataset_fragment — the dataset analog of the existing evidence-fragment
importers.

Read first: docs/milestones/milestone_dataset_tools.md (Part 4), then CLAUDE.md, STYLE.md,
R/import_fragment.R (your REFERENCE — import_fragment(), import_seurat_markers(),
import_hdwgcna_dme(), import_enrichr(): study the format-specific column_map normalization
pattern), R/dataset_fragment.R (the target contract), and R/dataset_tools.R (Part 3's fragment
assembly, to stay consistent).

Environment: no new packages — do NOT depend on miloR itself; accept a plain data.frame the user
extracted from it. OFFLINE. If something's missing, STOP and tell me.

SCOPE — Part 4 only, all in R/import_fragment.R:

1. import_dataset_fragment(type, result, fragment_id = NULL, tool_id = 'import_dataset_fragment',
   params = list(), source_file = NULL) — generic dataset analog of import_fragment(): wraps a tidy
   user table into a dataset_fragment with provenance$source = 'user_supplied'. Mirror
   import_fragment()'s structure.

2. import_milo_da(result, column_map = list(), ...) — normalize a miloR::DAtesting neighborhood
   table (default columns: logFC, SpatialFDR, plus a cell-type annotation column) into a
   composition_summary dataset_fragment: summarize which cell states shift in abundance and their
   direction; set caveats where warranted (e.g. cell_state_imbalanced_across_condition). Default
   column_map handles miloR names; overridable, exactly like import_seurat_markers.

3. tests/testthat/test-import_dataset_fragment.R (offline): import_milo_da() on a small synthetic
   miloR-shaped table yields a valid composition_summary fragment with source='user_supplied';
   column_map override works; the second format normalizes too.

Non-negotiables as before. Note: these importers plug into dataset_tool_config as
list(fn=..., params=...) or are built directly and passed to build_dataset_context() — verify one
such wiring in the test.

Start by restating import_milo_da()'s default column_map and the fragment fields it populates;
confirm before writing. Run devtools::test() and report before committing.
```

---

## Part 5 — `dataset_variance_structure_tool` (recycle `PCRegression`)

```
You're implementing Part 5 of the dataset-tools milestone for `llegir` (installed R package,
conda env `hdWGCNA`). Parts 1-4 are DONE. Part 5 quantifies how much of the dataset's variance
aligns with each metadata covariate (condition vs batch vs depth) via principal-component
regression — the trust prior for every downstream cross_condition_delta.

Read first: docs/milestones/milestone_dataset_tools.md (Part 5 AND its "Recycled code pointers"
section), then CLAUDE.md, STYLE.md, and CRITICALLY the code you are recycling:
  - sample_code/pseudobulk_functions.R:762  PCRegression()  — port the MULTI-COVARIATE branch
    (lines ~900-936): per covariate x PC, lm(pc_scores ~ covariate), extract summary()$r.squared /
    adj.r.squared and anova()$`Pr(>F)`[1], rbind into data.frame(component, covariate, R2, adj_R2,
    pval), then p.adjust(method='BH'). STRIP all the SummarizedExperiment guard clauses and the
    metadata(se)[[reduction_name]] slot writes — llegir has no SE metadata slots. Skip the
    single-covariate "level mode" branch entirely.
  - sample_code/pseudobulk_functions.R:436  PseudobulkPCA()  — port the prcomp(t(X),
    rank.=n_components, scale=TRUE) call + pca_var <- sdev^2/sum(sdev^2); drop the SE assay plumbing.
  - sample_code/TCGA_predictions_clean.Rmd:191  — shows the call + the resulting regression table
    shape (component, covariate, R2, adj_R2, pval, fdr); THAT table IS this fragment's result.
Then read R/dataset_tools.R (Part 3, where this tool lives), R/dataset_fragment.R (the contract),
R/moduleset.R (pseudobulk_view(), expression(), module_scores(), metadata(), capabilities()), and
R/tool_differential_module_activity.R (how existing tools resolve pseudobulk_view() and skip).

DEPENDS ON the pseudo-bulk milestone (pseudobulk_view()) — confirm it exists in R/moduleset.R
before starting; if not, STOP and tell me.

Environment: base R only for the regression (lm/anova/prcomp/p.adjust — no new deps); OFFLINE.

SCOPE — Part 5 only:

1. In R/dataset_tools.R, dataset_variance_structure_tool(ctx):
   - Resolve pseudobulk_view(ms); NULL => graceful skip. Run on the pseudo-bulk expression matrix
     (closest to PCRegression's original use; module_scores(pb_view) is an acceptable alternative —
     pick and justify).
   - Internal helper .pc_regression(embedding, meta_df, covariates) = the ported multi-covariate loop
     above. Compute embedding with the ported prcomp call (top ctx$params$n_components, sane default).
   - ctx$params$covariates names the metadata columns to regress. result = the tidy regression table;
     top_findings = covariate/PC pairs with highest adj_R2 at fdr < 0.05.
   - caveat 'condition_confounded_with_batch' when a technical covariate (batch/nCount/depth) explains
     a top PC with higher adj_R2 than the biological condition does.
   - Emit dataset_fragment(type='variance_structure', ...). Register in .onLoad() with scope='dataset',
     type='variance_structure', requires='pseudobulk' (or the right capability).

2. tests/testthat/test-dataset_variance_structure.R (offline): valid variance_structure fragment
   reusing the ported logic; graceful skip without a pseudo-bulk view; the confounding caveat fires on
   a fixture where a technical covariate dominates a top PC. Reuse/extend the synthetic pseudo-bulk
   fixture from the pseudo-bulk milestone (tests/testthat/synthetic_pseudobulk*).

Non-negotiables as before. The ported regression math must match PCRegression's multi-covariate branch
numerically — do not redesign the statistic.

Start by restating the .pc_regression() signature, which substrate you chose (expression vs
module_scores) and why, and the confounding-caveat rule; confirm before writing. Run devtools::test()
and report before committing.
```

---

## Part 6 — `dataset_baseline_expression_tool` (secondary; optional)

```
You're implementing Part 6 (final, optional) of the dataset-tools milestone for `llegir` (installed
R package, conda env `hdWGCNA`). Parts 1-5 are DONE. Part 6 adds a dataset-wide baseline/housekeeping
expression profile so the model can discount modules whose hub genes are ubiquitous signal.

Read first: docs/milestones/milestone_dataset_tools.md (Part 6), then CLAUDE.md, STYLE.md,
R/dataset_tools.R (where this tool lives, alongside Parts 3 & 5), R/dataset_fragment.R (the contract),
and R/moduleset.R (expression(), counts(), capabilities()).

Environment: base R only; OFFLINE; iterate on the example moduleset. If something's missing, STOP.

SCOPE — Part 6 only:

1. In R/dataset_tools.R, dataset_baseline_expression_tool(ctx): consume expression(ms) (+ counts(ms)
   when has_capability(ms,'counts')). result: dataset-wide mean expression, detection rate, and CV per
   gene; top-N globally dominant genes; % ribosomal (^RP[LS]) / mitochondrial (^MT-) mass; an nCount/
   depth distribution summary. Return only a SMALL summary table — never the full matrix. compact_summary
   self-describes the unit (data_level/aggregated). top_findings: the global top-N dominant genes.
   Emit dataset_fragment(type='baseline_expression', ...). Register in .onLoad() with scope='dataset',
   type='baseline_expression', requires='expression'.
   Note: do NOT set a per-module 'hub_genes_are_housekeeping' caveat here (that's a per-module judgment);
   just expose the global ubiquitous-gene list so synthesis can make that call.

2. tests/testthat/test-dataset_baseline_expression.R (offline): valid baseline_expression fragment from
   the example moduleset; graceful skip without the expression capability; ribo/mito mass computed on a
   fixture with a couple of RP*/MT- genes.

Non-negotiables as before (no new deps, contract/ModuleSet-only deps, offline, roxygen + document(),
R CMD check clean, STYLE.md exactly, CLAUDE.md commit rules).

Start by restating the columns of the result df and the ubiquitous-gene threshold; confirm before
writing. Run devtools::test() and report before committing.
```

---

## Notes

- **Order matters.** Part 1 is the keystone; Part 2 is the spine that makes Part 3+ observable end-to-end. Do not start Part 3 before 1–2 are green.
- **The frozen decision** each instance must not relitigate: dataset summaries are a sibling contract, not evidence_fragments, and they never enter fusion/faithfulness. If an instance proposes routing them through `calculate_fusion_score()`/`enforce_faithfulness()`, stop it.
- **Recycling is mandatory in Part 5** — point the instance at the exact `sample_code/` line ranges; it ports the regression, it does not reinvent it.
- Each prompt ends with a "restate the plan, confirm before writing" gate to catch drift cheaply before code is written.
- Parts 3–6 all live in one growing `R/dataset_tools.R`; later parts append, they don't rewrite earlier tools.

---

*Last updated: 2026-07-22*
