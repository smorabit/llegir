# Evidence tool: correlate module activity with a signature library

The co-variation sibling of
[`geneset_enrichment_tool()`](https://smorabit.github.io/llegir/reference/geneset_enrichment_tool.md):
overlap asks whether a module *contains* a signature's genes; this tool
asks whether the module's *activity* co-varies with the signature's.
Scores every signature in `ctx$params$library_files` across cells via
[`UCell::ScoreSignatures_UCell()`](https://rdrr.io/pkg/UCell/man/ScoreSignatures_UCell.html)
or
[`decoupleR::run_ulm()`](https://saezlab.github.io/decoupleR/reference/run_ulm.html)
(the same scoring
[`gene_list_ModuleSet()`](https://smorabit.github.io/llegir/reference/gene_list_ModuleSet.md)
uses), then correlates each signature's score with this module's
[`module_scores()`](https://smorabit.github.io/llegir/reference/module_scores.md).

## Usage

``` r
signature_correlation_tool(ctx)
```

## Arguments

- ctx:

  A tool context list: `list(ms, module_id, params)`, as built by
  [`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md).
  `ctx$params$library_files` (required) is a named character vector of
  local `.gmt` or `.rds` signature-library file paths, e.g.
  `c(Hallmark = 'data/h.all.v2026.1.Hs.symbols.gmt')`. An `.rds` file
  must contain a named list of character vectors (gene sets); a `.gmt`
  is read via
  [`fgsea::gmtPathways()`](https://rdrr.io/pkg/fgsea/man/gmtPathways.html).
  `ctx$params$method` is `'UCell'` (default) or `'decoupleR'`.

## Value

An `evidence_fragment` of type `'signature_correlation'`, or `NULL` if
`ctx$ms` lacks the `module_scores` or `expression` capability (see
[`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md))
– a graceful skip, not an error.

## Details

Reports Pearson *r* as descriptive co-variation at the cell level always
(never a p-value there – cells aren't independent). When
[`pseudobulk_view()`](https://smorabit.github.io/llegir/reference/pseudobulk_view.md)
resolves a pseudo-bulk view for `ctx$ms` (either `ctx$ms` is itself a
pseudo-bulk `ModuleSet`, or one is attached via
[`with_pseudobulk()`](https://smorabit.github.io/llegir/reference/with_pseudobulk.md)),
the signature library is re-scored on that view's own expression and
correlated against its own
[`module_scores()`](https://smorabit.github.io/llegir/reference/module_scores.md)
instead, with a real p-value from those independent pseudo-bulk units.
With no pseudo-bulk view available, only the descriptive cell-level *r*
is reported.

## Examples

``` r
if (FALSE) { # \dontrun{
ms <- llegir_example_moduleset()
signature_correlation_tool(list(
    ms = ms, module_id = modules(ms)[1],
    params = list(library_files = c(Hallmark = 'data/h.all.v2026.1.Hs.symbols.gmt'))
))
} # }
```
