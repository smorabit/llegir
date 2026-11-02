# Ranked hub list (top 40 by kME) and kME distribution for MM2.
suppressPackageStartupMessages(library(llegir))
options(llegir.agent_session = TRUE)

manifest <- llegir::read_agent_manifest('.llegir_agent_manifest.md')
ms <- qs2::qs_read(manifest$artifacts$moduleset_lite)
stopifnot(identical(modules(ms), manifest$module_ids))

gm <- gene_membership(ms, 'MM2')
cat('module size:', nrow(gm), '\n')
print(summary(gm$kme))
print(head(gm, 40), row.names = TRUE)
sessionInfo()
