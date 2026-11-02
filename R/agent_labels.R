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

# label-mode hub ranks: supporting evidence from the top 25 (and at least one
# from the top 10), display from the top 10
.review_max_support_rank <- 25
.review_max_display_rank <- 10
.review_min_markers <- 3

# artifact-screen thresholds, stated in the manifest and enforced by
# check_agent_labels(): at or above them the gate may not simply 'pass', and a
# sample-concentrated module keeps its biological label with capped confidence
.screen_stress_min_hubs <- 5
.screen_depth_min_rho <- 0.5
.screen_sample_share_cap <- 0.5

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
    list(sample_col = sample_col, sample = names(counts)[1], share = as.numeric(counts[1]) / sum(counts),
         n_samples = length(unique(md[[sample_col]])))
}

# Spearman correlation of the module score with each sequencing-depth column
# (e.g. total counts, detected genes) across cells; columns the metadata lacks
# are skipped, so NULL when none are available
.depth_correlations <- function(ms, module_id, depth_cols){
    if (!length(depth_cols) || !has_capability(ms, 'module_scores')) return(NULL)
    md <- metadata(ms)
    depth_cols <- intersect(depth_cols, colnames(md))
    if (!length(depth_cols)) return(NULL)
    scores <- module_scores(ms)[[module_id]]
    vapply(depth_cols, function(col) stats::cor(scores, md[[col]], method = 'spearman', use = 'complete.obs'), numeric(1))
}

# the artifact screen's numbers for one module, shared by the rendered block
# and by check_agent_labels(), so what the agent reads is what gets enforced
.artifact_screen_values <- function(ms, module_id, sample_col = NULL, depth_cols = NULL){
    ranked <- .ranked_module_genes(ms, module_id)
    top_hubs <- utils::head(ranked$gene_name, .review_max_support_rank)
    list(
        n_genes = nrow(ranked),
        n_top = length(top_hubs),
        stress_top = intersect(top_hubs, .dissociation_stress_genes),
        stress_all = intersect(ranked$gene_name, .dissociation_stress_genes),
        sample_share = .top_decile_sample_share(ms, module_id, sample_col),
        depth_rho = .depth_correlations(ms, module_id, depth_cols)
    )
}

# which screen thresholds a module meets: stress / depth mean the gate may not
# simply pass; sample concentration caps the confidence instead
.screen_flags <- function(values){
    list(
        stress = length(values$stress_top) >= .screen_stress_min_hubs,
        depth = !is.null(values$depth_rho) && any(abs(values$depth_rho) >= .screen_depth_min_rho, na.rm = TRUE),
        sample = !is.null(values$sample_share) && values$sample_share$share >= .screen_sample_share_cap
    )
}

#' Artifact screen for one module (label mode)
#'
#' The deterministic inputs to the label-mode artifact gate, rendered as a
#' text block appended to each module's `label_evidence` file: module size;
#' how many of the dissociation-stress (immediate-early / heat-shock) genes
#' sit among the top 25 hubs and in the whole module; when `depth_cols` are
#' available, the module score's Spearman correlation with sequencing depth;
#' and, when `sample_col` names a metadata column (e.g. patient), how much of
#' the module's top-decile activity comes from a single sample. Each line
#' states its threshold and whether the module meets it. Not an evidence
#' fragment: it informs the gate but is never cited in `supporting_claims`.
#'
#' @param ms A `ModuleSet`.
#' @param module_id The module to screen.
#' @param sample_col Optional metadata column (e.g. `'Patient'`) for the
#'   single-sample share. Default `NULL` skips that line.
#' @param depth_cols Optional metadata columns holding per-cell sequencing
#'   depth (e.g. `c('nCount_RNA', 'nFeature_RNA')`). Default `NULL` skips that
#'   line.
#' @return A single character string.
#' @keywords internal
.label_artifact_screen <- function(ms, module_id, sample_col = NULL, depth_cols = NULL){
    values <- .artifact_screen_values(ms, module_id, sample_col, depth_cols)
    flags <- .screen_flags(values)
    meets <- function(x) if (isTRUE(x)) 'MEETS threshold' else 'below threshold'

    lines <- c(
        '[artifact_screen] computed by llegir for the label-mode artifact gate; not an evidence fragment, never cite it in supporting_claims',
        paste0('module_size: ', values$n_genes, ' genes'),
        paste0(
            'dissociation_stress: ', length(values$stress_top), ' of the top ', values$n_top, ' hubs',
            if (length(values$stress_top)) paste0(' (', paste(values$stress_top, collapse = ', '), ')') else '',
            '; ', length(values$stress_all), ' in the whole module',
            if (length(values$stress_all)) paste0(' (', paste(values$stress_all, collapse = ', '), ')') else '',
            ' [threshold: ', .screen_stress_min_hubs, ' of the top ', .review_max_support_rank, ' hubs; ', meets(flags$stress), ']'
        )
    )
    if (!is.null(values$depth_rho)) {
        lines <- c(lines, paste0(
            'depth_correlation (Spearman rho, module score vs ',
            paste(sprintf('%s %.2f', names(values$depth_rho), values$depth_rho), collapse = ', '),
            ') [threshold: |rho| >= ', .screen_depth_min_rho, ' for any; ', meets(flags$depth), ']'
        ))
    }
    if (!is.null(values$sample_share)) {
        lines <- c(lines, sprintf(
            'sample_concentration: %.1f%% of top-decile cells by module score from one %s (%s) of %d [threshold: %.0f%%; %s]',
            100 * values$sample_share$share, values$sample_share$sample_col %||% 'sample', values$sample_share$sample,
            values$sample_share$n_samples, 100 * .screen_sample_share_cap, meets(flags$sample)
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
    feature_genes <- if (!is.null(manifest$artifacts$feature_genes)) readLines(artifact_path('feature_genes')) else NULL
    list(
        manifest = manifest,
        feature_genes = feature_genes,
        sample_col = manifest$sample_col,
        depth_cols = unlist(manifest$depth_cols),
        workspace_dir = workspace_dir,
        ms = qs2::qs_read(artifact_path('moduleset_lite')),
        packets = qs2::qs_read(artifact_path('packets')),
        dataset_context = qs2::qs_read(artifact_path('dataset_context')),
        desc = qs2::qs_read(artifact_path('dataset_description')),
        labels_dir = file.path(workspace_dir, manifest$labels_dir)
    )
}

# where a gene sits relative to one module: in it, in another module of the
# network, in the input feature set but no module (e.g. hdWGCNA grey), or not
# in the input at all. Without a feature set the last two can't be told
# apart, so NA_character_ (either answer is accepted).
.marker_status <- function(gene, module_id, ms, feature_genes){
    if (gene %in% gene_membership(ms, module_id)$gene_name) return('in_module')
    in_other <- any(vapply(setdiff(modules(ms), module_id), function(m) gene %in% gene_membership(ms, m)$gene_name, logical(1)))
    if (in_other) return('in_network')
    if (is.null(feature_genes)) return(NA_character_)
    if (gene %in% feature_genes) 'unassigned' else 'not_tested'
}

# the label-mode review checks for one module, against the ModuleSet itself;
# returns a character vector of problems (empty when the review holds up)
.review_issues <- function(interp, ws){
    review <- interp$review
    mod <- interp$module_id
    ranked <- .ranked_module_genes(ws$ms, mod)
    rank_of <- function(gene) match(gene, ranked$gene_name)
    issues <- character(0)

    # without real gene weights (e.g. a gene-list ModuleSet) kME is NA and the
    # rank is just table order, so only membership and rank can be checked
    has_weights <- has_capability(ws$ms, 'gene_weights')
    hub_ranks <- vapply(review$supporting_hubs, function(hub) rank_of(hub$gene), numeric(1))
    for (i in seq_along(review$supporting_hubs)) {
        hub <- review$supporting_hubs[[i]]
        r <- hub_ranks[i]
        if (is.na(r)) {
            issues <- c(issues, sprintf('supporting hub %s is not in this module', hub$gene))
        } else if (r > .review_max_support_rank) {
            issues <- c(issues, sprintf('supporting hub %s is rank %d, outside the top %d', hub$gene, r, .review_max_support_rank))
        } else if (has_weights && abs(hub$kme - ranked$kme[r]) > 0.01) {
            issues <- c(issues, sprintf('supporting hub %s has kME %.3f, not %.3f', hub$gene, ranked$kme[r], hub$kme))
        }
    }
    if (!any(hub_ranks <= .review_max_display_rank, na.rm = TRUE)) {
        issues <- c(issues, sprintf('no supporting hub comes from the top %d; the call must rest on the top of the hub list', .review_max_display_rank))
    }

    # the falsification step is only worth anything if each marker's status is real
    if (length(review$expected_markers) < .review_min_markers) {
        issues <- c(issues, sprintf('only %d expected_markers; check at least %d', length(review$expected_markers), .review_min_markers))
    }
    for (marker in review$expected_markers) {
        actual <- .marker_status(marker$gene, mod, ws$ms, ws$feature_genes)
        ok <- if (is.na(actual)) marker$status %in% c('unassigned', 'not_tested') else identical(marker$status, actual)
        if (!ok) {
            issues <- c(issues, sprintf('expected marker %s is %s, not %s', marker$gene,
                                        if (is.na(actual)) 'in no module' else actual, marker$status))
        }
    }

    display <- unlist(review$display_hubs)
    for (gene in display) {
        r <- rank_of(gene)
        if (is.na(r) || r > .review_max_display_rank) {
            issues <- c(issues, sprintf('display hub %s is not in the top %d hubs', gene, .review_max_display_rank))
        }
    }
    # a normalizer can stay as a display hub only with a stated reason
    overridden <- vapply(review$display_hub_overrides %||% list(), function(o) if (nzchar(trimws(o$reason))) o$gene else NA_character_, character(1))
    excluded <- setdiff(intersect(display, .display_hub_excluded), overridden)
    if (length(excluded)) {
        issues <- c(issues, paste('display hubs include housekeeping normalizers without a display_hub_overrides reason:', paste(excluded, collapse = ', ')))
    }
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
    flags <- unlist(interp$flags)
    gate <- review$artifact_gate$status
    gate_technical <- identical(gate, 'technical')
    if (gate_technical != identical(review$evidence_tier, 'technical_artifact')) {
        issues <- c(issues, 'artifact_gate status technical and evidence_tier technical_artifact must go together')
    }
    if (gate_technical && !('possible_artifact' %in% flags)) {
        issues <- c(issues, 'a technical label must carry the possible_artifact flag')
    }

    # the screen's stated thresholds, enforced exactly as the manifest states them
    screen <- .screen_flags(.artifact_screen_values(ws$ms, mod, ws$sample_col, ws$depth_cols))
    if ((screen$stress || screen$depth) && identical(gate, 'pass')) {
        issues <- c(issues, sprintf('the artifact screen meets the %s threshold, so artifact_gate cannot be pass (use technical or uncertain)',
                                    paste(c(if (screen$stress) 'dissociation_stress', if (screen$depth) 'depth_correlation'), collapse = ' and ')))
    }
    if (screen$sample) {
        if (identical(review$confidence_level, 'high')) {
            issues <- c(issues, 'sample_concentration meets its threshold, so confidence_level is capped at moderate')
        }
        if (!('label_low_specificity' %in% flags)) {
            issues <- c(issues, 'sample_concentration meets its threshold, so add the label_low_specificity flag')
        }
    }

    notes_path <- file.path(ws$labels_dir, 'notes', paste0(mod, '.md'))
    notes <- if (file.exists(notes_path)) readLines(notes_path, warn = FALSE) else character(0)
    if (!any(nzchar(trimws(notes)))) {
        issues <- c(issues, paste('no working notes at', file.path('labels', 'notes', paste0(mod, '.md'))))
    }

    # every script run for this module is part of the record: kept output, cited in the notes
    scripts <- list.files(file.path(ws$workspace_dir, 'queries', mod), pattern = '\\.R$')
    for (script in scripts) {
        rel <- file.path('queries', mod, script)
        if (!file.exists(file.path(ws$workspace_dir, sub('\\.R$', '.out', rel)))) {
            issues <- c(issues, paste('no captured output for', rel))
        }
        if (!any(grepl(rel, notes, fixed = TRUE))) {
            issues <- c(issues, paste('notes do not cite', rel))
        }
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
#'   stated (within 0.01), and at least one is from the top 10;
#' * at least 3 expected markers, each with the right status (`in_module`,
#'   `in_network`, `unassigned`, `not_tested`; the last two are told apart
#'   only when the workspace ships the input feature set);
#' * the 3 display hubs are among the top 10 hubs, exclude housekeeping
#'   normalizers unless `review$display_hub_overrides` gives a reason, and do
#'   not repeat a gene family;
#' * `confidence$score` lies in the band of `review$confidence_level`
#'   (high 0.75-0.95, moderate 0.5-0.75, low 0.25-0.5, very_low 0-0.25);
#' * a technical artifact gate, a `technical_artifact` evidence tier and the
#'   `possible_artifact` flag go together;
#' * a module meeting the artifact screen's dissociation-stress or
#'   depth-correlation threshold does not `pass` the gate, and one meeting
#'   the sample-concentration threshold is at most `moderate` and flagged
#'   `label_low_specificity`;
#' * working notes exist at `labels/notes/<module_id>.md`, and every script
#'   in `queries/<module_id>/` has its captured `.out` and is cited in them;
#' * no two modules in the workspace share a `proposed_label`, unless one's
#'   `review$related_module` names the other.
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

    # the labeling task covers the modules that were exported with a packet,
    # which can be a subset of the network (run_orchestrator(modules_use =))
    label_mods <- intersect(ws$manifest$module_ids, names(ws$packets))
    rows <- lapply(label_mods, function(mod){
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
        issues <- .review_issues(interp, ws)
        data.frame(
            module_id = mod,
            status = if (length(violations)) 'unfaithful' else if (length(issues)) 'needs_revision' else 'ok',
            proposed_label = interp$proposed_label,
            detail = paste(c(violations, issues), collapse = '; ')
        )
    })

    # within-network uniqueness can only be judged across the whole workspace; a
    # shared label is accepted when either module's review.related_module names
    # the other (the same program, recorded honestly rather than distinguished)
    labelled <- do.call(rbind, rows)
    related <- vapply(labelled$module_id, function(mod){
        path <- file.path(ws$labels_dir, paste0(mod, '.json'))
        if (!file.exists(path)) return(NA_character_)
        lab <- tryCatch(jsonlite::read_json(path), error = function(e) NULL)
        lab$review$related_module$module_id %||% NA_character_
    }, character(1))
    linked <- function(a, b) identical(unname(related[a]), b) || identical(unname(related[b]), a)
    norm <- .normalize_label(labelled$proposed_label)
    dup <- !is.na(norm) & (duplicated(norm) | duplicated(norm, fromLast = TRUE))
    for (i in which(dup)) {
        others <- setdiff(labelled$module_id[norm == norm[i] & dup], labelled$module_id[i])
        others <- others[!vapply(others, function(o) linked(labelled$module_id[i], o), logical(1))]
        if (!length(others)) next
        note <- paste0('proposed_label also used by ', paste(others, collapse = ', '), ' (record review.related_module if they are the same program)')
        labelled$detail[i] <- paste(c(if (nzchar(labelled$detail[i])) labelled$detail[i], note), collapse = '; ')
        if (labelled$status[i] == 'ok') labelled$status[i] <- 'needs_revision'
    }
    rows <- list(labelled)

    label_files <- sub('\\.json$', '', list.files(ws$labels_dir, pattern = '\\.json$'))
    unexpected <- setdiff(label_files, label_mods)
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
#' and the `prompt_template_version` recorded in the workspace manifest,
#' whose rules the agent labelled under.
#'
#' Labels are first run through [check_agent_labels()]: with `strict = TRUE`
#' (default) collection stops unless every module is `ok`; with
#' `strict = FALSE` it warns and collects whatever passes validation.
#'
#' @param workspace_dir Path to the exported workspace.
#' @param output_dir Optional directory to write the synthesis outputs to.
#' @param agent Short name of the agent that wrote the labels.
#' @param strict Stop (rather than warn) when [check_agent_labels()] reports
#'   any module that is not `ok`. Default `TRUE`.
#' @return A named list of `interpretation` objects (`NULL` for a module
#'   whose label is missing or invalid, with a warning), invisibly when
#'   `output_dir` is given.
#' @examples
#' \dontrun{
#' interps <- collect_agent_labels('agent_workspace', output_dir = 'interpretations', agent = 'claude-code')
#' }
#' @export
collect_agent_labels <- function(workspace_dir, output_dir = NULL, agent = 'coding-agent', strict = TRUE){
    report <- check_agent_labels(workspace_dir)
    failing <- report[report$status != 'ok', , drop = FALSE]
    if (nrow(failing) > 0) {
        msg <- paste0(
            nrow(failing), ' module(s) did not pass check_agent_labels(): ',
            paste0(failing$module_id, ' [', failing$status, ']', collapse = ', ')
        )
        if (strict) stop(msg, '. Fix the labels, or use strict = FALSE to collect the rest.', call. = FALSE)
        warning(msg, call. = FALSE)
    }

    ws <- .read_label_workspace(workspace_dir)
    backend <- agent_label_backend(ws$labels_dir, ws$packets, agent = agent)
    # the agent labelled under the rules frozen into the manifest, which may
    # predate the installed package's prompt template
    synth_args <- list(
        desc = ws$desc, backend = backend, temperature = NA_real_,
        prompt_template_version = ws$manifest$prompt_template_version %||% PROMPT_TEMPLATE_VERSION,
        dataset_context = ws$dataset_context,
        data_level = ws$ms$data_level %||% 'cell', aggregated = isTRUE(ws$ms$aggregated)
    )

    if (!is.null(output_dir)) {
        return(do.call(run_synthesis_orchestrator, c(list(packets = ws$packets, output_dir = output_dir), synth_args)))
    }

    interps <- lapply(names(ws$packets), function(mod){
        tryCatch(
            do.call(synthesize_module, c(list(packet = ws$packets[[mod]]), synth_args)),
            error = function(e){
                warning('agent label rejected for module ', mod, ': ', conditionMessage(e), call. = FALSE)
                NULL
            }
        )
    })
    names(interps) <- names(ws$packets)
    interps
}
