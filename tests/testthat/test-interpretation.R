## interpretation contract: construction, validation, JSON round-trip, hash
## determinism. No dependency on any backend or packet here.

make_valid_interpretation <- function(){
    interpretation(
        module_id = 'MM1',
        proposed_label = 'Border TAM / complement program',
        dominant_biology = 'Complement activation and synaptic pruning.',
        interpretation = 'The hub genes and enriched terms mark a complement and phagocytic program in border-associated macrophages.',
        supporting_claims = list(
            list(claim = 'Top genes include complement components.', fragment_ids = 'top_genes', direction = 'na'),
            list(claim = 'Enriched for synapse pruning and complement terms.', fragment_ids = 'geneset_enrichment', direction = 'up')
        ),
        confidence = list(score = 0.8, model_score = 0.8, rationale = 'Strong, convergent evidence.'),
        provenance = make_interpretation_provenance(
            model = 'mock', prompt_template_version = '0.1', temperature = 0, input_packet_hash = 'abc123'
        )
    )
}

test_that('validate_interpretation() rejects an invalid claim direction', {
    interp <- interpretation(
        module_id = 'MM1', proposed_label = 'x', dominant_biology = 'x', interpretation = 'x',
        supporting_claims = list(list(claim = 'x', fragment_ids = 'top_genes', direction = 'sideways')),
        confidence = list(score = 0.5, model_score = 0.5, rationale = 'x'),
        provenance = make_interpretation_provenance('mock', '0.1', 0, 'abc')
    )
    expect_error(validate_interpretation(interp), 'invalid supporting_claims\\$direction')
})

test_that('validate_interpretation() passes a well-formed interpretation', {
    expect_true(validate_interpretation(make_valid_interpretation()))
})

test_that('validate_interpretation() catches missing required fields', {
    interp <- make_valid_interpretation()
    interp$dominant_biology <- NULL
    expect_error(validate_interpretation(interp), 'missing required fields')
})

test_that('validate_interpretation() requires the interpretation prose field', {
    interp <- make_valid_interpretation()
    interp$interpretation <- NULL
    expect_error(validate_interpretation(interp), 'missing required fields')

    interp$interpretation <- c('two', 'strings')
    expect_error(validate_interpretation(interp), 'interpretation must be a single string')
})

test_that('validate_interpretation() rejects invalid flags', {
    interp <- make_valid_interpretation()
    interp$flags <- list('not_a_real_flag')
    expect_error(validate_interpretation(interp), 'invalid flags')
})

test_that('validate_interpretation() requires supporting_claims unless insufficient_evidence is flagged', {
    interp <- make_valid_interpretation()
    interp$supporting_claims <- list()
    expect_error(validate_interpretation(interp), 'insufficient_evidence')

    interp$flags <- list('insufficient_evidence')
    expect_true(validate_interpretation(interp))
})

test_that('validate_interpretation() catches a claim missing fragment_ids', {
    interp <- make_valid_interpretation()
    interp$supporting_claims[[1]]$fragment_ids <- NULL
    expect_error(validate_interpretation(interp), 'missing fields')
})

test_that('validate_interpretation() catches an out-of-range confidence score', {
    interp <- make_valid_interpretation()
    interp$confidence$score <- 1.5
    expect_error(validate_interpretation(interp), 'confidence\\$score')
})

test_that('validate_interpretation() catches malformed provenance', {
    interp <- make_valid_interpretation()
    interp$provenance$model <- NULL
    expect_error(validate_interpretation(interp), 'provenance missing fields')
})

test_that('interpretation JSON round-trip preserves fields, including single-element fragment_ids arrays', {
    interp <- make_valid_interpretation()
    restored <- interpretation_from_json(interpretation_to_json(interp))
    expect_equal(restored$module_id, interp$module_id)
    expect_equal(restored$proposed_label, interp$proposed_label)
    expect_equal(restored$interpretation, interp$interpretation)
    expect_equal(restored$supporting_claims[[1]]$fragment_ids, 'top_genes')
    expect_equal(restored$confidence$score, interp$confidence$score)
    expect_true(validate_interpretation(restored))
})

test_that('interpretation JSON round-trip preserves an empty flags/literature list', {
    interp <- make_valid_interpretation()
    restored <- interpretation_from_json(interpretation_to_json(interp))
    expect_equal(length(restored$flags), 0)
    expect_equal(length(restored$literature), 0)
})

test_that('interpretation_hash() is stable across reruns and ignores the provenance timestamp', {
    interp_a <- make_valid_interpretation()
    interp_b <- make_valid_interpretation()
    interp_b$provenance$timestamp <- '2099-01-01T00:00:00+0000'
    expect_equal(interpretation_hash(interp_a), interpretation_hash(interp_b))
})

test_that('write_interpretation()/read_interpretation() round-trip through disk', {
    interp <- make_valid_interpretation()
    tmp <- tempfile(fileext = '.json')
    on.exit(unlink(tmp))
    write_interpretation(interp, tmp)
    restored <- read_interpretation(tmp)
    expect_equal(restored$module_id, interp$module_id)
    expect_true(validate_interpretation(restored))
})

test_that('an interpretation without a review serializes exactly as under schema 0.2', {
    interp <- interpretation(
        module_id = 'MM1', proposed_label = 'x', dominant_biology = 'x', interpretation = 'x',
        supporting_claims = list(list(claim = 'c', fragment_ids = 'top_genes', direction = 'na')),
        confidence = list(score = 0.5, model_score = 0.5, rationale = 'r'),
        provenance = make_interpretation_provenance('mock', '1.3', 0, 'hash')
    )
    expect_equal(interp$schema_version, '0.2')
    expect_false('review' %in% names(interp))
    expect_false(grepl('review', interpretation_to_json(interp), fixed = TRUE))
})

test_that('an interpretation with a review is schema 0.3 and round-trips through JSON', {
    review <- list(
        evidence_tier = 'hub_genes',
        artifact_gate = list(status = 'pass', reasons = 'clean'),
        supporting_hubs = list(list(gene = 'A', kme = 0.9), list(gene = 'B', kme = 0.8), list(gene = 'C', kme = 0.7)),
        expected_markers = list(list(gene = 'D', present = FALSE)),
        contradicting_evidence = 'D absent',
        alternative_label = list(label = 'y', reason_rejected = 'z'),
        confidence_level = 'moderate',
        display_hubs = c('A', 'B', 'C')
    )
    interp <- interpretation(
        module_id = 'MM1', proposed_label = 'x', dominant_biology = 'x', interpretation = 'x',
        supporting_claims = list(list(claim = 'c', fragment_ids = 'top_genes', direction = 'na')),
        confidence = list(score = 0.6, model_score = 0.6, rationale = 'r'),
        provenance = make_interpretation_provenance('agent:test', '1.3', NA_real_, 'hash'),
        review = review
    )
    expect_equal(interp$schema_version, '0.3')
    expect_true(validate_interpretation(interp))

    back <- interpretation_from_json(interpretation_to_json(interp))
    expect_equal(back$review$display_hubs, c('A', 'B', 'C'))
    expect_equal(back$review$supporting_hubs[[2]]$kme, 0.8)
    expect_false(back$review$expected_markers[[1]]$present)
    expect_true(validate_interpretation(back))

    bad <- interp
    bad$review$confidence_level <- 'certain'
    expect_error(validate_interpretation(bad), 'confidence_level')
    bad <- interp
    bad$review$display_hubs <- c('A', 'B')
    expect_error(validate_interpretation(bad), 'exactly 3')
})
