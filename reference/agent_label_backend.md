# Backend that replays agent-written label files

A synthesis backend (see
[`mock_backend()`](https://smorabit.github.io/llegir/reference/mock_backend.md)
for the contract) whose "model output" is a JSON file an external coding
agent wrote to `labels_dir/<module_id>.json` in a workspace exported
with `export_agent_workspace(mode = 'label')`. The packet a call is for
is resolved from `packet_hash`, so this plugs into
[`synthesize_module()`](https://smorabit.github.io/llegir/reference/synthesize_module.md)
and
[`run_synthesis_orchestrator()`](https://smorabit.github.io/llegir/reference/run_synthesis_orchestrator.md)
unchanged.

## Usage

``` r
agent_label_backend(labels_dir, packets, agent = "coding-agent")
```

## Arguments

- labels_dir:

  Directory holding one `<module_id>.json` per module, each filling the
  model-facing schema
  ([`model_output_schema_json()`](https://smorabit.github.io/llegir/reference/model_output_schema_json.md)).

- packets:

  The named list of evidence packets the labels describe.

- agent:

  Short name of the agent that wrote the labels, recorded on each
  interpretation's provenance as `model = 'agent:<agent>'`.

## Value

A backend function.

## Examples

``` r
if (FALSE) { # \dontrun{
backend <- agent_label_backend('agent_workspace/labels', packets, agent = 'claude-code')
synthesize_module(packets[[1]], desc, backend)
} # }
```
