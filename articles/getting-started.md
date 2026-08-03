# Getting started with llegir

*This vignette’s code chunks require a local
`data/CSF_Myeloid_hdWGCNA.rds` dev fixture (gitignored and
build-ignored, not shipped with the package) and are skipped here. The
prose below still walks through the full workflow.*

**llegir** is an R package to automate the interpretation of gene
modules in a specific context. From an input gene expression dataset
(single-cell, spatial transcriptomics, or bulk RNA-seq) and a set of
gene modules, **llegir** gathers a standardized bundle of evidence per
module using a pre-built toolbox of analysis functions, and drafts an
evidence-backed interpretation via a LLM-enabled synthesis layer.

*NOTE* this package is at an experimental development stage, and much of
the interface is subject to change.

## Setup data and define the `ModuleSet`

In this vignette, we demonstrate **llegir** using a scRNA-seq dataset of
myeloid cells from cerebrospinal fluid (CSF) cells profiled across
several CNS conditions, with co-expression modules computed by hdWGCNA.

To start the **llegir** pipeline, we first define the `ModuleSet`, which
contains the following attributes:
[`modules()`](https://smorabit.github.io/llegir/reference/modules.md),
[`gene_membership()`](https://smorabit.github.io/llegir/reference/gene_membership.md),
[`module_scores()`](https://smorabit.github.io/llegir/reference/module_scores.md),
[`expression()`](https://smorabit.github.io/llegir/reference/expression.md),
[`metadata()`](https://smorabit.github.io/llegir/reference/metadata.md),
[`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md),
[`pkg_versions()`](https://smorabit.github.io/llegir/reference/pkg_versions.md).
The function
[`hdWGCNA_ModuleSet()`](https://smorabit.github.io/llegir/reference/hdWGCNA_ModuleSet.md)
automatically formats the `ModuleSet` object for hdWGCNA results, but
this framework is flexible to modules from other packages.

``` r

library(Seurat)
library(hdWGCNA)
library(tidyverse)
library(llegir)

# load the CSF dataset, which has already been processed with hdWGCNA
seurat_obj <- readRDS('data/CSF_Myeloid_hdWGCNA.rds')

# initialize the ModuleSet 
ms <- hdWGCNA_ModuleSet(seurat_obj)
modules(ms)
```

A quick look at the two attributes most tools lean on: the ranked gene
membership of a module and the cell-level metadata.

``` r

head(gene_membership(ms, 'MM1'))
```

``` r

head(metadata(ms))
```

## Global experiment grounding

Before diving into individual modules, **llegir** first gathers global
context about the whole experiment, once, via a small toolbox of
**dataset tools** – the same kind of standardized, evidence-emitting
functions as the per-module tools below, just scoped to the whole
`ModuleSet` instead of one module.
[`dataset_composition_tool()`](https://smorabit.github.io/llegir/reference/dataset_composition_tool.md)
summarizes cell-state census and covariate balance (e.g. is one cell
state skewed across diagnosis groups?), and
[`dataset_variance_structure_tool()`](https://smorabit.github.io/llegir/reference/dataset_variance_structure_tool.md)
regresses each principal component of the pseudo-bulk expression matrix
against declared metadata covariates, so synthesis can tell whether a
module’s cross-condition signal reflects real biology or a technical
axis (batch, sequencing depth) riding the same PC.

[`run_dataset_context()`](https://smorabit.github.io/llegir/reference/run_dataset_context.md)
mirrors
[`run_orchestrator()`](https://smorabit.github.io/llegir/reference/run_orchestrator.md)
below, but runs its tool list once against the whole `ModuleSet` rather
than once per module:

``` r

dataset_tool_config <- list(
    list(fn = dataset_composition_tool, params = list(group_col = 'lv2_annot', condition_col = 'diagnosis')),
    list(fn = dataset_variance_structure_tool, params = list(
        covariates = c('diagnosis', 'nUMI'), condition_col = 'diagnosis'
    ))
)

dataset_ctx <- run_dataset_context(ms, dataset_tool_config)
dataset_ctx$dataset_fragments[[1]]$compact_summary
```

[`dataset_variance_structure_tool()`](https://smorabit.github.io/llegir/reference/dataset_variance_structure_tool.md)
needs a pseudo-bulk view of the data (see
[`pseudobulk_ModuleSet()`](https://smorabit.github.io/llegir/reference/pseudobulk_ModuleSet.md)
/
[`with_pseudobulk()`](https://smorabit.github.io/llegir/reference/with_pseudobulk.md))
to regress against, so it skips gracefully – rather than erroring – when
`ms` doesn’t carry one, as here. The resulting `dataset_ctx` is passed
into
[`run_synthesis_orchestrator()`](https://smorabit.github.io/llegir/reference/run_synthesis_orchestrator.md)
(or
[`synthesize_module()`](https://smorabit.github.io/llegir/reference/synthesize_module.md))
alongside `desc`, via `dataset_context = dataset_ctx`, injecting a
DATASET CONTEXT block into every module’s synthesis prompt (see the
`## Interpreting evidence` section below).

## Orchestrating a chain of analysis tools

Each module is characterized by running a set of analysis tools. Every
tool takes the same inputs (the `ModuleSet`, a module, and some
parameters, bundled together as `ctx`) and returns one
`evidence_fragment`: a standardized summary of what that tool found. To
demonstrate this, we run a single tool on its own to see what it
produces:

``` r

# set up the context (ctx) for the tool
ctx <- list(ms = ms, module_id = 'MM1', params = list(n_hubs = 10))

# run the top genes tool to get the top 10 genes by membership
top_frag <- top_genes_tool(ctx)

# sanity check:
validate_evidence_fragment(top_frag)

# show the result
top_frag$compact_summary
```

**llegir** ships several pre-built analysis tools:

- [`top_genes_tool()`](https://smorabit.github.io/llegir/reference/top_genes_tool.md):
  top genes by kME
- [`cluster_dme_tool()`](https://smorabit.github.io/llegir/reference/cluster_dme_tool.md):
  differential module expression across clusters
- [`geneset_enrichment_tool()`](https://smorabit.github.io/llegir/reference/geneset_enrichment_tool.md):
  GO/pathway enrichment
- [`signature_correlation_tool()`](https://smorabit.github.io/llegir/reference/signature_correlation_tool.md):
  co-variation with a signature library

Additionally, external results you have already computed elsewhere can
be leveraged the same way via
[`import_fragment()`](https://smorabit.github.io/llegir/reference/import_fragment.md).

We run a chain of tools over the module set using
[`run_orchestrator()`](https://smorabit.github.io/llegir/reference/run_orchestrator.md),
which then collects the results into one **evidence packet** per module,
saved as a JSON file. The tool list pairs each tool (`fn`) with its
parameters, and `modules_use` limits the run to three modules for this
example:

``` r

modules_use <- c('MM1', 'MM2', 'MM3')

tool_config <- list(
    list(fn = top_genes_tool, params = list(n_hubs = 25)),
    list(fn = cluster_dme_tool, params = list(group_by = 'lv2_annot')),
    list(fn = geneset_enrichment_tool, params = list(
        n_hubs = 25,
        db_files = c(
            GO_BP = 'data/GO_Biological_Process_2026.txt',
            Hallmark = 'data/h.all.v2026.1.Hs.symbols.gmt'
        )
    ))
)

packets <- run_orchestrator(ms, tool_config, output_dir = 'output/evidence_packets', modules_use = modules_use)
```

Each packet holds its evidence fragments plus a `packet_hash`, a
fingerprint of the evidence it contains. The same evidence always
produces the same hash, which makes runs easy to track and reproduce.

``` r

packet <- packets[['MM1']]
packet$packet_hash
length(packet$fragments)
```

## Provide dataset context

Before interpreting the modules, we provide a brief description of the
dataset
[`dataset_description()`](https://smorabit.github.io/llegir/reference/dataset_description.md).
This biological context is given to the model so it interprets each
module in an appropriate setting (the same gene program can mean
something different in CSF myeloid cells than in a solid tumor). It is
required: **llegir** will not run synthesis without it.

``` r

desc <- dataset_description(
    species = 'human',
    tissue = 'cerebrospinal fluid (CSF)',
    cell_compartment = 'myeloid cells',
    assay = 'single-cell RNA-seq (10x)',
    conditions = c(
        'Glioblastoma', 'Brain Metastasis', 'Primary CNS lymphoma',
        'Secondary CNS lymphoma', 'Inflammatory / other neuroinflammatory'
    ),
    notes = 'Modules are CSF-myeloid co-expression programs; interpret in a CNS-myeloid, neuro-oncology / neuroinflammation context.'
)
cat(render_dataset_description(desc))
```

## Interpreting evidence

[`run_synthesis_orchestrator()`](https://smorabit.github.io/llegir/reference/run_synthesis_orchestrator.md)
turns the evidence packets into written interpretations. Each module’s
evidence packet is sent to a user-specified LLM, checks that every claim
is actually backed by the evidence
([`enforce_faithfulness()`](https://smorabit.github.io/llegir/reference/enforce_faithfulness.md)),
and combines the model’s confidence with the evidence-based confidence
([`fuse_confidence()`](https://smorabit.github.io/llegir/reference/fuse_confidence.md)).
It saves an interpretation and a readable Markdown paragraph per module,
plus a `review_queue.tsv` and `manifest.json` for the whole run.

The language model’s role is deliberately limited: it only ever sees the
summarized evidence, never the raw data tables, and it never runs any
analysis itself.

You can use different model providers through
[`resolve_backend()`](https://smorabit.github.io/llegir/reference/resolve_backend.md)
(here `'github'`; `'gemini'` also works), which reads your API key from
the environment (e.g. `GITHUB_PAT` or `GEMINI_API_KEY`). Wrapping it in
[`cached_backend()`](https://smorabit.github.io/llegir/reference/cached_backend.md)
saves each result to disk, so re-running synthesis on unchanged packets
doesn’t spend another API call.

``` r

backend <- cached_backend(
    resolve_backend('github'),
    provider = 'github',
    model = 'gpt-4o-mini',
    prompt_template_version = PROMPT_TEMPLATE_VERSION
)

interps <- run_synthesis_orchestrator(
    packets, desc, backend = backend, output_dir = 'output/interpretations', dataset_context = dataset_ctx
)
```

Inspect one interpretation: its proposed label, fused confidence, and
the rendered paragraph.

``` r

interp <- interps[['MM1']]
interp$proposed_label
interp$confidence$score
cat(render_paragraph(interp))
```

The review queue
([`build_review_queue()`](https://smorabit.github.io/llegir/reference/build_review_queue.md))
collects only the interpretations flagged for a closer look
([`needs_review()`](https://smorabit.github.io/llegir/reference/needs_review.md)),
sorted lowest-confidence first, so you know which modules to check by
hand:

``` r

build_review_queue(interps)
```
