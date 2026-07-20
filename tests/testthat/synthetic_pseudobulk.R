## Synthetic pseudo-bulk fixtures (docs/milestone_pseudobulk.md Part 1): a
## self-contained pseudo-bulk counts matrix + metadata, no external data
## dependency. Covers both pseudobulk_ModuleSet() input paths (raw matrix +
## metadata, and SummarizedExperiment) and both mor sources (uniform vs a
## real weight column), plus a cell-level ModuleSet to exercise the
## attachment API against.

.pseudobulk_synthetic_data <- function(seed = 1, n_samples = 12, n_genes_per_module = 6, n_noise_genes = 10){
    set.seed(seed)
    module_a_genes <- paste0('PBGENEA', seq_len(n_genes_per_module))
    module_b_genes <- paste0('PBGENEB', seq_len(n_genes_per_module))
    noise_genes <- paste0('PBNOISE', seq_len(n_noise_genes))
    all_genes <- c(module_a_genes, module_b_genes, noise_genes)

    condition <- rep(c('case', 'control'), each = n_samples / 2)
    sample_id <- paste0('sample', seq_len(n_samples))

    # module_a is upregulated in 'case'; module_b carries no condition signal,
    # a true negative for downstream scoring/differential machinery
    base_lambda <- 200
    lambda_a <- ifelse(condition == 'case', base_lambda * 3, base_lambda)

    gene_counts <- function(lambda, n_genes){
        t(vapply(seq_len(n_genes), function(i) stats::rpois(n_samples, lambda), numeric(n_samples)))
    }

    counts <- rbind(
        gene_counts(lambda_a, n_genes_per_module),
        gene_counts(rep(base_lambda, n_samples), n_genes_per_module),
        matrix(stats::rpois(n_noise_genes * n_samples, base_lambda), nrow = n_noise_genes)
    )
    rownames(counts) <- all_genes
    colnames(counts) <- sample_id

    meta <- data.frame(
        sample = sample_id, condition = condition, n_cells = sample(50:200, n_samples),
        row.names = sample_id
    )

    list(counts = counts, meta = meta, module_a_genes = module_a_genes, module_b_genes = module_b_genes)
}

pb_fixture <- .pseudobulk_synthetic_data()
pb_gene_sets <- list(module_a = pb_fixture$module_a_genes, module_b = pb_fixture$module_b_genes)

# weighted variant: a real (non-identical) weight per gene, exercising the
# kME -> decoupleR mor mapping path instead of the uniform mor = 1 default
pb_gene_table_weighted <- do.call(rbind, lapply(names(pb_gene_sets), function(m){
    genes <- pb_gene_sets[[m]]
    data.frame(module = m, gene_name = genes, weight = seq(1, 0.5, length.out = length(genes)))
}))

pb_ms <- pseudobulk_ModuleSet(
    pb_fixture$counts, pb_gene_sets, pb_fixture$meta, group_col = 'condition', sample_col = 'sample'
)
pb_ms_weighted <- pseudobulk_ModuleSet(
    pb_fixture$counts, pb_gene_table_weighted, pb_fixture$meta, group_col = 'condition', sample_col = 'sample'
)

se_available <- requireNamespace('SummarizedExperiment', quietly = TRUE)
if (se_available) {
    pb_se <- SummarizedExperiment::SummarizedExperiment(
        assays = list(counts = pb_fixture$counts), colData = pb_fixture$meta
    )
}

# a cell-level ModuleSet, fully unrelated to the pseudo-bulk fixture, used
# only to exercise with_pseudobulk() / pseudobulk() / pseudobulk_view()
pb_cell_ms <- llegir_example_moduleset()

## a pseudo-bulk fixture built on the SAME GO gene sets/module ids as
## go_components_ms (synthetic_extensibility.R), so it can be attached to it
## via with_pseudobulk() for signature_correlation_tool's pseudo-bulk-level
## tests (docs/milestone_pseudobulk.md Part 2) -- go_gene_sets only exists
## when go_data_available, so this whole block is guarded the same way.
if (go_data_available) {
    .go_pseudobulk_data <- function(seed = 2, n_samples = 8){
        set.seed(seed)
        module_a_genes <- go_gene_sets$module_a
        module_b_genes <- go_gene_sets$module_b
        noise_genes <- paste0('GOPBNOISE', 1:10)
        all_genes <- c(module_a_genes, module_b_genes, noise_genes)

        condition <- rep(c('case', 'control'), each = n_samples / 2)
        sample_id <- paste0('gopbsample', seq_len(n_samples))

        # module_a is upregulated in 'case', mirroring the cell-level spike-in
        # signal so its own signature (sig_match_a) still shows real co-variation
        base_lambda <- 150
        lambda_a <- ifelse(condition == 'case', base_lambda * 3, base_lambda)

        gene_counts <- function(lambda, n_genes){
            t(vapply(seq_len(n_genes), function(i) stats::rpois(n_samples, lambda), numeric(n_samples)))
        }

        counts <- rbind(
            gene_counts(lambda_a, length(module_a_genes)),
            gene_counts(rep(base_lambda, n_samples), length(module_b_genes)),
            matrix(stats::rpois(length(noise_genes) * n_samples, base_lambda), nrow = length(noise_genes))
        )
        rownames(counts) <- all_genes
        colnames(counts) <- sample_id

        meta <- data.frame(sample = sample_id, condition = condition, row.names = sample_id)
        list(counts = counts, meta = meta)
    }

    go_pb_fixture <- .go_pseudobulk_data()
    go_pb_ms <- pseudobulk_ModuleSet(
        go_pb_fixture$counts, go_gene_sets, go_pb_fixture$meta,
        group_col = 'condition', sample_col = 'sample'
    )
    go_components_ms_with_pb <- with_pseudobulk(go_components_ms, go_pb_ms)
}
