## small shared helpers, no adapter or backend dependency.

# null-coalesce; used for ctx$params defaults in tool files
`%||%` <- function(a, b) if (is.null(a)) b else a

# a metadata-column parameter (group_col, sample_col, condition_col): the
# tool's own param wins, else the column the ModuleSet itself declared, so a
# column named once on the ModuleSet reaches every tool
.param_col <- function(ctx, name){
    ctx$params[[name]] %||% ctx$ms[[name]]
}
