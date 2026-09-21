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
analysis run. Three rules govern every action you take in this workspace:

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
4. **Labelling mode: your deliverable goes to `labels/`, and only there.**
   This workspace was exported with `mode = 'label'`: you are commissioned to
   write one interpretation per module, following the Labeling Task below.
   `labels/` is the only directory besides `scratch/` you may write to;
   rules 1-3 still hold for everything else.

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
  query you ran and what it returned, the expected markers you checked, the
  alternative label and why you rejected it. These notes are the module's
  methods record.

**Evidence.** Start each module from `artifacts/label_evidence/<module_id>.md`:
its evidence packet rendered exactly as the synthesis model sees it, followed
by an `[artifact_screen]` block llegir computed for the gate below. Read it
with the Dataset Grounding in section 3. You may go deeper through the
`ModuleSet` and tools (sections 4-6), for example the full ranked gene list or
whether a gene belongs to any module in this network, but every
`supporting_claims` entry must still cite `fragment_id`s that exist in that
module's packet, with the direction that fragment reports. Do not assert
facts from the literature: claims rest on this workspace's evidence plus the
identity of well-known genes.

**Refinement protocol.** Run these steps in order for every module.

1. **Artifact gate, before any biology.** Check the `[artifact_screen]` block
   and the hub list for technical signatures:
   - an immediate-early / heat-shock dissociation-stress signature among the
     top hubs (screened genes: {{stress_genes}});
   - hubs dominated by generic high-expressers (housekeeping, ribosomal,
     glycolytic and OXPHOS genes together), which suggests a global
     expression-output or depth axis rather than one program;
   - activity carried mostly by one sample, when the screen reports a
     single-sample share.

   A module that fails the gate gets a technical label (for example
   "Immediate-early / heat-shock stress response, likely dissociation"), with
   `review.artifact_gate.status` = `technical`, `review.evidence_tier` =
   `technical_artifact` and the `possible_artifact` flag. Use `uncertain` when
   the signal is partial, and say so in the label or flags. Read each gene's
   role with its sign: a growth-arrest or anti-proliferative gene is not
   evidence for a proliferation or cell-cycle program.
2. **Evidence hierarchy.** Hub genes ranked by kME are the primary evidence
   and carry the call (`review.evidence_tier` = `hub_genes`). GO / gene-set
   enrichment is secondary: it may carry the call only when the hub genes are
   uninformative (`geneset_enrichment`), and never against them. CancerSEA
   (overlap or correlation) is corroboration only and may never be the sole or
   main basis for a label.
3. **Use the top of the hub list, not the module's bulk.** Every supporting
   hub must be among the module's top {{support_rank}} hubs by kME. A large
   module overlaps some gene set whatever it does, so a whole-module
   enrichment count is not evidence of identity on its own. Several paralogs
   or family members (e.g. a run of keratins or histone genes) lighting up
   one GO branch are one line of evidence, not several.
4. **Falsification.** Name the canonical markers the proposed label implies,
   obligate partners included (for example, a type I interferon label implies
   STAT1, IRF9 and several ISGs; an EMT label implies VIM, ZEB1/2 or SNAI2),
   and check each against this module and, where it helps, the whole network:
   a partner missing from every module of the network is strong evidence
   against the label. Record each in `review.expected_markers` with `present` true or
   false. If obligate partners are absent, reject or downgrade the label.
5. **Alternative.** Name the strongest alternative label and why you rejected
   it (`review.alternative_label`). Record the evidence against your label in
   `review.contradicting_evidence`.
6. **Anchored confidence.** Pick `review.confidence_level` and set
   `confidence.score` inside its band:
   - `high` (0.75-0.95): the gate passes; several top hubs are canonical for
     the program; its expected markers are largely present; a secondary tier
     agrees; nothing contradicts.
   - `moderate` (0.5-0.75): clear hub support, but some expected markers are
     absent, secondary evidence is weak, or a plausible alternative remains.
   - `low` (0.25-0.5): the label rests on a minority of hubs or on secondary
     evidence, key markers are absent, or activity is sample-restricted.
   - `very_low` (0-0.25): a technical label, insufficient evidence, or hubs
     with no coherent program.

   Scores should spread across modules; they are not a default 0.8.
7. **Display hubs.** Pick exactly 3 `review.display_hubs` for figure
   annotation: from the top {{display_rank}} hubs by kME, the three most
   congruent with the label, spanning both halves when the label names two
   processes. Never use housekeeping normalizers ({{display_excluded}}), and
   never spend two slots on one gene family (e.g. two keratins or two RPL
   genes).
8. **Unique labels.** After every module is labelled, re-read all labels: no
   two modules in this network may carry the same `proposed_label`. Where two
   collide, sharpen both from their hubs (or conclude one is the weaker,
   technical version of the other).

**Labeling rules.** Identical to llegir's synthesis prompt (template version
{{prompt_template_version}}); they apply to you exactly as they would to the
synthesis model, alongside the protocol above:

{{{labeling_rules}}}

Two of these rules are written for a model that cannot run code. Here, "the
evidence given below" means the module's `artifacts/label_evidence/<module_id>.md`
plus the Dataset Grounding in section 3; "do not run any analysis" is relaxed
to allow read-only queries through the `ModuleSet` and tools (sections 4-6)
to check a call. Such queries may inform your label and confidence, but never
introduce a claim that no fragment in the module's packet supports.

**Validate before you finish.** Run `Rscript validate_labels.R`. It replays
every `labels/<module_id>.json` through llegir's synthesis post-processing
(schema validation, citation and direction faithfulness, the
significance-wording check) and checks the `review` block against the
`ModuleSet`: supporting hubs must be top-{{support_rank}} hubs with the kME you
state, every expected marker's `present` call must match the module, display
hubs must follow step 7, the score must sit in its band, a technical gate
must match the tier and flag, the notes file must exist, and no label may
repeat. It writes `scratch/label_validation.tsv` with one row per module
(`ok`, `missing`, `invalid`, `unfaithful`, `needs_revision`, `unexpected`).
Fix every row that is not `ok` and re-run until all {{n_modules}} modules are
`ok`. Do not edit `validate_labels.R`.

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
    "artifact_gate": {"status": "pass", "reasons": "no stress genes among the top 25 hubs; activity spread across samples"},
    "supporting_hubs": [{"gene": "IFIT1", "kme": 0.61}, {"gene": "ISG15", "kme": 0.58}, {"gene": "MX1", "kme": 0.55}],
    "expected_markers": [{"gene": "STAT1", "present": true}, {"gene": "IRF7", "present": true}, {"gene": "OAS1", "present": false}],
    "contradicting_evidence": "OAS1 absent; no significant GO term.",
    "alternative_label": {"label": "Antiviral / inflammatory response", "reason_rejected": "no NF-kB or cytokine genes among the top hubs"},
    "confidence_level": "high",
    "display_hubs": ["IFIT1", "ISG15", "MX1"]
  }
}
```
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
`expression`/`counts`); load `moduleset_full.qs2` instead for that row:

| id | scope | tier | type | requires | runnable here | invocation |
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
