## entry point: run the synthesis stage (docs/milestone_2.md) end-to-end on
## the CSF dev object's evidence packets. Run from the repo root, after
## scripts/run_csf.R has produced output/evidence_packets/:
##   conda activate hdWGCNA
##   Rscript scripts/run_synthesis_csf.R
##
## Dev economy (docs/dev_economy.md): `provider` is config-selected via
## resolve_backend() -- 'github' (gpt-4o-mini, ~150/day, default here) for
## routine dev iteration, 'gemini' for occasional cross-checks, 'mock' for an
## offline / no-network / no-API-key run. `modules_use` restricts synthesis to
## a small subset so internal testing doesn't burn calls on all 14 modules.
## The live backend is wrapped in cached_backend(): a repeat run over the same
## packet/provider/model/prompt makes no API call at all -- set
## `force_refresh <- TRUE` to bypass the cache deliberately.

source('R/utils.R')
source('R/moduleset.R')
source('R/moduleset_hdwgcna.R')
source('R/fragment.R')
source('R/stats_utils.R')
source('R/tool_hub_genes.R')
source('R/tool_cluster_dme.R')
source('R/tool_module_by_metadata.R')
source('R/tool_geneset_enrichment.R')
source('R/import_fragment.R')
source('R/orchestrator.R')
source('R/interpretation.R')
source('R/dataset_description.R')
source('R/prompt.R')
source('R/synthesis.R')
source('R/faithfulness.R')
source('R/confidence.R')
source('R/render.R')

data_path <- 'data/CSF_Myeloid_hdWGCNA.rds'
packets_dir <- 'output/evidence_packets'
output_dir <- 'output/interpretations'

# dev-economy knobs (docs/dev_economy.md) -- keep the dev default cheap:
# one module, GitHub Models, cache on. Widen modules_use / n_modules or flip
# provider for a real full-batch or cross-check run.
provider <- 'github'
model <- NULL                 # NULL -> resolve_backend()'s default for `provider`
modules_use <- c('MM2')       # NULL to use n_modules instead, or all packets if both are NULL
n_modules <- NULL
force_refresh <- FALSE        # TRUE bypasses the cache for these modules

# same context docs/handoff_prompt_m2.md suggests for this dev object; a
# hard error from validate_dataset_description() if this doesn't hold
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

seurat_obj <- readRDS(data_path)
ms <- hdWGCNA_ModuleSet(seurat_obj)

packet_files <- list.files(packets_dir, pattern = '\\.json$', full.names = TRUE)
if (length(packet_files) == 0) stop('no evidence packets found in ', packets_dir, ' -- run scripts/run_csf.R first')
packets <- lapply(packet_files, read_evidence_packet)
names(packets) <- vapply(packets, function(p) p$module_id, character(1))

if (!is.null(modules_use)) {
    packets <- packets[intersect(modules_use, names(packets))]
} else if (!is.null(n_modules)) {
    packets <- packets[utils::head(names(packets), n_modules)]
}
if (length(packets) == 0) stop('modules_use/n_modules matched no packets in ', packets_dir)

resolved_model <- model %||% .default_models[[provider]] %||% NA_character_
backend <- cached_backend(
    resolve_backend(provider, model = model), provider = provider, model = resolved_model,
    prompt_template_version = PROMPT_TEMPLATE_VERSION, force_refresh = force_refresh
)

interps <- run_synthesis_orchestrator(packets, desc, backend, output_dir)

n_ok <- sum(!vapply(interps, is.null, logical(1)))
n_flagged <- sum(vapply(Filter(Negate(is.null), interps), needs_review, logical(1)))
cat(n_ok, '/', length(interps), 'modules synthesized,', n_flagged, 'flagged for review. Written to', output_dir, '\n')
