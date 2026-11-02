## quick walkthrough of the plot-ingestion feature
## (docs/milestones/milestone_plot_ingestion.md) against the real CSF dataset
## (see scripts/interactive_test.Rmd for more on this object): run a small
## evidence toolbox over modules MM1-MM3, attach a live ggplot to each
## module's cluster_dme fragment only, synthesize via a live backend (Gemini
## here -- GitHub Models was down for a scheduled retirement brownout;
## cached so a repeat run doesn't re-spend budget), and render the HTML
## report to see each figure card show up next to its module's raw evidence
## table.
## conda activate hdWGCNA, then run this line-by-line.

#---------------------------------------------------------
# setup: load the package and the real CSF hdWGCNA object
#---------------------------------------------------------

devtools::load_all()

data_path <- 'data/CSF_Myeloid_hdWGCNA.rds'
seurat_obj <- readRDS(data_path)

ms <- hdWGCNA_ModuleSet(seurat_obj)
modules(ms)

modules_use <- modules(ms)[1:3]

#---------------------------------------------------------
# gemini-flash-latest -- gemini-2.5-flash (a fixed snapshot) came back "no
# longer available to new users" on this account, and the package default
# gemini-3.5-flash has NA pricing in ellmer::models_google_gemini() (likely
# preview-only); cached_backend() keys on packet_hash + provider + model +
# prompt version, so re-running this script over the same packets costs no
# additional call -- three modules means three live calls the first time
# through, none on repeat runs
#---------------------------------------------------------

gemini_model <- 'gemini-flash-latest'
backend <- cached_backend(
    resolve_backend('gemini', model = gemini_model), provider = 'gemini', model = gemini_model,
    prompt_template_version = PROMPT_TEMPLATE_VERSION
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
# gather evidence for all three modules -- top 25 hub genes, cluster_dme
# (group_by = 'lv2_annot', the cell-state annotation column on this dataset,
# same one scripts/interactive_test.Rmd uses), and GO enrichment. run_orchestrator()
# rather than a manual run_module() loop: it validates ms up front, isolates
# one module's tool failure (warn + NULL, not an uncaught error killing the
# whole run) instead of the bare loop having no error handling at all, and
# writes each raw packet to output_dir for free
#---------------------------------------------------------

packets <- run_orchestrator(
    ms,
    tool_config = list(
        list(id = 'top_genes', params = list(n_hubs = 25)),
        list(id = 'cluster_dme', params = list(group_by = 'lv2_annot')),
        list(id = 'geneset_enrichment', params = list(
            n_hubs = 25,
            db_files = c(GO_BP = 'data/GO_Biological_Process_2026.txt')
        ))
    ),
    output_dir = 'output/plot_ingestion_example/evidence_packets',
    modules_use = modules_use
)

# inspect one module's fragments before moving on
vapply(packets[[modules_use[1]]]$fragments, function(f) f$fragment_id, character(1))

#---------------------------------------------------------
# attach a beeswarm + boxplot of activity to each module's cluster_dme
# fragment only -- no orchestrator hook for this, since a plot isn't part of
# any tool's output, so this is a separate pass over the returned packets
#---------------------------------------------------------

for (cur_mod in modules_use) {
    packet <- packets[[cur_mod]]

    # points as a beeswarm, boxplot drawn on top (no fill, no duplicate
    # outlier points) so the quartile summary reads clearly over the swarm
    plot_df <- data.frame(
        score = module_scores(ms, module = cur_mod),
        lv2_annot = metadata(ms)$lv2_annot
    )

    p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = lv2_annot, y = score)) +
        ggbeeswarm::geom_quasirandom(ggplot2::aes(color = lv2_annot), alpha = 0.5, cex = 0.6, width=0.35, method='pseudorandom') +
        ggplot2::geom_boxplot(fill = NA, outlier.shape = NA, width = 0.3) +
        ggplot2::theme_minimal() +
        ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)) + Seurat::NoLegend()

    cluster_dme_idx <- which(vapply(packet$fragments, function(f) f$fragment_id, character(1)) == 'cluster_dme')
    packet$fragments[[cluster_dme_idx]] <- attach_plots(packet$fragments[[cluster_dme_idx]], list(
        activity_beeswarm = list(
            plot_obj = p,
            legend = paste0(cur_mod, ' activity score across lv2_annot cell states, showing which cell state most strongly expresses this module.'),
            placement = 'above'
        )
    ))

    # only needed if you want the PNGs persisted to disk alongside the packet
    # (e.g. for a report rendered later from a re-read packet, see Part 2) --
    # not required for the render below, since plot_obj is still live
    # write_fragment_figures(packet, 'output/figures')
    packets[[cur_mod]] <- packet
}

#---------------------------------------------------------
# synthesize the whole batch -- run_synthesis_orchestrator() (not the raw
# synthesize_interpretation() per module) so each interpretation goes through
# the full pipeline: calculate_fusion_score()/fuse_confidence() (blends the
# model's self-reported confidence with deterministic evidence strength, not
# just the raw model score) and enforce_faithfulness() (every claimed
# fragment_id/direction is checked against the packet); one module's
# synthesis failure is warned and recorded as NULL rather than aborting the
# whole run, and review_queue.tsv/manifest.json land in output_dir for free
#---------------------------------------------------------

interps <- run_synthesis_orchestrator(packets, desc, backend, output_dir = 'output/plot_ingestion_example/interpretations')

# inspect one module's interpretation before rendering
interps[[modules_use[1]]]

#---------------------------------------------------------
# render the combined report
#---------------------------------------------------------

report_path <- write_interpretation_report(interps, packets, desc, output_file = 'output/report.html')

cat('report written to', report_path, '\n')
# open it and confirm: each of MM1-MM3 gets a beeswarm+boxplot card ABOVE its
# cluster_dme evidence table only -- top_genes/geneset_enrichment render as
# plain tables with no figure card
