## interpretation contract: constructor, validator, JSON (de)serialization.
## docs/schemas.md, inst/schemas/interpretation.schema.json

.interpretation_flags <- c(
    'insufficient_evidence', 'needs_human_review', 'possible_artifact',
    'tool_conflict', 'label_low_specificity'
)

#' Construct an interpretation object
#'
#' One module's filled schema, produced by the synthesis layer
#' ([synthesize_interpretation()]) from a fixed evidence packet.
#' `confidence$score` equals `confidence$model_score` (the deterministic
#' fused blend is shelved as of Part 4.5; [fuse_confidence()] now only adds
#' review flags and leaves the score alone); `provenance` is attached by the
#' orchestrator, never by the model itself.
#'
#' @param module_id The module this interpretation describes.
#' @param proposed_label Short program name, e.g. `'Interferon response'`.
#' @param dominant_biology The main program, as a short label.
#' @param interpretation 1-3 sentences of prose supporting the
#'   `dominant_biology` call, grounded in the cited fragments; folds in where
#'   the module is expressed and how its activity shifts across the tested
#'   condition where relevant.
#' @param supporting_claims A list of claims, each
#'   `list(claim, fragment_ids, direction, strength)`.
#' @param confidence A confidence list: `list(score, model_score, rationale)`.
#' @param provenance A provenance list, typically built with
#'   [make_interpretation_provenance()].
#' @param literature A list of `list(statement, pmids)`. Always empty in the
#'   current synthesis layer.
#' @param flags A subset of the flag vocabulary: `'insufficient_evidence'`,
#'   `'needs_human_review'`, `'possible_artifact'`, `'tool_conflict'`,
#'   `'label_low_specificity'`.
#' @param review Optional structured self-review (schema 0.3), attached by
#'   an agent labelling run (see [export_agent_workspace()] with
#'   `mode = 'label'`); `NULL` (default) for LLM synthesis.
#' @param schema_version Schema version tag. Defaults to `'0.2'`, or `'0.3'`
#'   when `review` is supplied (the only 0.3 addition).
#' @return An `interpretation` object.
#' @export
interpretation <- function(module_id, proposed_label, dominant_biology, interpretation,
                            supporting_claims, confidence, provenance,
                            literature = list(), flags = list(), review = NULL,
                            schema_version = if (is.null(review)) '0.2' else '0.3'){
    interp <- list(
        module_id = module_id,
        proposed_label = proposed_label,
        dominant_biology = dominant_biology,
        interpretation = interpretation,
        supporting_claims = supporting_claims,
        literature = literature,
        confidence = confidence,
        flags = flags
    )
    # added only when present, so an interpretation without one serializes and
    # hashes exactly as it did under schema 0.2
    if (!is.null(review)) interp$review <- review
    interp$provenance <- provenance
    interp$schema_version <- schema_version
    structure(interp, class = 'interpretation')
}

#' Build an interpretation's provenance record
#'
#' @param model Model identifier (e.g. `'mock'`, a provider model id).
#' @param prompt_template_version Version of the system/user prompt template used.
#' @param temperature Sampling temperature used for the model call.
#' @param input_packet_hash The evidence packet's `packet_hash`.
#' @param model_version Provider-reported model version, if available.
#' @param seed Sampling seed, if available.
#' @param ellmer_call Arbitrary named list of backend call bookkeeping (e.g. token counts).
#' @return A provenance list suitable for [interpretation()]'s `provenance` argument.
#' @export
make_interpretation_provenance <- function(model, prompt_template_version, temperature,
                                            input_packet_hash, model_version = NA_character_,
                                            seed = NA_real_, ellmer_call = list()){
    list(
        model = model,
        model_version = model_version,
        prompt_template_version = prompt_template_version,
        temperature = temperature,
        seed = seed,
        input_packet_hash = input_packet_hash,
        ellmer_call = ellmer_call,
        timestamp = format(Sys.time(), '%Y-%m-%dT%H:%M:%S%z')
    )
}

#' Validate an interpretation object
#'
#' Asserts required fields and basic shape against
#' `inst/schemas/interpretation.schema.json`. Faithfulness (fragment_ids exist
#' in the packet, direction matches) is a separate check against the packet
#' (see [check_faithfulness()]), not enforced here.
#'
#' @param interp An `interpretation` object.
#' @return `TRUE`, invisibly, on success. Throws on the first violation.
#' @export
validate_interpretation <- function(interp){
    required <- c(
        'module_id', 'proposed_label', 'dominant_biology', 'interpretation',
        'supporting_claims', 'confidence', 'provenance'
    )
    missing_fields <- setdiff(required, names(interp))
    if (length(missing_fields) > 0) {
        stop('interpretation missing required fields: ', paste(missing_fields, collapse = ', '))
    }
    if (!inherits(interp, 'interpretation')) stop('object is not class interpretation')
    if (!is.character(interp$module_id) || length(interp$module_id) != 1) stop('module_id must be a single string')
    if (!is.character(interp$proposed_label) || length(interp$proposed_label) != 1) stop('proposed_label must be a single string')
    if (!is.character(interp$dominant_biology) || length(interp$dominant_biology) != 1) stop('dominant_biology must be a single string')
    if (!is.character(interp$interpretation) || length(interp$interpretation) != 1) stop('interpretation must be a single string')

    flags <- interp$flags
    if (is.null(flags)) flags <- list()
    flags <- unlist(flags)
    if (length(flags) > 0 && !all(flags %in% .interpretation_flags)) {
        stop('invalid flags: ', paste(setdiff(flags, .interpretation_flags), collapse = ', '))
    }

    if (!is.list(interp$supporting_claims)) stop('supporting_claims must be a list')
    if (length(interp$supporting_claims) == 0 && !('insufficient_evidence' %in% flags)) {
        stop('supporting_claims may only be empty when flags includes insufficient_evidence')
    }
    for (claim in interp$supporting_claims) {
        claim_required <- c('claim', 'fragment_ids', 'direction')
        claim_missing <- setdiff(claim_required, names(claim))
        if (length(claim_missing) > 0) stop('supporting_claims entry missing fields: ', paste(claim_missing, collapse = ', '))
        if (!is.character(claim$claim) || length(claim$claim) != 1) stop('supporting_claims$claim must be a single string')
        if (!is.character(claim$fragment_ids) || length(claim$fragment_ids) == 0) stop('supporting_claims$fragment_ids must be a non-empty character vector')
        if (!(claim$direction %in% .direction_types)) stop('invalid supporting_claims$direction: ', claim$direction)
    }

    if (!is.list(interp$literature)) stop('literature must be a list')
    for (lit in interp$literature) {
        lit_required <- c('statement', 'pmids')
        lit_missing <- setdiff(lit_required, names(lit))
        if (length(lit_missing) > 0) stop('literature entry missing fields: ', paste(lit_missing, collapse = ', '))
    }

    confidence <- interp$confidence
    if (!is.list(confidence)) stop('confidence must be a list')
    conf_required <- c('score', 'model_score', 'rationale')
    conf_missing <- setdiff(conf_required, names(confidence))
    if (length(conf_missing) > 0) stop('confidence missing fields: ', paste(conf_missing, collapse = ', '))
    if (!is.numeric(confidence$score) || confidence$score < 0 || confidence$score > 1) stop('confidence$score must be a number in [0, 1]')
    if (!is.numeric(confidence$model_score) || confidence$model_score < 0 || confidence$model_score > 1) stop('confidence$model_score must be a number in [0, 1]')
    if (!is.character(confidence$rationale) || length(confidence$rationale) != 1) stop('confidence$rationale must be a single string')

    if (!is.null(interp$review)) .validate_review(interp$review)

    provenance <- interp$provenance
    if (!is.list(provenance)) stop('provenance must be a list')
    prov_required <- c('model', 'prompt_template_version', 'temperature', 'input_packet_hash', 'timestamp')
    prov_missing <- setdiff(prov_required, names(provenance))
    if (length(prov_missing) > 0) stop('interpretation provenance missing fields: ', paste(prov_missing, collapse = ', '))

    invisible(TRUE)
}

# parsed JSON (simplifyVector = FALSE) gives display_hubs as a list; the
# object carries a character vector, whichever door the review came in by
.normalize_review <- function(review){
    if (is.null(review)) return(NULL)
    review$display_hubs <- unlist(review$display_hubs)
    review
}

# shape check for the optional review block (inst/schemas/interpretation.schema.json);
# whether its genes, kMEs and marker calls are TRUE is checked against the
# ModuleSet by check_agent_labels(), not here
.review_tiers <- c('hub_genes', 'geneset_enrichment', 'technical_artifact', 'insufficient')
.review_gate_status <- c('pass', 'technical', 'uncertain')
.review_confidence_levels <- c('high', 'moderate', 'low', 'very_low')

.validate_review <- function(review){
    if (!is.list(review)) stop('review must be a list')
    required <- c('evidence_tier', 'artifact_gate', 'supporting_hubs', 'expected_markers',
                  'contradicting_evidence', 'alternative_label', 'confidence_level', 'display_hubs')
    missing_fields <- setdiff(required, names(review))
    if (length(missing_fields) > 0) stop('review missing fields: ', paste(missing_fields, collapse = ', '))

    is_string <- function(x) is.character(x) && length(x) == 1
    if (!(is_string(review$evidence_tier) && review$evidence_tier %in% .review_tiers)) {
        stop('review$evidence_tier must be one of: ', paste(.review_tiers, collapse = ', '))
    }
    if (!(is_string(review$artifact_gate$status) && review$artifact_gate$status %in% .review_gate_status)) {
        stop('review$artifact_gate$status must be one of: ', paste(.review_gate_status, collapse = ', '))
    }
    if (!is_string(review$artifact_gate$reasons)) stop('review$artifact_gate$reasons must be a single string')
    if (!(is_string(review$confidence_level) && review$confidence_level %in% .review_confidence_levels)) {
        stop('review$confidence_level must be one of: ', paste(.review_confidence_levels, collapse = ', '))
    }
    if (!is_string(review$contradicting_evidence)) stop('review$contradicting_evidence must be a single string')
    if (!is_string(review$alternative_label$label) || !is_string(review$alternative_label$reason_rejected)) {
        stop('review$alternative_label needs a label and a reason_rejected string')
    }

    if (!is.list(review$supporting_hubs) || length(review$supporting_hubs) < 3) stop('review$supporting_hubs needs at least 3 genes')
    for (hub in review$supporting_hubs) {
        if (!is_string(hub$gene) || !is.numeric(hub$kme) || length(hub$kme) != 1) stop('each review$supporting_hubs entry needs a gene and a numeric kme')
    }
    if (!is.list(review$expected_markers) || length(review$expected_markers) < 1) stop('review$expected_markers needs at least 1 gene')
    for (marker in review$expected_markers) {
        if (!is_string(marker$gene) || !is.logical(marker$present) || length(marker$present) != 1) stop('each review$expected_markers entry needs a gene and a logical present')
    }
    display_hubs <- unlist(review$display_hubs)
    if (!is.character(display_hubs) || length(display_hubs) != 3) stop('review$display_hubs must be exactly 3 genes')
    invisible(TRUE)
}

# strip volatile fields (timestamps) before hashing so identical interpretations
# hash identically across reruns, same convention as .fragment_hashable()
.interpretation_hashable <- function(interp){
    interp$provenance$timestamp <- NULL
    unclass(interp)
}

#' Hash an interpretation
#'
#' @param interp An `interpretation` object.
#' @return A sha256 hash string, stable across reruns (volatile fields like
#'   timestamps are stripped before hashing).
#' @export
interpretation_hash <- function(interp){
    digest::digest(.interpretation_hashable(interp), algo = 'sha256')
}

# character-vector fields that must stay JSON arrays even at length 0/1;
# jsonlite's auto_unbox otherwise collapses a length-1 vector to a scalar
.boxed_arrays <- function(interp){
    interp$flags <- I(unlist(interp$flags) %||% character(0))
    interp$supporting_claims <- lapply(interp$supporting_claims, function(claim){
        claim$fragment_ids <- I(claim$fragment_ids)
        claim
    })
    interp$literature <- lapply(interp$literature, function(lit){
        lit$pmids <- I(unlist(lit$pmids) %||% character(0))
        lit
    })
    if (!is.null(interp$review)) interp$review$display_hubs <- I(unlist(interp$review$display_hubs))
    interp
}

#' Serialize an interpretation to JSON
#'
#' @param interp An `interpretation` object.
#' @param pretty Pretty-print the JSON. Default `TRUE`.
#' @return A JSON string (a `jsonlite::json` scalar).
#' @export
interpretation_to_json <- function(interp, pretty = TRUE){
    jsonlite::toJSON(unclass(.boxed_arrays(interp)), auto_unbox = TRUE, na = 'null', pretty = pretty)
}

#' Parse an interpretation from JSON
#'
#' Inverse of [interpretation_to_json()]; rebuilds the `interpretation` class.
#'
#' @param json_str A JSON string as produced by [interpretation_to_json()].
#' @return An `interpretation` object.
#' @export
interpretation_from_json <- function(json_str){
    parsed <- jsonlite::fromJSON(json_str, simplifyDataFrame = FALSE, simplifyVector = FALSE)
    to_claim <- function(claim){
        list(
            claim = claim$claim,
            fragment_ids = unlist(claim$fragment_ids),
            direction = claim$direction %||% 'na',
            strength = claim$strength %||% NA_real_
        )
    }
    interpretation(
        module_id = parsed$module_id,
        proposed_label = parsed$proposed_label,
        dominant_biology = parsed$dominant_biology,
        interpretation = parsed$interpretation,
        supporting_claims = lapply(parsed$supporting_claims, to_claim),
        confidence = parsed$confidence,
        provenance = parsed$provenance,
        literature = parsed$literature %||% list(),
        flags = unlist(parsed$flags) %||% list(),
        review = .normalize_review(parsed$review),
        schema_version = parsed$schema_version %||% '0.2'
    )
}

#' Write an interpretation to a JSON file
#'
#' @param interp An `interpretation` object.
#' @param path Output file path.
#' @return `path`, invisibly.
#' @export
write_interpretation <- function(interp, path){
    writeLines(interpretation_to_json(interp), path)
    invisible(path)
}

#' Read an interpretation from a JSON file
#'
#' @param path Path to an interpretation JSON file.
#' @return An `interpretation` object.
#' @export
read_interpretation <- function(path){
    interpretation_from_json(paste(readLines(path, warn = FALSE), collapse = '\n'))
}
