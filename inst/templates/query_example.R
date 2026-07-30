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
ms <- qs2::qs_read(manifest$artifacts$moduleset_lite)
dctx <- qs2::qs_read(manifest$artifacts$dataset_context)
packets <- qs2::qs_read(manifest$artifacts$packets)

# only load this for an expression()/counts() query -- see Data Topography
# in the manifest for why moduleset_lite is the default
# ms_full <- qs2::qs_read(manifest$artifacts$moduleset_full)

# only present if this run synthesized interpretations
if (!is.null(manifest$artifacts$interpretations)) {
    interps <- qs2::qs_read(manifest$artifacts$interpretations)
}

# fail fast if the workspace drifted from what the manifest promised
stopifnot(identical(modules(ms), manifest$module_ids))

# structure only -- near-zero tokens
print(modules(ms))
print(capabilities(ms))

# per-module slice -- bounded rows, always safe
print(head(gene_membership(ms, manifest$module_ids[1]), 25))

# never print, head()-dump, or return a full expression/counts matrix --
# matrices stay inside R; only tidy summaries cross into your context
