## write_interpretation_report(): argument handling for the optional
## dataset_context, plus a rendered-report smoke test for the
## "Dataset-level evidence" section (skipped when pandoc is unavailable).

make_report_interp <- function(module_id){
    interpretation(
        module_id = module_id, proposed_label = 'Test program',
        dominant_biology = 'Test biology.',
        interpretation = 'A short grounded interpretation for the report smoke test.',
        supporting_claims = list(
            list(claim = 'Hub genes claim.', fragment_ids = 'top_genes', direction = 'na')
        ),
        confidence = list(score = 0.7, model_score = 0.7, rationale = 'test'),
        provenance = make_interpretation_provenance('mock', '0.1', 0, 'hash')
    )
}

make_report_packet <- function(module_id){
    top <- evidence_fragment(
        fragment_id = 'top_genes', tool_id = 'top_genes', module_id = module_id, type = 'ranked_genes',
        result = data.frame(gene_name = c('A', 'B'), kme = c(0.9, 0.8)),
        compact_summary = 'top genes', top_findings = list(list(gene = 'A', kme = 0.9)),
        effect_strength = 0.9, direction = 'na', provenance = make_provenance('0.1')
    )
    build_evidence_packet(module_id, list(top), input_hash = 'report_test')
}

make_dataset_ctx_with_plot <- function(png_path){
    frag <- dataset_fragment(
        'composition', 'dataset_composition_tool', 'composition_summary',
        data.frame(group = c('a', 'b'), n = c(6, 4)),
        'across 10 cells: group a 60%, group b 40%',
        list(list(group = 'a', n = 6), list(group = 'b', n = 4)),
        provenance = make_provenance('dataset_composition_tool', '0.1', list(), list(), NA_character_)
    )
    frag <- attach_plots(frag, list(
        composition_umap = list(image_path = png_path, legend = 'A dataset-level UMAP figure.', placement = 'below')
    ))
    build_dataset_context(list(frag), input_hash = 'ctx_hash')
}

test_that('write_interpretation_report() rejects a malformed dataset_context', {
    expect_error(
        write_interpretation_report(list(), list(), csf_dataset_description(),
                                    dataset_context = list(not_fragments = 1)),
        'dataset_context'
    )
})

test_that('write_interpretation_report() renders the dataset-level evidence section only when a context is passed', {
    skip_if_not(rmarkdown::pandoc_available(), 'pandoc not available')

    interps <- list(MOD_A = make_report_interp('MOD_A'))
    packets <- list(MOD_A = make_report_packet('MOD_A'))
    desc <- csf_dataset_description()

    png_path <- tempfile(fileext = '.png')
    grDevices::png(png_path, width = 400, height = 300)
    graphics::par(mar = c(2, 2, 1, 1)); graphics::plot(1:3, 1:3)
    grDevices::dev.off()

    out_dir <- tempfile('report_out'); dir.create(out_dir)
    on.exit(unlink(c(out_dir, png_path), recursive = TRUE), add = TRUE)

    with_ctx <- file.path(out_dir, 'with_ctx.html')
    write_interpretation_report(interps, packets, desc,
                                dataset_context = make_dataset_ctx_with_plot(png_path),
                                output_file = with_ctx)
    html_with <- paste(readLines(with_ctx, warn = FALSE), collapse = '\n')
    expect_true(grepl('Dataset-level evidence', html_with, fixed = TRUE))
    expect_true(grepl('composition', html_with, fixed = TRUE))
    expect_true(grepl('A dataset-level UMAP figure.', html_with, fixed = TRUE))
    expect_true(grepl('data:image/png;base64', html_with, fixed = TRUE))

    without_ctx <- file.path(out_dir, 'without_ctx.html')
    write_interpretation_report(interps, packets, desc, output_file = without_ctx)
    html_without <- paste(readLines(without_ctx, warn = FALSE), collapse = '\n')
    expect_false(grepl('Dataset-level evidence', html_without, fixed = TRUE))
})
