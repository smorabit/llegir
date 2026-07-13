## run once for the whole test_dir() session (testthat 3e convention).
## wd here is tests/testthat/, hence the ../../ paths.

source('../../R/utils.R')
source('../../R/moduleset.R')
source('../../R/moduleset_hdwgcna.R')
source('../../R/fragment.R')
source('../../R/stats_utils.R')
source('../../R/tool_hub_genes.R')
source('../../R/tool_cluster_dme.R')
source('../../R/tool_module_by_metadata.R')
source('../../R/tool_geneset_enrichment.R')
source('../../R/import_fragment.R')
source('../../R/orchestrator.R')
source('../../R/interpretation.R')
source('../../R/dataset_description.R')
source('../../R/prompt.R')
source('../../R/synthesis.R')
source('../../R/faithfulness.R')
source('../../R/confidence.R')
source('../../R/render.R')

# not named helper-*.R on purpose: testthat's automatic helper loader sources
# helpers into a private environment that tool functions (bound to .GlobalEnv
# by the source() calls above) can't see for S3 dispatch, so it's sourced
# explicitly here instead, same as everything else in this file
source('synthetic_moduleset.R')

# loaded once and shared read-only across test files; readRDS + adapter
# construction is the slow part of this suite, no need to repeat it per file
so_test <- readRDS('../../data/CSF_Myeloid_hdWGCNA.rds')
ms_test <- hdWGCNA_ModuleSet(so_test)
mod_test <- modules(ms_test)[1]

# geneset_enrichment_tool()'s default db_files path is relative to the repo
# root (matches scripts/run_csf.R); testthat runs with cwd tests/testthat/,
# so tests override it with this path instead
test_db_files <- c(GO_BP = '../../data/GO_Biological_Process_2026.txt')

# reused across prompt/synthesis tests: a minimal but valid dataset
# description for the CSF dev object (mirrors docs/handoff_prompt_m2.md's
# suggested config)
csf_dataset_description <- function(){
    dataset_description(
        species = 'human',
        tissue = 'cerebrospinal fluid (CSF)',
        cell_compartment = 'myeloid cells (microglia / monocyte-derived macrophages / DCs)',
        assay = 'single-cell RNA-seq (10x)',
        conditions = c(
            'Glioblastoma', 'Brain Metastasis', 'Primary CNS lymphoma',
            'Secondary CNS lymphoma', 'Inflammatory / other neuroinflammatory'
        ),
        notes = 'Modules are CSF-myeloid co-expression programs; interpret in a CNS-myeloid, neuro-oncology / neuroinflammation context.'
    )
}

# interpretation.schema.json's default path (synthesize_interpretation()'s
# schema_path arg) is relative to the repo root; tests run with cwd
# tests/testthat/, same reasoning as test_db_files above
test_schema_path <- '../../schemas/interpretation.schema.json'

# a real evidence packet for mod_test, built with the same tool_config as
# scripts/run_csf.R, for prompt/synthesis tests that need a real packet
# without depending on the gitignored output/evidence_packets/ directory
csf_tool_config <- list(
    list(fn = hub_genes_tool, params = list(n_hubs = 25)),
    list(fn = cluster_dme_tool, params = list(group_by = 'lv2_annot')),
    list(fn = module_by_metadata_tool, params = list(column = 'diagnosis', column_type = 'categorical')),
    list(fn = module_by_metadata_tool, params = list(column = 'sample', column_type = 'categorical')),
    list(fn = geneset_enrichment_tool, params = list(n_hubs = 25, db_files = test_db_files))
)

## spike-in fixtures (docs/milestone_1.md task 5): shared across
## test-spike_in.R, test-confidence.R and test-faithfulness.R, so they're
## built once here rather than duplicated per file.
positive_ms <- synthetic_ModuleSet(ms_test, list(pdc_module = pdc_genes))
negative_ms <- synthetic_ModuleSet(ms_test, list(random_module = random_control_genes(so_test)))

# a full evidence packet (hub_genes, cluster_dme, module_by_metadata::diagnosis,
# geneset_enrichment) for a spike-in module -- confidence/faithfulness tests
# need a multi-fragment packet, not just a single tool's output
build_spike_in_packet <- function(ms, module_id, n_hubs){
    tool_config <- list(
        list(fn = hub_genes_tool, params = list(n_hubs = n_hubs)),
        list(fn = cluster_dme_tool, params = list(group_by = 'lv2_annot')),
        list(fn = module_by_metadata_tool, params = list(column = 'diagnosis', column_type = 'categorical')),
        list(fn = geneset_enrichment_tool, params = list(n_hubs = n_hubs, db_files = test_db_files))
    )
    run_module(ms, module_id, tool_config, input_hash = 'spike_in')
}
