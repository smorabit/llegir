# Collect an agent's labels as validated interpretations

Turns the label files from a workspace exported with
`export_agent_workspace(mode = 'label')` into `interpretation` objects
via the same pipeline as LLM synthesis
([`synthesize_module()`](https://smorabit.github.io/llegir/reference/synthesize_module.md):
validation,
[`enforce_faithfulness()`](https://smorabit.github.io/llegir/reference/enforce_faithfulness.md),
[`fuse_confidence()`](https://smorabit.github.io/llegir/reference/fuse_confidence.md)).
With `output_dir`, delegates to
[`run_synthesis_orchestrator()`](https://smorabit.github.io/llegir/reference/run_synthesis_orchestrator.md),
which also writes per-module JSON/Markdown, `review_queue.tsv` and
`manifest.json`, exactly as for an LLM run. Provenance records
`model = 'agent:<agent>'` and the current
[PROMPT_TEMPLATE_VERSION](https://smorabit.github.io/llegir/reference/PROMPT_TEMPLATE_VERSION.md),
whose rules the workspace manifest handed the agent.

## Usage

``` r
collect_agent_labels(workspace_dir, output_dir = NULL, agent = "coding-agent")
```

## Arguments

- workspace_dir:

  Path to the exported workspace.

- output_dir:

  Optional directory to write the synthesis outputs to.

- agent:

  Short name of the agent that wrote the labels.

## Value

A named list of `interpretation` objects (`NULL` for a module whose
label is missing or invalid, with a warning), invisibly when
`output_dir` is given.

## Examples

``` r
if (FALSE) { # \dontrun{
interps <- collect_agent_labels('agent_workspace', output_dir = 'interpretations', agent = 'claude-code')
} # }
```
