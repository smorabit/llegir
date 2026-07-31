## quick walkthrough of the plot-ingestion feature
## (docs/milestones/milestone_plot_ingestion.md) against the real CSF dataset
## (see scripts/interactive_test.Rmd for more on this object): run a small
## evidence toolbox, attach a live ggplot to the cluster_dme fragment only,
## synthesize via a live backend (Gemini here -- GitHub Models was down for a
## scheduled retirement brownout; cached so a repeat run doesn't re-spend
## budget), and render the HTML report to see the figure card show up next
## to the raw evidence table.
## conda activate hdWGCNA, then run this line-by-line.

#---------------------------------------------------------
# setup: load the package and the real CSF hdWGCNA object
#---------------------------------------------------------

devtools::load_all()

data_path <- 'data/CSF_Myeloid_hdWGCNA.rds'
seurat_obj <- readRDS(data_path)

ms <- hdWGCNA_ModuleSet(seurat_obj)
modules(ms)

cur_mod <- modules(ms)[1]

#---------------------------------------------------------
# run three evidence tools for one module -- top 25 hub genes, cluster_dme
# (group_by = 'lv2_annot', the cell-state annotation column on this dataset,
# same one scripts/interactive_test.Rmd uses), and GO enrichment over those
# hub genes. top_genes/geneset_enrichment don't need any plot attached --
# only cluster_dme gets one below.
#---------------------------------------------------------

packet <- run_module(ms, cur_mod, tool_config = list(
    list(id = 'top_genes', params = list(n_hubs = 25)),
    list(id = 'cluster_dme', params = list(group_by = 'lv2_annot')),
    list(id = 'geneset_enrichment', params = list(
        n_hubs = 25,
        db_files = c(GO_BP = 'data/GO_Biological_Process_2026.txt')
    ))
))

# inspect the fragments before attaching anything
vapply(packet$fragments, function(f) f$fragment_id, character(1))
packet$fragments[[1]]

#---------------------------------------------------------
# build a violin of this module's activity across lv2_annot and attach it to
# the cluster_dme fragment specifically (looked up by fragment_id, since
# tool_config order isn't guaranteed to match packet$fragments order)
#---------------------------------------------------------

plot_df <- data.frame(
    score = module_scores(ms, module = cur_mod),
    lv2_annot = metadata(ms)$lv2_annot
)

p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = lv2_annot, y = score)) +
    ggplot2::geom_violin(fill = 'steelblue', alpha = 0.5) +
    ggplot2::theme_minimal() +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))

cluster_dme_idx <- which(vapply(packet$fragments, function(f) f$fragment_id, character(1)) == 'cluster_dme')
packet$fragments[[cluster_dme_idx]] <- attach_plots(packet$fragments[[cluster_dme_idx]], list(
    activity_violin = list(
        plot_obj = p,
        legend = paste0(cur_mod, ' activity score across lv2_annot cell states, showing which cell state most strongly expresses this module.'),
        placement = 'above'
    )
))

# only needed if you want the PNG persisted to disk alongside the packet
# (e.g. for a report rendered later from a re-read packet, see Part 2) --
# not required for the render below, since plot_obj is still live
# write_fragment_figures(packet, 'output/figures')

#---------------------------------------------------------
# synthesize via a live backend and render the report
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

# gemini-flash-latest -- gemini-2.5-flash (a fixed snapshot) came back "no
# longer available to new users" on this account, and the package default
# gemini-3.5-flash has NA pricing in ellmer::models_google_gemini() (likely
# preview-only); cached_backend() keys on packet_hash + provider + model +
# prompt version, so re-running this script over the same packet costs no
# additional call
gemini_model <- 'gemini-flash-latest'
backend <- cached_backend(
    resolve_backend('gemini', model = gemini_model), provider = 'gemini', model = gemini_model,
    prompt_template_version = PROMPT_TEMPLATE_VERSION
)
interp <- synthesize_interpretation(packet, desc, backend)

report_path <- write_interpretation_report(
    setNames(list(interp), packet$module_id),
    setNames(list(packet), packet$module_id),
    desc,
    output_file = 'output/report.html'
)

cat('report written to', report_path, '\n')
# open it and confirm: the violin card + italic legend sit ABOVE the
# cluster_dme evidence table only -- top_genes/geneset_enrichment render as
# plain tables with no figure card
