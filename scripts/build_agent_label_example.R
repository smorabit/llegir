# Builds the label-mode agent workspace used by vignettes/agent-labels.Rmd.
#
# Run this from the package root, in the compact_fresh conda env, with the
# CSF dev fixture present at data/CSF_Myeloid_hdWGCNA.rds. It writes the
# workspace to output/agent_label_example/label_ws (gitignored). Once it has
# run, point a coding agent at the workspace:
#
#   cd output/agent_label_example/label_ws
#   claude "Read .llegir_agent_manifest.md, then complete its Labeling Task, following its Mission & Guardrails and Execution Protocol."
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
# moduleset
#---------------------------------------------------------

# loading the CSF object takes a minute; it already holds the hdWGCNA network.
# declaring the grouping and sample columns here means no tool needs them
# repeated, and the label workspace's sample-concentration screen picks up
# the patient column automatically
seurat_obj <- readRDS('data/CSF_Myeloid_hdWGCNA.rds')
ms <- hdWGCNA_ModuleSet(seurat_obj, group_col = 'lv2_annot', sample_col = 'patient')

# check modules(ms) in the console: the example labels MM1-MM3 only
modules_use <- c('MM1', 'MM2', 'MM3')

#---------------------------------------------------------
# evidence
#---------------------------------------------------------

gene_sets <- c(
    GO_BP = 'data/GO_Biological_Process_2026.txt',
    Hallmark = 'data/h.all.v2026.1.Hs.symbols.gmt'
)

# one tool list for the whole run: dataset_composition runs once, the rest
# once per module. n_hubs and condition_col are shared run-level params
ev <- run_evidence(
    ms,
    tools = list(
        tool('dataset_composition'),
        tool('top_genes'),
        tool('cluster_dme'),
        tool('geneset_enrichment', db_files = gene_sets)
    ),
    params = list(n_hubs = 25, condition_col = 'diagnosis'),
    modules_use = modules_use,
    output_dir = 'output/agent_label_example/evidence'
)

# inspect ev$packets$MM1$provenance$skipped in the console: any tool that did
# not run for a module is listed there with the reason

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
    ms, ev$dataset_context, ev$packets, desc,
    out_dir = 'output/agent_label_example/label_ws',
    mode = 'label',
    depth_cols = c('nCount_RNA', 'nFeature_RNA'),
    feature_genes = GetWGCNAGenes(seurat_obj)
)

# the manifest path printed here is what the agent reads first
print(manifest_path)
