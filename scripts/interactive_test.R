## interactive dev script: source/run line-by-line in an R session to walk
## the core package workflow end-to-end on three modules (MM1-MM3).
## conda activate hdWGCNA, then open this file and run it chunk by chunk.

#---------------------------------------------------------
# setup environment and load the dataset
#---------------------------------------------------------

devtools::load_all()

# load the seurat object
data_path <- 'data/CSF_Myeloid_hdWGCNA.rds'
seurat_obj <- readRDS(data_path)

# define the set of modules to use for this test
modules_use <- c('MM1', 'MM2', 'MM3')


#---------------------------------------------------------
# initialize the ModuleSet adapter
#---------------------------------------------------------

ms <- hdWGCNA_ModuleSet(seurat_obj)
modules(ms)

# run the capabilities check
capabilities(ms)

#---------------------------------------------------------
# run core evidence tools over MM1-MM3 only
#---------------------------------------------------------

hallmark_gmt <- c(Hallmark = 'data/h.all.v2026.1.Hs.symbols.gmt')

# define the list of tools to run
tool_config <- list(
    list(fn = top_genes_tool, params = list(n_hubs = 30)),
    list(fn = cluster_dme_tool, params = list(group_by = 'lv2_annot')),
    list(fn = geneset_enrichment_tool, params = list(
        n_hubs = 25,
        db_files = c(GO_BP = 'data/GO_Biological_Process_2026.txt', hallmark_gmt)
    )),
    list(fn = signature_correlation_tool, params = list(library_files = hallmark_gmt))
)

# run the orchestrator over the list of tools to construct evidence packets per module
packets <- run_orchestrator(ms, tool_config, output_dir = 'output/evidence_packets', modules_use = modules_use)

# inspect one packet's fragments before moving on
packets[['MM1']]
packets[['MM1']]$fragments[[1]]

# Question: Is the orchestrator running the UCell signature scoring for each module??? Or what's happening???


#---------------------------------------------------------
# run synthesis on the same three modules via GitHub Models
#---------------------------------------------------------

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

backend <- cached_backend(
    resolve_backend('github'), provider = 'github', model = .default_models[['github']],
    prompt_template_version = PROMPT_TEMPLATE_VERSION
)

interps <- run_synthesis_orchestrator(packets, desc, backend, output_dir = 'output/interpretations')

# inspect one interpretation
interps[['MM1']]
needs_review(interps[['MM1']])

# maybe I am missing something, but "interps" I think should also have the fullly assembled paragraph 