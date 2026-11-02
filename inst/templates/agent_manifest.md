---
{{{front_matter}}}---

# llegir Agent Workspace Manifest

This file is a static launchpad, not a runtime: `llegir` wrote it once from a
completed run and will not update it as you work. Read every section below
before running anything -- it tells you what you may touch, how, and where
the reduced/summarized views of the data already live so you never have to
reach for a raw matrix yourself.

## 1. Mission & Guardrails

You are a terminal coding agent working against a completed `llegir`
analysis run. {{#label_mode}}Four{{/label_mode}}{{^label_mode}}Three{{/label_mode}} rules govern every action you take in this workspace:

1. **Read through the adapter, never the backend.** Touch data only through
   `ModuleSet` generics (`modules()`, `gene_membership()`, `module_scores()`,
   `expression()`, `metadata()`, `capabilities()`, ...) -- never `hdWGCNA` or
   `Seurat` directly. The adapter is the entire contract; nothing else is
   guaranteed stable.
2. **Summaries cross the context boundary, matrices never do.** Every worked
   example in this manifest returns a tidy table or a fragment digest, never
   a raw genes-by-cells matrix. Never print, `head()`-dump, or return a full
   expression/counts matrix into your own context.
3. **Inspect, don't mutate.** The loaded `ModuleSet` / dataset context /
   packets are immutable. Work in a fresh `R --vanilla` / `Rscript` process,
   never a live graphical or `Seurat` session, and write any derived output
   to `scratch/` -- never back over `artifacts/`.
{{#label_mode}}
4. **Labelling mode: your deliverables go to `labels/` and `queries/`.**
   This workspace was exported with `mode = 'label'`: you are commissioned to
   label the modules of this ONE network, following the Labeling Task below.
   `labels/`, `queries/` and `scratch/` are the only directories you may
   write to; rules 1-3 still hold for everything else. Do not compare with,
   or reconcile against, other networks.

## Labeling Task

{{#label_refine}}
**Refine the draft labels.** Every module already has a draft interpretation
in `artifacts/interpretations/<module_id>.json`. Treat each one as a
hypothesis to test, not as ground truth: run the full protocol below on every
module as if no draft existed, then keep, revise or replace the draft label.
Write the result for every module, changed or not, to
`labels/<module_id>.json`.
{{/label_refine}}
{{^label_refine}}
**Label every module.** No interpretations exist yet for this run. Write one
for each of the {{n_modules}} modules in `module_ids` to
`labels/<module_id>.json`.
{{/label_refine}}

Give every module the same depth of treatment; none is more important than
another.

**Deliverables, per module.**

- `labels/<module_id>.json`, filling
  `artifacts/interpretation_model_output.schema.json`: the model-facing
  schema llegir's synthesis step asks an LLM to fill, plus a required
  `review` block (below). `module_id` inside the file must match its
  filename. Leave `literature` as an empty array; do not add `provenance`,
  `schema_version` or `confidence.model_score` (llegir attaches those).
- `labels/notes/<module_id>.md`: your working notes for the module, in the
  order of the protocol: the artifact screen, the hubs you weighed, each
  query you ran and what it returned, the expected markers and their status,
  the alternative label and why you rejected it. Each query you describe must
  cite the script that produced it by relative path
  (`queries/<module_id>/<NN>_<slug>.R`) and give the exact command used to
  run it, so a reader can re-execute it; prose summaries alone are not
  sufficient.
- `queries/<module_id>/`: every script you ran for the module, with its
  captured output (see section 8).

**Evidence.** Start each module from `artifacts/label_evidence/<module_id>.md`:
its evidence packet as the synthesis model sees it, followed by an
`[artifact_screen]` block llegir computed for the gate below (the synthesis
model never sees the screen; its fields are documented at the end of section
3). Read it with the Dataset Grounding in section 3. You may go deeper
through the `ModuleSet` and tools (sections 4-6), for example the full
ranked gene list or whether a gene belongs to any module in this network,
but every `supporting_claims` entry must still cite `fragment_id`s that
exist in that module's packet, with the direction that fragment reports. Do
not assert facts from the literature: claims rest on this workspace's
evidence plus the identity of well-known genes.

**Refinement protocol.** Run these steps in order for every module.

1. **Artifact gate, before any biology.** Check the `[artifact_screen]` block
   and the hub list for technical signatures:
   - an immediate-early / heat-shock dissociation-stress signature: the
     screen's `dissociation_stress` line meets its threshold when at least
     {{stress_min_hubs}} of the top {{support_rank}} hubs are among the
     screened genes ({{stress_genes}});
   - the module eigengene tracking sequencing depth: the screen's
     `depth_correlation` line meets its threshold when |Spearman rho| >=
     {{depth_min_rho}} against any depth column, which indicates a global
     expression-output axis rather than one program. Qualitatively, glycolytic
     AND OXPHOS hubs together in the same top-{{support_rank}} list support
     this reading; either family alone does not, since a genuine respiration
     module will have OXPHOS and ribosomal hubs together.

   When a threshold is met, `review.artifact_gate.status` may not be `pass`.
   A module whose signal is clearly technical gets a technical label (for
   example "Immediate-early / heat-shock stress response, likely
   dissociation"), with `review.artifact_gate.status` = `technical`,
   `review.evidence_tier` = `technical_artifact` and the `possible_artifact`
   flag. Use `uncertain` when the signal is partial or competes with a
   biological reading, and say so in the label or flags. Read each gene's
   role with its sign: a growth-arrest or anti-proliferative gene is not
   evidence for a proliferation or cell-cycle program.
2. **Evidence hierarchy.** Hub genes ranked by kME are the primary evidence
   and carry the call (`review.evidence_tier` = `hub_genes`). GO / gene-set
   enrichment is secondary: it may carry the call only when the hub genes are
   uninformative (`geneset_enrichment`), and never against them. CancerSEA
   (overlap or correlation) is corroboration only and may never be the sole or
   main basis for a label.
3. **Use the top of the hub list, not the module's bulk.** Every supporting
   hub must be among the module's top {{support_rank}} hubs by kME, and at
   least one must come from the top {{display_rank}}. A large module overlaps
   some gene set whatever it does, so a whole-module enrichment count is not
   evidence of identity on its own. Several paralogs or family members (e.g.
   a run of keratins or histone genes) lighting up one GO branch are one line
   of evidence, not several.
4. **Falsification.** Name at least {{min_markers}} canonical markers the
   proposed label implies, obligate partners included (for example, a type I
   interferon label implies STAT1, IRF9 and several ISGs; an EMT label implies
   VIM, ZEB1/2 or SNAI2). Check each marker's status against this module, the
   rest of the network, and the input feature set, and record it in
   `review.expected_markers`: `in_module` (assigned to this module),
   `in_network` (assigned to another module of this network), `unassigned`
   (in the input feature set but in no module), or `not_tested` (not in the
   input feature set at all). Only `unassigned` or `in_network` is evidence
   about the module's identity; `not_tested` is evidence about the pipeline,
   not the biology, and must never be cited against a label. {{#has_feature_genes}}The input
   feature set is `artifacts/feature_genes.txt`.{{/has_feature_genes}}{{^has_feature_genes}}This
   workspace ships no input feature set, so a gene in no module cannot be
   placed; say so rather than guessing.{{/has_feature_genes}} State the status
   you found for every marker. If obligate partners are `unassigned` or
   `in_network`, reject or downgrade the label.
5. **Alternative.** Name the strongest alternative label and why you rejected
   it (`review.alternative_label`). Record the evidence against your label in
   `review.contradicting_evidence`.
6. **Anchored confidence.** Pick `review.confidence_level` and set
   `confidence.score` inside its band:
   - `high` (0.75-0.95): the gate passes; several top hubs are canonical for
     the program; its expected markers are largely `in_module`; a secondary
     tier agrees; nothing contradicts.
   - `moderate` (0.5-0.75): clear hub support, but some expected markers sit
     elsewhere or are unassigned, secondary evidence is weak, or a plausible
     alternative remains.
   - `low` (0.25-0.5): the label rests on a minority of hubs or on secondary
     evidence, or key markers sit elsewhere or are unassigned.
   - `very_low` (0-0.25): a technical label, insufficient evidence, or hubs
     with no coherent program.

   Scores should spread across modules; they are not a default 0.8.

   Sample concentration is not a technical signature: a malignant program
   carried largely by one patient is expected in this compartment and keeps
   its biological label. It constrains generalizability, not validity. When
   the screen's `sample_concentration` line meets its threshold (at least
   {{sample_share_pct}}% of top-decile cells from one sample), cap
   `confidence_level` at `moderate`, add the `label_low_specificity` flag, and
   say so in `confidence.rationale`.
7. **Display hubs.** Pick exactly 3 `review.display_hubs` for figure
   annotation: from the top {{display_rank}} hubs by kME, the three most
   congruent with the label, spanning both halves when the label names two
   processes. Avoid housekeeping normalizers ({{display_excluded}}); if one is
   genuinely the module's biology (e.g. a ubiquitin gene in a proteostasis
   module), you may keep it by giving the reason in
   `review.display_hub_overrides`. Never spend two slots on one gene family
   (e.g. two keratins or two RPL genes).
8. **Unique labels.** After every module is labelled, re-read all labels: no
   two modules in this network may carry the same `proposed_label`. Where two
   collide, sharpen both from their hubs (or conclude one is the weaker,
   technical version of the other). Where two modules genuinely capture the
   same program, do not invent a distinction. Label them honestly and record
   the relationship in `review.related_module`
   (`{"module_id": ..., "relationship": "overlapping program" | "weaker partial version" | "technical counterpart"}`),
   then differentiate the labels only by what their hubs actually support
   (e.g. a qualifier naming the distinguishing hub genes); a shared label is
   accepted when `review.related_module` links the pair.

**Labeling rules.** Identical to llegir's synthesis prompt (template version
{{prompt_template_version}}). The protocol above supersedes these rules on
ordering and on tool use. The quoted "FIRST STEP" is the first INTERPRETIVE
step, taken after the artifact gate. "Do not run or imagine any analysis" is
relaxed here: read-only queries through the ModuleSet and the tools in
sections 4-6 are permitted and encouraged to check a call, but may never
introduce a claim that no fragment in the module's packet supports. "The
evidence given below" means the module's
`artifacts/label_evidence/<module_id>.md` plus the Dataset Grounding in
section 3.

{{{labeling_rules}}}

**Validate before you finish.** Run `Rscript validate_labels.R`. It replays
every `labels/<module_id>.json` through llegir's synthesis post-processing
(schema validation, citation and direction faithfulness, the
significance-wording check) and checks the `review` block against the
`ModuleSet` and the artifact screen: supporting hubs must be
top-{{support_rank}} hubs with the kME you state and at least one from the
top {{display_rank}}; at least {{min_markers}} expected markers, each with its
true status; display hubs must follow step 7; the score must sit in its band;
a technical gate must match the tier and flag; the gate and confidence must
respect the screen's thresholds; the notes file must exist and cite every
script in `queries/<module_id>/`, each with its `.out`; and no label may
repeat unless `review.related_module` links the pair. It writes
`scratch/label_validation.tsv` with one row per module (`ok`, `missing`,
`invalid`, `unfaithful`, `needs_revision`, `unexpected`). Fix every row that
is not `ok` and re-run until all {{n_modules}} modules are `ok`. Do not edit
`validate_labels.R`.

**Shape of one label file** (illustrative values):

```json
{
  "module_id": "<module_id>",
  "proposed_label": "Type I interferon response",
  "dominant_biology": "Type I interferon signalling",
  "interpretation": "The top hubs (IFIT1, ISG15, MX1) are interferon-stimulated genes ... (1 to 3 sentences, grounded in the cited fragments).",
  "supporting_claims": [
    {"claim": "The top hubs IFIT1, ISG15 and MX1 are interferon-stimulated genes.", "fragment_ids": ["top_genes"], "direction": "na"}
  ],
  "literature": [],
  "flags": [],
  "confidence": {"score": 0.8, "rationale": "Why this label, and what would change it."},
  "review": {
    "evidence_tier": "hub_genes",
    "artifact_gate": {"status": "pass", "reasons": "no screen threshold met; hubs are not generic high-expressers"},
    "supporting_hubs": [{"gene": "IFIT1", "kme": 0.61}, {"gene": "ISG15", "kme": 0.58}, {"gene": "MX1", "kme": 0.55}],
    "expected_markers": [{"gene": "STAT1", "status": "in_module"}, {"gene": "IRF9", "status": "in_network"}, {"gene": "OAS1", "status": "not_tested"}],
    "contradicting_evidence": "IRF9 sits in another module; no significant GO term.",
    "alternative_label": {"label": "Antiviral / inflammatory response", "reason_rejected": "no NF-kB or cytokine genes among the top hubs"},
    "confidence_level": "high",
    "display_hubs": ["IFIT1", "ISG15", "MX1"]
  }
}
```

`review.display_hub_overrides` (`[{"gene": ..., "reason": ...}]`) and
`review.related_module` are optional; add them only when steps 7 or 8 call
for them.
{{/label_mode}}

## 2. Data Topography

Every artifact this workspace ships, resolved at export time. The
`ModuleSet` is serialized twice -- `moduleset_lite.qs2` (load this by
default) and `moduleset_full.qs2` (only for an `expression()`/`counts()`
query) -- so read the `moduleset_lite` row's note before reaching for the
full object:

{{{topography_block}}}

`workspace_root` in the front matter above is this workspace's absolute
path; every relative path in this table is resolvable against it.

{{#interpretations_missing}}
**No interpretations shipped with this run.** `artifacts/interpretations.qs2`
does not exist. Do not invent or mock-synthesize a `proposed_label`,
`dominant_biology`, or any other `interpretation` field for a module --
treat this workspace as evidence-only (fragments/packets), not narrative.
{{/interpretations_missing}}

## 3. Dataset Grounding

The same compact grounding the synthesis model itself was given for this
run -- one source of truth, reused verbatim, never a divergent second
rendering:

{{{desc_block}}}

{{{context_block}}}
{{#label_mode}}

### The `[artifact_screen]` block (label mode)

llegir appends this block to every `artifacts/label_evidence/<module_id>.md`.
It is deterministic, computed from this workspace's `ModuleSet`, and is not an
evidence fragment: use it for the artifact gate and confidence, never cite it
in `supporting_claims`. `validate_labels.R` recomputes it and enforces the
thresholds below. Lines appear only when the data to compute them exists.

| field | meaning | threshold, and what meeting it requires |
|---|---|---|
| `module_size` | number of genes assigned to the module | none (context for step 3) |
| `dissociation_stress` | how many of the top {{support_rank}} hubs (and of the whole module) are among the screened immediate-early / heat-shock genes | at least {{stress_min_hubs}} of the top {{support_rank}}: the gate may not be `pass` |
| `depth_correlation` | Spearman rho across cells between the module score and each sequencing-depth column | \|rho\| >= {{depth_min_rho}} for any column: the gate may not be `pass` |
| `sample_concentration` | share of the module's top-decile cells (by module score) coming from its single most frequent sample, out of all samples | at least {{sample_share_pct}}%: keep the biological label, cap `confidence_level` at `moderate`, add `label_low_specificity` |
{{/label_mode}}

## 4. The ModuleSet API Cheat-Sheet

Worked getter examples for this run's `ModuleSet`, emitted only for the
capabilities it actually reports (see `capabilities` in the front matter
above):

{{#api_cheatsheet}}
- `{{{call}}}` -- {{{note}}}
{{/api_cheatsheet}}

## 5. The Tool Registry Cheat-Sheet

Every tool registered in the live registry at export time, including any
custom `register_tool()` call -- this table is generated, never
hand-maintained, so a workspace exported after you register a new tool
documents it with no manual step. A `requires` entry tagged `(full object
only)` needs a capability `moduleset_lite.qs2` dropped (always
`expression`/`counts`); load `moduleset_full.qs2` instead for that row.
`fusion_tier` is the weight llegir's (currently shelved) confidence fusion
gives a tool's output; it is not an evidence hierarchy and says nothing about
how much a fragment should count toward a label:

| id | scope | fusion_tier | type | requires | runnable here | invocation |
|---|---|---|---|---|---|---|
{{#tool_cheatsheet}}
| `{{{id}}}` | {{{scope}}} | {{{tier}}} | {{{type}}} | {{{requires}}} | {{{runnable}}} | `{{{invocation}}}` |
{{/tool_cheatsheet}}

## 6. Safe Interrogation Recipes

> Never print, `head()`-dump, or return a full expression/counts matrix.
> Matrices stay inside R; only tidy summaries (a few hundred rows at most)
> cross into your context.

Cheapest to heaviest; each rung below is emitted only when this run's
`ModuleSet` reports the capability it needs.

{{#recipes}}
### {{{title}}}

```r
{{{code}}}
```

{{{note}}}

{{/recipes}}

## 7. Contract Reference

Every tool result you touch is one of three record types. Read only the
fields below -- `result` (when present) is the full backing table and is not
meant to cross into your context; `compact_summary` / `top_findings` are the
token-efficient digest built for exactly that purpose.

### `evidence_fragment` (per-module tool output)

| field | meaning |
|---|---|
| `fragment_id` | unique id of this fragment within its packet |
| `tool_id` | id of the tool that produced it |
| `module_id` | which module this fragment describes |
| `type` | controlled-vocabulary fragment type, e.g. `ranked_genes`, `state_expression` |
| `result` | full backing table -- do not print into your context |
| `compact_summary` | one-paragraph token-efficient digest |
| `top_findings` | a few salient rows, structured |
| `effect_strength` | magnitude of the finding, tool-defined scale |
| `significance` | p-value or analogous statistic, if applicable |
| `direction` | `up` / `down` / `na` |
| `provenance` | tool version, params, input hashes, package versions, timestamp |

### `dataset_fragment` (once-per-dataset tool output)

| field | meaning |
|---|---|
| `fragment_id` | unique id of this fragment within the dataset context |
| `tool_id` | id of the tool that produced it |
| `type` | controlled-vocabulary type, e.g. `composition_summary`, `variance_structure` |
| `result` | full backing table -- do not print into your context |
| `compact_summary` | one-paragraph token-efficient digest |
| `top_findings` | a few salient rows, structured |
| `caveats` | data-quality or confounding flags raised by the tool |
| `provenance` | tool version, params, input hashes, package versions, timestamp |

### `interpretation` (synthesized narrative, if this run produced any)

| field | meaning |
|---|---|
| `module_id` | which module this interpretation describes |
| `proposed_label` | short human-readable label for the module |
| `one_line_summary` | one-sentence summary |
| `dominant_biology` | the dominant biological theme, in prose |
| `supporting_claims` | claims tied back to specific evidence fragments |
| `cell_state` / `condition_dynamics` | optional narrower framing, if evidenced |
| `metadata_associations` / `literature` | optional supporting associations |
| `confidence` | fused confidence score and its components |
| `flags` | faithfulness / review flags raised during synthesis |
| `provenance` | model, backend, prompt/schema versions, timestamp |
| `schema_version` | version of this contract the object was built against |

## 8. Execution Protocol

- **Prefer `Rscript query_example.R` (or `R --vanilla -f query_example.R`)
  for anything non-trivial.** A vanilla process guarantees no
  `.Rprofile`/`.RData` bleed and no accidental attach of a heavy `Seurat`
  graphics stack. Write a small `query_*.R` script, run it, read stdout.
- **Console (`R -q`) only for one-liners** -- `modules(ms)`,
  `capabilities(ms)`. Discouraged for anything that could print a matrix.
- **Never spin up plots.** No `plot()`, `DimPlot()`, `ModuleFeaturePlot()`,
  or anything opening a graphics device. If a visual is unavoidable, write to
  a file device (`ragg::agg_png(...)`) and hand back the path.
- **Never mutate the loaded objects.** `ms`, `dctx`, `packets` are read-only
  -- no `saveRDS()` back over an artifact, no `ms$...` reassignment, no
  in-place packet overwrite. Derived results go to a new path under
  `scratch/`.
- **Corruption guard.** Because `expression()` shadows `base::expression()`,
  always namespace-qualify ambiguous getters (`llegir::expression(ms)`)
  inside scripts.
{{#label_mode}}

**Every script you run is part of the deliverable (label mode).** Write
analysis scripts to `queries/<module_id>/<NN>_<short_slug>.R` (e.g.
`queries/<module_id>/01_depth_correlation.R`), numbered in the order you ran
them. Never reuse or overwrite a script name: if a query changes, write the
next number. Capture each run's stdout to the matching
`queries/<module_id>/<NN>_<short_slug>.out`, e.g.
`Rscript queries/<module_id>/01_depth_correlation.R > queries/<module_id>/01_depth_correlation.out 2>&1`,
run from the workspace root. Scripts that apply to the whole network rather
than one module go in `queries/_network/`.

`scratch/` is for intermediate data you do not need to keep (and for
`label_validation.tsv`). `queries/` is retained as the methods record and
must not be cleaned up at the end of the run.

Begin each script with the canonical bootstrap below and end it with
`sessionInfo()`, so the captured output records the environment it ran in.
{{/label_mode}}

The canonical bootstrap, shipped alongside this manifest as
`query_example.R`:

```r
suppressPackageStartupMessages(library(llegir))
options(llegir.agent_session = TRUE)

manifest <- llegir::read_agent_manifest('.llegir_agent_manifest.md')
ms       <- qs2::qs_read(manifest$artifacts$moduleset_lite)   # default -- expression()/counts() dropped
dctx     <- qs2::qs_read(manifest$artifacts$dataset_context)
packets  <- qs2::qs_read(manifest$artifacts$packets)

# fail fast if the workspace drifted from what the manifest promised
stopifnot(identical(modules(ms), manifest$module_ids))

# only load this for an expression()/counts() query -- see Data Topography
# ms_full <- qs2::qs_read(manifest$artifacts$moduleset_full)

# only present if this run synthesized interpretations -- see Data Topography
# interps <- qs2::qs_read(manifest$artifacts$interpretations)
```

`options(llegir.agent_session = TRUE)` signals read-only intent. The primary
defense is procedural -- a vanilla process plus the immutability rule above
-- not a runtime lock.

## 9. Provenance & Reproducibility

{{{provenance_block}}}

To cite a fragment faithfully, quote its `compact_summary` or
`top_findings` verbatim alongside its `tool_id` and `provenance$timestamp`
-- never paraphrase a number that appears in `result` without pulling it
from the fragment itself.
