## Tool registry: register_tool()/get_tool()/list_tools() make tool
## registration a uniform, documented public API for both core and custom
## tools (docs/milestone_extensibility.md Part 2b, docs/custom_tools.md). A
## tool_spec carries id, description, the fragment `type`(s) it may emit, and
## the ModuleSet capabilities it requires, which the runners check before a
## tool runs (whether the spec names it by id or by function) so tools never
## need to self-skip on a missing capability.
##
## Core tools are registered through the exact same register_tool() call,
## from .onLoad() below rather than at this file's top level: R sources R/
## files in (roughly) alphabetical order, so a top-level call here would run
## before tool_signature_correlation.R etc. define the functions it
## references. .onLoad() is invoked by the package-loading machinery only
## after every R/ file has been sourced, so it's the correct place for
## cross-file registration regardless of file order.

.tool_registry <- new.env(parent = emptyenv())

#' Register a tool (core or custom) in the tool registry
#'
#' A tool is any `function(ctx) -> evidence_fragment` (or `NULL`, to skip;
#' see [run_module()]). Registering it makes it runnable from `tool_config`
#' by id (`list(id = 'my_tool', params = list(...))`) and lets
#' [run_module()] check its required `ModuleSet` [capabilities()] before
#' calling it, skipping gracefully and recording why in the packet if
#' they're unmet, rather than the tool having to self-skip. See
#' `docs/custom_tools.md` for a worked template.
#'
#' @param id A unique tool id, e.g. `'top_genes'` or `'my_custom_tool'`.
#' @param fn A `function(ctx) -> evidence_fragment`, where `ctx` is
#'   `list(ms, module_id, params)` (see [run_module()]).
#' @param type One or more of the `evidence_fragment` controlled vocabulary
#'   (see [evidence_fragment()]) this tool may emit. Descriptive only -- the
#'   fragment a tool actually returns is always checked against the full
#'   contract by [validate_evidence_fragment()] regardless of what's declared
#'   here. A tool whose emitted type depends on its params can declare more
#'   than one.
#' @param description A one-line, human-readable description of what the tool does.
#' @param requires The `ModuleSet` [capabilities()] this tool needs to run:
#'   either a character vector (e.g. `c('grouping', 'module_scores')`), or a
#'   `function(params) -> character vector` for a tool whose requirement
#'   depends on how it's called. Default `character(0)` (no requirement).
#' @param tier Structural importance tier consulted by
#'   [calculate_fusion_score()] to weight this tool's fragments: one of
#'   `'high'`, `'medium'`, `'low'`. Default `'medium'`. Ignored when
#'   `scope == 'dataset'` -- dataset fragments never enter fusion.
#' @param scope Whether this tool runs per module (default) or once per
#'   dataset: one of `'module'`, `'dataset'`. A `'module'` tool's `type` is
#'   checked against the [evidence_fragment()] vocabulary; a `'dataset'`
#'   tool's `type` against the [dataset_fragment()] vocabulary. Default
#'   `'module'`.
#' @param params Optional character vector naming the parameters the tool
#'   accepts. When given, [tool()] warns about any other parameter (usually a
#'   typo) and [run_evidence()] hands the tool only the run-level parameters
#'   it accepts. `NULL` (default) skips both checks.
#' @return `id`, invisibly.
#' @examples
#' my_tool <- function(ctx) top_genes_tool(ctx)
#' register_tool(
#'     'my_tool', my_tool, type = 'ranked_genes',
#'     description = 'demo', requires = character(0), params = 'n_hubs'
#' )
#' @export
register_tool <- function(id, fn, type, description, requires = character(0), tier = 'medium', scope = 'module',
                          params = NULL){
    if (!is.character(id) || length(id) != 1) stop('id must be a single string')
    if (!is.function(fn)) stop('fn must be a function')
    if (!(scope %in% c('module', 'dataset'))) stop("scope must be one of 'module', 'dataset'")
    valid_types <- if (scope == 'dataset') .dataset_fragment_types else .fragment_types
    if (!all(type %in% valid_types)) stop('invalid type: ', paste(setdiff(type, valid_types), collapse = ', '))
    if (!is.function(requires) && !is.character(requires)) stop('requires must be a character vector or a function(params)')
    if (!(tier %in% c('high', 'medium', 'low'))) stop("tier must be one of 'high', 'medium', 'low'")
    if (!is.null(params) && !is.character(params)) stop('params must be a character vector of parameter names')

    # registration order breaks ties when one function is registered under
    # several ids (.find_registered() keeps the earliest, i.e. the core id)
    order <- if (exists(id, envir = .tool_registry, inherits = FALSE)) get_tool(id)$order else length(ls(envir = .tool_registry)) + 1
    spec <- structure(
        list(
            id = id, fn = fn, type = type, description = description, requires = requires,
            tier = tier, scope = scope, params = params, order = order
        ),
        class = 'tool_spec'
    )
    assign(id, spec, envir = .tool_registry)
    invisible(id)
}

#' Look up a registered tool spec by id
#'
#' @param id A tool id, as passed to [register_tool()].
#' @return A `tool_spec` object: `list(id, fn, type, description, requires)`.
#' @examples
#' get_tool('top_genes')
#' @export
get_tool <- function(id){
    if (!exists(id, envir = .tool_registry, inherits = FALSE)) stop('tool not registered: ', id)
    get(id, envir = .tool_registry, inherits = FALSE)
}

#' List every registered tool id
#'
#' @param scope Filter by [register_tool()]'s `scope`: `NULL` (default)
#'   returns every registered tool, `'module'` or `'dataset'` returns only
#'   tools registered with that scope.
#' @return A sorted character vector of tool ids.
#' @examples
#' list_tools()
#' list_tools('dataset')
#' @export
list_tools <- function(scope = NULL){
    ids <- sort(ls(envir = .tool_registry))
    if (is.null(scope)) return(ids)
    if (!(scope %in% c('module', 'dataset'))) stop("scope must be one of 'module', 'dataset'")
    Filter(function(id) get_tool(id)$scope == scope, ids)
}

#---------------------------------------------------------
# tool specs
#---------------------------------------------------------

.spec_fields <- c('id', 'fn', 'params')

# the registry entry whose fn is this exact function, so a list(fn = ) spec
# naming a registered tool gets its capability check and id; NULL for an
# unregistered (ad hoc) function
.find_registered <- function(fn){
    matches <- Filter(function(entry) identical(entry$fn, fn), lapply(list_tools(), get_tool))
    if (length(matches) == 0) return(NULL)
    matches[[which.min(vapply(matches, function(entry) entry$order, numeric(1)))]]
}

# normalizes any spec form (tool(), list(id = ), list(fn = )) to one
# llegir_tool_spec, failing loudly on the config mistakes that used to pass
# silently: an unknown field (e.g. `param =`), neither fn nor id, or a tool of
# the wrong scope for the runner it was handed to
.resolve_spec <- function(spec, scope = NULL){
    if (!inherits(spec, 'llegir_tool_spec')) {
        if (!is.list(spec)) stop('a tool spec must be tool(...), list(id = , params = ) or list(fn = , params = )')
        unknown <- setdiff(names(spec), .spec_fields)
        if (length(unknown) > 0) {
            stop('tool spec has unknown field(s): ', paste(unknown, collapse = ', '), ' (expected id or fn, plus params)')
        }
        if (is.null(spec$id) && is.null(spec$fn)) stop('tool spec needs an id or a fn')
        entry <- if (!is.null(spec$id)) get_tool(spec$id) else .find_registered(spec$fn)
        spec <- structure(
            list(
                id = entry$id,
                fn = spec$fn %||% entry$fn,
                params = spec$params %||% list(),
                requires = entry$requires %||% character(0),
                scope = entry$scope,
                accepts = entry$params
            ),
            class = 'llegir_tool_spec'
        )
        unknown_params <- setdiff(names(spec$params), spec$accepts)
        if (!is.null(spec$accepts) && length(unknown_params) > 0) {
            warning(
                'tool ', spec$id, ' does not take parameter(s): ', paste(unknown_params, collapse = ', '),
                ' (it takes: ', paste(spec$accepts, collapse = ', '), ')', call. = FALSE
            )
        }
    }
    if (!is.null(scope) && !is.null(spec$scope) && spec$scope != scope) {
        runner <- if (scope == 'module') 'the module tool list' else 'the dataset tool list'
        stop('tool ', spec$id, ' is ', spec$scope, '-scoped and cannot run in ', runner)
    }
    spec
}

#' Name one tool in a tool chain
#'
#' The preferred way to list tools for [run_evidence()], [run_orchestrator()]
#' or [run_dataset_context()]: `tool('top_genes', n_hubs = 25)` instead of
#' `list(id = 'top_genes', params = list(n_hubs = 25))`. A registered tool is
#' capability-checked before it runs and every skip is recorded on the packet.
#'
#' @param x A registered tool id (see [list_tools()]) or a tool function
#'   (`function(ctx)` returning an `evidence_fragment`, a `dataset_fragment`
#'   or `NULL`).
#' @param ... Tool parameters, passed to the tool as `ctx$params`.
#' @return A `llegir_tool_spec`.
#' @examples
#' tool('top_genes', n_hubs = 25)
#' tool(top_genes_tool, n_hubs = 25)
#' @export
tool <- function(x, ...){
    params <- list(...)
    spec <- if (is.character(x) && length(x) == 1) {
        list(id = x, params = params)
    } else if (is.function(x)) {
        list(fn = x, params = params)
    } else {
        stop('tool() takes a registered tool id or a tool function')
    }
    .resolve_spec(spec)
}

#' @export
print.llegir_tool_spec <- function(x, ...){
    label <- x$id %||% 'unregistered tool'
    params <- if (length(x$params)) paste(names(x$params), collapse = ', ') else 'none'
    cat('<llegir tool> ', label, ' [', x$scope %||% 'unknown scope', '] params: ', params, '\n', sep = '')
    if (length(x$accepts)) cat('  accepts: ', paste(x$accepts, collapse = ', '), '\n', sep = '')
    if (length(x$requires) && !is.function(x$requires)) {
        cat('  requires: ', paste(x$requires, collapse = ', '), '\n', sep = '')
    }
    invisible(x)
}

# the required capabilities for one call: requires may be a static vector or
# a function(params), for a tool whose requirement depends on how it's called
.tool_spec_requires <- function(spec, params){
    if (is.function(spec$requires)) spec$requires(params) else spec$requires
}

.onLoad <- function(libname, pkgname){
    register_tool(
        'top_genes', top_genes_tool, type = 'ranked_genes',
        description = 'Top module genes ranked by membership (kME)',
        requires = character(0), tier = 'medium',
        params = 'n_hubs'
    )
    register_tool(
        'cluster_dme', cluster_dme_tool, type = 'state_expression',
        description = 'Which cell states express this module',
        requires = c('grouping', 'module_scores'), tier = 'high',
        params = 'group_col'
    )
    register_tool(
        'cluster_expression_profile', cluster_expression_profile_tool, type = 'state_expression',
        description = "Per-state profile of a module's global score deciles, so medium expressers stay visible",
        requires = c('grouping', 'module_scores'), tier = 'high',
        params = c('group_col', 'n_deciles')
    )
    register_tool(
        'geneset_enrichment', geneset_enrichment_tool, type = 'geneset_enrichment',
        description = "Gene-set overlap enrichment among a module's hub genes",
        requires = 'expression', tier = 'low',
        params = c('db_files', 'n_hubs', 'alpha')
    )
    register_tool(
        'signature_correlation', signature_correlation_tool, type = 'signature_correlation',
        description = "Correlate a module's activity with a signature library",
        requires = c('module_scores', 'expression'), tier = 'medium',
        params = c('library_files', 'method')
    )
    register_tool(
        'differential_module_activity', differential_module_activity_tool,
        type = c('cross_condition_delta', 'categorical_association'),
        description = "Module-level differential activity across a condition, on pseudo-bulk samples",
        requires = 'pseudobulk', tier = 'high',
        params = c('condition_col', 'covariates', 'method')
    )
    register_tool(
        'pseudobulk_de_limma', pseudobulk_de_limma_tool,
        type = 'cross_condition_delta',
        description = "Gene-level differential expression (limma-voom) within a module, on pseudo-bulk counts",
        requires = 'pseudobulk', tier = 'high',
        params = c('condition_col', 'covariates', 'min_count', 'min_count_samples')
    )
    register_tool(
        'dataset_composition', dataset_composition_tool, type = 'composition_summary',
        description = 'Cell-state census and condition covariate balance across the whole dataset',
        requires = 'grouping', scope = 'dataset',
        params = c('group_col', 'condition_col', 'sample_col', 'residual_threshold', 'min_samples', 'min_cells')
    )
    register_tool(
        'dataset_variance_structure', dataset_variance_structure_tool, type = 'variance_structure',
        description = 'Principal-component regression against metadata covariates, on the pseudo-bulk view',
        requires = 'pseudobulk', scope = 'dataset',
        params = c('covariates', 'condition_col', 'technical_covariates', 'n_components')
    )
    register_tool(
        'dataset_baseline_expression', dataset_baseline_expression_tool, type = 'baseline_expression',
        description = 'Dataset-wide baseline expression, ribosomal/mitochondrial mass, and depth distribution',
        requires = 'expression', scope = 'dataset',
        params = 'top_n'
    )
}
