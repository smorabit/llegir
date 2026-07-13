## prompt assembly: evidence packet -> compact model input (docs/milestone_2.md
## task 1). Compact rendering only (compact_summary + top_findings +
## effect_strength/significance) -- never the raw `result` tables.

# bump whenever the system prompt or rendering shape changes; recorded in
# interpretation$provenance$prompt_template_version for reproducibility
PROMPT_TEMPLATE_VERSION <- '0.2'

# a fragment's compact block: one header line (id/type/direction/effect/sig),
# the compact_summary, and up to `max_findings` top_findings as compact JSON;
# already-curated fragments (tools only keep the top few) rarely hit the cap,
# it's a backstop for token efficiency, not the primary truncation
.render_fragment_compact <- function(frag, max_findings = 8){
    sig <- if (is.null(frag$significance) || is.na(frag$significance)) 'NA' else format(frag$significance, digits = 4)
    header <- sprintf(
        '[%s] type=%s direction=%s effect_strength=%s significance=%s',
        frag$fragment_id, frag$type, frag$direction, format(frag$effect_strength, digits = 4), sig
    )
    findings <- utils::head(frag$top_findings, max_findings)
    findings_json <- jsonlite::toJSON(findings, auto_unbox = TRUE, na = 'null')
    paste(header, frag$compact_summary, paste0('top_findings: ', findings_json), sep = '\n')
}

render_packet_compact <- function(packet, max_findings = 8){
    blocks <- vapply(packet$fragments, .render_fragment_compact, character(1), max_findings = max_findings)
    paste0(
        'Module ', packet$module_id, ' evidence packet (', length(packet$fragments), ' fragments):\n\n',
        paste(blocks, collapse = '\n\n')
    )
}

build_system_prompt <- function(){
    paste(
        'You are filling a structured interpretation of one gene co-expression module',
        'from a fixed evidence packet produced by a deterministic analysis pipeline.',
        '',
        'Rules:',
        '- Use only the evidence given below. Do not invent genes, terms, or results, and do not run or imagine any analysis.',
        '- Every entry in supporting_claims must cite the fragment_id(s) it is based on, and its direction must match the direction reported by those fragments.',
        '- A single supporting_claims entry may only cite fragment_ids that all share the same direction. ranked_genes fragments (e.g. hub_genes) always report direction na, so never combine one in the same claim as a directional fragment (e.g. geneset_enrichment, direction up/down) -- cite them as separate supporting_claims entries instead, each using the direction its own fragment(s) actually report.',
        '- metadata_associations entries must cite a real fragment_id the same way.',
        paste0('- Each fragment has a type from a controlled vocabulary: ', paste(.fragment_types, collapse = ', '), '.'),
        paste0('- flags must be drawn only from: ', paste(.interpretation_flags, collapse = ', '), '.'),
        '- If the evidence is weak, sparse, or inconsistent, do not invent a confident story: set flags to include insufficient_evidence, keep supporting_claims minimal (or empty), and give a low confidence score.',
        '- confidence.score is your own calibrated estimate in [0, 1] of how well-supported proposed_label is by the evidence below.',
        '- literature must be left empty; literature grounding is not available in this pipeline.',
        sep = '\n'
    )
}

build_user_prompt <- function(packet, desc){
    paste(
        render_dataset_description(desc),
        '',
        render_packet_compact(packet),
        sep = '\n'
    )
}
