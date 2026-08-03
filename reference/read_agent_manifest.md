# Read an agent workspace manifest's front-matter

Parses only the YAML front-matter of a `.llegir_agent_manifest.md` file
(delimited by `---` fences) back into an R list, recovering the artifact
paths, module ids, capabilities, and workspace metadata that
[`export_agent_workspace()`](https://smorabit.github.io/llegir/reference/export_agent_workspace.md)
recorded. The inverse operation the agent bootstrap depends on.

## Usage

``` r
read_agent_manifest(path)
```

## Arguments

- path:

  Path to a `.llegir_agent_manifest.md` file.

## Value

A named list parsed from the manifest's YAML front-matter, including
`artifacts`, `module_ids`, `capabilities`, `workspace_root`,
`data_level`, and `aggregated`.
