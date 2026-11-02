# Status of expected and alternative-label markers for MM3: in_module,
# in_network (other module), unassigned (feature set, no module), not_tested.
suppressPackageStartupMessages(library(llegir))
suppressPackageStartupMessages(library(dplyr))
options(llegir.agent_session = TRUE)

manifest <- llegir::read_agent_manifest('.llegir_agent_manifest.md')
ms <- qs2::qs_read(manifest$artifacts$moduleset_lite)
stopifnot(identical(modules(ms), manifest$module_ids))
features <- readLines(manifest$artifacts$feature_genes)

assign_df <- lapply(modules(ms), function(m) {
    gm <- gene_membership(ms, m)
    gm$rank <- seq_len(nrow(gm))
    gm
}) %>%
    bind_rows()

markers <- c('ACTG1', 'CFL1', 'ARPC3', 'ARPC1B', 'TMSB4X', 'MYL6', 'CAPZB', 'HSPA5', 'HSP90B1', 'CANX', 'S100A8', 'S100A9', 'LYZ', 'CD14', 'FCN1', 'GAPDH', 'TMSB10')
status_df <- tibble(gene = markers) %>%
    left_join(assign_df, by = c('gene' = 'gene_name')) %>%
    mutate(status = case_when(
        module == 'MM3' ~ 'in_module',
        !is.na(module) ~ 'in_network',
        gene %in% features ~ 'unassigned',
        TRUE ~ 'not_tested'
    ))
print(as.data.frame(status_df))
sessionInfo()
