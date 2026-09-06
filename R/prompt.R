## prompt assembly: evidence packet -> compact model input (docs/milestone_2.md
## task 1). Compact rendering only (compact_summary + top_findings +
## effect_strength/significance) -- never the raw `result` tables.

#' Prompt template version
#'
#' Bumped whenever the system prompt or the compact packet rendering shape
#' changes; recorded in `interpretation$provenance$prompt_template_version`
#' for reproducibility.
#'
#' @export
PROMPT_TEMPLATE_VERSION <- '0.9'

# a fragment's compact block: one header line (id/type/direction/effect/sig),
# the compact_summary, and up to `max_findings` top_findings as compact JSON;
# already-curated fragments (tools only keep the top few) rarely hit the cap,
# it's a backstop for token efficiency, not the primary truncation -- true for
# every core tool except top_genes_tool(), whose ranked_genes fragment
# deliberately carries the tool's full requested n_hubs (25 by default, often
# more), not "the top few"; capping it at the same max_findings as a 5-item
# signature list would silently hide lower-ranked-but-biologically-important
# hub genes from the model (confirmed doing exactly that for a real module:
# checkpoint/exhaustion markers ranked 9-16 by kME never reached the prompt),
# so ranked_genes fragments are exempt from the cap
.render_fragment_compact <- function(frag, max_findings = 8){
    sig <- if (is.null(frag$significance) || is.na(frag$significance)) 'NA' else format(frag$significance, digits = 4)
    header <- sprintf(
        '[%s] type=%s direction=%s effect_strength=%s significance=%s',
        frag$fragment_id, frag$type, frag$direction, format(frag$effect_strength, digits = 4), sig
    )
    findings <- if (identical(frag$type, 'ranked_genes')) frag$top_findings else utils::head(frag$top_findings, max_findings)
    findings_json <- jsonlite::toJSON(findings, auto_unbox = TRUE, na = 'null')
    paste(header, frag$compact_summary, paste0('top_findings: ', findings_json), sep = '\n')
}

#' Render an evidence packet as a compact model-facing text block
#'
#' Renders only the compact, curated fields of each fragment
#' (`compact_summary`, `top_findings`, `effect_strength`/`significance`) --
#' never the raw `result` tables -- so the prompt stays small and the model
#' only sees pre-summarized evidence.
#'
#' @param packet An evidence packet, as built by [build_evidence_packet()].
#' @param max_findings Maximum number of `top_findings` entries rendered per
#'   fragment; a token-efficiency backstop, since tools already curate
#'   `top_findings` to a handful of entries.
#' @return A single character string.
#' @examples
#' ms <- llegir_example_moduleset()
#' packet <- run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
#' cat(render_packet_compact(packet))
#' @export
render_packet_compact <- function(packet, max_findings = 8){
    blocks <- vapply(packet$fragments, .render_fragment_compact, character(1), max_findings = max_findings)

    # deterministic housekeeping-composition note, appended to the ranked_genes
    # block so a part-ribosomal/mitochondrial hub list is visible to the model
    # rather than silently diluting the biological call (R/confidence.R)
    note <- housekeeping_composition_note(packet)
    if (!is.null(note)) {
        hub_idx <- which(vapply(packet$fragments, function(f) identical(f$type, 'ranked_genes'), logical(1)))
        if (length(hub_idx) > 0) blocks[hub_idx[1]] <- paste0(blocks[hub_idx[1]], '\n', note)
    }

    paste0(
        'Module ', packet$module_id, ' evidence packet (', length(packet$fragments), ' fragments):\n\n',
        paste(blocks, collapse = '\n\n')
    )
}

# a dataset_fragment's compact block: mirrors .render_fragment_compact() but
# there's no direction/effect_strength/significance (dataset_fragment drops
# the fusion fields), and caveats are appended when present
.render_dataset_fragment_compact <- function(frag, max_findings = 8){
    header <- sprintf('[%s] type=%s', frag$fragment_id, frag$type)
    findings <- utils::head(frag$top_findings, max_findings)
    findings_json <- jsonlite::toJSON(findings, auto_unbox = TRUE, na = 'null')
    lines <- c(header, frag$compact_summary, paste0('top_findings: ', findings_json))
    if (length(frag$caveats) > 0) {
        lines <- c(lines, paste0('caveats: ', paste(unlist(frag$caveats), collapse = ', ')))
    }
    paste(lines, collapse = '\n')
}

#' Render a dataset context as a compact model-facing text block
#'
#' Renders only the compact, curated fields of each `dataset_fragment`
#' (`compact_summary`, `top_findings`, `caveats`) -- never the raw `result`
#' tables -- mirroring [render_packet_compact()]. Injected once per dataset
#' into every module's prompt via [build_user_prompt()]'s `dataset_context`
#' argument; unlike the per-module evidence packet, this block is global
#' framing and never enters fusion or faithfulness.
#'
#' @param dataset_context A dataset context, as built by [build_dataset_context()].
#' @param max_findings Maximum number of `top_findings` entries rendered per
#'   fragment. Default `8`.
#' @return A single character string.
#' @examples
#' frag <- dataset_fragment(
#'     'composition', 'dataset_composition_tool', 'composition_summary',
#'     data.frame(group = 'A', n = 10), 'One group, 10 cells.', list(),
#'     provenance = make_provenance('dataset_composition_tool', '0.1', list(), list(), NA_character_)
#' )
#' ctx <- build_dataset_context(list(frag))
#' cat(render_dataset_context_compact(ctx))
#' @export
render_dataset_context_compact <- function(dataset_context, max_findings = 8){
    blocks <- vapply(
        dataset_context$dataset_fragments, .render_dataset_fragment_compact,
        character(1), max_findings = max_findings
    )
    paste0(
        'DATASET CONTEXT (', length(dataset_context$dataset_fragments), ' fragments):\n\n',
        paste(blocks, collapse = '\n\n')
    )
}

#' Build the synthesis system prompt
#'
#' A fixed set of rules governing how a backend must fill the model-facing
#' interpretation schema: evidence-only claims, citation requirements,
#' direction consistency, controlled vocabularies, the empty-literature
#' constraint, and a self-calibrated `confidence.score`. The deterministic
#' fused evidence score is shelved (`docs/prompts/handoff_prompt_serpentine_tcell.md`
#' Part 4.5): the EVIDENCE CONFIDENCE MATRIX is no longer injected and the
#' model reports its own certainty, while [enforce_faithfulness()] and
#' [fuse_confidence()]'s `possible_artifact` check still set review flags.
#'
#' @return A single character string.
#' @examples
#' cat(build_system_prompt())
#' @export
build_system_prompt <- function(){
    paste(
        'You are filling a structured interpretation of one gene co-expression module',
        'from a fixed evidence packet produced by a deterministic analysis pipeline.',
        '',
        'Rules:',
        '- FIRST STEP, before drafting anything else: find the ranked_genes fragment (e.g. top_genes) and read its top_findings gene list. Using your own biological knowledge of those specific gene symbols, identify the single most specific cell state or program they mark as a set (e.g. a named checkpoint/exhaustion program, a cytotoxicity program, a naive/memory state, a proliferation program, a signaling pathway) -- this gene-identity call is the module\'s core biological identity and must anchor proposed_label and dominant_biology. Only after that, use the other fragments (state_expression, differential_module_activity, signature_correlation, geneset_enrichment, etc.) to add supporting context, cell-state localization, and condition dynamics around that identity -- never let a different fragment\'s numeric ranking override or replace the gene-identity call, and do not default to whichever fragment happens to report the single largest effect_strength number: a top-ranked item within one fragment\'s top_findings can reflect a small-sample statistical artifact rather than the module\'s dominant biology, so weigh a fragment\'s top_findings list as a whole rather than only its top-ranked entry.',
        '- Use only the evidence given below. Do not invent genes, terms, or results, and do not run or imagine any analysis.',
        '- Every entry in supporting_claims must cite the fragment_id(s) it is based on, and its direction must match the direction reported by those fragments.',
        '- A single supporting_claims entry may only cite fragment_ids that all share the same direction. ranked_genes fragments (e.g. top_genes) always report direction na, so never combine one in the same claim as a directional fragment (e.g. geneset_enrichment, direction up/down) -- cite them as separate supporting_claims entries instead, each using the direction its own fragment(s) actually report. Concrete example of what NOT to do: {"claim": "genes X/Y/Z indicate cytotoxicity, consistent with geneset_enrichment", "fragment_ids": ["top_genes", "geneset_enrichment"], "direction": "up"} is INVALID because top_genes reports direction na, not up. Instead write two entries: {"claim": "the module\'s hub genes (X, Y, Z) mark a cytotoxicity program", "fragment_ids": ["top_genes"], "direction": "na"} and {"claim": "consistent with this, geneset_enrichment shows cytotoxicity terms enriched", "fragment_ids": ["geneset_enrichment"], "direction": "up"}.',
        '- metadata_associations entries must cite a real fragment_id the same way.',
        '- Fill cell_state from a state_expression fragment when one is present (which cell state(s) the module is expressed in), and condition_dynamics from a cross_condition_delta fragment when one is present (how the module\'s activity shifts across the tested condition) -- leave either NA only when no such fragment is in the packet.',
        paste0('- Each fragment has a type from a controlled vocabulary: ', paste(.fragment_types, collapse = ', '), '.'),
        paste0('- flags must be drawn only from: ', paste(.interpretation_flags, collapse = ', '), '.'),
        '- If the evidence is weak, sparse, or inconsistent, do not invent a confident story: set flags to include insufficient_evidence, keep supporting_claims minimal (or empty), and give a low confidence score.',
        '- Set confidence.score (0 to 1) to your own calibrated certainty that proposed_label is the right call given only the evidence in this packet: high when several fragments converge on one identity, low when the packet is thin, the hub genes are non-specific, or the fragments disagree.',
        '- literature must be left empty; literature grounding is not available in this pipeline.',
        '- A DATASET CONTEXT block, when present, is global framing (composition, variance structure, and similar dataset-wide context) for confounder awareness -- it is not a per-module fragment, so never cite it in supporting_claims or metadata_associations.',
        sep = '\n'
    )
}

#' Build the synthesis user prompt for one module
#'
#' Concatenates the rendered [dataset_description()], the optional
#' [render_dataset_context_compact()] block, and the compact evidence packet
#' ([render_packet_compact()]). The deterministic EVIDENCE CONFIDENCE MATRIX
#' is no longer injected (Part 4.5: the fused score is shelved); the model
#' sets `confidence.score` from its own calibrated certainty.
#'
#' @param packet An evidence packet, as built by [build_evidence_packet()].
#' @param desc A `dataset_description`; see [dataset_description()].
#' @param fusion Ignored; retained for call-site compatibility. The fused
#'   evidence matrix is no longer part of the prompt.
#' @param data_level Observation-unit descriptor of the `ModuleSet` the
#'   packet was built from; see [render_dataset_description()]. Default `'cell'`.
#' @param aggregated Whether that `ModuleSet`'s expression/scores are already
#'   aggregated across cells; see [render_dataset_description()]. Default `FALSE`.
#' @param user_weights Ignored; retained for call-site compatibility.
#' @param dataset_context An optional dataset context, as built by
#'   [build_dataset_context()] / [run_dataset_context()]. Rendered via
#'   [render_dataset_context_compact()] between the dataset description and
#'   the evidence packet. `NULL` (default) omits the block entirely.
#' @return A single character string.
#' @examples
#' ms <- llegir_example_moduleset()
#' packet <- run_module(ms, modules(ms)[1], list(list(fn = top_genes_tool, params = list())))
#' desc <- dataset_description('human', 'CSF', 'myeloid', 'scRNA-seq')
#' cat(build_user_prompt(packet, desc))
#' @export
build_user_prompt <- function(packet, desc, fusion = NULL, data_level = 'cell', aggregated = FALSE,
                               user_weights = list(), dataset_context = NULL){
    dataset_block <- if (is.null(dataset_context)) NULL else render_dataset_context_compact(dataset_context)
    blocks <- Filter(Negate(is.null), list(
        render_dataset_description(desc, data_level = data_level, aggregated = aggregated),
        dataset_block,
        render_packet_compact(packet)
    ))
    paste(blocks, collapse = '\n\n')
}
