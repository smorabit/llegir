## agent labelling mode (export_agent_workspace(mode = 'label')): an external
## terminal coding agent writes the same model-facing interpretation JSON the
## synthesis LLM would fill (model_output_schema_json()), one file per module
## under <workspace>/labels/. agent_label_backend() replays those files through
## the standard backend contract (R/synthesis.R), so an agent's labels pass
## through exactly the post-processing an LLM's do: validate_interpretation(),
## enforce_faithfulness() (including the significance-wording check) and
## fuse_confidence(). Nothing here calls a model.
##
## Label mode also requires the interpretation's optional `review` block
## (schema 0.3) and checks it against the ModuleSet itself: supporting hubs
## must be real top hubs with the kME stated, "absent" markers must really be
## absent, display hubs must follow the figure convention, the confidence
## score must sit in its rubric band, and no two modules may share a label.

# the immediate-early / heat-shock genes of the dissociation-stress signature
# the label-mode artifact gate screens for
.dissociation_stress_genes <- c(
    'FOS', 'FOSB', 'JUN', 'JUNB', 'EGR1', 'ATF3', 'IER2', 'IER3', 'NR4A1', 'ZFP36',
    'DUSP1', 'HSPA1A', 'HSPA1B', 'DNAJB1', 'HSPH1', 'BAG3'
)

# classic qPCR/normalization reference genes: reviewers read them as depth
# artifacts, so they may never be a module's figure display hubs
.display_hub_excluded <- c('GAPDH', 'ACTB', 'ACTG1', 'PPIA', 'RPLP0', 'TBP', 'HPRT1', 'GUSB', 'YWHAZ', 'UBC')

# anchored rubric: confidence$score must sit inside its level's band
.confidence_bands <- list(
    high = c(0.75, 0.95),
    moderate = c(0.5, 0.75),
    low = c(0.25, 0.5),
    very_low = c(0, 0.25)
)

# label-mode hub ranks: supporting evidence from the top 25, display from the top 10
.review_max_support_rank <- 25
.review_max_display_rank <- 10

# gene family for the "no two display hubs from one family" rule: the symbol
# up to its first digit or hyphen (HLA-A/HLA-B -> HLA, RPL13/RPL13A -> RPL,
# COX7B/COX5A -> COX). A heuristic, so it only ever asks for a revision.
.gene_family <- function(genes) sub('[-0-9].*$', '', genes)

# a module's genes ranked by kME, highest first (the gene_membership() contract)
.ranked_module_genes <- function(ms, module_id){
    gm <- gene_membership(ms, module_id)
    gm[order(-gm$kme), c('gene_name', 'kme')]
}

# top-decile share of the single most frequent sample (e.g. patient): how far
# a module's activity is carried by one sample. NULL when the ModuleSet has no
# module scores or no such column.
.top_decile_sample_share <- function(ms, module_id, sample_col){
    if (is.null(sample_col) || !has_capability(ms, 'module_scores')) return(NULL)
    md <- metadata(ms)
    if (!(sample_col %in% colnames(md))) return(NULL)
    scores <- module_scores(ms)[[module_id]]
    high <- scores >= stats::quantile(scores, 0.9, na.rm = TRUE)
    counts <- sort(table(md[[sample_col]][high]), decreasing = TRUE)
    list(sample = names(counts)[1], share = as.numeric(counts[1]) / sum(counts), n_samples = length(unique(md[[sample_col]])))
}

#' Artifact screen for one module (label mode)
#'
#' The deterministic inputs to the label-mode artifact gate, rendered as a
#' text block appended to each module's `label_evidence` file: module size,
#' how many of the dissociation-stress (immediate-early / heat-shock) genes
#' sit among the top hubs and in the whole module, and, when `sample_col`
#' names a metadata column (e.g. patient), how much of the module's top-decile
#' activity comes from a single sample. Not an evidence fragment: it may
#' inform the gate but is never cited in `supporting_claims`.
#'
#' @param ms A `ModuleSet`.
#' @param module_id The module to screen.
#' @param sample_col Optional metadata column (e.g. `'Patient'`) for the
#'   single-sample share. Default `NULL` skips that line.
#' @return A single character string.
#' @keywords internal
.label_artifact_screen <- function(ms, module_id, sample_col = NULL){
    ranked <- .ranked_module_genes(ms, module_id)
    top_hubs <- utils::head(ranked$gene_name, .review_max_support_rank)
    stress_top <- intersect(top_hubs, .dissociation_stress_genes)
    stress_all <- intersect(ranked$gene_name, .dissociation_stress_genes)

    lines <- c(
        paste0('[artifact_screen] computed by llegir for the label-mode artifact gate; not an evidence fragment, never cite it in supporting_claims'),
        paste0('module size in this ModuleSet: ', nrow(ranked), ' genes'),
        paste0(
            'dissociation-stress genes (immediate-early / heat-shock, ', length(.dissociation_stress_genes), ' screened): ',
            length(stress_top), ' of the top ', length(top_hubs), ' hubs',
            if (length(stress_top)) paste0(' (', paste(stress_top, collapse = ', '), ')') else '',
            '; ', length(stress_all), ' in the whole module',
            if (length(stress_all)) paste0(' (', paste(stress_all, collapse = ', '), ')') else ''
        )
    )
    share <- .top_decile_sample_share(ms, module_id, sample_col)
    if (!is.null(share)) {
        lines <- c(lines, sprintf(
            'top-decile cells by module score: %.1f%% from one %s (%s) of %d',
            100 * share$share, sample_col, share$sample, share$n_samples
        ))
    }
    paste(lines, collapse = '\n')
}

#' Backend that replays agent-written label files
#'
#' A synthesis backend (see [mock_backend()] for the contract) whose "model
#' output" is a JSON file an external coding agent wrote to
#' `labels_dir/<module_id>.json` in a workspace exported with
#' `export_agent_workspace(mode = 'label')`. The packet a call is for is
#' resolved from `packet_hash`, so this plugs into [synthesize_module()] and
#' [run_synthesis_orchestrator()] unchanged.
#'
#' @param labels_dir Directory holding one `<module_id>.json` per module, each
#'   filling the model-facing schema ([model_output_schema_json()]).
#' @param packets The named list of evidence packets the labels describe.
#' @param agent Short name of the agent that wrote the labels, recorded on
#'   each interpretation's provenance as `model = 'agent:<agent>'`.
#' @return A backend function.
#' @examples
#' \dontrun{
#' backend <- agent_label_backend('agent_workspace/labels', packets, agent = 'claude-code')
#' synthesize_module(packets[[1]], desc, backend)
#' }
#' @export
agent_label_backend <- function(labels_dir, packets, agent = 'coding-agent'){
    module_by_hash <- stats::setNames(names(packets), vapply(packets, function(p) p$packet_hash, character(1)))

    function(system_prompt, user_prompt, schema_json, packet_hash = NA_character_){
        module_id <- unname(module_by_hash[packet_hash])
        if (length(module_id) != 1 || is.na(module_id)) {
            stop('agent_label_backend: no packet with hash ', packet_hash)
        }
        label_path <- file.path(labels_dir, paste0(module_id, '.json'))
        if (!file.exists(label_path)) stop('no agent label file for ', module_id, ' (expected ', label_path, ')')

        content <- tryCatch(
            jsonlite::read_json(label_path, simplifyVector = FALSE),
            error = function(e) stop('could not parse ', label_path, ': ', conditionMessage(e), call. = FALSE)
        )
        # synthesize_interpretation() forces module_id from the packet, so a
        # label written under the wrong filename would otherwise be silently
        # re-keyed onto a module it doesn't describe
        if (!identical(content$module_id, module_id)) {
            stop(label_path, ' has module_id ', content$module_id %||% 'NULL', ', expected ', module_id)
        }

        list(
            content = content,
            meta = list(
                model = paste0('agent:', agent),
                model_version = NA_character_,
                ellmer_call = list(backend = 'agent_labels', label_file = normalizePath(label_path))
            )
        )
    }
}

# everything a label check needs, read from a workspace exported with
# mode = 'label'; artifact paths resolve against workspace_dir (not the
# recorded workspace_root) so a moved or copied workspace still works
.read_label_workspace <- function(workspace_dir){
    manifest <- read_agent_manifest(file.path(workspace_dir, '.llegir_agent_manifest.md'))
    if (!identical(manifest$mode, 'label')) {
        stop('workspace was not exported with mode = "label": ', workspace_dir)
    }
    artifact_path <- function(key) file.path(workspace_dir, manifest$artifacts[[key]])
    list(
        manifest = manifest,
        ms = qs2::qs_read(artifact_path('moduleset_lite')),
        packets = qs2::qs_read(artifact_path('packets')),
        dataset_context = qs2::qs_read(artifact_path('dataset_context')),
        desc = qs2::qs_read(artifact_path('dataset_description')),
        labels_dir = file.path(workspace_dir, manifest$labels_dir)
    )
}

# the label-mode review checks for one module, against the ModuleSet itself;
# returns a character vector of problems (empty when the review holds up)
.review_issues <- function(interp, ms, notes_path){
    review <- interp$review
    ranked <- .ranked_module_genes(ms, interp$module_id)
    rank_of <- function(gene) match(gene, ranked$gene_name)
    issues <- character(0)

    for (hub in review$supporting_hubs) {
        r <- rank_of(hub$gene)
        if (is.na(r)) {
            issues <- c(issues, sprintf('supporting hub %s is not in this module', hub$gene))
        } else if (r > .review_max_support_rank) {
            issues <- c(issues, sprintf('supporting hub %s is rank %d, outside the top %d', hub$gene, r, .review_max_support_rank))
        } else if (abs(hub$kme - ranked$kme[r]) > 0.01) {
            issues <- c(issues, sprintf('supporting hub %s has kME %.3f, not %.3f', hub$gene, ranked$kme[r], hub$kme))
        }
    }

    # the falsification step is only worth anything if the absences are real
    for (marker in review$expected_markers) {
        in_module <- marker$gene %in% ranked$gene_name
        if (!identical(in_module, isTRUE(marker$present))) {
            issues <- c(issues, sprintf('expected marker %s is %s this module, not %s', marker$gene,
                                        if (in_module) 'in' else 'absent from', if (isTRUE(marker$present)) 'present' else 'absent'))
        }
    }

    display <- unlist(review$display_hubs)
    for (gene in display) {
        r <- rank_of(gene)
        if (is.na(r) || r > .review_max_display_rank) {
            issues <- c(issues, sprintf('display hub %s is not in the top %d hubs', gene, .review_max_display_rank))
        }
    }
    excluded <- intersect(display, .display_hub_excluded)
    if (length(excluded)) issues <- c(issues, paste('display hubs include housekeeping normalizers:', paste(excluded, collapse = ', ')))
    families <- .gene_family(display)
    if (anyDuplicated(families)) {
        issues <- c(issues, paste('display hubs repeat a gene family:', paste(display[families %in% families[duplicated(families)]], collapse = ', ')))
    }

    band <- .confidence_bands[[review$confidence_level]]
    score <- interp$confidence$score
    if (score < band[1] || score > band[2]) {
        issues <- c(issues, sprintf('confidence %.2f is outside the %s band [%.2f, %.2f]', score, review$confidence_level, band[1], band[2]))
    }

    # a technical call must be made consistently in the gate, the tier and the flags
    gate_technical <- identical(review$artifact_gate$status, 'technical')
    tier_technical <- identical(review$evidence_tier, 'technical_artifact')
    if (gate_technical != tier_technical) {
        issues <- c(issues, 'artifact_gate status technical and evidence_tier technical_artifact must go together')
    }
    if (gate_technical && !('possible_artifact' %in% unlist(interp$flags))) {
        issues <- c(issues, 'a technical label must carry the possible_artifact flag')
    }

    if (!file.exists(notes_path) || !any(nzchar(trimws(readLines(notes_path, warn = FALSE))))) {
        issues <- c(issues, paste('no working notes at', file.path('labels', 'notes', basename(notes_path))))
    }
    issues
}

# labels compared case- and whitespace-insensitively for the within-network
# uniqueness rule
.normalize_label <- function(x) gsub('\\s+', ' ', trimws(tolower(x)))

#' Check an agent's label files against their evidence packets
#'
#' For every module in a workspace exported with
#' `export_agent_workspace(mode = 'label')`, replays `labels/<module_id>.json`
#' through [synthesize_interpretation()] via [agent_label_backend()], runs
#' [check_faithfulness()] against the module's packet, and checks the
#' required `review` block against the ModuleSet itself:
#' * every supporting hub is among the module's top 25 hubs, with the kME
#'   stated (within 0.01);
#' * every expected marker's `present` call matches the module's membership;
#' * the 3 display hubs are among the top 10 hubs, exclude housekeeping
#'   normalizers, and do not repeat a gene family;
#' * `confidence$score` lies in the band of `review$confidence_level`
#'   (high 0.75-0.95, moderate 0.5-0.75, low 0.25-0.5, very_low 0-0.25);
#' * a technical artifact gate, a `technical_artifact` evidence tier and the
#'   `possible_artifact` flag go together;
#' * working notes exist at `labels/notes/<module_id>.md`;
#' * no two modules in the workspace share a `proposed_label`.
#'
#' This is what the workspace's `validate_labels.R` runs, so an agent can
#' iterate until every module is `'ok'`.
#'
#' @param workspace_dir Path to the exported workspace.
#' @param alpha Significance threshold for the faithfulness wording check.
#' @return A data.frame with one row per module (plus one per unexpected
#'   label file): `module_id`, `status` (`'ok'`, `'missing'`, `'invalid'`,
#'   `'unfaithful'`, `'needs_revision'` or `'unexpected'`), `proposed_label`
#'   and `detail`.
#' @export
check_agent_labels <- function(workspace_dir, alpha = 0.05){
    ws <- .read_label_workspace(workspace_dir)
    backend <- agent_label_backend(ws$labels_dir, ws$packets)

    rows <- lapply(ws$manifest$module_ids, function(mod){
        packet <- ws$packets[[mod]]
        if (!file.exists(file.path(ws$labels_dir, paste0(mod, '.json')))) {
            return(data.frame(module_id = mod, status = 'missing', proposed_label = NA_character_, detail = 'no label file'))
        }
        interp <- tryCatch(
            synthesize_interpretation(packet, ws$desc, backend, temperature = NA_real_, dataset_context = ws$dataset_context),
            error = function(e) conditionMessage(e)
        )
        if (!is.character(interp) && is.null(interp$review)) interp <- 'review block missing (required in label mode)'
        if (is.character(interp)) {
            return(data.frame(module_id = mod, status = 'invalid', proposed_label = NA_character_, detail = interp))
        }
        violations <- vapply(check_faithfulness(interp, packet, alpha = alpha), .describe_violation, character(1))
        issues <- .review_issues(interp, ws$ms, file.path(ws$labels_dir, 'notes', paste0(mod, '.md')))
        data.frame(
            module_id = mod,
            status = if (length(violations)) 'unfaithful' else if (length(issues)) 'needs_revision' else 'ok',
            proposed_label = interp$proposed_label,
            detail = paste(c(violations, issues), collapse = '; ')
        )
    })

    # within-network uniqueness can only be judged across the whole workspace
    labelled <- do.call(rbind, rows)
    norm <- .normalize_label(labelled$proposed_label)
    dup <- !is.na(norm) & (duplicated(norm) | duplicated(norm, fromLast = TRUE))
    for (i in which(dup)) {
        others <- setdiff(labelled$module_id[norm == norm[i] & dup], labelled$module_id[i])
        note <- paste0('proposed_label also used by ', paste(others, collapse = ', '))
        labelled$detail[i] <- paste(c(if (nzchar(labelled$detail[i])) labelled$detail[i], note), collapse = '; ')
        if (labelled$status[i] == 'ok') labelled$status[i] <- 'needs_revision'
    }
    rows <- list(labelled)

    label_files <- sub('\\.json$', '', list.files(ws$labels_dir, pattern = '\\.json$'))
    unexpected <- setdiff(label_files, ws$manifest$module_ids)
    if (length(unexpected) > 0) {
        rows <- c(rows, list(data.frame(
            module_id = unexpected, status = 'unexpected', proposed_label = NA_character_,
            detail = 'label file for a module not in this workspace'
        )))
    }
    do.call(rbind, rows)
}

#' Collect an agent's labels as validated interpretations
#'
#' Turns the label files from a workspace exported with
#' `export_agent_workspace(mode = 'label')` into `interpretation` objects via
#' the same pipeline as LLM synthesis ([synthesize_module()]:
#' validation, [enforce_faithfulness()], [fuse_confidence()]). With
#' `output_dir`, delegates to [run_synthesis_orchestrator()], which also
#' writes per-module JSON/Markdown, `review_queue.tsv` and `manifest.json`,
#' exactly as for an LLM run. Provenance records `model = 'agent:<agent>'`
#' and the current [PROMPT_TEMPLATE_VERSION], whose rules the workspace
#' manifest handed the agent.
#'
#' @param workspace_dir Path to the exported workspace.
#' @param output_dir Optional directory to write the synthesis outputs to.
#' @param agent Short name of the agent that wrote the labels.
#' @return A named list of `interpretation` objects (`NULL` for a module
#'   whose label is missing or invalid, with a warning), invisibly when
#'   `output_dir` is given.
#' @examples
#' \dontrun{
#' interps <- collect_agent_labels('agent_workspace', output_dir = 'interpretations', agent = 'claude-code')
#' }
#' @export
collect_agent_labels <- function(workspace_dir, output_dir = NULL, agent = 'coding-agent'){
    ws <- .read_label_workspace(workspace_dir)
    backend <- agent_label_backend(ws$labels_dir, ws$packets, agent = agent)

    if (!is.null(output_dir)) {
        return(run_synthesis_orchestrator(
            ws$packets, ws$desc, backend, output_dir = output_dir,
            temperature = NA_real_, dataset_context = ws$dataset_context
        ))
    }

    interps <- lapply(names(ws$packets), function(mod){
        tryCatch(
            synthesize_module(ws$packets[[mod]], ws$desc, backend, temperature = NA_real_, dataset_context = ws$dataset_context),
            error = function(e){
                warning('agent label rejected for module ', mod, ': ', conditionMessage(e), call. = FALSE)
                NULL
            }
        )
    })
    names(interps) <- names(ws$packets)
    interps
}
