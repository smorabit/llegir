## pseudobulk_ModuleSet: ModuleSet built from a user-supplied pseudo-bulk
## counts matrix (or SummarizedExperiment), with modules re-scored directly
## on the pseudo-bulk matrix via decoupleR -- never by averaging cell-level
## scores. Builds a components_ModuleSet under the hood, same pattern as
## gene_list_ModuleSet, with data_level = 'pseudobulk' and aggregated = TRUE.
## SummarizedExperiment is a Suggests dependency, only touched inside
## .pseudobulk_counts_from_se().
##
## Also carries the attachment API: with_pseudobulk() / pseudobulk() /
## pseudobulk_view() let a pseudo-bulk view ride alongside a cell-level
## ModuleSet without every adapter needing its own pseudobulk-aware code --
## with_pseudobulk() just prepends a decorator class so capabilities() and
## pseudobulk() pick up an override while every other generic falls through
## to the wrapped adapter's own method via NextMethod() dispatch.

# genes-by-samples CPM, log2-transformed; base-R only, no edgeR dependency --
# this normalization only feeds decoupleR scoring, not a differential test
.log_cpm <- function(counts_mat){
    lib_sizes <- colSums(counts_mat)
    cpm <- sweep(counts_mat, 2, lib_sizes, FUN = '/') * 1e6
    log2(cpm + 1)
}

# accepts either a tidy module/gene_name(/weight) data.frame or a named list
# of gene vectors, normalizing both into the tidy shape components_ModuleSet() expects
.normalize_gene_table <- function(gene_table){
    if (!is.data.frame(gene_table)) {
        gene_table <- do.call(rbind, lapply(names(gene_table), function(m){
            data.frame(module = m, gene_name = gene_table[[m]])
        }))
    }
    if (!all(c('module', 'gene_name') %in% colnames(gene_table))) {
        stop("gene_table must have 'module' and 'gene_name' columns")
    }
    gene_table
}

.pseudobulk_counts_from_se <- function(se, assay){
    if (!requireNamespace('SummarizedExperiment', quietly = TRUE)) {
        stop("package 'SummarizedExperiment' is required to build a pseudobulk_ModuleSet from a SummarizedExperiment")
    }
    list(
        counts = SummarizedExperiment::assay(se, assay),
        metadata = as.data.frame(SummarizedExperiment::colData(se))
    )
}

# modules x pseudobulk-units score matrix via decoupleR::run_ulm(), matching
# module_scores()'s documented shape and row order (aligned to colnames(log_cpm))
.score_pseudobulk_network <- function(network, log_cpm){
    long <- decoupleR::run_ulm(log_cpm, network)
    wide <- as.data.frame(tidyr::pivot_wider(
        long, id_cols = 'condition', names_from = 'source', values_from = 'score'
    ))
    rownames(wide) <- wide$condition
    wide$condition <- NULL
    wide[colnames(log_cpm), , drop = FALSE]
}

#' Build a ModuleSet from pseudo-bulk counts, re-scoring modules with decoupleR
#'
#' Ingests a user-supplied pseudo-bulk counts matrix -- llegir does not build
#' pseudo-bulk itself -- and re-scores the module definitions directly on it,
#' rather than averaging cell-level module scores. Scoring runs on a
#' log2-CPM normalization of `counts` via [decoupleR::run_ulm()]: each
#' gene's `weight` in `gene_table` (e.g. hdWGCNA kME) becomes decoupleR's
#' mode-of-regulation (`mor`) when present, otherwise every gene gets a
#' uniform `mor = 1`. Builds on [components_ModuleSet()] with `data_level =
#' 'pseudobulk'` and `aggregated = TRUE`, so [validate_moduleset()] passes
#' and `counts()`/`capabilities()$counts` are populated.
#'
#' @param counts Either a raw-counts matrix (genes x pseudo-bulk units) or a
#'   `SummarizedExperiment` (assay `assay`, `colData` becomes `metadata`,
#'   `rownames` are genes).
#' @param gene_table The module definitions to score: a tidy data.frame with
#'   `module`, `gene_name`, and an optional numeric `weight` column, or a
#'   named list of gene vectors (one per module, no weights). Normally the
#'   same modules found at cell level.
#' @param metadata A data.frame with one row per pseudo-bulk unit, aligned to
#'   the columns of `counts`. Required when `counts` is a raw matrix; ignored
#'   (taken from `colData`) when `counts` is a `SummarizedExperiment`.
#' @param assay Assay name to read counts from when `counts` is a
#'   `SummarizedExperiment`. Default `'counts'`.
#' @param group_col Optional name of a `metadata` column declared as the
#'   unit-state grouping (see [components_ModuleSet()]).
#' @param sample_col Optional name of a `metadata` column declared as the
#'   sample id.
#' @param data_level Observation-unit descriptor. Default `'pseudobulk'`;
#'   override for finer-grained units, e.g. `'pseudobulk_sample_x_cluster'`.
#' @return A `pseudobulk_ModuleSet` object (a `components_ModuleSet` under
#'   the hood).
#' @examples
#' \dontrun{
#' pb_ms <- pseudobulk_ModuleSet(pb_counts, list(module_a = c('GENE1', 'GENE2')), pb_meta)
#' validate_moduleset(pb_ms)
#' }
#' @export
pseudobulk_ModuleSet <- function(counts, gene_table, metadata = NULL, assay = 'counts',
                                  group_col = NULL, sample_col = NULL, data_level = 'pseudobulk'){
    if (methods::is(counts, 'SummarizedExperiment')) {
        se_data <- .pseudobulk_counts_from_se(counts, assay)
        counts <- se_data$counts
        metadata <- se_data$metadata
    }
    if (is.null(metadata)) {
        stop('metadata is required when counts is a raw matrix (not a SummarizedExperiment)')
    }
    counts <- as.matrix(counts)

    gene_table <- .normalize_gene_table(gene_table)
    gene_table <- gene_table[gene_table$gene_name %in% rownames(counts), , drop = FALSE]
    has_weight <- 'weight' %in% colnames(gene_table)

    mor <- if (has_weight) ifelse(is.na(gene_table$weight), 1, gene_table$weight) else rep(1, nrow(gene_table))
    network <- data.frame(source = gene_table$module, target = gene_table$gene_name, mor = mor)

    log_cpm <- .log_cpm(counts)
    scores <- .score_pseudobulk_network(network, log_cpm)

    cm_gene_table <- gene_table[, c('module', 'gene_name'), drop = FALSE]
    if (has_weight) cm_gene_table$weight <- gene_table$weight

    ms <- components_ModuleSet(
        cm_gene_table, expression = log_cpm, metadata = metadata, scores = scores, counts = counts,
        group_col = group_col, sample_col = sample_col, data_level = data_level, aggregated = TRUE
    )
    class(ms) <- c('pseudobulk_ModuleSet', class(ms))
    ms
}

#' @rdname pseudobulk_ModuleSet
#' @param ms A `ModuleSet` object; the dispatch target for [pkg_versions()].
#' @param ... Passed to methods.
#' @export
pkg_versions.pseudobulk_ModuleSet <- function(ms, ...){
    list(
        llegir = as.character(utils::packageVersion('llegir')),
        decoupleR = as.character(utils::packageVersion('decoupleR'))
    )
}

#---------------------------------------------------------
# attachment api
#---------------------------------------------------------

#' Attach a pseudo-bulk ModuleSet view to a cell-level ModuleSet
#'
#' Stores `pb_ms` on `cell_ms` and flips `cell_ms`'s `pseudobulk` capability
#' to `TRUE`, so cell-level tools keep using `cell_ms` as their primary view
#' while pseudo-bulk-specific tools pull the sample-level view via
#' [pseudobulk()] / [pseudobulk_view()]. Implemented by prepending a
#' decorator class rather than rewriting every adapter: `capabilities()` and
#' `pseudobulk()` get an override, every other generic ([modules()],
#' [gene_membership()], [module_scores()], [expression()], [counts()],
#' [metadata()], [pkg_versions()]) falls through unchanged to `cell_ms`'s own
#' method.
#'
#' @param cell_ms A cell-level `ModuleSet` (e.g. built by [hdWGCNA_ModuleSet()]).
#' @param pb_ms A pseudo-bulk `ModuleSet`, normally built by
#'   [pseudobulk_ModuleSet()].
#' @return `cell_ms`, with `pb_ms` attached.
#' @examples
#' \dontrun{
#' ms <- with_pseudobulk(cell_ms, pb_ms)
#' has_capability(ms, 'pseudobulk')
#' pseudobulk(ms)
#' }
#' @export
with_pseudobulk <- function(cell_ms, pb_ms){
    cell_ms$.pseudobulk_ms <- pb_ms
    class(cell_ms) <- c('with_pseudobulk_ModuleSet', class(cell_ms))
    cell_ms
}

#' Attached pseudo-bulk view for a ModuleSet
#'
#' Returns the pseudo-bulk `ModuleSet` attached via [with_pseudobulk()], or
#' `NULL` if none is attached. Most callers want [pseudobulk_view()] instead,
#' which also handles the case where `ms` is itself already a pseudo-bulk
#' set.
#'
#' @param ms A `ModuleSet` object.
#' @param ... Passed to methods.
#' @return A `ModuleSet`, or `NULL`.
#' @export
pseudobulk <- function(ms, ...) UseMethod('pseudobulk')

#' @rdname pseudobulk
#' @export
pseudobulk.default <- function(ms, ...) NULL

#' @rdname pseudobulk
#' @export
pseudobulk.with_pseudobulk_ModuleSet <- function(ms, ...) ms$.pseudobulk_ms

#' @rdname with_pseudobulk
#' @export
capabilities.with_pseudobulk_ModuleSet <- function(ms, ...){
    caps <- NextMethod()
    caps['pseudobulk'] <- TRUE
    caps
}

#' Resolve the pseudo-bulk view for a ModuleSet
#'
#' The resolver every pseudo-bulk tool uses: returns `ms` itself when it is
#' already a pseudo-bulk set (built by [pseudobulk_ModuleSet()]), returns the
#' attached view via [pseudobulk()] when one exists, and `NULL` otherwise --
#' the signal for a tool to skip gracefully.
#'
#' @param ms A `ModuleSet` object.
#' @return A `ModuleSet`, or `NULL`.
#' @export
pseudobulk_view <- function(ms){
    if (inherits(ms, 'pseudobulk_ModuleSet')) return(ms)
    pb <- pseudobulk(ms)
    if (!is.null(pb)) return(pb)
    NULL
}
