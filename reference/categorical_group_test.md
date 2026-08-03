# One-vs-rest categorical group test with an omnibus Kruskal-Wallis test

Tests `scores` against every level of `groups` (one-vs-rest,
rank-biserial effect size), plus an omnibus Kruskal-Wallis test across
all levels. Used by `cluster_dme_tool` (grouping = cell state);
reimplements the statistic behind
[`hdWGCNA::FindAllDMEs`](https://smorabit.github.io/hdWGCNA/reference/FindAllDMEs.html)
directly on
[`module_scores()`](https://smorabit.github.io/llegir/reference/module_scores.md) +
[`metadata()`](https://smorabit.github.io/llegir/reference/metadata.md)
rather than calling `FindAllDMEs()` itself, since that function needs
the Seurat object.

## Usage

``` r
categorical_group_test(scores, groups)
```

## Arguments

- scores:

  A numeric vector of module scores.

- groups:

  A vector (coercible to factor) of group labels, same length as
  `scores`.

## Value

A list with `table` (a data.frame, one row per group, strongest
association first) and `omnibus_p` (the Kruskal-Wallis p-value).
