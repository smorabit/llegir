## HTML report exporter: compiles a batch of interpretations and their paired
## evidence packets into a single self-contained report via the packaged
## inst/templates/summary_report.Rmd template.
##
## Below it: the agent workspace exporter (docs/milestones/milestone_agent_workspace.md),
## a sibling pure exporter that serializes a completed run and renders a
## static launchpad file for an external terminal coding agent. Part 1 is the
## serialization plumbing and the manifest reader; Part 2 (below that) is the
## cheat-sheet generators, pure introspection with no rendering; Part 3
## (below that) renders the packaged template via export_agent_workspace().
## Part 4 (v0.2 hardening, below that) splits the serialized ModuleSet into a
## lite (default) / full pair, switches artifact serialization to qs2,
## exports interpretations when present, and fixes the hardcoded grouping
## column and positional fragment access two bugs found reviewing a real
## exported workspace.

.llegir_manifest_version <- '0.2'

#' Write a combined interpretation + evidence HTML report
#'
#' Renders every module's synthesized interpretation alongside the raw
#' deterministic evidence it was drawn from into one human-readable HTML file.
#' Modules are paired by matching the names of `interps` and `packets`.
#'
#' @param interps A named list of `interpretation` objects, keyed by module id
#'   (e.g. the return value of [run_synthesis_orchestrator()]).
#' @param packets A named list of evidence packets, keyed by module id (e.g. the
#'   return value of [run_orchestrator()]).
#' @param desc The `dataset_description` used for this synthesis run.
#' @param output_file Destination HTML path. Default `'output/report.html'`.
#' @param quiet Suppress the pandoc/knitr progress output. Default `TRUE`.
#' @return The rendered file path, invisibly.
#' @export
write_interpretation_report <- function(interps, packets, desc,
                                        output_file = 'output/report.html',
                                        quiet = TRUE){
    if (!is.list(interps)) stop('interps must be a list of interpretation objects')
    if (!is.list(packets)) stop('packets must be a list of evidence packets')

    template <- system.file('templates/summary_report.Rmd', package = 'llegir')
    if (!nzchar(template)) stop('could not locate summary_report.Rmd in the installed llegir package')

    # guarantee the output directory exists, then resolve it to an absolute
    # path: render() otherwise resolves a relative output path against the
    # template's own (installed-package) directory, not the caller's cwd
    output_dir <- dirname(output_file)
    dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
    output_dir <- normalizePath(output_dir, mustWork = TRUE)

    rmarkdown::render(
        input = template,
        output_file = basename(output_file),
        output_dir = output_dir,
        params = list(interps = interps, packets = packets, desc = desc),
        quiet = quiet,
        envir = new.env(parent = globalenv())
    )
    invisible(file.path(output_dir, basename(output_file)))
}

#---------------------------------------------------------
# agent workspace: serialization plumbing (part 1)
#---------------------------------------------------------

# creates the two top-level workspace directories export_agent_workspace()
# writes into: artifacts/ (serialized run) and scratch/ (empty, reserved for
# the guest agent's own derived output -- never written to by llegir itself)
.scaffold_workspace <- function(out_dir){
    art_dir <- file.path(out_dir, 'artifacts')
    scratch_dir <- file.path(out_dir, 'scratch')
    dir.create(art_dir, showWarnings = FALSE, recursive = TRUE)
    dir.create(scratch_dir, showWarnings = FALSE, recursive = TRUE)
    list(art_dir = art_dir, scratch_dir = scratch_dir)
}

# the declared grouping / sample-id column name for a ModuleSet, if any --
# plain field access (the convention components_ModuleSet() and its
# subclasses use, delegated by synthetic_ModuleSet()); NULL when the adapter
# never declared one (e.g. hdWGCNA_ModuleSet reports the grouping capability
# without naming a column), the signal to omit a recipe/invocation that would
# otherwise hardcode a guessed column name
.ms_group_col <- function(ms) ms[['group_col']]
.ms_sample_col <- function(ms) ms[['sample_col']]

# a pseudobulk view above this many rows (samples/units) is dropped from the
# lite object rather than carried forward -- lite is meant to stay cheap to
# reload, and a pseudobulk view is only "free" to keep when it's already
# small
.lite_pseudobulk_row_limit <- 500

#' Build a reduced ModuleSet carrying only the token-safe views
#'
#' Rebuilds a `components_ModuleSet` from `ms`'s own getters, carrying the
#' full gene-membership tables (every module), module scores, metadata, the
#' declared grouping/sample-id columns, `pkg_versions()`, `data_level`/
#' `aggregated`, and the pseudobulk view when one is attached and already
#' small -- but never the backing expression/counts matrices. This is the
#' artifact an agent workspace loads by default (`moduleset_lite.qs2`); the
#' full `ms` still ships alongside it (`moduleset_full.qs2`) for the rare
#' `expression()`/`counts()` query.
#'
#' Reuses [components_ModuleSet()] rather than a bespoke class so every
#' `ModuleSet` generic keeps dispatching unchanged against the reduced
#' object.
#'
#' @param ms A validated `ModuleSet`.
#' @return A `components_ModuleSet` with `capabilities()$expression` and
#'   `$counts` `FALSE`.
#' @keywords internal
.make_moduleset_lite <- function(ms){
    caps <- capabilities(ms)
    mods <- modules(ms)
    gene_table <- do.call(rbind, lapply(mods, function(m){
        gm <- gene_membership(ms, m)
        data.frame(module = gm$module, gene_name = gm$gene_name, weight = gm$kme)
    }))
    # drop the weight column entirely (rather than carry all-NA kme) when the
    # source ms never declared real gene weights, so components_ModuleSet()'s
    # has_weight/gene_weights capability stays faithful to the original
    if (!isTRUE(caps[['gene_weights']])) gene_table$weight <- NULL

    lite <- components_ModuleSet(
        gene_table = gene_table,
        expression = NULL,
        metadata = metadata(ms),
        scores = if (isTRUE(caps[['module_scores']])) module_scores(ms) else NULL,
        counts = NULL,
        group_col = .ms_group_col(ms),
        sample_col = .ms_sample_col(ms),
        data_level = ms$data_level,
        aggregated = ms$aggregated,
        pkg_versions = pkg_versions(ms)
    )

    if (isTRUE(caps[['pseudobulk']])) {
        pb <- pseudobulk_view(ms)
        if (!is.null(pb) && nrow(metadata(pb)) <= .lite_pseudobulk_row_limit) {
            lite <- with_pseudobulk(lite, pb)
        }
    }
    lite
}

# qs2 is authoritative (full S3 objects, faster + smaller than .rds); .json
# is the portable/hashable mirror an agent can read without spawning R. Both
# point at the same run. art_dir is expected to already exist (see
# .scaffold_workspace()). ms_lite is passed in (rather than recomputed here)
# so callers that also need it for capability-diffing build it once.
.write_workspace_artifacts <- function(ms, ms_lite, dataset_context, packets, interps, art_dir, write_json){
    ms_lite_path <- file.path(art_dir, 'moduleset_lite.qs2')
    ms_full_path <- file.path(art_dir, 'moduleset_full.qs2')
    dctx_path <- file.path(art_dir, 'dataset_context.qs2')
    pkt_path <- file.path(art_dir, 'evidence_packets.qs2')
    qs2::qs_save(ms_lite, ms_lite_path)
    qs2::qs_save(ms, ms_full_path)
    qs2::qs_save(dataset_context, dctx_path)
    qs2::qs_save(packets, pkt_path)

    paths <- list(
        moduleset_lite = ms_lite_path,
        moduleset_full = ms_full_path,
        dataset_context = dctx_path,
        packets = pkt_path
    )
    if (!is.null(interps)) {
        interps_path <- file.path(art_dir, 'interpretations.qs2')
        qs2::qs_save(interps, interps_path)
        paths$interpretations <- interps_path
    }

    if (isTRUE(write_json)) {
        dctx_json_path <- file.path(art_dir, 'dataset_context.json')
        writeLines(dataset_context_to_json(dataset_context), dctx_json_path)

        pkt_json_dir <- file.path(art_dir, 'packets')
        dir.create(pkt_json_dir, showWarnings = FALSE)
        for (mid in names(packets)) {
            writeLines(packet_to_json(packets[[mid]]), file.path(pkt_json_dir, paste0(mid, '.json')))
        }

        paths$dataset_context_json <- dctx_json_path
        paths$packets_dir_json <- pkt_json_dir

        if (!is.null(interps)) {
            interps_json_dir <- file.path(art_dir, 'interpretations')
            dir.create(interps_json_dir, showWarnings = FALSE)
            for (mid in names(interps)) {
                writeLines(interpretation_to_json(interps[[mid]]), file.path(interps_json_dir, paste0(mid, '.json')))
            }
            paths$interpretations_dir_json <- interps_json_dir
        }
    }
    lapply(paths, normalizePath, mustWork = TRUE)
}

# stable content hash per artifact for the manifest's provenance block;
# directories (packets_dir_json) have no single file to hash and are skipped
.hash_artifacts <- function(paths){
    lapply(paths, function(p){
        if (dir.exists(p)) return(NA_character_)
        digest::digest(file = p, algo = 'sha256')
    })
}

#' Read an agent workspace manifest's front-matter
#'
#' Parses only the YAML front-matter of a `.llegir_agent_manifest.md` file
#' (delimited by `---` fences) back into an R list, recovering the artifact
#' paths, module ids, capabilities, and workspace metadata that
#' [export_agent_workspace()] recorded. The inverse operation the agent
#' bootstrap depends on.
#'
#' @param path Path to a `.llegir_agent_manifest.md` file.
#' @return A named list parsed from the manifest's YAML front-matter,
#'   including `artifacts`, `module_ids`, `capabilities`, `workspace_root`,
#'   `data_level`, and `aggregated`.
#' @export
read_agent_manifest <- function(path){
    lines <- readLines(path, warn = FALSE)
    fence_idx <- which(lines == '---')
    if (length(fence_idx) < 2) {
        stop('read_agent_manifest: no YAML front matter found in ', path)
    }
    front_matter <- lines[(fence_idx[1] + 1):(fence_idx[2] - 1)]
    yaml::yaml.load(paste(front_matter, collapse = '\n'))
}

#---------------------------------------------------------
# agent workspace: cheat-sheet generators (part 2; part 4 adds the
# lite/full capability diff and the grouping-column injection)
#---------------------------------------------------------

# TRUE when `need` is something the full ms reports but the lite object
# doesn't -- the signal a cheat-sheet row/recipe rung must tell the agent it
# needs moduleset_full.qs2, not the default moduleset_lite.qs2
.capability_gap <- function(need, full_caps, lite_caps) isTRUE(full_caps[[need]]) && !isTRUE(lite_caps[[need]])

.any_capability_gap <- function(needs, full_caps, lite_caps){
    length(needs) > 0 && any(vapply(needs, .capability_gap, logical(1), full_caps = full_caps, lite_caps = lite_caps))
}

# one copy-pasteable call string per tool_spec: run_module() for a
# module-scope tool, run_dataset_context() for a dataset-scope tool. String
# only, never executed here -- the manifest template just interpolates it.
# cluster_dme is the one core tool with a required params$group_by (see
# cluster_dme_tool()); fill it in with this ms's actual declared grouping
# column rather than a guessed name, and fall back to the bare invocation
# (no params) when this ms never declared one.
.example_invocation <- function(spec, ms){
    if (spec$scope == 'dataset') {
        return(sprintf("run_dataset_context(ms, list(list(id = '%s')))", spec$id))
    }
    if (identical(spec$id, 'cluster_dme')) {
        group_col <- .ms_group_col(ms)
        if (!is.null(group_col)) {
            return(sprintf(
                "run_module(ms, module_ids[1], tool_config = list(list(id = 'cluster_dme', params = list(group_by = '%s'))))",
                group_col
            ))
        }
    }
    sprintf("run_module(ms, module_ids[1], tool_config = list(list(id = '%s')))", spec$id)
}

# walks the live registry (list_tools() -> get_tool()) rather than any
# hard-coded tool list, so a custom register_tool() call is picked up with no
# special-casing; runnable is computed the same way run_module() itself gates
# a registered tool, so this table never promises a call that would skip.
# `requires` is tagged "(full object only)" when a needed capability is
# present on the full ms but dropped from lite_caps, so the agent knows this
# row won't work against the default moduleset_lite.qs2.
.build_tool_cheatsheet <- function(ms, lite_caps){
    full_caps <- capabilities(ms)
    lapply(list_tools(), function(id){
        spec <- get_tool(id)
        needs <- .tool_spec_requires(spec, params = list())
        requires_txt <- if (length(needs)) paste(needs, collapse = ', ') else 'none'
        if (.any_capability_gap(needs, full_caps, lite_caps)) {
            requires_txt <- paste(requires_txt, '(full object only)')
        }
        list(
            id = spec$id,
            scope = spec$scope,
            tier = spec$tier,
            type = paste(spec$type, collapse = ', '),
            requires = requires_txt,
            runnable = length(needs) == 0 || all(vapply(needs, function(cap) has_capability(ms, cap), logical(1))),
            description = spec$description,
            invocation = .example_invocation(spec, ms)
        )
    })
}

# worked ModuleSet getter examples; modules()/gene_membership() are part of
# the core adapter contract so they always dispatch, everything else is
# emitted only when this ms's capabilities() reports it -- keeps the
# cheat-sheet honest about what will actually return data instead of
# erroring. Rows are still emitted purely off the full ms's capabilities
# (nothing is dropped from the docs); a row is tagged "(full object only)"
# when lite_caps can't back it.
.build_api_cheatsheet <- function(ms, lite_caps){
    full_caps <- capabilities(ms)
    rows <- list(
        list(call = 'modules(ms)', note = 'module ids'),
        list(call = 'gene_membership(ms, module_ids[1])', note = 'ranked hub genes + kME')
    )
    if (has_capability(ms, 'module_scores')) {
        note <- 'per-cell/sample eigengenes'
        if (.capability_gap('module_scores', full_caps, lite_caps)) note <- paste(note, '(full object only)')
        rows <- c(rows, list(list(call = 'module_scores(ms)', note = note)))
    }
    if (has_capability(ms, 'expression')) {
        note <- 'SHAPE ONLY -- never print the matrix; expression() shadows base::expression()'
        if (.capability_gap('expression', full_caps, lite_caps)) note <- paste(note, '(full object only)')
        rows <- c(rows, list(list(call = 'dim(llegir::expression(ms))', note = note)))
    }
    if (has_capability(ms, 'pseudobulk')) {
        note <- 'sample-level view for condition questions'
        if (.capability_gap('pseudobulk', full_caps, lite_caps)) note <- paste(note, '(full object only)')
        rows <- c(rows, list(list(call = 'pseudobulk_view(ms)', note = note)))
    }
    rows
}

# the aggregate-then-summarize ladder, cheapest to heaviest: structure only
# and the per-module slice always apply (core adapter contract), the deeper
# rungs are emitted only when this ms's capabilities() covers what they read.
# FIX: the aggregate rung used to hardcode 'cell_state' as the grouping
# column regardless of what this ms actually declared; it now reads the real
# column via .ms_group_col() and is omitted entirely (rather than emitting a
# call that would error) when this ms never declared one.
.build_safe_recipes <- function(ms, lite_caps){
    full_caps <- capabilities(ms)
    structure_lines <- c('modules(ms)', 'capabilities(ms)')
    if (has_capability(ms, 'expression')) {
        expr_line <- 'dim(llegir::expression(ms))'
        if (.capability_gap('expression', full_caps, lite_caps)) expr_line <- paste(expr_line, '# full object only')
        structure_lines <- c(structure_lines, expr_line)
    }
    recipes <- list(
        list(
            title = 'Structure only',
            code = paste(structure_lines, collapse = '\n'),
            note = 'near-zero tokens -- shape and ids only, never matrix contents'
        ),
        list(
            title = 'Per-module slice',
            code = 'gene_membership(ms, module_ids[1]) %>%\n    head(25)',
            note = 'bounded rows, always safe -- ranked hub genes + kME for one module'
        )
    )

    group_col <- .ms_group_col(ms)
    if (has_capability(ms, 'module_scores') && has_capability(ms, 'grouping') && !is.null(group_col)) {
        note <- 'module scores are already the reduced representation -- never re-derive it from the matrix'
        if (.any_capability_gap(c('module_scores', 'grouping'), full_caps, lite_caps)) {
            note <- paste(note, '(full object only)')
        }
        recipes <- c(recipes, list(list(
            title = 'Aggregate-then-summarize',
            code = paste(
                'module_scores(ms) %>%',
                paste0("    dplyr::bind_cols(metadata(ms)['", group_col, "']) %>%"),
                paste0('    dplyr::group_by(', group_col, ') %>%'),
                '    dplyr::summarise(dplyr::across(dplyr::everything(), mean))',
                sep = '\n'
            ),
            note = note
        )))
    }

    # names a tool via the same registry walk the tool cheat-sheet uses, so
    # this rung always points at something this ms can actually run rather
    # than hard-coding a tool id that might be capability-gated out
    runnable_tools <- Filter(function(row) row$scope == 'module' && row$runnable, .build_tool_cheatsheet(ms, lite_caps))
    if (length(runnable_tools) > 0) {
        tool_id <- runnable_tools[[1]]$id
        needs <- .tool_spec_requires(get_tool(tool_id), params = list())
        note <- 'let a tool do the reduction and hand back a token-efficient fragment digest'
        if (.any_capability_gap(needs, full_caps, lite_caps)) note <- paste(note, '(full object only)')
        recipes <- c(recipes, list(list(
            title = 'Delegate to a registered tool',
            # named/filtered access by fragment_id -- never the positional
            # packet$fragments[[1]], which silently grabs the wrong fragment
            # once a tool_config runs more than one tool
            code = paste(
                sprintf("packet <- run_module(ms, module_ids[1], tool_config = list(list(id = '%s')))", tool_id),
                sprintf("frag <- Filter(function(f) f$fragment_id == '%s', packet$fragments)[[1]]", tool_id),
                'frag$compact_summary',
                'frag$top_findings',
                sep = '\n'
            ),
            note = note
        )))
    }

    recipes
}

#---------------------------------------------------------
# agent workspace: template render + public entry point (part 3)
#---------------------------------------------------------

# human-readable byte size for the Data Topography table
.format_bytes <- function(n){
    if (is.na(n)) return('n/a')
    units <- c('B', 'KB', 'MB', 'GB')
    i <- 1
    while (n >= 1024 && i < length(units)) {
        n <- n / 1024
        i <- i + 1
    }
    sprintf('%.1f %s', n, units[i])
}

# packets_dir_json has no single file to size; sum every file it contains
.path_size <- function(path){
    if (dir.exists(path)) {
        files <- list.files(path, full.names = TRUE, recursive = TRUE)
        if (length(files) == 0) return(0)
        return(sum(file.size(files)))
    }
    file.size(path)
}

# strips workspace_root off an absolute artifact path so the manifest can
# record both a portable relative path and the absolute one; a directory
# (packets_dir_json) gets a trailing slash to read unambiguously. Plain
# prefix stripping rather than sub() -- fixed = TRUE treats '^' as a literal
# character, not an anchor, so a regex-based approach silently no-ops here
.relativize <- function(path, base){
    prefix <- paste0(base, .Platform$file.sep)
    rel <- if (startsWith(path, prefix)) substring(path, nchar(prefix) + 1) else path
    if (dir.exists(path) && !endsWith(rel, '/')) rel <- paste0(rel, '/')
    rel
}

# one row per artifact for the manifest's Data Topography table; class/notes
# are known statically per artifact rather than re-read from disk since ms,
# ms_lite, and dataset_context are already in scope at export time. The
# lite/full rows are annotated so the real on-disk size gap between them
# (moduleset_lite drops expression/counts entirely) is visible at a glance.
.build_data_topography <- function(ms, ms_lite, dataset_context, paths, workspace_root){
    classes <- list(
        moduleset_lite = paste(class(ms_lite), collapse = '/'),
        moduleset_full = paste(class(ms), collapse = '/'),
        dataset_context = paste(class(dataset_context), collapse = '/'),
        packets = 'list[evidence_packet]',
        interpretations = 'list[interpretation]',
        dataset_context_json = 'json',
        packets_dir_json = 'directory[json]',
        interpretations_dir_json = 'directory[json]'
    )
    notes <- list(
        moduleset_lite = 'default -- load this. qs2::qs_read() to a ModuleSet with expression()/counts() dropped; every other getter/tool works unchanged',
        moduleset_full = 'load only for expression()/counts() queries. qs2::qs_read() to the original ModuleSet, backing matrices included',
        dataset_context = 'qs2::qs_read() to a dataset_context S3 object',
        packets = 'qs2::qs_read() to a named list of evidence packets, keyed by module id',
        interpretations = 'qs2::qs_read() to a named list of interpretation objects, keyed by module id',
        dataset_context_json = 'text mirror of dataset_context; hashable, readable without R',
        packets_dir_json = 'one <module_id>.json per evidence packet; text mirror of packets',
        interpretations_dir_json = 'one <module_id>.json per interpretation; text mirror of interpretations'
    )
    lapply(names(paths), function(nm){
        list(
            name = nm,
            rel_path = .relativize(paths[[nm]], workspace_root),
            abs_path = paths[[nm]],
            class = classes[[nm]] %||% 'unknown',
            size = .format_bytes(.path_size(paths[[nm]])),
            note = notes[[nm]] %||% ''
        )
    })
}

# markdown table text for the manifest's Data Topography section
.render_data_topography_block <- function(rows){
    header <- c(
        '| artifact | relative path | absolute path | class | size | notes |',
        '|---|---|---|---|---|---|'
    )
    body <- vapply(rows, function(r){
        sprintf('| `%s` | `%s` | `%s` | %s | %s | %s |', r$name, r$rel_path, r$abs_path, r$class, r$size, r$note)
    }, character(1))
    paste(c(header, body), collapse = '\n')
}

# markdown text block for the manifest's Provenance & Reproducibility section
.render_provenance_block <- function(provenance){
    pkg_lines <- vapply(names(provenance$pkg_versions), function(nm){
        sprintf('- %s: %s', nm, provenance$pkg_versions[[nm]])
    }, character(1))
    hash_lines <- vapply(names(provenance$input_hashes), function(nm){
        h <- provenance$input_hashes[[nm]]
        sprintf('- %s: %s', nm, if (is.na(h)) 'n/a (directory)' else h)
    }, character(1))
    paste(
        paste0('- exported: ', provenance$timestamp),
        paste0('- exporter tool_version (llegir): ', provenance$tool_version),
        '',
        'Package versions:',
        paste(pkg_lines, collapse = '\n'),
        '',
        'Artifact hashes (sha256):',
        paste(hash_lines, collapse = '\n'),
        sep = '\n'
    )
}

# %H:%M:%S%z ('+0200') is ambiguous to a YAML timestamp resolver and yaml::
# as.yaml() doesn't reliably quote it; inserting the ISO 8601 offset colon
# ('+02:00') makes the value visibly non-numeric so as.yaml() quotes it
# itself -- read_agent_manifest() then round-trips it as a plain character
.iso8601_now <- function(){
    ts <- format(Sys.time(), '%Y-%m-%dT%H:%M:%S%z')
    sub('([+-][0-9]{2})([0-9]{2})$', '\\1:\\2', ts)
}

# yaml::as.yaml() renders R logicals as YAML 1.1 yes/no by default; this
# handler forces the lowercase true/false the manifest spec documents, still
# round-tripping to an R logical via yaml::yaml.load()
.yaml_bool_handler <- list(logical = function(x) structure(ifelse(x, 'true', 'false'), class = 'verbatim'))

# the machine-readable YAML front matter read_agent_manifest() parses back;
# artifact paths are recorded relative to workspace_root so the folder stays
# portable if zipped/moved, resolvable against the absolute workspace_root
# also recorded here. capabilities are always the FULL ms's -- nothing is
# dropped from the docs just because the default load is the lite object.
.build_front_matter <- function(ms, desc, paths, workspace_root){
    front <- list(
        llegir_manifest_version = .llegir_manifest_version,
        generated_at = .iso8601_now(),
        llegir_version = as.character(utils::packageVersion('llegir')),
        r_version = as.character(getRversion()),
        workspace_root = workspace_root,
        dataset_description = desc[c('species', 'tissue', 'cell_compartment', 'assay', 'conditions')],
        artifacts = lapply(paths, .relativize, base = workspace_root),
        capabilities = names(which(capabilities(ms))),
        module_ids = modules(ms),
        data_level = ms$data_level,
        aggregated = ms$aggregated
    )
    yaml::as.yaml(front, handlers = .yaml_bool_handler)
}

#' Export a self-contained agent workspace and manifest
#'
#' Serializes the run's `ModuleSet`, dataset context, and evidence packets to
#' `out_dir`, then renders `.llegir_agent_manifest.md`: a static launchpad an
#' external terminal coding agent points at to run open-ended, read-only
#' queries against this analysis. The API and tool cheat-sheets are generated
#' from the live registry and this `ModuleSet`'s capabilities, so a workspace
#' exported after a user registers a custom tool documents that tool with no
#' manual step. Pure exporter: writes files and returns a path, never calls
#' `ellmer` or spends budget.
#'
#' The `ModuleSet` is serialized twice: `artifacts/moduleset_lite.qs2` (a
#' [`.make_moduleset_lite()`] reduction with the backing expression/counts
#' matrices dropped -- what `query_example.R` loads by default) and
#' `artifacts/moduleset_full.qs2` (`ms` unchanged, for the rare
#' `expression()`/`counts()` query). Every cheat-sheet row, tool-registry
#' row, and recipe rung is still generated against `ms`'s full capabilities
#' -- nothing is dropped from the docs -- but is tagged `(full object only)`
#' when it needs something the lite object doesn't carry.
#'
#' @param ms A validated `ModuleSet`.
#' @param dataset_context A `dataset_context` (see [build_dataset_context()]).
#' @param packets A named list of evidence packets, keyed by module id (e.g.
#'   the return value of [run_orchestrator()]).
#' @param desc The `dataset_description` for this run.
#' @param interps A named list of `interpretation` objects, keyed by module
#'   id (e.g. the return value of [run_synthesis_orchestrator()]), or `NULL`
#'   (default) when this run didn't synthesize any. When `NULL`, no
#'   interpretation artifacts are written and the manifest records that this
#'   run shipped no interpretations, so the guest agent does not
#'   mock-synthesize one.
#' @param out_dir Destination workspace directory. Default `'agent_workspace'`.
#' @param write_json Also emit portable JSON copies of the context, packets,
#'   and (if present) interpretations. Default `TRUE`.
#' @return The absolute path to the written manifest, invisibly.
#' @export
export_agent_workspace <- function(ms, dataset_context, packets, desc, interps = NULL,
                                   out_dir = 'agent_workspace', write_json = TRUE){
    validate_moduleset(ms)
    validate_dataset_description(desc)

    #---------------------------------------------------------
    # materialize the workspace tree and serialize artifacts
    #---------------------------------------------------------
    # kept as-passed (not normalized) for the onboarding message's `cd`
    # command below -- basename(out_dir) would truncate a nested path like
    # 'output/agent_workspace' down to just 'agent_workspace'
    out_dir_display <- out_dir
    scaffold <- .scaffold_workspace(out_dir)
    out_dir <- normalizePath(out_dir, mustWork = TRUE)

    ms_lite <- .make_moduleset_lite(ms)
    lite_caps <- capabilities(ms_lite)
    paths <- .write_workspace_artifacts(ms, ms_lite, dataset_context, packets, interps, scaffold$art_dir, write_json)

    provenance <- make_provenance(
        tool_version = as.character(utils::packageVersion('llegir')),
        params = list(out_dir = out_dir),
        input_hashes = .hash_artifacts(paths),
        pkg_versions = pkg_versions(ms),
        source = 'computed'
    )

    #---------------------------------------------------------
    # derive the sections that must track the live registry/adapter
    #---------------------------------------------------------
    manifest_model <- list(
        front_matter = .build_front_matter(ms, desc, paths, out_dir),
        desc_block = render_dataset_description(desc, ms$data_level, ms$aggregated),
        context_block = render_dataset_context_compact(dataset_context),
        topography_block = .render_data_topography_block(.build_data_topography(ms, ms_lite, dataset_context, paths, out_dir)),
        interpretations_missing = is.null(interps),
        api_cheatsheet = .build_api_cheatsheet(ms, lite_caps),
        tool_cheatsheet = .build_tool_cheatsheet(ms, lite_caps),
        recipes = .build_safe_recipes(ms, lite_caps),
        provenance_block = .render_provenance_block(provenance)
    )

    #---------------------------------------------------------
    # render the packaged template; manifest is pure interpolation
    #---------------------------------------------------------
    template <- system.file('templates/agent_manifest.md', package = 'llegir')
    if (!nzchar(template)) stop('could not locate agent_manifest.md in the installed llegir package')

    manifest_txt <- whisker::whisker.render(readLines(template), manifest_model)
    manifest_path <- file.path(out_dir, '.llegir_agent_manifest.md')
    writeLines(manifest_txt, manifest_path)

    query_example_src <- system.file('templates/query_example.R', package = 'llegir')
    if (!nzchar(query_example_src)) stop('could not locate query_example.R in the installed llegir package')
    file.copy(query_example_src, file.path(out_dir, 'query_example.R'), overwrite = TRUE)

    artifact_summary <- 'moduleset_lite.qs2 (default), moduleset_full.qs2, dataset_context.qs2, evidence_packets.qs2'
    if (!is.null(interps)) artifact_summary <- paste0(artifact_summary, ', interpretations.qs2')

    message(
        '\u2714 Agent workspace exported.\n\n',
        '  Manifest : ', file.path(out_dir_display, '.llegir_agent_manifest.md'), '\n',
        '  Artifacts: ', file.path(out_dir_display, 'artifacts'), '/  (', artifact_summary, ')\n\n',
        'Start your terminal coding agent in this folder and point it at the manifest:\n\n',
        '  cd ', out_dir_display, '\n',
        '  claude   "Read .llegir_agent_manifest.md, then follow its Mission & Guardrails and Execution Protocol before answering anything."\n',
        '  # or:  aider --read .llegir_agent_manifest.md\n\n',
        'The manifest is read-only by contract: query the ModuleSet through llegir\n',
        'getters and tools, keep matrices inside R, and write any derived output to\n',
        'scratch/ -- never back over artifacts/.'
    )

    invisible(manifest_path)
}
