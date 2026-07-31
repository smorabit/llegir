## quick offline walkthrough of the plot-ingestion feature
## (docs/milestones/milestone_plot_ingestion.md): attach a live ggplot to a
## fragment, synthesize with the mock backend (no API calls), and render the
## HTML report to see the figure card show up next to the raw evidence table.
## conda activate hdWGCNA, then run this line-by-line.

#---------------------------------------------------------
# setup: load the package and the self-contained example fixture
#---------------------------------------------------------

devtools::load_all()

ms <- llegir_example_moduleset()
modules(ms)

cur_mod <- modules(ms)[1]

#---------------------------------------------------------
# run cluster_dme for one module -- group_by = 'cell_type' matches the
# fixture's declared grouping column (see .example_base_moduleset() in
# R/example_moduleset.R, group_col = 'cell_type')
#---------------------------------------------------------

packet <- run_module(ms, cur_mod, tool_config = list(
    list(id = 'cluster_dme', params = list(group_by = 'cell_type'))
))

# inspect the fragment before attaching anything
packet$fragments[[1]]

#---------------------------------------------------------
# build a violin of this module's activity across cell_type and attach it
#---------------------------------------------------------

plot_df <- data.frame(
    score = module_scores(ms, module = cur_mod),
    cell_type = metadata(ms)$cell_type
)

p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = cell_type, y = score)) +
    ggplot2::geom_violin(fill = 'steelblue', alpha = 0.5) +
    ggplot2::theme_minimal()

frag <- attach_plots(packet$fragments[[1]], list(
    activity_violin = list(
        plot_obj = p,
        legend = 'Module activity score across cell_type, showing which cell state most strongly expresses this module.',
        placement = 'above'
    )
))
packet$fragments[[1]] <- frag

# only needed if you want the PNG persisted to disk alongside the packet
# (e.g. for a report rendered later from a re-read packet, see Part 2) --
# not required for the render below, since plot_obj is still live
# write_fragment_figures(packet, 'output/figures')

#---------------------------------------------------------
# synthesize offline (mock backend, no API calls) and render the report
#---------------------------------------------------------

desc <- dataset_description(
    species = 'human',
    tissue = 'synthetic',
    cell_compartment = 'myeloid',
    assay = 'scRNA-seq',
    notes = 'llegir_example_moduleset() fixture -- for exercising the pipeline, not real biology.'
)

interp <- synthesize_interpretation(packet, desc, mock_backend())

report_path <- write_interpretation_report(
    setNames(list(interp), packet$module_id),
    setNames(list(packet), packet$module_id),
    desc,
    output_file = 'output/report.html'
)

cat('report written to', report_path, '\n')
# open it and confirm: the violin card + italic legend sit ABOVE the
# cluster_dme evidence table, and a plotless module (there isn't one in this
# packet) would render with no card at all
