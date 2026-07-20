# Custom tools

← [Overview](overview.md) · [Schemas](schemas.md) · [Extensibility milestone](milestone_extensibility.md)

*Status: Part 2b of the extensibility milestone. `register_tool()` is the public API for adding a tool, core or custom, to the registry `run_module()`/`run_orchestrator()` consult.*

---

## When a tool is "custom"

Most new analyses are **core + config**: `signature_correlation` and `geneset_enrichment` are both general, config-driven tools that take a gene-set/signature library path as a parameter -- pointing them at a different `.gmt` is a config change, not a new tool.

Reach for a genuinely **custom** tool when the logic itself is bespoke -- a statistic, a data source, or a cross-module computation no core tool expresses generically. Two real motivating cases from SERPENTINE (not built here, noted for when they land):

- **Cross-lineage T-cell coordination.** A module's association with a *different* cell lineage's states/programs -- not expressible as "this module vs. this module's own cells," so it doesn't fit any core tool's shape.
- **TF-regulon scoring.** Correlating a module with transcription-factor regulon activity (e.g. from a regulon database) rather than an arbitrary gene signature -- the regulon inference step itself is the bespoke part.

## The `function(ctx) -> evidence_fragment` contract

Every tool, core or custom, has the same signature:

```r
my_tool <- function(ctx){
    # ctx$ms      a ModuleSet (see docs/schemas.md's adapter contract: modules(),
    #             gene_membership(), module_scores(), expression(), metadata(),
    #             pkg_versions(), capabilities())
    # ctx$module_id  the single module id this call is for
    # ctx$params     whatever was passed as params in tool_config

    # 1. Capability-gate yourself too (defense in depth -- run_module() also
    #    gates registered tools using `requires`, but a tool called directly
    #    via `fn =` has no other guard):
    if (!has_capability(ctx$ms, 'expression')) {
        message('my_tool: skipped, module set lacks the expression capability')
        return(NULL)
    }

    # 2. Do the actual (bespoke) analysis, touching only the ModuleSet
    #    adapter contract -- never a backend package (Seurat/hdWGCNA) directly.
    result <- ...  # a tidy data.frame

    # 3. Return a validated evidence_fragment (see docs/schemas.md for the
    #    full field contract and the `type` controlled vocabulary).
    evidence_fragment(
        fragment_id = 'my_tool',
        tool_id = 'my_tool',
        module_id = ctx$module_id,
        type = 'ranked_genes',   # pick from the controlled vocabulary
        result = result,
        compact_summary = '...',   # short, token-efficient digest
        top_findings = list(...),  # a few of the most salient rows
        effect_strength = ...,     # a comparable magnitude
        direction = 'na',          # 'up' / 'down' / 'mixed' / 'na'
        provenance = make_provenance(
            tool_version = '0.1',
            params = ctx$params,
            pkg_versions = pkg_versions(ctx$ms)
        )
    )
}
```

## Registering it

```r
register_tool(
    id = 'my_tool',
    fn = my_tool,
    type = 'ranked_genes',                # or a vector, if the tool's output type varies by params
    description = 'One-line description of what my_tool computes',
    requires = 'expression'               # a ModuleSet capabilities() name, a vector of them, or
                                           # function(params) -> character vector for a param-dependent
                                           # requirement
)
```

`requires` is declared once and consulted by `run_module()` before every call -- if `ctx$ms` doesn't have a required capability, the tool is skipped and the reason is recorded on the evidence packet's `provenance$skipped`, instead of the tool having to self-skip. (Step 1 above is still worth keeping for tools also called directly via `list(fn = my_tool, params = ...)`, which bypasses the registry's gate.)

Reference it from `tool_config` by id, exactly like a core tool:

```r
tool_config <- list(
    list(id = 'hub_genes', params = list(n_hubs = 25)),
    list(id = 'my_tool', params = list())
)
run_module(ms, module_id, tool_config)
```

`list(fn = ..., params = ...)` (calling a tool function directly, no registry involved) still works unchanged -- registering a tool is additive, not required.

## What you get for free

- **Uniform orchestration.** `run_module()`/`run_orchestrator()` don't distinguish core from custom tools registered this way.
- **Capability-gated graceful skips**, formalized rather than ad hoc.
- **Schema validation.** Every fragment your tool returns is checked by [`validate_evidence_fragment()`](../R/fragment.R) inside `build_evidence_packet()` -- a malformed fragment fails the module loudly rather than silently corrupting the packet.
- **Discovery.** `list_tools()` / `get_tool(id)` for introspection.

---

*Last updated: 2026-07-14.*
