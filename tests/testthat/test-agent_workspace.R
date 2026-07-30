## agent workspace exporter, part 1 (docs/milestones/milestone_agent_workspace.md):
## serialization plumbing + read_agent_manifest() only. Offline, on
## llegir_example_moduleset() -- no template, no cheat-sheets, no
## export_agent_workspace() yet.

make_stub_workspace_dataset_context <- function(){
    frag <- dataset_fragment(
        fragment_id = 'composition',
        tool_id = 'stub_dataset_tool',
        type = 'composition_summary',
        result = data.frame(group = c('a', 'b'), n = c(5, 3)),
        compact_summary = 'across 8 cells: group a 62%, group b 38%',
        top_findings = list(list(group = 'a', n = 5)),
        provenance = make_provenance(tool_version = '0.1', pkg_versions = list(dummy = '1.0'))
    )
    build_dataset_context(list(frag), input_hash = 'abc')
}

make_stub_interpretation <- function(module_id){
    interpretation(
        module_id = module_id,
        proposed_label = 'test label',
        one_line_summary = 'test summary',
        dominant_biology = 'test biology',
        supporting_claims = list(),
        confidence = list(score = 0.5, model_score = 0.5, rationale = 'stub'),
        provenance = make_interpretation_provenance(
            model = 'mock', prompt_template_version = '0.1', temperature = 0, input_packet_hash = 'abc'
        )
    )
}

test_that('.scaffold_workspace() creates artifacts/ and scratch/', {
    out_dir <- tempfile()
    paths <- .scaffold_workspace(out_dir)
    expect_true(dir.exists(paths$art_dir))
    expect_true(dir.exists(paths$scratch_dir))
    expect_equal(paths$art_dir, file.path(out_dir, 'artifacts'))
    expect_equal(paths$scratch_dir, file.path(out_dir, 'scratch'))
})

test_that('.write_workspace_artifacts() round-trips a run to qs2 and json', {
    ms <- llegir_example_moduleset()
    ms_lite <- .make_moduleset_lite(ms)
    dctx <- make_stub_workspace_dataset_context()
    mod <- modules(ms)[1]
    packets <- run_orchestrator(ms, list(list(fn = top_genes_tool, params = list())),
                                output_dir = tempfile(), modules_use = mod)

    out_dir <- tempfile()
    scaffold <- .scaffold_workspace(out_dir)
    paths <- .write_workspace_artifacts(ms, ms_lite, dctx, packets, interps = NULL,
                                        scaffold$art_dir, write_json = TRUE)

    expect_true(validate_moduleset(qs2::qs_read(paths$moduleset_lite)))
    expect_true(validate_moduleset(qs2::qs_read(paths$moduleset_full)))
    expect_equal(qs2::qs_read(paths$dataset_context)$context_hash, dctx$context_hash)
    restored_packets <- qs2::qs_read(paths$packets)
    expect_true(validate_evidence_fragment(restored_packets[[mod]]$fragments[[1]]))

    expect_true(file.exists(paths$dataset_context_json))
    expect_true(dir.exists(paths$packets_dir_json))
    expect_true(file.exists(file.path(paths$packets_dir_json, paste0(mod, '.json'))))

    expect_null(paths$interpretations)
    expect_null(paths$interpretations_dir_json)
})

test_that('.write_workspace_artifacts() writes interpretation artifacts when interps is non-NULL', {
    ms <- llegir_example_moduleset()
    ms_lite <- .make_moduleset_lite(ms)
    dctx <- make_stub_workspace_dataset_context()
    mod <- modules(ms)[1]
    packets <- run_orchestrator(ms, list(list(fn = top_genes_tool, params = list())),
                                output_dir = tempfile(), modules_use = mod)
    interps <- list(make_stub_interpretation(mod))
    names(interps) <- mod

    out_dir <- tempfile()
    scaffold <- .scaffold_workspace(out_dir)
    paths <- .write_workspace_artifacts(ms, ms_lite, dctx, packets, interps,
                                        scaffold$art_dir, write_json = TRUE)

    expect_true(file.exists(paths$interpretations))
    restored <- qs2::qs_read(paths$interpretations)
    expect_equal(restored[[mod]]$module_id, mod)

    expect_true(dir.exists(paths$interpretations_dir_json))
    expect_true(file.exists(file.path(paths$interpretations_dir_json, paste0(mod, '.json'))))
})

test_that('.write_workspace_artifacts() skips the json mirror when write_json is FALSE', {
    ms <- llegir_example_moduleset()
    ms_lite <- .make_moduleset_lite(ms)
    dctx <- make_stub_workspace_dataset_context()
    mod <- modules(ms)[1]
    packets <- run_orchestrator(ms, list(list(fn = top_genes_tool, params = list())),
                                output_dir = tempfile(), modules_use = mod)

    out_dir <- tempfile()
    scaffold <- .scaffold_workspace(out_dir)
    paths <- .write_workspace_artifacts(ms, ms_lite, dctx, packets, interps = NULL,
                                        scaffold$art_dir, write_json = FALSE)

    expect_null(paths$dataset_context_json)
    expect_null(paths$packets_dir_json)
})

test_that('.hash_artifacts() returns a stable hash per file and NA for directories', {
    ms <- llegir_example_moduleset()
    ms_lite <- .make_moduleset_lite(ms)
    dctx <- make_stub_workspace_dataset_context()
    mod <- modules(ms)[1]
    packets <- run_orchestrator(ms, list(list(fn = top_genes_tool, params = list())),
                                output_dir = tempfile(), modules_use = mod)

    out_dir <- tempfile()
    scaffold <- .scaffold_workspace(out_dir)
    paths <- .write_workspace_artifacts(ms, ms_lite, dctx, packets, interps = NULL,
                                        scaffold$art_dir, write_json = TRUE)
    hashes <- .hash_artifacts(paths)

    expect_equal(hashes$moduleset_lite, digest::digest(file = paths$moduleset_lite, algo = 'sha256'))
    expect_true(is.na(hashes$packets_dir_json))
})

test_that('read_agent_manifest() recovers module_ids, artifacts, and capabilities', {
    manifest_path <- tempfile(fileext = '.md')
    writeLines(c(
        '---',
        "llegir_manifest_version: '0.2'",
        "workspace_root: '/abs/path/to/analysis'",
        'artifacts:',
        "  moduleset_lite: 'artifacts/moduleset_lite.qs2'",
        "  moduleset_full: 'artifacts/moduleset_full.qs2'",
        "  dataset_context: 'artifacts/dataset_context.qs2'",
        "  packets: 'artifacts/evidence_packets.qs2'",
        "capabilities: ['gene_weights', 'module_scores']",
        "module_ids: ['M1', 'M2']",
        "data_level: 'cell'",
        'aggregated: false',
        '---',
        '',
        '## Mission & Guardrails',
        '',
        'body text the parser must ignore'
    ), manifest_path)

    parsed <- read_agent_manifest(manifest_path)
    expect_equal(parsed$module_ids, c('M1', 'M2'))
    expect_equal(parsed$capabilities, c('gene_weights', 'module_scores'))
    expect_equal(parsed$artifacts$moduleset_lite, 'artifacts/moduleset_lite.qs2')
    expect_equal(parsed$workspace_root, '/abs/path/to/analysis')
    expect_equal(parsed$data_level, 'cell')
    expect_false(parsed$aggregated)
})

test_that('read_agent_manifest() errors when no front matter fences are found', {
    manifest_path <- tempfile(fileext = '.md')
    writeLines(c('# not a manifest', 'no front matter here'), manifest_path)
    expect_error(read_agent_manifest(manifest_path), 'no YAML front matter found')
})

#---------------------------------------------------------
# agent workspace: lite ModuleSet (part 4, task 1)
#---------------------------------------------------------

test_that('.make_moduleset_lite() passes validate_moduleset() and drops expression/counts', {
    ms <- llegir_example_moduleset()
    lite <- .make_moduleset_lite(ms)

    expect_true(validate_moduleset(lite))
    expect_s3_class(lite, 'components_ModuleSet')

    caps <- capabilities(lite)
    expect_false(caps[['expression']])
    expect_false(caps[['counts']])
    expect_true(caps[['module_scores']])
    expect_true(caps[['grouping']])
    expect_true(caps[['sample_ids']])
    expect_true(caps[['gene_weights']])

    expect_null(llegir::expression(lite))
    expect_null(counts(lite))
    expect_equal(modules(lite), modules(ms))
    expect_equal(nrow(gene_membership(lite, modules(ms)[1])), nrow(gene_membership(ms, modules(ms)[1])))
})

test_that('.make_moduleset_lite() is materially smaller serialized than the full object', {
    ms <- llegir_example_moduleset()
    lite <- .make_moduleset_lite(ms)

    full_path <- tempfile(fileext = '.qs2')
    lite_path <- tempfile(fileext = '.qs2')
    qs2::qs_save(ms, full_path)
    qs2::qs_save(lite, lite_path)

    expect_lt(file.size(lite_path), file.size(full_path) * 0.5)
})

test_that('.make_moduleset_lite() reports gene_weights FALSE when the source ms never declared real weights', {
    ms <- llegir_example_moduleset()
    class(ms) <- c('no_weights_test_ModuleSet', class(ms))
    capabilities.no_weights_test_ModuleSet <- function(ms, ...){
        caps <- NextMethod()
        caps['gene_weights'] <- FALSE
        caps
    }
    registerS3method('capabilities', 'no_weights_test_ModuleSet', capabilities.no_weights_test_ModuleSet)

    lite <- .make_moduleset_lite(ms)
    expect_false(capabilities(lite)[['gene_weights']])
})

#---------------------------------------------------------
# agent workspace: cheat-sheet generators (part 2)
#---------------------------------------------------------

# wraps the real example fixture rather than hand-rolling a minimal stub, so
# modules()/gene_membership()/module_scores() still dispatch (via NextMethod()
# fallthrough to synthetic_ModuleSet) -- only capabilities()$expression flips
make_no_expression_test_ms <- function(){
    ms <- llegir_example_moduleset()
    class(ms) <- c('no_expression_test_ModuleSet', class(ms))
    ms
}
capabilities.no_expression_test_ModuleSet <- function(ms, ...){
    caps <- NextMethod()
    caps['expression'] <- FALSE
    caps
}
registerS3method('capabilities', 'no_expression_test_ModuleSet', capabilities.no_expression_test_ModuleSet)

# llegir_example_moduleset() declares group_col = 'cell_type'; this strips it
# to simulate an adapter (e.g. hdWGCNA_ModuleSet) that reports the grouping
# capability without ever naming the backing column
make_no_group_col_test_ms <- function(){
    ms <- llegir_example_moduleset()
    ms$group_col <- NULL
    ms$sample_col <- NULL
    ms
}

test_that('.build_tool_cheatsheet() picks up a custom register_tool() call with no special-casing', {
    register_tool(
        'synthetic_cheatsheet_probe', top_genes_tool, type = 'ranked_genes',
        description = 'test probe for .build_tool_cheatsheet()', requires = 'pseudobulk'
    )
    on.exit(rm('synthetic_cheatsheet_probe', envir = .tool_registry), add = TRUE)

    ms <- llegir_example_moduleset()
    lite_caps <- capabilities(.make_moduleset_lite(ms))
    sheet <- .build_tool_cheatsheet(ms, lite_caps)
    ids <- vapply(sheet, `[[`, character(1), 'id')
    expect_true('synthetic_cheatsheet_probe' %in% ids)

    row <- sheet[[which(ids == 'synthetic_cheatsheet_probe')]]
    expect_equal(row$requires, 'pseudobulk')
    expect_false(row$runnable)
    expect_equal(
        row$invocation,
        "run_module(ms, module_ids[1], tool_config = list(list(id = 'synthetic_cheatsheet_probe')))"
    )
})

test_that('.build_tool_cheatsheet() marks a tool runnable when its requirements are met', {
    ms <- llegir_example_moduleset()
    lite_caps <- capabilities(.make_moduleset_lite(ms))
    sheet <- .build_tool_cheatsheet(ms, lite_caps)
    ids <- vapply(sheet, `[[`, character(1), 'id')
    top_genes_row <- sheet[[which(ids == 'top_genes')]]
    expect_true(top_genes_row$runnable)
    expect_equal(top_genes_row$requires, 'none')
})

test_that('.build_tool_cheatsheet() tags an expression-dependent row "(full object only)"', {
    ms <- llegir_example_moduleset()
    lite_caps <- capabilities(.make_moduleset_lite(ms))
    sheet <- .build_tool_cheatsheet(ms, lite_caps)
    ids <- vapply(sheet, `[[`, character(1), 'id')

    geneset_row <- sheet[[which(ids == 'geneset_enrichment')]]
    expect_true(grepl('(full object only)', geneset_row$requires, fixed = TRUE))

    # module_scores/grouping both survive into the lite object, so cluster_dme
    # should NOT be tagged
    cluster_row <- sheet[[which(ids == 'cluster_dme')]]
    expect_false(grepl('(full object only)', cluster_row$requires, fixed = TRUE))
})

test_that('.example_invocation() emits the dataset-tool form for scope == "dataset"', {
    ms <- llegir_example_moduleset()
    spec <- get_tool('composition')
    expect_equal(.example_invocation(spec, ms), "run_dataset_context(ms, list(list(id = 'composition')))")
})

test_that('.example_invocation() fills cluster_dme params$group_by with the real declared column', {
    ms <- llegir_example_moduleset()
    spec <- get_tool('cluster_dme')
    invocation <- .example_invocation(spec, ms)
    expect_true(grepl("group_by = 'cell_type'", invocation, fixed = TRUE))
    expect_false(grepl('cell_state', invocation, fixed = TRUE))
})

test_that('.example_invocation() omits cluster_dme params when no grouping column is declared', {
    ms <- make_no_group_col_test_ms()
    spec <- get_tool('cluster_dme')
    invocation <- .example_invocation(spec, ms)
    expect_equal(invocation, "run_module(ms, module_ids[1], tool_config = list(list(id = 'cluster_dme')))")
})

test_that('.build_api_cheatsheet() gates the expression row on capabilities()$expression', {
    full_ms <- llegir_example_moduleset()
    lite_caps <- capabilities(.make_moduleset_lite(full_ms))
    full_calls <- vapply(.build_api_cheatsheet(full_ms, lite_caps), `[[`, character(1), 'call')
    expect_true('dim(llegir::expression(ms))' %in% full_calls)

    no_expr_ms <- make_no_expression_test_ms()
    no_expr_lite_caps <- capabilities(.make_moduleset_lite(no_expr_ms))
    no_expr_calls <- vapply(.build_api_cheatsheet(no_expr_ms, no_expr_lite_caps), `[[`, character(1), 'call')
    expect_false('dim(llegir::expression(ms))' %in% no_expr_calls)
    expect_true('modules(ms)' %in% no_expr_calls)
})

test_that('.build_api_cheatsheet() tags the expression row "(full object only)"', {
    ms <- llegir_example_moduleset()
    lite_caps <- capabilities(.make_moduleset_lite(ms))
    rows <- .build_api_cheatsheet(ms, lite_caps)
    expr_row <- rows[[which(vapply(rows, `[[`, character(1), 'call') == 'dim(llegir::expression(ms))')]]
    expect_true(grepl('(full object only)', expr_row$note, fixed = TRUE))
})

test_that('.build_safe_recipes() drops the expression line and gates the deeper rungs', {
    full_ms <- llegir_example_moduleset()
    lite_caps <- capabilities(.make_moduleset_lite(full_ms))
    full_recipes <- .build_safe_recipes(full_ms, lite_caps)
    expect_true(grepl('dim\\(llegir::expression\\(ms\\)\\)', full_recipes[[1]]$code, fixed = FALSE))
    titles <- vapply(full_recipes, `[[`, character(1), 'title')
    expect_true('Aggregate-then-summarize' %in% titles)
    expect_true('Delegate to a registered tool' %in% titles)

    no_expr_ms <- make_no_expression_test_ms()
    no_expr_lite_caps <- capabilities(.make_moduleset_lite(no_expr_ms))
    no_expr_recipes <- .build_safe_recipes(no_expr_ms, no_expr_lite_caps)
    expect_false(grepl('dim\\(llegir::expression\\(ms\\)\\)', no_expr_recipes[[1]]$code, fixed = FALSE))
})

test_that('.build_safe_recipes() aggregate rung uses the real grouping column, not a hardcoded "cell_state"', {
    ms <- llegir_example_moduleset()
    lite_caps <- capabilities(.make_moduleset_lite(ms))
    recipes <- .build_safe_recipes(ms, lite_caps)
    titles <- vapply(recipes, `[[`, character(1), 'title')
    agg <- recipes[[which(titles == 'Aggregate-then-summarize')]]

    expect_true(grepl("metadata(ms)['cell_type']", agg$code, fixed = TRUE))
    expect_true(grepl('dplyr::group_by(cell_type)', agg$code, fixed = TRUE))
    expect_false(grepl('cell_state', agg$code, fixed = TRUE))
})

test_that('.build_safe_recipes() omits the aggregate rung when no grouping column is declared', {
    ms <- make_no_group_col_test_ms()
    lite_caps <- capabilities(.make_moduleset_lite(ms))
    recipes <- .build_safe_recipes(ms, lite_caps)
    titles <- vapply(recipes, `[[`, character(1), 'title')
    expect_false('Aggregate-then-summarize' %in% titles)
})

test_that('.build_safe_recipes() "delegate to a tool" rung uses named fragment access, not a positional index', {
    ms <- llegir_example_moduleset()
    lite_caps <- capabilities(.make_moduleset_lite(ms))
    recipes <- .build_safe_recipes(ms, lite_caps)
    titles <- vapply(recipes, `[[`, character(1), 'title')
    delegate <- recipes[[which(titles == 'Delegate to a registered tool')]]

    expect_false(grepl('fragments[[1]]', delegate$code, fixed = TRUE))
    expect_true(grepl('Filter(function(f) f$fragment_id ==', delegate$code, fixed = TRUE))
})

#---------------------------------------------------------
# agent workspace: template render + export_agent_workspace() (part 3)
#---------------------------------------------------------

make_full_workspace_run <- function(){
    ms <- llegir_example_moduleset()
    mod <- modules(ms)[1]
    packets <- run_orchestrator(ms, list(list(fn = top_genes_tool, params = list())),
                                output_dir = tempfile(), modules_use = mod)
    dctx <- make_stub_workspace_dataset_context()
    desc <- dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq', conditions = c('MS', 'control'))
    list(ms = ms, packets = packets, dctx = dctx, desc = desc, mod = mod)
}

test_that('export_agent_workspace() writes a manifest that round-trips via read_agent_manifest()', {
    run <- make_full_workspace_run()
    out_dir <- tempfile()

    dev_before <- length(grDevices::dev.list())
    manifest_path <- suppressMessages(
        export_agent_workspace(run$ms, run$dctx, run$packets, run$desc, out_dir = out_dir)
    )
    expect_equal(length(grDevices::dev.list()), dev_before)

    expect_true(file.exists(manifest_path))
    expect_equal(basename(manifest_path), '.llegir_agent_manifest.md')

    parsed <- read_agent_manifest(manifest_path)
    expect_equal(parsed$module_ids, modules(run$ms))
    expect_equal(parsed$capabilities, names(which(capabilities(run$ms))))
    expect_equal(parsed$data_level, run$ms$data_level)
    expect_equal(parsed$aggregated, run$ms$aggregated)
    expect_true(is.logical(parsed$aggregated))

    resolved <- lapply(parsed$artifacts, function(rel) file.path(parsed$workspace_root, rel))
    for (p in resolved) expect_true(file.exists(p) || dir.exists(p))

    expect_true(validate_moduleset(qs2::qs_read(resolved$moduleset_lite)))
    expect_true(validate_moduleset(qs2::qs_read(resolved$moduleset_full)))
    expect_false(capabilities(qs2::qs_read(resolved$moduleset_lite))[['expression']])
    expect_true(capabilities(qs2::qs_read(resolved$moduleset_full))[['expression']])
})

test_that('export_agent_workspace() writes interpretation artifacts when interps is supplied, all qs2-round-trippable', {
    run <- make_full_workspace_run()
    interps <- list(make_stub_interpretation(run$mod))
    names(interps) <- run$mod
    out_dir <- tempfile()

    manifest_path <- suppressMessages(
        export_agent_workspace(run$ms, run$dctx, run$packets, run$desc, interps = interps, out_dir = out_dir)
    )
    parsed <- read_agent_manifest(manifest_path)
    expect_true('interpretations' %in% names(parsed$artifacts))
    expect_true('interpretations_dir_json' %in% names(parsed$artifacts))

    resolved_interps <- file.path(parsed$workspace_root, parsed$artifacts$interpretations)
    restored <- qs2::qs_read(resolved_interps)
    expect_equal(restored[[run$mod]]$module_id, run$mod)

    manifest_txt <- paste(readLines(manifest_path), collapse = '\n')
    expect_false(grepl('No interpretations shipped', manifest_txt, fixed = TRUE))
})

test_that('export_agent_workspace() omits interpretation artifacts and flags none shipped when interps is NULL', {
    run <- make_full_workspace_run()
    out_dir <- tempfile()

    manifest_path <- suppressMessages(
        export_agent_workspace(run$ms, run$dctx, run$packets, run$desc, out_dir = out_dir)
    )
    expect_false(file.exists(file.path(out_dir, 'artifacts', 'interpretations.qs2')))

    parsed <- read_agent_manifest(manifest_path)
    expect_false('interpretations' %in% names(parsed$artifacts))

    manifest_txt <- paste(readLines(manifest_path), collapse = '\n')
    expect_true(grepl('No interpretations shipped', manifest_txt, fixed = TRUE))
})

test_that('export_agent_workspace() Data Topography tags the lite/full rows', {
    run <- make_full_workspace_run()
    out_dir <- tempfile()
    manifest_path <- suppressMessages(
        export_agent_workspace(run$ms, run$dctx, run$packets, run$desc, out_dir = out_dir)
    )
    manifest_txt <- paste(readLines(manifest_path), collapse = '\n')
    expect_true(grepl('moduleset_lite.*default -- load this', manifest_txt))
    expect_true(grepl('moduleset_full.*load only for expression\\(\\)/counts\\(\\) queries', manifest_txt))
})

test_that('export_agent_workspace() manifest names every registered tool in its Tool Registry Cheat-Sheet', {
    run <- make_full_workspace_run()
    out_dir <- tempfile()
    manifest_path <- suppressMessages(
        export_agent_workspace(run$ms, run$dctx, run$packets, run$desc, out_dir = out_dir)
    )
    manifest_txt <- paste(readLines(manifest_path), collapse = '\n')
    for (id in list_tools()) {
        expect_true(grepl(id, manifest_txt, fixed = TRUE), info = paste('missing tool id:', id))
    }
})

test_that('export_agent_workspace() picks up a newly registered tool with no manual sync', {
    run <- make_full_workspace_run()

    register_tool(
        'synthetic_export_probe', top_genes_tool, type = 'ranked_genes',
        description = 'test probe for export_agent_workspace()', requires = character(0)
    )
    on.exit(rm('synthetic_export_probe', envir = .tool_registry), add = TRUE)

    out_dir <- tempfile()
    manifest_path <- suppressMessages(
        export_agent_workspace(run$ms, run$dctx, run$packets, run$desc, out_dir = out_dir)
    )
    manifest_txt <- paste(readLines(manifest_path), collapse = '\n')
    expect_true(grepl('synthetic_export_probe', manifest_txt, fixed = TRUE))
})

test_that('export_agent_workspace() copies the query_example.R bootstrap and creates scratch/', {
    run <- make_full_workspace_run()
    out_dir <- tempfile()
    suppressMessages(export_agent_workspace(run$ms, run$dctx, run$packets, run$desc, out_dir = out_dir))

    expect_true(file.exists(file.path(out_dir, 'query_example.R')))
    expect_true(dir.exists(file.path(out_dir, 'scratch')))
})

test_that('export_agent_workspace() does not mutate its inputs', {
    run <- make_full_workspace_run()
    ms_before <- run$ms
    dctx_before <- run$dctx
    packets_before <- run$packets

    out_dir <- tempfile()
    suppressMessages(export_agent_workspace(run$ms, run$dctx, run$packets, run$desc, out_dir = out_dir))

    expect_identical(run$ms, ms_before)
    expect_identical(run$dctx, dctx_before)
    expect_identical(run$packets, packets_before)
})
