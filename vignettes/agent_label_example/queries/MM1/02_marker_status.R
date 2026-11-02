# Status of expected and alternative-label markers for MM1: in_module,
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

markers <- c('MRC1', 'CD163', 'LYVE1', 'FOLR2', 'F13A1', 'C1QA', 'C1QB', 'C1QC', 'MS4A7', 'STAB1', 'SIGLEC1', 'CD14', 'P2RY12', 'TMEM119', 'CX3CR1', 'SALL1', 'APOE', 'SPP1', 'GPNMB')
status_df <- tibble(gene = markers) %>%
    left_join(assign_df, by = c('gene' = 'gene_name')) %>%
    mutate(status = case_when(
        module == 'MM1' ~ 'in_module',
        !is.na(module) ~ 'in_network',
        gene %in% features ~ 'unassigned',
        TRUE ~ 'not_tested'
    ))
print(as.data.frame(status_df))
sessionInfo()
