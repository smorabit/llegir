# Serialize a dataset context to JSON

Serialize a dataset context to JSON

## Usage

``` r
dataset_context_to_json(context, pretty = TRUE)
```

## Arguments

- context:

  A dataset context, as returned by
  [`build_dataset_context()`](https://smorabit.github.io/llegir/reference/build_dataset_context.md).

- pretty:

  Pretty-print the JSON. Default `TRUE`.

## Value

A JSON string (a `jsonlite::json` scalar).
