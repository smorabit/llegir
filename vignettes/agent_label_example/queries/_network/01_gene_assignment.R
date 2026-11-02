# Build a gene -> module assignment table for the whole network, used to
# classify expected markers as in_module / in_network / unassigned / not_tested.
suppressPackageStartupMessages(library(llegir))
suppressPackageStartupMessages(library(dplyr))
options(llegir.agent_session = TRUE)

manifest <- llegir::read_agent_manifest('.llegir_agent_manifest.md')
ms <- qs2::qs_read(manifest$artifacts$moduleset_lite)
stopifnot(identical(modules(ms), manifest$module_ids))

print(modules(ms))
print(capabilities(ms))
str(gene_membership(ms, 'MM1'))

assign_df <- lapply(modules(ms), function(m) {
    gm <- gene_membership(ms, m)
    gm$module <- m
    gm$rank <- seq_len(nrow(gm))
    gm
}) %>%
    bind_rows()

features <- readLines(manifest$artifacts$feature_genes)
cat('n features:', length(features), '\n')
cat('n assigned genes:', n_distinct(assign_df$gene), '\n')
print(assign_df %>% count(module))
saveRDS(assign_df, 'scratch/gene_assignment.rds')
sessionInfo()
