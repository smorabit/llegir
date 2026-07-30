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

.llegir_manifest_version <- '0.1'

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

# .rds is authoritative (full S3 objects); .json is the portable/hashable
# mirror an agent can read without spawning R. Both point at the same run.
# art_dir is expected to already exist (see .scaffold_workspace()).
.write_workspace_artifacts <- function(ms, dataset_context, packets, art_dir, write_json){
    ms_path <- file.path(art_dir, 'moduleset.rds')
    dctx_path <- file.path(art_dir, 'dataset_context.rds')
    pkt_path <- file.path(art_dir, 'evidence_packets.rds')
    saveRDS(ms, ms_path)
    saveRDS(dataset_context, dctx_path)
    saveRDS(packets, pkt_path)

    paths <- list(
        moduleset_rds = ms_path,
        dataset_context_rds = dctx_path,
        packets_rds = pkt_path
    )
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
# agent workspace: cheat-sheet generators (part 2)
#---------------------------------------------------------

# one copy-pasteable call string per tool_spec: run_module() for a
# module-scope tool, run_dataset_context() for a dataset-scope tool. String
# only, never executed here -- the manifest template just interpolates it.
.example_invocation <- function(spec){
    if (spec$scope == 'dataset') {
        sprintf("run_dataset_context(ms, list(list(id = '%s')))", spec$id)
    } else {
        sprintf("run_module(ms, module_ids[1], tool_config = list(list(id = '%s')))", spec$id)
    }
}

# walks the live registry (list_tools() -> get_tool()) rather than any
# hard-coded tool list, so a custom register_tool() call is picked up with no
# special-casing; runnable is computed the same way run_module() itself gates
# a registered tool, so this table never promises a call that would skip
.build_tool_cheatsheet <- function(ms){
    lapply(list_tools(), function(id){
        spec <- get_tool(id)
        needs <- .tool_spec_requires(spec, params = list())
        list(
            id = spec$id,
            scope = spec$scope,
            tier = spec$tier,
            type = paste(spec$type, collapse = ', '),
            requires = if (length(needs)) paste(needs, collapse = ', ') else 'none',
            runnable = length(needs) == 0 || all(vapply(needs, function(cap) has_capability(ms, cap), logical(1))),
            description = spec$description,
            invocation = .example_invocation(spec)
        )
    })
}

# worked ModuleSet getter examples; modules()/gene_membership() are part of
# the core adapter contract so they always dispatch, everything else is
# emitted only when this ms's capabilities() reports it -- keeps the
# cheat-sheet honest about what will actually return data instead of erroring
.build_api_cheatsheet <- function(ms){
    rows <- list(
        list(call = 'modules(ms)', note = 'module ids'),
        list(call = 'gene_membership(ms, module_ids[1])', note = 'ranked hub genes + kME')
    )
    if (has_capability(ms, 'module_scores')) {
        rows <- c(rows, list(list(call = 'module_scores(ms)', note = 'per-cell/sample eigengenes')))
    }
    if (has_capability(ms, 'expression')) {
        rows <- c(rows, list(list(
            call = 'dim(llegir::expression(ms))',
            note = 'SHAPE ONLY -- never print the matrix; expression() shadows base::expression()'
        )))
    }
    if (has_capability(ms, 'pseudobulk')) {
        rows <- c(rows, list(list(call = 'pseudobulk_view(ms)', note = 'sample-level view for condition questions')))
    }
    rows
}

# the aggregate-then-summarize ladder, cheapest to heaviest: structure only
# and the per-module slice always apply (core adapter contract), the deeper
# rungs are emitted only when this ms's capabilities() covers what they read
.build_safe_recipes <- function(ms){
    structure_lines <- c('modules(ms)', 'capabilities(ms)')
    if (has_capability(ms, 'expression')) {
        structure_lines <- c(structure_lines, 'dim(llegir::expression(ms))')
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

    if (has_capability(ms, 'module_scores') && has_capability(ms, 'grouping')) {
        recipes <- c(recipes, list(list(
            title = 'Aggregate-then-summarize',
            code = paste(
                "module_scores(ms) %>%",
                "    dplyr::bind_cols(metadata(ms)['cell_state']) %>%",
                "    dplyr::group_by(cell_state) %>%",
                "    dplyr::summarise(dplyr::across(dplyr::everything(), mean))",
                sep = '\n'
            ),
            note = 'module scores are already the reduced representation -- never re-derive it from the matrix'
        )))
    }

    # names a tool via the same registry walk the tool cheat-sheet uses, so
    # this rung always points at something this ms can actually run rather
    # than hard-coding a tool id that might be capability-gated out
    runnable_tools <- Filter(function(row) row$scope == 'module' && row$runnable, .build_tool_cheatsheet(ms))
    if (length(runnable_tools) > 0) {
        tool_id <- runnable_tools[[1]]$id
        recipes <- c(recipes, list(list(
            title = 'Delegate to a registered tool',
            code = paste(
                sprintf("packet <- run_module(ms, module_ids[1], tool_config = list(list(id = '%s')))", tool_id),
                'packet$fragments[[1]]$compact_summary',
                'packet$fragments[[1]]$top_findings',
                sep = '\n'
            ),
            note = 'let a tool do the reduction and hand back a token-efficient fragment digest'
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
# are known statically per artifact rather than re-read from disk since ms
# and dataset_context are already in scope at export time
.build_data_topography <- function(ms, dataset_context, paths, workspace_root){
    classes <- list(
        moduleset_rds = paste(class(ms), collapse = '/'),
        dataset_context_rds = paste(class(dataset_context), collapse = '/'),
        packets_rds = 'list[evidence_packet]',
        dataset_context_json = 'json',
        packets_dir_json = 'directory[json]'
    )
    notes <- list(
        moduleset_rds = 'readRDS() to a ModuleSet S3 object; pass straight into any llegir getter',
        dataset_context_rds = 'readRDS() to a dataset_context S3 object',
        packets_rds = 'readRDS() to a named list of evidence packets, keyed by module id',
        dataset_context_json = 'text mirror of dataset_context_rds; hashable, readable without R',
        packets_dir_json = 'one <module_id>.json per evidence packet; text mirror of packets_rds'
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

# the machine-readable YAML front matter read_agent_manifest() parses back;
# artifact paths are recorded relative to workspace_root so the folder stays
# portable if zipped/moved, resolvable against the absolute workspace_root
# also recorded here
.build_front_matter <- function(ms, desc, paths, workspace_root){
    front <- list(
        llegir_manifest_version = .llegir_manifest_version,
        generated_at = format(Sys.time(), '%Y-%m-%dT%H:%M:%S%z'),
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
    yaml::as.yaml(front)
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
#' @param ms A validated `ModuleSet`.
#' @param dataset_context A `dataset_context` (see [build_dataset_context()]).
#' @param packets A named list of evidence packets, keyed by module id (e.g.
#'   the return value of [run_orchestrator()]).
#' @param desc The `dataset_description` for this run.
#' @param out_dir Destination workspace directory. Default `'agent_workspace'`.
#' @param write_json Also emit portable JSON copies of the context and
#'   packets. Default `TRUE`.
#' @return The absolute path to the written manifest, invisibly.
#' @export
export_agent_workspace <- function(ms, dataset_context, packets, desc,
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
    paths <- .write_workspace_artifacts(ms, dataset_context, packets, scaffold$art_dir, write_json)

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
        topography_block = .render_data_topography_block(.build_data_topography(ms, dataset_context, paths, out_dir)),
        api_cheatsheet = .build_api_cheatsheet(ms),
        tool_cheatsheet = .build_tool_cheatsheet(ms),
        recipes = .build_safe_recipes(ms),
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

    message(
        '\u2714 Agent workspace exported.\n\n',
        '  Manifest : ', file.path(out_dir_display, '.llegir_agent_manifest.md'), '\n',
        '  Artifacts: ', file.path(out_dir_display, 'artifacts'),
        '/  (moduleset.rds, dataset_context.rds, evidence_packets.rds)\n\n',
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
