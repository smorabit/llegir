#---------------------------------------------------------
# llegir agent bootstrap: read-only, non-graphical
#---------------------------------------------------------
# Run with `Rscript query_example.R` (or `R --vanilla -f query_example.R`)
# from inside this workspace. Do not source this into a live/graphical R
# session -- a vanilla process guarantees no .Rprofile/.RData bleed and no
# accidental attach of a heavy Seurat graphics stack.

suppressPackageStartupMessages(library(llegir))
options(llegir.agent_session = TRUE)

manifest <- llegir::read_agent_manifest('.llegir_agent_manifest.md')
ms <- readRDS(manifest$artifacts$moduleset_rds)
dctx <- readRDS(manifest$artifacts$dataset_context_rds)
packets <- readRDS(manifest$artifacts$packets_rds)

# fail fast if the workspace drifted from what the manifest promised
stopifnot(identical(modules(ms), manifest$module_ids))

# structure only -- near-zero tokens
print(modules(ms))
print(capabilities(ms))

# per-module slice -- bounded rows, always safe
print(head(gene_membership(ms, manifest$module_ids[1]), 25))

# never print, head()-dump, or return a full expression/counts matrix --
# matrices stay inside R; only tidy summaries cross into your context
