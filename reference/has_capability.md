# Check whether a ModuleSet has a given capability

Check whether a ModuleSet has a given capability

## Usage

``` r
has_capability(ms, name)
```

## Arguments

- ms:

  A `ModuleSet` object.

- name:

  A single capability name, e.g. `'grouping'`; see
  [`capabilities()`](https://smorabit.github.io/llegir/reference/capabilities.md).

## Value

A single logical; `FALSE` if `name` isn't reported at all.
