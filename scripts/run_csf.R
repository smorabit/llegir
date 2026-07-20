## entry point: run the deterministic evidence core end-to-end on the CSF dev
## object. Run from the repo root:
##   conda activate hdWGCNA
##   Rscript scripts/run_csf.R

source('R/utils.R')
source('R/moduleset.R')
source('R/moduleset_components.R')
source('R/moduleset_hdwgcna.R')
source('R/fragment.R')
source('R/stats_utils.R')
source('R/tool_hub_genes.R')
source('R/tool_cluster_dme.R')
source('R/tool_geneset_enrichment.R')
source('R/moduleset_gene_list.R')  # .score_gene_sets(), reused by tool_signature_correlation.R below
source('R/tool_signature_correlation.R')
source('R/import_fragment.R')
source('R/orchestrator.R')

data_path <- 'data/CSF_Myeloid_hdWGCNA.rds'
output_dir <- 'output/evidence_packets'
tables_dir <- 'output/tables'

# focused MSigDB collections for enrichment/correlation, not the full Human
# MSigDB (which buries the signal, docs/milestone_extensibility.md Part 2a):
# all 50 Hallmark gene sets, small enough to use in full. C8 (cell-type) /
# C7 (immunologic) aren't downloaded locally yet -- add them here alongside
# Hallmark once they are.
hallmark_gmt <- c(Hallmark = 'data/h.all.v2026.1.Hs.symbols.gmt')

# core tools for the CSF dataset (docs/milestone_1.md): hub genes, which cell
# state expresses the module (lv2_annot), offline GO enrichment (GeneOverlap
# against local GMTs) over hub genes, and Hallmark signature co-variation
# over the module's own activity.
tool_config <- list(
    list(fn = hub_genes_tool, params = list(n_hubs = 25)),
    list(fn = cluster_dme_tool, params = list(group_by = 'lv2_annot')),
    list(fn = geneset_enrichment_tool, params = list(
        n_hubs = 25,
        db_files = c(GO_BP = 'data/GO_Biological_Process_2026.txt', hallmark_gmt)
    )),
    list(fn = signature_correlation_tool, params = list(library_files = hallmark_gmt))
)

seurat_obj <- readRDS(data_path)
ms <- hdWGCNA_ModuleSet(seurat_obj)
input_hash <- digest::digest(file = data_path, algo = 'sha256')

packets <- run_orchestrator(ms, tool_config, output_dir, tables_dir = tables_dir, input_hash = input_hash)

n_ok <- sum(!vapply(packets, is.null, logical(1)))
cat(n_ok, '/', length(packets), 'modules written to', output_dir, '\n')

# echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bash_profile && source ~/.bash_profile