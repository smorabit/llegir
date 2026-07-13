## synthesis layer: model-facing schema derivation + mock-backend end-to-end
## (docs/milestone_2.md task 2). No network / no API key anywhere in this file.

test_that('model_output_schema_json() strips orchestrator-only fields', {
    schema_json <- model_output_schema_json('../../schemas/interpretation.schema.json')
    schema <- jsonlite::fromJSON(schema_json, simplifyVector = FALSE)
    expect_false('provenance' %in% names(schema$properties))
    expect_false('schema_version' %in% names(schema$properties))
    expect_false('model_score' %in% names(schema$properties$confidence$properties))
    expect_true('module_id' %in% names(schema$properties))
    expect_true('score' %in% names(schema$properties$confidence$properties))
})

test_that('model_output_schema_json() is loadable by ellmer::type_from_schema()', {
    skip_if_not_installed('ellmer')
    schema_json <- model_output_schema_json('../../schemas/interpretation.schema.json')
    type_spec <- ellmer::type_from_schema(text = schema_json)
    expect_true(inherits(type_spec, 'ellmer::TypeJsonSchema'))
})

test_that('synthesize_interpretation() hard-errors without a valid dataset_description', {
    packet <- run_module(ms_test, mod_test, csf_tool_config, input_hash = 'abc')
    bad_desc <- csf_dataset_description()
    bad_desc$species <- NA_character_
    expect_error(
        synthesize_interpretation(packet, bad_desc, backend = mock_backend(), schema_path = test_schema_path),
        'species'
    )
})

test_that('synthesize_interpretation() with mock_backend() returns a valid interpretation, module_id forced from the packet', {
    packet <- run_module(ms_test, mod_test, csf_tool_config, input_hash = 'abc')
    interp <- synthesize_interpretation(packet, csf_dataset_description(), backend = mock_backend(), schema_path = test_schema_path)
    expect_true(validate_interpretation(interp))
    # the mock backend's canned content says module_id = 'MOCK'; the
    # orchestrator must override it with the real packet's module_id
    expect_equal(interp$module_id, mod_test)
    expect_equal(interp$provenance$input_packet_hash, packet$packet_hash)
    expect_equal(interp$provenance$model, 'mock')
    expect_equal(interp$provenance$prompt_template_version, PROMPT_TEMPLATE_VERSION)
    expect_equal(interp$confidence$score, interp$confidence$model_score)
    expect_equal(interp$literature, list())
})

test_that('.to_openai_strict_schema() satisfies GitHub Models strict structured-output rules', {
    schema_json <- model_output_schema_json('../../schemas/interpretation.schema.json')
    schema <- jsonlite::fromJSON(schema_json, simplifyVector = FALSE)
    strict <- .to_openai_strict_schema(schema)

    # every property must be listed in required (optionality comes from a
    # nullable type instead), and additionalProperties must be false --
    # checked at the top level and at two nested object levels
    expect_setequal(strict$required, names(strict$properties))
    expect_false(is.null(strict$additionalProperties) || strict$additionalProperties)

    claim_item <- strict$properties$supporting_claims$items
    expect_setequal(claim_item$required, names(claim_item$properties))
    expect_false(claim_item$additionalProperties)

    expect_setequal(strict$properties$confidence$required, names(strict$properties$confidence$properties))
    expect_false(strict$properties$confidence$additionalProperties)
})

test_that('resolve_backend() dispatches provider without touching the network (docs/dev_economy.md task 1)', {
    expect_true(is.function(resolve_backend('mock')))
    expect_true(is.function(resolve_backend('github', model = 'gpt-4o-mini')))
    expect_true(is.function(resolve_backend('gemini', model = 'gemini-3.5-flash')))
    expect_error(resolve_backend('bogus'))
})

test_that('cached_backend() skips the inner backend on a cache hit and honors force_refresh (docs/dev_economy.md task 3)', {
    cache_dir <- tempfile('cache_')
    on.exit(unlink(cache_dir, recursive = TRUE))

    n_calls <- 0
    counting_backend <- function(system_prompt, user_prompt, schema_json, packet_hash = NA_character_){
        n_calls <<- n_calls + 1
        mock_backend()(system_prompt, user_prompt, schema_json, packet_hash = packet_hash)
    }
    backend <- cached_backend(counting_backend, provider = 'github', model = 'gpt-4o-mini',
                               prompt_template_version = 'v-test', cache_dir = cache_dir)

    r1 <- backend('sys', 'user', '{}', packet_hash = 'hash-a')
    r2 <- backend('sys', 'user', '{}', packet_hash = 'hash-a')
    expect_equal(n_calls, 1)
    expect_equal(r1, r2)

    # a different packet hash is a different cache key -- still a live call
    backend('sys', 'user', '{}', packet_hash = 'hash-b')
    expect_equal(n_calls, 2)

    # force_refresh bypasses an existing hit
    backend_refresh <- cached_backend(counting_backend, provider = 'github', model = 'gpt-4o-mini',
                                       prompt_template_version = 'v-test', cache_dir = cache_dir, force_refresh = TRUE)
    backend_refresh('sys', 'user', '{}', packet_hash = 'hash-a')
    expect_equal(n_calls, 3)
})

test_that('synthesize_interpretation() with mock_backend() runs end-to-end over every module', {
    all_modules <- modules(ms_test)
    desc <- csf_dataset_description()
    interps <- lapply(all_modules, function(mod){
        packet <- run_module(ms_test, mod, csf_tool_config, input_hash = 'abc')
        synthesize_interpretation(packet, desc, backend = mock_backend(), schema_path = test_schema_path)
    })
    names(interps) <- all_modules
    expect_equal(length(interps), length(all_modules))
    for (mod in all_modules) {
        expect_true(validate_interpretation(interps[[mod]]))
        expect_equal(interps[[mod]]$module_id, mod)
    }
})
