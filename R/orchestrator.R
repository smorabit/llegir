## orchestrator: runs a configured set of tools over every module in a
## ModuleSet and writes validated, hashed evidence packets to disk.
##
## `tool_config` is a list of `list(fn, params)` specs, e.g.:
##   list(
##       list(fn = hub_genes_tool, params = list(n_hubs = 25)),
##       list(fn = cluster_dme_tool, params = list(group_by = 'lv2_annot'))
##   )
## `fn` is any function(ctx) -> evidence_fragment; core tools today, custom
## tools later (M2) just append to this list.

# fragments for one module, in packet form; one bad tool call fails the whole
# module (a partial packet would be worse than no packet)
run_module <- function(ms, module_id, tool_config, input_hash = NA_character_){
    fragments <- lapply(tool_config, function(spec){
        ctx <- list(ms = ms, module_id = module_id, params = spec$params)
        spec$fn(ctx)
    })
    build_evidence_packet(module_id, fragments, input_hash = input_hash)
}

# runs every module independently so one module's failure (e.g. a tool
# erroring on a degenerate module) doesn't take down the whole batch; failures
# are reported via `warning()` and recorded as NULL in the returned list.
# `tables_dir`, when given, also persists every fragment's result table
# (docs/milestone_1_5.md task 4) alongside the JSON packets in `output_dir`.
run_orchestrator <- function(ms, tool_config, output_dir, tables_dir = NULL, modules_use = NULL, input_hash = NA_character_){
    if (is.null(modules_use)) modules_use <- modules(ms)
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    if (!is.null(tables_dir)) dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

    packets <- lapply(modules_use, function(mod){
        packet <- tryCatch(
            run_module(ms, mod, tool_config, input_hash = input_hash),
            error = function(e){
                warning('module ', mod, ' failed: ', conditionMessage(e), call. = FALSE)
                NULL
            }
        )
        if (!is.null(packet)) {
            write_evidence_packet(packet, file.path(output_dir, paste0(mod, '.json')))
            if (!is.null(tables_dir)) write_fragment_tables(packet, tables_dir)
        }
        packet
    })
    names(packets) <- modules_use
    invisible(packets)
}

## synthesis-stage orchestration (docs/milestone_2.md tasks 5-7): mirrors
## run_module()/run_orchestrator() above but for the packet -> interpretation
## stage. Kept in this file rather than a separate one since it's the same
## per-module-then-batch shape, just one stage further down the pipeline.

# one packet -> one validated, faithfulness-enforced, confidence-fused
# interpretation. The three steps always run together -- an interpretation
# that skipped faithfulness or fusion isn't one this engine should emit.
synthesize_module <- function(packet, desc, backend, temperature = 0, seed = NA_real_,
                               prompt_template_version = PROMPT_TEMPLATE_VERSION,
                               schema_path = 'schemas/interpretation.schema.json'){
    interp <- synthesize_interpretation(
        packet, desc, backend, temperature = temperature, seed = seed,
        prompt_template_version = prompt_template_version, schema_path = schema_path
    )
    interp <- enforce_faithfulness(interp, packet)
    interp <- fuse_confidence(interp, packet)
    validate_interpretation(interp)
    interp
}

# runs synthesis over every packet independently, same failure isolation as
# run_orchestrator(): one module's synthesis error is warned and recorded as
# NULL rather than failing the batch. Writes per-module JSON + Markdown, plus
# a run-level review_queue.tsv and manifest.json (docs/milestone_2.md tasks
# 6-7). `packets` is a named list of evidence packets, e.g. the return value
# of run_orchestrator().
run_synthesis_orchestrator <- function(packets, desc, backend, output_dir, temperature = 0, seed = NA_real_,
                                        prompt_template_version = PROMPT_TEMPLATE_VERSION,
                                        schema_path = 'schemas/interpretation.schema.json'){
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    mods <- names(packets)

    interps <- lapply(mods, function(mod){
        packet <- packets[[mod]]
        if (is.null(packet)) return(NULL)
        interp <- tryCatch(
            synthesize_module(
                packet, desc, backend, temperature = temperature, seed = seed,
                prompt_template_version = prompt_template_version, schema_path = schema_path
            ),
            error = function(e){
                warning('synthesis failed for module ', mod, ': ', conditionMessage(e), call. = FALSE)
                NULL
            }
        )
        if (!is.null(interp)) {
            write_interpretation(interp, file.path(output_dir, paste0(mod, '.json')))
            writeLines(render_paragraph(interp), file.path(output_dir, paste0(mod, '.md')))
        }
        interp
    })
    names(interps) <- mods

    write_review_queue(interps, file.path(output_dir, 'review_queue.tsv'))
    write_synthesis_manifest(build_synthesis_manifest(interps, desc, prompt_template_version), file.path(output_dir, 'manifest.json'))

    invisible(interps)
}
