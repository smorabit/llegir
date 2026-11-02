# Builds the label-mode agent workspace used by vignettes/agent-labels.Rmd.
#
# Run this from the package root, in the compact_fresh conda env, with the
# CSF dev fixture present at data/CSF_Myeloid_hdWGCNA.rds. It writes the
# workspace to output/agent_label_example/label_ws (gitignored). Once it has
# run, point a coding agent at the workspace:
#
#   cd output/agent_label_example/label_ws
#   claude "Read .llegir_agent_manifest.md, then follow its Mission & Guardrails and Execution Protocol before answering anything."
#
# When check_agent_labels() reports every module as ok, copy the agent's
# labels/ and queries/ folders into vignettes/agent_label_example/ so the
# vignette can show real agent output without re-running the agent.

suppressPackageStartupMessages({
    library(Seurat)
    library(hdWGCNA)
    library(tidyverse)
})
devtools::load_all(quiet = TRUE)

#---------------------------------------------------------
# moduleset and dataset context
#---------------------------------------------------------

# loading the CSF object takes a minute; it already holds the hdWGCNA network
seurat_obj <- readRDS('data/CSF_Myeloid_hdWGCNA.rds')
ms <- hdWGCNA_ModuleSet(seurat_obj)

# check modules(ms) in the console: the example labels MM1-MM3 only
modules_use <- c('MM1', 'MM2', 'MM3')

dataset_tool_config <- list(
    list(fn = dataset_composition_tool, params = list(group_col = 'lv2_annot', condition_col = 'diagnosis'))
)
dataset_ctx <- run_dataset_context(ms, dataset_tool_config)

#---------------------------------------------------------
# evidence packets
#---------------------------------------------------------

tool_config <- list(
    list(fn = top_genes_tool, params = list(n_hubs = 25)),
    list(fn = cluster_dme_tool, params = list(group_by = 'lv2_annot')),
    list(fn = geneset_enrichment_tool, params = list(
        n_hubs = 25,
        db_files = c(
            GO_BP = 'data/GO_Biological_Process_2026.txt',
            Hallmark = 'data/h.all.v2026.1.Hs.symbols.gmt'
        )
    ))
)
packets <- run_orchestrator(
    ms, tool_config,
    output_dir = 'output/agent_label_example/evidence_packets',
    modules_use = modules_use
)

desc <- dataset_description(
    species = 'human',
    tissue = 'cerebrospinal fluid (CSF)',
    cell_compartment = 'myeloid cells',
    assay = 'single-cell RNA-seq (10x)',
    conditions = c(
        'Glioblastoma', 'Brain Metastasis', 'Primary CNS lymphoma',
        'Secondary CNS lymphoma', 'Inflammatory / other neuroinflammatory'
    ),
    notes = 'Modules are CSF-myeloid co-expression programs; interpret in a CNS-myeloid, neuro-oncology / neuroinflammation context.'
)

#---------------------------------------------------------
# label-mode workspace
#---------------------------------------------------------

# feature_genes is every gene hdWGCNA could assign (grey included), so a
# missing marker can be classed unassigned rather than not_tested
manifest_path <- export_agent_workspace(
    ms, dataset_ctx, packets, desc,
    out_dir = 'output/agent_label_example/label_ws',
    mode = 'label',
    sample_col = 'patient',
    depth_cols = c('nCount_RNA', 'nFeature_RNA'),
    feature_genes = GetWGCNAGenes(seurat_obj)
)

# the manifest path printed here is what the agent reads first
print(manifest_path)
