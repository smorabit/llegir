## shared statistics helpers for categorical / continuous module-score associations.
## generic (base R only); no adapter or backend dependency, so any ModuleSet works here.

# rank-biserial correlation from a two-sample Wilcoxon: bounded in [-1, 1] and
# well-defined for signed module scores, unlike a ratio-based log2FC.
# positive = x tends higher than y. R's W statistic counts pairs where x > y,
# so W == n1*n2 (x always bigger) must map to +1, not -1.
.rank_biserial <- function(x, y){
    n1 <- length(x)
    n2 <- length(y)
    w <- suppressWarnings(stats::wilcox.test(x, y, exact = FALSE)$statistic)
    (2 * w) / (n1 * n2) - 1
}

#' One-vs-rest categorical group test with an omnibus Kruskal-Wallis test
#'
#' Tests `scores` against every level of `groups` (one-vs-rest, rank-biserial
#' effect size), plus an omnibus Kruskal-Wallis test across all levels.
#' Shared by `cluster_dme_tool` (grouping = cell state) and the categorical
#' branch of `module_by_metadata_tool` (grouping = a metadata column like
#' diagnosis). Reimplements the statistic behind `hdWGCNA::FindAllDMEs`
#' directly on [module_scores()] + [metadata()] rather than calling
#' `FindAllDMEs()` itself, since that function needs the Seurat object.
#'
#' @param scores A numeric vector of module scores.
#' @param groups A vector (coercible to factor) of group labels, same length as `scores`.
#' @return A list with `table` (a data.frame, one row per group, strongest
#'   association first) and `omnibus_p` (the Kruskal-Wallis p-value).
#' @export
categorical_group_test <- function(scores, groups){
    groups <- droplevels(as.factor(groups))
    levels_use <- levels(groups)

    kw <- suppressWarnings(stats::kruskal.test(scores ~ groups))

    per_group <- do.call(rbind, lapply(levels_use, function(g){
        in_group <- groups == g
        x <- scores[in_group]
        y <- scores[!in_group]
        p_value <- suppressWarnings(stats::wilcox.test(x, y, exact = FALSE)$p.value)
        data.frame(
            group = g,
            n = length(x),
            mean_score = mean(x),
            median_score = stats::median(x),
            rank_biserial = .rank_biserial(x, y),
            p_value = p_value
        )
    }))
    per_group$fdr <- stats::p.adjust(per_group$p_value, method = 'BH')
    per_group$direction <- ifelse(per_group$rank_biserial > 0, 'up', 'down')
    # strongest association first, so callers can just take row 1 for top_findings
    per_group <- per_group[order(-abs(per_group$rank_biserial)), ]
    rownames(per_group) <- NULL

    list(table = per_group, omnibus_p = unname(kw$p.value))
}

#' Check whether a variable is constant within every sample
#'
#' `TRUE` if `x` takes at most one distinct non-NA value within every level of
#' `sample_id` (e.g. diagnosis is constant per sample, a QC metric is not).
#' Used by `module_by_metadata_tool` to auto-select cell- vs. sample-level
#' testing so sample-level variables don't get pseudoreplicated across
#' correlated cells.
#'
#' @param x A vector to test.
#' @param sample_id A grouping vector (e.g. sample id), same length as `x`.
#' @return A single logical.
#' @export
is_sample_constant <- function(x, sample_id){
    per_sample <- tapply(x, sample_id, function(v) length(unique(v[!is.na(v)])))
    all(per_sample <= 1)
}

#' Aggregate module scores to the sample level
#'
#' Mean module score per sample (the pseudoreplication fix: test at the
#' sample level, not the cell level), plus one label per sample for
#' `group_col` when supplied (assumes `group_col` is constant within sample).
#'
#' @param scores A numeric vector of per-cell module scores.
#' @param sample_id A grouping vector (sample id), same length as `scores`.
#' @param group_col Optional categorical vector (e.g. diagnosis), same length
#'   as `scores`, assumed constant within each sample.
#' @return A data.frame with one row per sample: `sample`, `mean_score`, and
#'   `group` if `group_col` was supplied.
#' @export
aggregate_by_sample <- function(scores, sample_id, group_col = NULL){
    agg_scores <- tapply(scores, sample_id, mean)
    out <- data.frame(sample = names(agg_scores), mean_score = as.numeric(agg_scores))
    if (!is.null(group_col)) {
        agg_group <- tapply(group_col, sample_id, function(v) as.character(v[!is.na(v)][1]))
        out$group <- unname(agg_group[out$sample])
    }
    out
}

#' Pearson and Spearman correlation of module scores against a continuous variable
#'
#' Used by the continuous branch of `module_by_metadata_tool`.
#'
#' @param scores A numeric vector of module scores.
#' @param x A numeric vector, same length as `scores`.
#' @return A one-row data.frame: `n`, `pearson_r`, `pearson_p`,
#'   `spearman_rho`, `spearman_p`.
#' @export
continuous_correlation_test <- function(scores, x){
    keep <- !is.na(x) & !is.na(scores)
    scores <- scores[keep]
    x <- x[keep]
    pear <- suppressWarnings(stats::cor.test(scores, x, method = 'pearson'))
    spear <- suppressWarnings(stats::cor.test(scores, x, method = 'spearman'))
    data.frame(
        n = length(x),
        pearson_r = unname(pear$estimate),
        pearson_p = pear$p.value,
        spearman_rho = unname(spear$estimate),
        spearman_p = spear$p.value
    )
}
