## run once for the whole test_dir() session (testthat 3e convention).
## wd here is tests/testthat/, hence the ../../ paths.
##
## package code itself is loaded by the testthat harness (devtools::load_all()
## in dev, the installed package under R CMD check) -- this file only sources
## the test-only synthetic_moduleset.R helper and builds shared fixtures.

# not named helper-*.R on purpose: testthat's automatic helper loader sources
# helpers into a private environment that can't see package S3 methods for
# dispatch the way this explicit source() into .GlobalEnv can
source('synthetic_moduleset.R')
source('synthetic_extensibility.R')
source('synthetic_pseudobulk.R')

# data/CSF_Myeloid_hdWGCNA.rds is a large, gitignored dev-only file, excluded
# from the built package tarball via .Rbuildignore -- it won't exist under
# R CMD check / CI, so every test that depends on it is skipped there and
# only runs for regression coverage on a dev machine that has the file
csf_data_available <- file.exists('../../data/CSF_Myeloid_hdWGCNA.rds')

if (csf_data_available) {
    # loaded once and shared read-only across test files; readRDS + adapter
    # construction is the slow part of this suite, no need to repeat it per file
    so_test <- readRDS('../../data/CSF_Myeloid_hdWGCNA.rds')
    ms_test <- hdWGCNA_ModuleSet(so_test)
    mod_test <- modules(ms_test)[1]
}

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

# interpretation.schema.json now ships at inst/schemas/ and is resolved via
# system.file(); works under devtools::load_all() and once installed alike
test_schema_path <- system.file('schemas', 'interpretation.schema.json', package = 'llegir')

# a real evidence packet for mod_test, built with the same tool_config as
# scripts/run_csf.R, for prompt/synthesis tests that need a real packet
# without depending on the gitignored output/evidence_packets/ directory
csf_tool_config <- list(
    list(fn = top_genes_tool, params = list(n_hubs = 25)),
    list(fn = cluster_dme_tool, params = list(group_by = 'lv2_annot')),
    list(fn = geneset_enrichment_tool, params = list(n_hubs = 25, db_files = test_db_files))
)

## spike-in fixtures (docs/milestone_1.md task 5): shared across
## test-spike_in.R, test-confidence.R and test-faithfulness.R, so they're
## built once here rather than duplicated per file. Depend on the CSF dev
## object, so guarded the same way as so_test/ms_test above.
if (csf_data_available) {
    positive_ms <- synthetic_ModuleSet(ms_test, list(pdc_module = pdc_genes))
    negative_ms <- synthetic_ModuleSet(ms_test, list(random_module = random_control_genes(so_test)))
}

# a full evidence packet (top_genes, cluster_dme, geneset_enrichment) for a
# spike-in module -- confidence/faithfulness tests need a multi-fragment
# packet, not just a single tool's output
build_spike_in_packet <- function(ms, module_id, n_hubs){
    tool_config <- list(
        list(fn = top_genes_tool, params = list(n_hubs = n_hubs)),
        list(fn = cluster_dme_tool, params = list(group_by = 'lv2_annot')),
        list(fn = geneset_enrichment_tool, params = list(n_hubs = n_hubs, db_files = test_db_files))
    )
    run_module(ms, module_id, tool_config, input_hash = 'spike_in')
}
