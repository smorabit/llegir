## run_evidence(): one tool list, split by registry scope, with run-level
## params routed to the tools that accept them.

test_that('run_evidence() runs dataset and module tools from one list', {
    ms <- llegir_example_moduleset()
    out_dir <- tempfile()
    ev <- run_evidence(
        ms,
        tools = list(tool('top_genes'), tool('dataset_composition'), tool('cluster_dme')),
        params = list(n_hubs = 7),
        modules_use = modules(ms)[1:2],
        output_dir = out_dir
    )
    expect_named(ev, c('dataset_context', 'packets'))
    expect_equal(names(ev$packets), modules(ms)[1:2])
    expect_equal(ev$dataset_context$dataset_fragments[[1]]$tool_id, 'dataset_composition')
    ids <- vapply(ev$packets[[1]]$fragments, function(f) f$fragment_id, character(1))
    expect_setequal(ids, c('top_genes', 'cluster_dme'))
    expect_true(file.exists(file.path(out_dir, 'dataset_context.json')))
    expect_true(file.exists(file.path(out_dir, 'packets', paste0(modules(ms)[1], '.json'))))
})

test_that('run_evidence() hands each tool only the run-level params it accepts, tool params winning', {
    ms <- llegir_example_moduleset()
    seen <- new.env()
    probe <- function(ctx){
        seen$params <- ctx$params
        NULL
    }
    register_tool('run_evidence_probe', probe, type = 'ranked_genes', description = 'probe', params = c('n_hubs', 'alpha'))
    ev <- run_evidence(
        ms,
        tools = list(tool('run_evidence_probe', alpha = 0.1), tool('top_genes')),
        params = list(n_hubs = 4, alpha = 0.5),
        modules_use = modules(ms)[1]
    )
    expect_equal(seen$params, list(n_hubs = 4, alpha = 0.1))
    expect_equal(nrow(ev$packets[[1]]$fragments[[1]]$result), 4)
})

test_that('run_evidence() and tool() warn about parameters no tool takes', {
    ms <- llegir_example_moduleset()
    expect_warning(tool('top_genes', n_hub = 5), 'does not take parameter.*n_hub')
    expect_warning(
        run_evidence(ms, list(tool('top_genes')), params = list(n_hubbs = 5), modules_use = modules(ms)[1]),
        'taken by none of the tools: n_hubbs'
    )
})
