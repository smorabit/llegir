## ModuleSet adapter interface (generic contract).
## Core tools call only these generics, never a backend package directly.
## docs/implementation_guide.md#5

#' List the module ids in a module set
#'
#' @param ms A `ModuleSet` object (e.g. one built by [hdWGCNA_ModuleSet()]).
#' @param ... Passed to methods.
#' @return A character vector of module ids.
#' @export
modules <- function(ms, ...) UseMethod('modules')

#' Genes assigned to a module, ranked by membership strength
#'
#' @param ms A `ModuleSet` object.
#' @param module A single module id, as returned by [modules()].
#' @param ... Passed to methods.
#' @return A data.frame with one row per gene, ranked strongest membership first
#'   (e.g. by hdWGCNA's kME).
#' @export
gene_membership <- function(ms, module, ...) UseMethod('gene_membership')

#' Per-cell (or per-sample) module scores
#'
#' @param ms A `ModuleSet` object.
#' @param ... Passed to methods.
#' @return A data.frame with one column per module (e.g. hdWGCNA module
#'   eigengenes), one row per cell/sample.
#' @export
module_scores <- function(ms, ...) UseMethod('module_scores')

#' Underlying expression matrix backing a module set
#'
#' @param ms A `ModuleSet` object.
#' @param ... Passed to methods.
#' @return A genes-by-cells (or genes-by-samples) numeric matrix.
#' @note Shadows `base::expression()` once this package is attached; this
#'   package makes no use of `base::expression()` / plotmath. Flagged here as
#'   a known design tradeoff, not fixed in this packaging pass.
#' @export
expression <- function(ms, ...) UseMethod('expression')

#' Cell / sample metadata for a module set
#'
#' @param ms A `ModuleSet` object.
#' @param ... Passed to methods.
#' @return A data.frame with one row per cell/sample, matching the columns of
#'   [expression()] / [module_scores()].
#' @export
metadata <- function(ms, ...) UseMethod('metadata')

#' Backend package versions for provenance logging
#'
#' @param ms A `ModuleSet` object.
#' @param ... Passed to methods.
#' @return A named list of backend package versions (e.g. `hdWGCNA`,
#'   `Seurat`), so core tools stay backend-agnostic while still recording
#'   which package versions produced the evidence.
#' @export
pkg_versions <- function(ms, ...) UseMethod('pkg_versions')

#' Which capabilities a ModuleSet provides
#'
#' Reports which of a fixed vocabulary this module set supports:
#' `gene_weights` (real per-gene membership weights, e.g. kME, not a uniform
#' placeholder), `module_scores` (per-cell/sample module scores are
#' available), `expression` (the backing expression matrix is available),
#' `clusters` (a cell/sample-state grouping column was declared to the
#' adapter), and `sample_ids` (a sample-id column was declared). Capabilities
#' are declared by the adapter, not inferred from probing `metadata()` --
#' declaring `clusters`/`sample_ids` is how a source advertises that it
#' supports that concept at all, independent of which particular metadata
#' column a tool is asked to use. Core tools consult this ([has_capability()])
#' before running so they can skip gracefully instead of erroring when a
#' capability the source doesn't support is required.
#'
#' @param ms A `ModuleSet` object.
#' @param ... Passed to methods.
#' @return A named logical vector over `c('gene_weights', 'module_scores',
#'   'expression', 'clusters', 'sample_ids')`.
#' @export
capabilities <- function(ms, ...) UseMethod('capabilities')

#' Check whether a ModuleSet has a given capability
#'
#' @param ms A `ModuleSet` object.
#' @param name A single capability name, e.g. `'clusters'`; see [capabilities()].
#' @return A single logical; `FALSE` if `name` isn't reported at all.
#' @export
has_capability <- function(ms, name){
    # single-bracket indexing (not `[[`) so a name capabilities() doesn't
    # report comes back NA, not a "subscript out of bounds" error
    isTRUE(capabilities(ms)[name])
}
