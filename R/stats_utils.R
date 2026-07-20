## shared statistics helpers for categorical module-score associations.
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
#' effect size), plus an omnibus Kruskal-Wallis test across all levels. Used
#' by `cluster_dme_tool` (grouping = cell state); reimplements the statistic
#' behind `hdWGCNA::FindAllDMEs` directly on [module_scores()] + [metadata()]
#' rather than calling `FindAllDMEs()` itself, since that function needs the
#' Seurat object.
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
