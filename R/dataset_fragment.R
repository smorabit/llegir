## dataset_fragment contract: constructor, validator, JSON (de)serialization,
## and dataset-context assembly + hashing. Sibling of the evidence_fragment
## contract in R/fragment.R -- scoped to the whole dataset rather than one
## module, so it drops module_id and the fusion fields (effect_strength/
## significance/direction) and adds caveats. docs/schemas.md,
## inst/schemas/dataset_fragment.schema.json

# when a dataset context mixes fragments that set render_max_findings with
# ones that don't, jsonlite's simplifyDataFrame can turn the sparse column
# into a numeric vector padded with NA for the fragments that omitted it,
# rather than leaving the field absent -- collapse both "absent" and "NA" to
# a true NULL so the round trip matches dataset_fragment()'s own omit-if-NULL
# treatment
.null_if_absent <- function(x){
    if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) NULL else x
}

# controlled vocab for dataset_fragment$type (docs/schemas.md); mirrors
# .fragment_types in R/fragment.R but is its own list -- extend deliberately
.dataset_fragment_types <- c(
    'composition_summary', 'baseline_expression', 'variance_structure', 'module_landscape'
)

# machine-readable confounder flags a dataset tool can surface to the model;
# start small and grow per tool
.dataset_caveat_vocab <- c(
    'condition_confounded_with_batch', 'cell_state_imbalanced_across_condition',
    'hub_genes_are_housekeeping', 'underpowered_contrast'
)

#' Construct a dataset fragment
#'
#' One dataset-level tool's global summary of the whole experiment. Sibling
#' of [evidence_fragment()]: no `module_id`, no `effect_strength`/
#' `significance`/`direction` -- it is descriptive framing bundled into a
#' `dataset_context`, never fused or cited per module. See
#' `inst/schemas/dataset_fragment.schema.json` for the full contract.
#'
#' @param fragment_id Unique id within a dataset_context, e.g.
#'   `'composition'` or `'milo::abundance'`.
#' @param tool_id Which tool produced this fragment.
#' @param type One of the controlled vocabulary: `'composition_summary'`,
#'   `'baseline_expression'`, `'variance_structure'`, `'module_landscape'`.
#' @param result The small tidy summary (a data.frame); never the raw matrix.
#' @param compact_summary Short digest for the model (token-efficient, no raw tables).
#' @param top_findings A list of the few most salient items (cell states / covariates / genes).
#' @param caveats A list of machine-readable confounder flags, drawn from the
#'   controlled vocab. Default `list()`.
#' @param provenance A provenance list, typically built with [make_provenance()].
#' @param plots Optional named list of plot specs to attach; see
#'   [attach_plots()]. Default `NULL`.
#' @param render_max_findings Optional override for how many `top_findings`
#'   entries [.render_dataset_fragment_compact()] renders for this fragment,
#'   for a fragment whose findings are a census (one entry per group) rather
#'   than a top-N ranking, e.g. a cluster reference card with one row per
#'   cluster. `NULL` (default) means "use the caller's cap"; see
#'   [build_user_prompt()]. Never added to `required`, so a fragment that
#'   omits it validates, serializes, and hashes exactly as one built before
#'   this field existed.
#' @return A `dataset_fragment` object.
#' @export
dataset_fragment <- function(fragment_id, tool_id, type, result, compact_summary,
                              top_findings, caveats = list(), provenance = list(), plots = NULL,
                              render_max_findings = NULL){
    type <- match.arg(type, .dataset_fragment_types)
    frag <- list(
        fragment_id = fragment_id,
        tool_id = tool_id,
        type = type,
        result = result,
        compact_summary = compact_summary,
        top_findings = top_findings,
        caveats = caveats,
        provenance = provenance,
        plots = plots
    )
    # omitted (not set to NULL) when unused, unlike `plots`, so the on-disk
    # and hashed shape of a fragment that never opts in is byte-identical to
    # one built before this field existed
    if (!is.null(render_max_findings)) frag$render_max_findings <- render_max_findings
    structure(frag, class = 'dataset_fragment')
}

#' Validate a dataset fragment
#'
#' Asserts required fields and basic types against
#' `inst/schemas/dataset_fragment.schema.json`.
#'
#' @param frag A `dataset_fragment` object.
#' @return `TRUE`, invisibly, on success. Throws on the first violation.
#' @export
validate_dataset_fragment <- function(frag){
    required <- c(
        'fragment_id', 'tool_id', 'type', 'result', 'compact_summary', 'top_findings', 'provenance'
    )
    missing_fields <- setdiff(required, names(frag))
    if (length(missing_fields) > 0) {
        stop('dataset_fragment missing required fields: ', paste(missing_fields, collapse = ', '))
    }
    if (!inherits(frag, 'dataset_fragment')) stop('object is not class dataset_fragment')
    if (!is.character(frag$fragment_id) || length(frag$fragment_id) != 1) stop('fragment_id must be a single string')
    if (!is.character(frag$tool_id) || length(frag$tool_id) != 1) stop('tool_id must be a single string')
    if (!(frag$type %in% .dataset_fragment_types)) stop('invalid type: ', frag$type)
    if (!is.data.frame(frag$result)) stop('result must be a data.frame')
    if (!is.character(frag$compact_summary) || length(frag$compact_summary) != 1) stop('compact_summary must be a single string')
    if (!is.list(frag$top_findings)) stop('top_findings must be a list')
    caveats <- frag$caveats
    if (is.null(caveats)) caveats <- list()
    invalid_caveats <- setdiff(unlist(caveats), .dataset_caveat_vocab)
    if (length(invalid_caveats) > 0) stop('invalid caveats: ', paste(invalid_caveats, collapse = ', '))
    if (!is.list(frag$provenance)) stop('provenance must be a list')
    prov_required <- c('tool_version', 'params', 'input_hashes', 'pkg_versions', 'timestamp')
    prov_missing <- setdiff(prov_required, names(frag$provenance))
    if (length(prov_missing) > 0) {
        stop('provenance missing fields: ', paste(prov_missing, collapse = ', '))
    }
    .validate_plots(frag$plots, 'dataset_fragment')
    rmf <- frag$render_max_findings
    if (!is.null(rmf) && (!is.numeric(rmf) || length(rmf) != 1 || is.na(rmf) || rmf <= 0)) {
        stop('render_max_findings must be a single positive number')
    }
    invisible(TRUE)
}

# strip volatile fields (timestamps) before hashing so identical dataset
# fragments hash identically across reruns; plot_obj is stripped first since a
# live grob holds environments/external pointers and would make the hash
# non-reproducible across sessions -- legends are text and stay in, so they
# still count toward the hash
.dataset_fragment_hashable <- function(frag){
    frag <- .strip_plot_objs(frag)
    frag$provenance$timestamp <- NULL
    unclass(frag)
}

#' Serialize a dataset fragment to JSON
#'
#' @param frag A `dataset_fragment` object.
#' @param pretty Pretty-print the JSON. Default `TRUE`.
#' @return A JSON string (a `jsonlite::json` scalar).
#' @export
dataset_fragment_to_json <- function(frag, pretty = TRUE){
    # `.strip_plot_objs()` drops any live plot_obj so a raw grob never reaches jsonlite
    jsonlite::toJSON(unclass(.strip_plot_objs(frag)), dataframe = 'rows', auto_unbox = TRUE, na = 'null', pretty = pretty)
}

#' Parse a dataset fragment from JSON
#'
#' Inverse of [dataset_fragment_to_json()]; rebuilds the `dataset_fragment`
#' class and defaults for fields that may have been dropped by JSON's null
#' handling.
#'
#' @param json_str A JSON string as produced by [dataset_fragment_to_json()].
#' @return A `dataset_fragment` object.
#' @export
dataset_fragment_from_json <- function(json_str){
    parsed <- jsonlite::fromJSON(json_str, simplifyDataFrame = TRUE, simplifyVector = TRUE)
    do.call(dataset_fragment, list(
        fragment_id = parsed$fragment_id,
        tool_id = parsed$tool_id,
        type = parsed$type,
        result = as.data.frame(parsed$result),
        compact_summary = parsed$compact_summary,
        top_findings = .rowlist_from_simplified(parsed$top_findings),
        caveats = if (is.null(parsed$caveats)) list() else parsed$caveats,
        provenance = parsed$provenance,
        plots = parsed$plots,
        render_max_findings = .null_if_absent(parsed$render_max_findings)
    ))
}

#' Materialize a dataset context's live plots to PNG files
#'
#' The dataset-level sibling of [write_fragment_figures()]: renders each
#' `dataset_fragment`'s live `plot_obj` to
#' `<figures_dir>/dataset/<fragment_id>__<plot_id>.png` and records that path
#' back onto the spec as `image_path`, so a report rendered after the live
#' `plot_obj` has been stripped can still embed the figure. A spec's own
#' `width`/`height`/`dpi` (see [attach_plots()]) are honored when set;
#' otherwise [save_plot_to_png()]'s `7`/`4`/`150` defaults apply. Fragments
#' with no plots are skipped.
#'
#' @param dataset_context A dataset context, as returned by
#'   [build_dataset_context()] / [run_dataset_context()].
#' @param figures_dir Output directory.
#' @return `dataset_context`, with `image_path` filled in on every rendered
#'   plot spec.
#' @export
write_dataset_figures <- function(dataset_context, figures_dir){
    out_dir <- file.path(figures_dir, 'dataset')
    dataset_context$dataset_fragments <- lapply(dataset_context$dataset_fragments, function(frag){
        if (is.null(frag$plots) || length(frag$plots) == 0) return(frag)
        dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
        file_stub <- gsub(':', '_', frag$fragment_id)
        plot_ids <- names(frag$plots)
        frag$plots <- lapply(plot_ids, function(plot_id){
            spec <- frag$plots[[plot_id]]
            if (!is.null(spec$plot_obj)) {
                path <- file.path(out_dir, paste0(file_stub, '__', plot_id, '.png'))
                .save_plot_spec_png(spec, path)
                spec$image_path <- path
            }
            spec
        })
        names(frag$plots) <- plot_ids
        frag
    })
    dataset_context
}

#' Assemble and hash a dataset context
#'
#' Validates every fragment, then hashes the content (fragments minus
#' timestamps) so the hash is a reproducibility fingerprint, not just a
#' run-to-run-unique id. The once-per-dataset analog of
#' [build_evidence_packet()] -- computed once and injected into every
#' module's synthesis prompt, never entering fusion or faithfulness.
#'
#' @param dataset_fragments A list of `dataset_fragment` objects.
#' @param input_hash A content hash identifying the source dataset (e.g. of
#'   the backing `.rds`), for provenance.
#' @param schema_version Schema version tag. Default `'0.1'`.
#' @param skipped A list of `list(tool_id, reason)` entries for tools that
#'   were skipped because a required `ModuleSet` [capabilities()] was unmet,
#'   recorded on `provenance$skipped` for an audit trail. Default `list()`.
#' @return A list with `dataset_fragments`, `context_hash`, `schema_version`,
#'   and `provenance`.
#' @export
build_dataset_context <- function(dataset_fragments, input_hash = NA_character_,
                                   schema_version = '0.1', skipped = list()){
    lapply(dataset_fragments, validate_dataset_fragment)
    context_hash <- digest::digest(lapply(dataset_fragments, .dataset_fragment_hashable), algo = 'sha256')
    list(
        dataset_fragments = dataset_fragments,
        context_hash = context_hash,
        schema_version = schema_version,
        provenance = list(
            created_at = format(Sys.time(), '%Y-%m-%dT%H:%M:%S%z'),
            input_hash = input_hash,
            tool_ids = vapply(dataset_fragments, function(f) f$tool_id, character(1)),
            skipped = skipped
        )
    )
}

#' Serialize a dataset context to JSON
#'
#' @param context A dataset context, as returned by [build_dataset_context()].
#' @param pretty Pretty-print the JSON. Default `TRUE`.
#' @return A JSON string (a `jsonlite::json` scalar).
#' @export
dataset_context_to_json <- function(context, pretty = TRUE){
    jsonlite::toJSON(
        list(
            dataset_fragments = lapply(context$dataset_fragments, function(f) unclass(.strip_plot_objs(f))),
            context_hash = context$context_hash,
            schema_version = context$schema_version,
            provenance = context$provenance
        ),
        dataframe = 'rows', auto_unbox = TRUE, na = 'null', pretty = pretty
    )
}

#' Write a dataset context to a JSON file
#'
#' @param context A dataset context, as returned by [build_dataset_context()].
#' @param path Output file path.
#' @return `path`, invisibly.
#' @export
write_dataset_context <- function(context, path){
    writeLines(dataset_context_to_json(context), path)
    invisible(path)
}

#' Read a dataset context from a JSON file
#'
#' Reconstructs a context (and each fragment's S3 class) from a JSON file
#' written by [write_dataset_context()].
#'
#' @param path Path to a context JSON file.
#' @return A dataset context, as returned by [build_dataset_context()].
#' @export
read_dataset_context <- function(path){
    # jsonlite simplifies the dataset_fragments array into a data.frame, so
    # fragments are indexed row-by-row; see read_evidence_packet() for the
    # same unwrapping pattern, including the second unsimplified parse needed
    # to pull `plots` out untouched (it's keyed by plot id, not a uniform
    # array, so the row-simplification mangles it once a spec has more than
    # one field)
    parsed <- jsonlite::fromJSON(path, simplifyDataFrame = TRUE, simplifyVector = TRUE)
    raw <- jsonlite::fromJSON(path, simplifyDataFrame = FALSE, simplifyVector = FALSE)
    dataset_fragments <- lapply(seq_len(nrow(parsed$dataset_fragments)), function(i) {
        f <- parsed$dataset_fragments[i, ]
        raw_plots <- raw$dataset_fragments[[i]]$plots
        do.call(dataset_fragment, list(
            fragment_id = f$fragment_id[[1]],
            tool_id = f$tool_id[[1]],
            type = f$type[[1]],
            result = as.data.frame(f$result[[1]]),
            compact_summary = f$compact_summary[[1]],
            top_findings = .rowlist_from_simplified(f$top_findings[[1]]),
            caveats = if (is.null(f$caveats[[1]])) list() else f$caveats[[1]],
            provenance = as.list(f$provenance),
            plots = if (length(raw_plots) == 0) NULL else raw_plots,
            render_max_findings = .null_if_absent(f$render_max_findings[[1]])
        ))
    })
    list(
        dataset_fragments = dataset_fragments,
        context_hash = parsed$context_hash,
        schema_version = parsed$schema_version,
        provenance = parsed$provenance
    )
}
