# Status of expected and alternative-label markers for MM2: in_module,
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

markers <- c('B2M', 'TAP1', 'HLA-E', 'HLA-A', 'RPS3', 'RPL10', 'RPS27A', 'EEF1A1', 'TPT1', 'COX4I1', 'GAPDH', 'ENO1', 'PKM', 'LDHA', 'TPI1', 'HLA-DRA', 'CD74', 'MKI67', 'TOP2A')
status_df <- tibble(gene = markers) %>%
    left_join(assign_df, by = c('gene' = 'gene_name')) %>%
    mutate(status = case_when(
        module == 'MM2' ~ 'in_module',
        !is.na(module) ~ 'in_network',
        gene %in% features ~ 'unassigned',
        TRUE ~ 'not_tested'
    ))
print(as.data.frame(status_df))
sessionInfo()
