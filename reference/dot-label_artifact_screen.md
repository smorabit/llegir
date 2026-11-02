# Artifact screen for one module (label mode)

The deterministic inputs to the label-mode artifact gate, rendered as a
text block appended to each module's `label_evidence` file: module size;
how many of the dissociation-stress (immediate-early / heat-shock) genes
sit among the top 25 hubs and in the whole module; when `depth_cols` are
available, the module score's Spearman correlation with sequencing
depth; and, when `sample_col` names a metadata column (e.g. patient),
how much of the module's top-decile activity comes from a single sample.
Each line states its threshold and whether the module meets it. Not an
evidence fragment: it informs the gate but is never cited in
`supporting_claims`.

## Usage

``` r
.label_artifact_screen(ms, module_id, sample_col = NULL, depth_cols = NULL)
```

## Arguments

- ms:

  A `ModuleSet`.

- module_id:

  The module to screen.

- sample_col:

  Optional metadata column (e.g. `'Patient'`) for the single-sample
  share. Default `NULL` skips that line.

- depth_cols:

  Optional metadata columns holding per-cell sequencing depth (e.g.
  `c('nCount_RNA', 'nFeature_RNA')`). Default `NULL` skips that line.

## Value

A single character string.
