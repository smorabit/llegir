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
