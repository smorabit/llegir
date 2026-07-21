# hdWGCNA pseudo-bulk aggregation helper, trimmed down from the SERPENTINE
# pseudobulk_functions.R used across the hdWGCNA snakemake/T-cell-tumor
# analyses. Not part of the hdWGCNA package itself -- source this file
# directly, then call AggregatePseudobulk() on a raw counts matrix + cell
# metadata to get back a genes x pseudobulk-units SummarizedExperiment.

# helper for AggregatePseudobulk: finds metadata columns that are constant
# within every pseudobulk group, so they can be carried into colData(se)
find_replicate_columns <- function(meta, group){
    is_replicate_col <- function(col){
        all(tapply(col, group, function(x) length(unique(x)) == 1))
    }
    names(meta)[sapply(meta, is_replicate_col)]
}

# helper for AggregatePseudobulk: builds one colData row per pseudobulk unit
# by pulling the single constant value of each replicate-level column
make_pseudobulk_metadata <- function(meta, group){
    replicate_cols <- find_replicate_columns(meta, group)
    out <- sapply(replicate_cols, function(colname){
        tapply(meta[[colname]], group, function(x) unique(x)[1])
    })
    as.data.frame(out, row.names = levels(group))
}

# aggregate a gene x cell counts matrix into gene x pseudobulk counts.
# pseudobulk units are the interaction of replicate_col x group_col (pass
# the same column to both when one pseudobulk per replicate is wanted, as
# below); units with <= min_cells contributing cells are dropped, as are
# genes with zero variance across the retained units.
AggregatePseudobulk <- function(X, meta, replicate_col, group_col, min_cells = 10, assay_name = 'counts'){
    if (!inherits(X, 'Matrix') && !is.matrix(X)) {
        stop("'X' must be a dense matrix or a sparse 'Matrix' object from the Matrix package.")
    }
    if (!is.data.frame(meta)) {
        stop("'meta' must be a data.frame")
    }
    if (!all(colnames(X) %in% rownames(meta))) {
        stop('Mismatch between cells in colnames(X) and rownames(meta)')
    }
    meta <- meta[colnames(X), , drop = FALSE]

    for (col in c(replicate_col, group_col)) {
        if (!(col %in% colnames(meta))) {
            stop(sprintf("Column '%s' not found in meta.", col))
        }
        if (any(is.na(meta[[col]]))) {
            stop(sprintf("Column '%s' contains NA values.", col))
        }
    }

    pb_groups <- interaction(meta[, replicate_col], meta[, group_col], drop = TRUE)
    n_cells <- table(pb_groups)

    # sparse cells x pseudobulks indicator matrix; counts %*% G sums cells into units
    G <- Matrix::sparse.model.matrix(~0 + pb_groups)
    pb <- X %*% G
    colnames(pb) <- gsub('pb_groups', '', colnames(pb))

    pb <- pb[, as.logical(n_cells >= min_cells)]

    good_genes <- names(which(apply(pb, 1, sd) != 0))
    pb <- pb[good_genes, ]

    pb_meta <- make_pseudobulk_metadata(meta, pb_groups)
    pb_meta <- pb_meta[colnames(pb), ]

    assay_list <- list(tmp = pb)
    names(assay_list) <- assay_name

    se <- SummarizedExperiment::SummarizedExperiment(assays = assay_list, colData = pb_meta)
    SummarizedExperiment::colData(se)$nCells <- as.numeric(n_cells[colnames(se)])
    # Matrix::colSums(), not the bare generic -- constructing se above pulls in
    # DelayedArray/MatrixGenerics, which redefines colSums as an S4 generic
    # that dgCMatrix no longer dispatches through by default
    SummarizedExperiment::colData(se)$nUMI <- Matrix::colSums(pb)
    pb[pb > 1] <- 1
    SummarizedExperiment::colData(se)$nFeatures <- Matrix::colSums(pb)

    se
}
