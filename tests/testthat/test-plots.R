## plots slot: .validate_plots(), .strip_plot_objs(), attach_plots(). Uses a
## fake structure(list(), class = 'ggplot') object to exercise the inherits()
## path without a ggplot2 dependency. testthat isolates each test file, so
## make_valid_fragment() / make_valid_dataset_fragment() are local copies of
## the sibling helpers in test-fragment.R / test-dataset_fragment.R rather
## than shared across files.

fake_plot <- function(){
    structure(list(), class = 'ggplot')
}

make_valid_fragment <- function(){
    evidence_fragment(
        fragment_id = 'dummy',
        tool_id = 'dummy_tool',
        module_id = 'MM1',
        type = 'ranked_genes',
        result = data.frame(gene = c('A', 'B'), score = c(0.9, 0.5)),
        compact_summary = 'top genes: A, B',
        top_findings = list(list(gene = 'A', score = 0.9)),
        effect_strength = 0.9,
        significance = 0.01,
        direction = 'up',
        provenance = make_provenance(tool_version = '0.1', pkg_versions = list(dummy = '1.0'))
    )
}

make_valid_dataset_fragment <- function(){
    dataset_fragment(
        fragment_id = 'composition',
        tool_id = 'dataset_composition_tool',
        type = 'composition_summary',
        result = data.frame(group = c('myeloid', 'lymphoid'), n_cells = c(120, 80)),
        compact_summary = 'across 200 cells: myeloid 60%, lymphoid 40%',
        top_findings = list(list(group = 'myeloid', n_cells = 120)),
        caveats = list('cell_state_imbalanced_across_condition'),
        provenance = make_provenance(tool_version = '0.1', pkg_versions = list(dummy = '1.0'))
    )
}

test_that('.validate_plots() passes NULL/empty on both fragment types', {
    expect_true(.validate_plots(NULL, 'evidence_fragment'))
    expect_true(.validate_plots(list(), 'evidence_fragment'))
})

test_that('.validate_plots() passes a well-formed plots slot', {
    plots <- list(
        activity_violin = list(
            plot_obj = fake_plot(),
            legend = 'Module activity across cell states.',
            placement = 'below'
        )
    )
    expect_true(.validate_plots(plots, 'evidence_fragment'))
})

test_that('.validate_plots() rejects an unnamed list', {
    plots <- list(list(plot_obj = fake_plot(), legend = 'no id'))
    expect_error(.validate_plots(plots, 'evidence_fragment'), 'named list')
})

test_that('.validate_plots() rejects a spec with neither plot_obj nor image_path', {
    plots <- list(bad_spec = list(legend = 'missing payload'))
    expect_error(.validate_plots(plots, 'evidence_fragment'), 'plot_obj or image_path')
})

test_that('.validate_plots() accepts a stripped image_path-only spec', {
    plots <- list(
        activity_violin = list(image_path = 'MM1/dummy__activity_violin.png', legend = 'persisted figure')
    )
    expect_true(.validate_plots(plots, 'evidence_fragment'))
})

test_that('.validate_plots() rejects a non-graphic plot_obj', {
    plots <- list(bad_spec = list(plot_obj = 'not a plot'))
    expect_error(.validate_plots(plots, 'evidence_fragment'), 'supported graphics object')
})

test_that('.validate_plots() rejects a non-scalar legend', {
    plots <- list(bad_spec = list(plot_obj = fake_plot(), legend = c('one', 'two')))
    expect_error(.validate_plots(plots, 'evidence_fragment'), 'legend must be a single string')
})

test_that('.validate_plots() rejects an invalid placement', {
    plots <- list(bad_spec = list(plot_obj = fake_plot(), placement = 'sideways'))
    expect_error(.validate_plots(plots, 'evidence_fragment'), 'placement must be')
})

test_that('.strip_plot_objs() drops plot_obj and leaves a plotless fragment unchanged', {
    frag <- make_valid_fragment()
    expect_identical(.strip_plot_objs(frag), frag)

    frag$plots <- list(activity_violin = list(plot_obj = fake_plot(), legend = 'a figure'))
    stripped <- .strip_plot_objs(frag)
    expect_null(stripped$plots$activity_violin$plot_obj)
    expect_equal(stripped$plots$activity_violin$legend, 'a figure')
})

test_that('a fragment with no plots validates exactly as before on both types', {
    expect_true(validate_evidence_fragment(make_valid_fragment()))
    expect_true(validate_dataset_fragment(make_valid_dataset_fragment()))
})

test_that('attach_plots() round-trips and re-validates an evidence_fragment', {
    frag <- make_valid_fragment()
    plots <- list(activity_violin = list(plot_obj = fake_plot(), legend = 'a figure', placement = 'above'))
    decorated <- attach_plots(frag, plots)
    expect_true(inherits(decorated, 'evidence_fragment'))
    expect_true(validate_evidence_fragment(decorated))
    expect_identical(decorated$plots$activity_violin$plot_obj, fake_plot())
})

test_that('attach_plots() round-trips and re-validates a dataset_fragment', {
    frag <- make_valid_dataset_fragment()
    plots <- list(composition_bar = list(plot_obj = fake_plot(), legend = 'cell composition'))
    decorated <- attach_plots(frag, plots)
    expect_true(inherits(decorated, 'dataset_fragment'))
    expect_true(validate_dataset_fragment(decorated))
})

test_that('attach_plots() propagates a malformed spec at attach time', {
    frag <- make_valid_fragment()
    plots <- list(bad_spec = list(legend = 'missing payload'))
    expect_error(attach_plots(frag, plots), 'plot_obj or image_path')
})

test_that('attach_plots() rejects an object that is neither fragment type', {
    not_a_fragment <- list(plots = NULL)
    expect_error(
        attach_plots(not_a_fragment, list(x = list(plot_obj = fake_plot()))),
        'evidence_fragment or dataset_fragment'
    )
})

test_that('fragment_to_json() strips plot_obj but keeps the legend', {
    frag <- attach_plots(make_valid_fragment(), list(
        activity_violin = list(plot_obj = fake_plot(), legend = 'a figure', placement = 'above')
    ))
    json <- fragment_to_json(frag)
    expect_false(grepl('plot_obj', json))
    expect_true(grepl('a figure', json))
})

test_that('.fragment_hashable() is stable across sessions and sensitive to legend text', {
    make_frag <- function(legend){
        attach_plots(make_valid_fragment(), list(
            activity_violin = list(plot_obj = fake_plot(), legend = legend, placement = 'below')
        ))
    }
    hash_of <- function(frag) digest::digest(.fragment_hashable(frag), algo = 'sha256')

    frag_a <- make_frag('legend text')
    frag_b <- make_frag('legend text')
    frag_c <- make_frag('different legend text')

    expect_equal(hash_of(frag_a), hash_of(frag_b))
    expect_false(hash_of(frag_a) == hash_of(frag_c))
})

test_that('.dataset_fragment_hashable() is stable across sessions and sensitive to legend text', {
    make_frag <- function(legend){
        attach_plots(make_valid_dataset_fragment(), list(
            composition_bar = list(plot_obj = fake_plot(), legend = legend)
        ))
    }
    hash_of <- function(frag) digest::digest(.dataset_fragment_hashable(frag), algo = 'sha256')

    frag_a <- make_frag('legend text')
    frag_b <- make_frag('legend text')
    frag_c <- make_frag('different legend text')

    expect_equal(hash_of(frag_a), hash_of(frag_b))
    expect_false(hash_of(frag_a) == hash_of(frag_c))
})

test_that('fragment JSON round-trip preserves plots (already-persisted spec)', {
    frag <- attach_plots(make_valid_fragment(), list(
        activity_violin = list(
            plot_obj = fake_plot(), image_path = 'MM1/dummy__activity_violin.png',
            legend = 'a figure', placement = 'above'
        )
    ))
    restored <- fragment_from_json(fragment_to_json(frag))
    expect_null(restored$plots$activity_violin$plot_obj)
    expect_equal(restored$plots$activity_violin$legend, 'a figure')
    expect_equal(restored$plots$activity_violin$image_path, 'MM1/dummy__activity_violin.png')
    expect_equal(restored$plots$activity_violin$placement, 'above')
    expect_true(validate_evidence_fragment(restored))
})

test_that('evidence_packet JSON round-trip preserves plots on a mix of plotted and plotless fragments', {
    frag_with_plots <- attach_plots(make_valid_fragment(), list(
        activity_violin = list(
            plot_obj = fake_plot(), image_path = 'MM1/dummy__activity_violin.png', legend = 'a figure'
        )
    ))
    frag_no_plots <- make_valid_fragment()
    frag_no_plots$fragment_id <- 'metadata::diagnosis'
    packet <- build_evidence_packet('MM1', list(frag_with_plots, frag_no_plots), input_hash = 'abc')

    tmp <- tempfile(fileext = '.json')
    on.exit(unlink(tmp))
    write_evidence_packet(packet, tmp)
    restored <- read_evidence_packet(tmp)

    expect_equal(restored$fragments[[1]]$plots$activity_violin$legend, 'a figure')
    expect_null(restored$fragments[[1]]$plots$activity_violin$plot_obj)
    expect_true(validate_evidence_fragment(restored$fragments[[1]]))
    expect_null(restored$fragments[[2]]$plots)
    expect_true(validate_evidence_fragment(restored$fragments[[2]]))
})

test_that('dataset_context JSON round-trip preserves plots on a mix of plotted and plotless fragments', {
    frag_with_plots <- attach_plots(make_valid_dataset_fragment(), list(
        composition_bar = list(plot_obj = fake_plot(), image_path = 'composition.png', legend = 'a figure')
    ))
    frag_no_plots <- make_valid_dataset_fragment()
    frag_no_plots$fragment_id <- 'baseline'
    context <- build_dataset_context(list(frag_with_plots, frag_no_plots), input_hash = 'abc')

    tmp <- tempfile(fileext = '.json')
    on.exit(unlink(tmp))
    write_dataset_context(context, tmp)
    restored <- read_dataset_context(tmp)

    expect_equal(restored$dataset_fragments[[1]]$plots$composition_bar$legend, 'a figure')
    expect_null(restored$dataset_fragments[[1]]$plots$composition_bar$plot_obj)
    expect_true(validate_dataset_fragment(restored$dataset_fragments[[1]]))
    expect_null(restored$dataset_fragments[[2]]$plots)
    expect_true(validate_dataset_fragment(restored$dataset_fragments[[2]]))
})

test_that('save_plot_to_png() renders a ggplot to a real PNG file', {
    testthat::skip_if_not_installed('ggplot2')
    p <- ggplot2::ggplot(data.frame(x = 1:3, y = 1:3), ggplot2::aes(x, y)) + ggplot2::geom_point()
    tmp <- tempfile(fileext = '.png')
    on.exit(unlink(tmp))
    save_plot_to_png(p, tmp, width = 4, height = 3, dpi = 72)
    expect_true(file.exists(tmp))
    expect_gt(file.size(tmp), 0)
})

test_that('write_fragment_figures() materializes live plots and records image_path', {
    testthat::skip_if_not_installed('ggplot2')
    p <- ggplot2::ggplot(data.frame(x = 1:3, y = 1:3), ggplot2::aes(x, y)) + ggplot2::geom_point()
    frag_with_plots <- attach_plots(make_valid_fragment(), list(
        activity_violin = list(plot_obj = p, legend = 'a figure')
    ))
    frag_no_plots <- make_valid_fragment()
    frag_no_plots$fragment_id <- 'metadata::diagnosis'
    packet <- build_evidence_packet('MM1', list(frag_with_plots, frag_no_plots), input_hash = 'abc')

    tmp_dir <- tempfile()
    on.exit(unlink(tmp_dir, recursive = TRUE))
    result <- write_fragment_figures(packet, tmp_dir)

    expected_path <- file.path(tmp_dir, 'MM1', 'dummy__activity_violin.png')
    expect_true(file.exists(expected_path))
    expect_equal(result$fragments[[1]]$plots$activity_violin$image_path, expected_path)
    expect_null(result$fragments[[2]]$plots)
})
