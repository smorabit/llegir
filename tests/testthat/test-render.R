## paragraph renderer + review queue + manifest (docs/milestone_2.md tasks
## 5-7), and the synthesis-stage orchestrator (R/orchestrator.R) that ties
## synthesis + faithfulness + confidence fusion + output-writing together.
## Fixtures here are hand-built (not run through the real hdWGCNA tools) so
## this file stays fast and independent of the slow geneset_enrichment I/O
## exercised elsewhere (test-synthesis.R, test-confidence.R).

# a packet whose fragment_ids/directions match what mock_backend() cites
# ('hub_genes'/'na', 'geneset_enrichment'/'up'), so synthesize_module() on it
# is faithful without per-test wiring
make_render_packet <- function(module_id){
    hub <- evidence_fragment(
        fragment_id = 'hub_genes', tool_id = 'hub_genes', module_id = module_id, type = 'ranked_genes',
        result = data.frame(gene_name = c('AIF1', 'CD68', 'C1QA'), kme = c(0.9, 0.8, 0.7)),
        compact_summary = 'top hub genes', top_findings = list(), effect_strength = 0.9,
        direction = 'na', provenance = make_provenance('0.1')
    )
    enrich <- evidence_fragment(
        fragment_id = 'geneset_enrichment', tool_id = 'geneset_enrichment', module_id = module_id, type = 'geneset_enrichment',
        result = data.frame(term = c('complement activation', 'phagocytosis'), fdr = c(0.001, 0.01), ngenes = c(3, 2)),
        compact_summary = 'enriched terms', top_findings = list(), effect_strength = 8,
        significance = 0.001, direction = 'up', provenance = make_provenance('0.1')
    )
    build_evidence_packet(module_id, list(hub, enrich), input_hash = 'render_test')
}

make_render_interpretation <- function(module_id, packet_hash, model_score = 0.9){
    interpretation(
        module_id = module_id, proposed_label = 'Complement/phagocytic program', one_line_summary = 'x',
        dominant_biology = 'Complement activation and phagocytosis.',
        supporting_claims = list(
            list(claim = 'Hub genes include complement components.', fragment_ids = 'hub_genes', direction = 'na'),
            list(claim = 'Enriched for complement/phagocytosis terms.', fragment_ids = 'geneset_enrichment', direction = 'up')
        ),
        cell_state = 'microglia', condition_dynamics = 'elevated in glioblastoma',
        metadata_associations = list(list(variable = 'diagnosis', summary = 'higher in GBM', fragment_id = 'geneset_enrichment')),
        confidence = list(score = model_score, model_score = model_score, rationale = 'model self-report'),
        provenance = make_interpretation_provenance('mock', '0.1', 0, packet_hash)
    )
}

test_that('render_paragraph() is byte-identical across repeated calls on the same interpretation', {
    interp <- make_render_interpretation('MM1', 'abc')
    expect_identical(render_paragraph(interp), render_paragraph(interp))
})

test_that('render_paragraph() includes label, summary, claims, and confidence', {
    interp <- make_render_interpretation('MM1', 'abc')
    txt <- render_paragraph(interp)
    expect_true(grepl('Complement/phagocytic program', txt, fixed = TRUE))
    expect_true(grepl('MM1', txt, fixed = TRUE))
    expect_true(grepl('Primarily expressed in: microglia', txt, fixed = TRUE))
    expect_true(grepl('Condition dynamics: elevated in glioblastoma', txt, fixed = TRUE))
    expect_true(grepl('Hub genes include complement components', txt, fixed = TRUE))
    expect_true(grepl('Metadata associations:', txt, fixed = TRUE))
    expect_true(grepl(sprintf('Confidence: %.2f', interp$confidence$score), txt))
})

test_that('render_paragraph() omits optional sections when fields are NA/empty', {
    interp <- make_render_interpretation('MM1', 'abc')
    interp$cell_state <- NA_character_
    interp$condition_dynamics <- NA_character_
    interp$metadata_associations <- list()
    interp$supporting_claims <- list()
    interp$flags <- list('insufficient_evidence')
    txt <- render_paragraph(interp)
    expect_false(grepl('Primarily expressed in', txt, fixed = TRUE))
    expect_false(grepl('Condition dynamics', txt, fixed = TRUE))
    expect_false(grepl('Metadata associations', txt, fixed = TRUE))
    expect_false(grepl('Supporting evidence', txt, fixed = TRUE))
    expect_true(grepl('Flags: insufficient_evidence', txt, fixed = TRUE))
})

test_that('describe_flags() has a reason for every controlled-vocab flag', {
    for (flag in .interpretation_flags) {
        expect_true(nchar(describe_flags(list(flag))) > 0)
    }
})

test_that('build_review_queue() includes only flagged interpretations, sorted by confidence ascending', {
    clean <- make_render_interpretation('CLEAN', 'abc', model_score = 0.9)
    clean$confidence$score <- 0.9
    flagged_lo <- make_render_interpretation('FLAGGED_LO', 'abc', model_score = 0.2)
    flagged_lo$confidence$score <- 0.2
    flagged_lo$flags <- list('insufficient_evidence')
    flagged_hi <- make_render_interpretation('FLAGGED_HI', 'abc', model_score = 0.6)
    flagged_hi$confidence$score <- 0.6
    flagged_hi$flags <- list('tool_conflict')

    queue <- build_review_queue(list(a = clean, b = flagged_lo, c = flagged_hi, d = NULL))
    expect_equal(nrow(queue), 2)
    expect_equal(queue$module_id, c('FLAGGED_LO', 'FLAGGED_HI'))
    expect_true(all(nchar(queue$reason) > 0))
})

test_that('build_review_queue() returns a zero-row data.frame when nothing is flagged', {
    clean <- make_render_interpretation('CLEAN', 'abc')
    queue <- build_review_queue(list(a = clean))
    expect_equal(nrow(queue), 0)
})

test_that('write_review_queue() writes a readable TSV', {
    flagged <- make_render_interpretation('FLAGGED', 'abc')
    flagged$flags <- list('needs_human_review')
    tmp <- tempfile(fileext = '.tsv')
    on.exit(unlink(tmp))
    write_review_queue(list(a = flagged), tmp)
    df <- utils::read.delim(tmp, stringsAsFactors = FALSE)
    expect_equal(df$module_id, 'FLAGGED')
})

test_that('build_synthesis_manifest() summarizes counts, versions, and dataset description', {
    ok <- make_render_interpretation('OK', 'abc')
    flagged <- make_render_interpretation('FLAGGED', 'abc')
    flagged$flags <- list('insufficient_evidence')
    manifest <- build_synthesis_manifest(list(a = ok, b = flagged, c = NULL), csf_dataset_description())
    expect_equal(manifest$n_modules, 3)
    expect_equal(manifest$n_synthesized, 2)
    expect_equal(manifest$n_flagged, 1)
    expect_equal(manifest$prompt_template_version, PROMPT_TEMPLATE_VERSION)
    expect_equal(manifest$render_template_version, RENDER_TEMPLATE_VERSION)
    expect_true('mock' %in% unlist(manifest$models))
    expect_equal(manifest$dataset_description$species, 'human')
})

test_that('write_synthesis_manifest() writes valid JSON', {
    manifest <- build_synthesis_manifest(list(a = make_render_interpretation('OK', 'abc')), csf_dataset_description())
    tmp <- tempfile(fileext = '.json')
    on.exit(unlink(tmp))
    write_synthesis_manifest(manifest, tmp)
    parsed <- jsonlite::fromJSON(tmp, simplifyVector = FALSE)
    expect_equal(parsed$n_modules, 1)
})

test_that('synthesize_module() runs synthesis, faithfulness, and confidence fusion together', {
    packet <- make_render_packet('MM1')
    interp <- synthesize_module(packet, csf_dataset_description(), backend = mock_backend(), schema_path = test_schema_path)
    expect_true(validate_interpretation(interp))
    expect_equal(interp$module_id, 'MM1')
    # confidence$score must have been overwritten by fuse_confidence(), so it
    # differs from the mock backend's flat 0.5 self-report post-fusion
    expect_equal(interp$confidence$model_score, 0.5)
    expect_true(grepl('fusion:', interp$confidence$rationale, fixed = TRUE))
})

test_that('run_synthesis_orchestrator() writes per-module JSON/MD plus a review queue and manifest', {
    packets <- list(MOD_A = make_render_packet('MOD_A'), MOD_B = make_render_packet('MOD_B'))
    out_dir <- tempfile('synthesis_out')
    on.exit(unlink(out_dir, recursive = TRUE))

    interps <- run_synthesis_orchestrator(packets, csf_dataset_description(), backend = mock_backend(), output_dir = out_dir, schema_path = test_schema_path)

    expect_equal(length(interps), 2)
    expect_true(file.exists(file.path(out_dir, 'MOD_A.json')))
    expect_true(file.exists(file.path(out_dir, 'MOD_A.md')))
    expect_true(file.exists(file.path(out_dir, 'MOD_B.json')))
    expect_true(file.exists(file.path(out_dir, 'MOD_B.md')))
    expect_true(file.exists(file.path(out_dir, 'review_queue.tsv')))
    expect_true(file.exists(file.path(out_dir, 'manifest.json')))

    restored <- read_interpretation(file.path(out_dir, 'MOD_A.json'))
    expect_equal(restored$module_id, 'MOD_A')

    manifest <- jsonlite::fromJSON(file.path(out_dir, 'manifest.json'), simplifyVector = FALSE)
    expect_equal(manifest$n_synthesized, 2)
})

test_that('run_synthesis_orchestrator() isolates a per-module synthesis failure without failing the batch', {
    bad_backend <- function() function(system_prompt, user_prompt, schema_json) stop('backend exploded')
    packets <- list(MOD_A = make_render_packet('MOD_A'), MOD_B = NULL)
    out_dir <- tempfile('synthesis_out')
    on.exit(unlink(out_dir, recursive = TRUE))

    expect_warning(
        interps <- run_synthesis_orchestrator(packets, csf_dataset_description(), backend = bad_backend(), output_dir = out_dir, schema_path = test_schema_path),
        'synthesis failed'
    )
    expect_true(is.null(interps$MOD_A))
    expect_true(is.null(interps$MOD_B))
    expect_false(file.exists(file.path(out_dir, 'MOD_A.json')))
    expect_true(file.exists(file.path(out_dir, 'review_queue.tsv')))
})
