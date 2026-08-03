# Register a tool (core or custom) in the tool registry

A tool is any `function(ctx) -> evidence_fragment` (or `NULL`, to skip;
see
[`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md)).
Registering it makes it runnable from `tool_config` by id
(`list(id = 'my_tool', params = list(...))`) and lets
[`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md)
check its required `ModuleSet`
[`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)
before calling it, skipping gracefully and recording why in the packet
if they're unmet, rather than the tool having to self-skip. See
`docs/custom_tools.md` for a worked template.

## Usage

``` r
register_tool(
  id,
  fn,
  type,
  description,
  requires = character(0),
  tier = "medium",
  scope = "module"
)
```

## Arguments

- id:

  A unique tool id, e.g. `'top_genes'` or `'my_custom_tool'`.

- fn:

  A `function(ctx) -> evidence_fragment`, where `ctx` is
  `list(ms, module_id, params)` (see
  [`run_module()`](https://smorabit.github.io/llegir/reference/run_module.md)).

- type:

  One or more of the `evidence_fragment` controlled vocabulary (see
  [`evidence_fragment()`](https://smorabit.github.io/llegir/reference/evidence_fragment.md))
  this tool may emit. Descriptive only – the fragment a tool actually
  returns is always checked against the full contract by
  [`validate_evidence_fragment()`](https://smorabit.github.io/llegir/reference/validate_evidence_fragment.md)
  regardless of what's declared here. A tool whose emitted type depends
  on its params can declare more than one.

- description:

  A one-line, human-readable description of what the tool does.

- requires:

  The `ModuleSet`
  [`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md)
  this tool needs to run: either a character vector (e.g.
  `c('grouping', 'module_scores')`), or a
  `function(params) -> character vector` for a tool whose requirement
  depends on how it's called. Default `character(0)` (no requirement).

- tier:

  Structural importance tier consulted by
  [`calculate_fusion_score()`](https://smorabit.github.io/llegir/reference/calculate_fusion_score.md)
  to weight this tool's fragments: one of `'high'`, `'medium'`, `'low'`.
  Default `'medium'`. Ignored when `scope == 'dataset'` – dataset
  fragments never enter fusion.

- scope:

  Whether this tool runs per module (default) or once per dataset: one
  of `'module'`, `'dataset'`. A `'module'` tool's `type` is checked
  against the
  [`evidence_fragment()`](https://smorabit.github.io/llegir/reference/evidence_fragment.md)
  vocabulary; a `'dataset'` tool's `type` against the
  [`dataset_fragment()`](https://smorabit.github.io/llegir/reference/dataset_fragment.md)
  vocabulary. Default `'module'`.

## Value

`id`, invisibly.

## Examples

``` r
my_tool <- function(ctx) top_genes_tool(ctx)
register_tool(
    'my_tool', my_tool, type = 'ranked_genes',
    description = 'demo', requires = character(0)
)
```
