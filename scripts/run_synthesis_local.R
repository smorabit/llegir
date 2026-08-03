## End-to-end synthesis run against a local vLLM server. Self-contained:
## generates MM1's evidence packet, runs synthesis via the local backend,
## prints the interpretation, and writes an HTML report.
##
## Prerequisites (docs/local_llm_backend.md):
##   - vLLM server running and accessible (see §5-6 of the guide)
##   - Environment variables set before invoking:
##       export LLEGIR_LLM_URL=http://127.0.0.1:8000/v1   # or the tunneled/direct URL
##       export VLLM_API_KEY=EMPTY                         # or real key if server uses --api-key
##
## Run from the repo root:
##   conda run -n compact_fresh Rscript scripts/run_synthesis_local.R

devtools::load_all(quiet = TRUE)

#---------------------------------------------------------
# knobs
#---------------------------------------------------------

module_use <- 'MM1'
force_refresh <- FALSE
output_dir <- 'output/interpretations'
packets_dir <- 'output/evidence_packets'
report_path <- 'output/local_qwen_report.html'

data_path <- 'data/CSF_Myeloid_hdWGCNA.rds'

# default: only tools that need no external files; first runs can't fail on a
# missing GMT/GO path. uncomment the add-ons below once the files are in place.
tool_config <- list(
    list(fn = top_genes_tool, params = list(n_hubs = 25)),
    list(fn = cluster_dme_tool, params = list(group_by = 'lv2_annot'))
    # add-ons -- require external GMT/GO files:
    # list(fn = geneset_enrichment_tool, params = list(
    #     n_hubs = 25,
    #     db_files = c(
    #         GO_BP    = 'data/GO_Biological_Process_2026.txt',
    #         Hallmark = 'data/h.all.v2026.1.Hs.symbols.gmt'
    #     )
    # )),
    # list(fn = signature_correlation_tool, params = list(
    #     library_files = c(Hallmark = 'data/h.all.v2026.1.Hs.symbols.gmt')
    # ))
)

desc <- dataset_description(
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

#---------------------------------------------------------
# evidence: load object, generate MM1 packet
#---------------------------------------------------------

cat('Loading', data_path, '...\n')
seurat_obj <- readRDS(data_path)
ms <- hdWGCNA_ModuleSet(seurat_obj)
input_hash <- digest::digest(file = data_path, algo = 'sha256')

cat('Running evidence toolbox for', module_use, '...\n')
packets <- run_orchestrator(
    ms, tool_config, packets_dir,
    tables_dir = 'output/tables',
    modules_use = module_use,
    input_hash = input_hash
)
if (is.null(packets[[module_use]])) stop('evidence collection failed for ', module_use)
cat('Evidence packet built:', length(packets[[module_use]]$fragments), 'fragments\n')

#---------------------------------------------------------
# synthesis: preflight + local vLLM backend via local_backend()
#---------------------------------------------------------

backend <- local_backend(force_refresh = force_refresh)

cat('Synthesizing', module_use, '...\n')
interps <- run_synthesis_orchestrator(packets, desc, backend, output_dir)

interp <- interps[[module_use]]
if (is.null(interp)) stop('synthesis failed for ', module_use)

cat('\n--- Interpretation: ', interp$proposed_label, ' ---\n', sep = '')
cat(interp$one_line_summary, '\n')
cat('Confidence:', interp$confidence$score, '--', interp$confidence$rationale, '\n')
cat('Flags:', if (length(interp$flags) == 0) 'none' else paste(interp$flags, collapse = ', '), '\n')

#---------------------------------------------------------
# report
#---------------------------------------------------------

cat('\nWriting HTML report to', report_path, '...\n')
write_interpretation_report(
    interps = interps,
    packets = packets,
    desc = desc,
    output_file = report_path
)
cat('Done:', report_path, '\n')
