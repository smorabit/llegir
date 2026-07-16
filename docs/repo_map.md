# Repository Map

Generated via `tree -I 'node_modules|build|output|data|.git' -a --dirsfirst`. Excludes `node_modules`, `build`, `output`, `data`, and `.git`.

```
.
|-- .claude
|-- .obsidian
|   |-- app.json
|   |-- appearance.json
|   |-- core-plugins.json
|   `-- workspace.json
|-- R
|   |-- confidence.R
|   |-- dataset_description.R
|   |-- example_moduleset.R
|   |-- faithfulness.R
|   |-- fragment.R
|   |-- import_fragment.R
|   |-- interpretation.R
|   |-- llegir-package.R
|   |-- moduleset.R
|   |-- moduleset_components.R
|   |-- moduleset_gene_list.R
|   |-- moduleset_hdwgcna.R
|   |-- orchestrator.R
|   |-- prompt.R
|   |-- registry.R
|   |-- render.R
|   |-- stats_utils.R
|   |-- synthesis.R
|   |-- tool_cluster_dme.R
|   |-- tool_geneset_enrichment.R
|   |-- tool_hub_genes.R
|   |-- tool_module_by_metadata.R
|   |-- tool_signature_correlation.R
|   `-- utils.R
|-- docs
|   |-- milestones
|   |   |-- milestone2_verification.md
|   |   |-- milestone_1.md
|   |   |-- milestone_1_5.md
|   |   |-- milestone_2.md
|   |   |-- milestone_extensibility.md
|   |   `-- milestone_packaging.md
|   |-- prompts
|   |   |-- handoff_prompt.md
|   |   |-- handoff_prompt_dev_economy.md
|   |   |-- handoff_prompt_extensibility_1.md
|   |   |-- handoff_prompt_extensibility_2.md
|   |   |-- handoff_prompt_hdwgcna_equivalence.md
|   |   |-- handoff_prompt_m1_5.md
|   |   |-- handoff_prompt_m2.md
|   |   |-- handoff_prompt_m2_run.md
|   |   `-- handoff_prompt_packaging.md
|   |-- 2026-07-10.md
|   |-- 2026-07-13.md
|   |-- custom_tools.md
|   |-- dev_economy.md
|   |-- implementation_guide.md
|   |-- overview.md
|   |-- repo_map.md
|   `-- schemas.md
|-- inst
|   `-- schemas
|       |-- evidence_fragment.schema.json
|       `-- interpretation.schema.json
|-- man
|   |-- PROMPT_TEMPLATE_VERSION.Rd
|   |-- RENDER_TEMPLATE_VERSION.Rd
|   |-- aggregate_by_sample.Rd
|   |-- assert_faithfulness.Rd
|   |-- build_evidence_packet.Rd
|   |-- build_review_queue.Rd
|   |-- build_synthesis_manifest.Rd
|   |-- build_system_prompt.Rd
|   |-- build_user_prompt.Rd
|   |-- cached_backend.Rd
|   |-- capabilities.Rd
|   |-- categorical_group_test.Rd
|   |-- check_faithfulness.Rd
|   |-- cluster_dme_tool.Rd
|   |-- components_ModuleSet.Rd
|   |-- compute_evidence_signals.Rd
|   |-- continuous_correlation_test.Rd
|   |-- dataset_description.Rd
|   |-- describe_flags.Rd
|   |-- ellmer_backend.Rd
|   |-- enforce_faithfulness.Rd
|   |-- evidence_fragment.Rd
|   |-- expression.Rd
|   |-- fragment_from_json.Rd
|   |-- fragment_to_json.Rd
|   |-- fuse_confidence.Rd
|   |-- gene_list_ModuleSet.Rd
|   |-- gene_membership.Rd
|   |-- geneset_enrichment_tool.Rd
|   |-- get_tool.Rd
|   |-- has_capability.Rd
|   |-- hdWGCNA_ModuleSet.Rd
|   |-- hub_genes_tool.Rd
|   |-- import_fragment.Rd
|   |-- import_fragment_tool.Rd
|   |-- interpretation.Rd
|   |-- interpretation_from_json.Rd
|   |-- interpretation_hash.Rd
|   |-- interpretation_to_json.Rd
|   |-- is_faithful.Rd
|   |-- is_sample_constant.Rd
|   |-- list_tools.Rd
|   |-- llegir-package.Rd
|   |-- llegir_example_moduleset.Rd
|   |-- make_interpretation_provenance.Rd
|   |-- make_provenance.Rd
|   |-- metadata.Rd
|   |-- mock_backend.Rd
|   |-- model_output_schema_json.Rd
|   |-- module_by_metadata_tool.Rd
|   |-- module_scores.Rd
|   |-- modules.Rd
|   |-- needs_review.Rd
|   |-- packet_to_json.Rd
|   |-- pkg_versions.Rd
|   |-- read_evidence_packet.Rd
|   |-- read_interpretation.Rd
|   |-- register_tool.Rd
|   |-- render_dataset_description.Rd
|   |-- render_packet_compact.Rd
|   |-- render_paragraph.Rd
|   |-- resolve_backend.Rd
|   |-- run_module.Rd
|   |-- run_orchestrator.Rd
|   |-- run_synthesis_orchestrator.Rd
|   |-- signature_correlation_tool.Rd
|   |-- synthesize_interpretation.Rd
|   |-- synthesize_module.Rd
|   |-- synthetic_ModuleSet.Rd
|   |-- validate_dataset_description.Rd
|   |-- validate_evidence_fragment.Rd
|   |-- validate_interpretation.Rd
|   |-- write_evidence_packet.Rd
|   |-- write_fragment_tables.Rd
|   |-- write_interpretation.Rd
|   |-- write_review_queue.Rd
|   `-- write_synthesis_manifest.Rd
|-- pkgdown_site
|   |-- articles
|   |   |-- getting-started.html
|   |   `-- index.html
|   |-- deps
|   |   |-- bootstrap-5.3.8
|   |   |   |-- bootstrap.bundle.min.js
|   |   |   |-- bootstrap.bundle.min.js.map
|   |   |   `-- bootstrap.min.css
|   |   |-- bootstrap-toc-1.0.1
|   |   |   `-- bootstrap-toc.min.js
|   |   |-- clipboard.js-2.0.11
|   |   |   `-- clipboard.min.js
|   |   |-- font-awesome-6.5.2
|   |   |   |-- css
|   |   |   |   |-- all.css
|   |   |   |   |-- all.min.css
|   |   |   |   |-- v4-shims.css
|   |   |   |   `-- v4-shims.min.css
|   |   |   `-- webfonts
|   |   |       |-- fa-brands-400.ttf
|   |   |       |-- fa-brands-400.woff2
|   |   |       |-- fa-regular-400.ttf
|   |   |       |-- fa-regular-400.woff2
|   |   |       |-- fa-solid-900.ttf
|   |   |       |-- fa-solid-900.woff2
|   |   |       |-- fa-v4compatibility.ttf
|   |   |       `-- fa-v4compatibility.woff2
|   |   |-- headroom-0.11.0
|   |   |   |-- headroom.min.js
|   |   |   `-- jQuery.headroom.min.js
|   |   |-- jquery-3.6.0
|   |   |   |-- jquery-3.6.0.js
|   |   |   |-- jquery-3.6.0.min.js
|   |   |   `-- jquery-3.6.0.min.map
|   |   |-- search-1.0.0
|   |   |   |-- autocomplete.jquery.min.js
|   |   |   |-- fuse.min.js
|   |   |   `-- mark.min.js
|   |   `-- data-deps.txt
|   |-- news
|   |   `-- index.html
|   |-- reference
|   |   |-- PROMPT_TEMPLATE_VERSION.html
|   |   |-- RENDER_TEMPLATE_VERSION.html
|   |   |-- aggregate_by_sample.html
|   |   |-- assert_faithfulness.html
|   |   |-- build_evidence_packet.html
|   |   |-- build_review_queue.html
|   |   |-- build_synthesis_manifest.html
|   |   |-- build_system_prompt.html
|   |   |-- build_user_prompt.html
|   |   |-- cached_backend.html
|   |   |-- categorical_group_test.html
|   |   |-- check_faithfulness.html
|   |   |-- cluster_dme_tool.html
|   |   |-- compute_evidence_signals.html
|   |   |-- continuous_correlation_test.html
|   |   |-- dataset_description.html
|   |   |-- describe_flags.html
|   |   |-- ellmer_backend.html
|   |   |-- enforce_faithfulness.html
|   |   |-- evidence_fragment.html
|   |   |-- expression.hdWGCNA_ModuleSet.html
|   |   |-- expression.html
|   |   |-- expression.synthetic_ModuleSet.html
|   |   |-- fragment_from_json.html
|   |   |-- fragment_to_json.html
|   |   |-- fuse_confidence.html
|   |   |-- gene_membership.hdWGCNA_ModuleSet.html
|   |   |-- gene_membership.html
|   |   |-- gene_membership.synthetic_ModuleSet.html
|   |   |-- geneset_enrichment_tool.html
|   |   |-- hdWGCNA_ModuleSet.html
|   |   |-- hub_genes_tool.html
|   |   |-- import_fragment.html
|   |   |-- import_fragment_tool.html
|   |   |-- index.html
|   |   |-- interpretation.html
|   |   |-- interpretation_from_json.html
|   |   |-- interpretation_hash.html
|   |   |-- interpretation_to_json.html
|   |   |-- is_faithful.html
|   |   |-- is_sample_constant.html
|   |   |-- make_interpretation_provenance.html
|   |   |-- make_provenance.html
|   |   |-- metadata.hdWGCNA_ModuleSet.html
|   |   |-- metadata.html
|   |   |-- metadata.synthetic_ModuleSet.html
|   |   |-- mock_backend.html
|   |   |-- model_output_schema_json.html
|   |   |-- module_by_metadata_tool.html
|   |   |-- module_scores.hdWGCNA_ModuleSet.html
|   |   |-- module_scores.html
|   |   |-- module_scores.synthetic_ModuleSet.html
|   |   |-- modules.hdWGCNA_ModuleSet.html
|   |   |-- modules.html
|   |   |-- modules.synthetic_ModuleSet.html
|   |   |-- needs_review.html
|   |   |-- packet_to_json.html
|   |   |-- pkg_versions.hdWGCNA_ModuleSet.html
|   |   |-- pkg_versions.html
|   |   |-- pkg_versions.synthetic_ModuleSet.html
|   |   |-- read_evidence_packet.html
|   |   |-- read_interpretation.html
|   |   |-- render_dataset_description.html
|   |   |-- render_packet_compact.html
|   |   |-- render_paragraph.html
|   |   |-- resolve_backend.html
|   |   |-- run_module.html
|   |   |-- run_orchestrator.html
|   |   |-- run_synthesis_orchestrator.html
|   |   |-- sentit-package.html
|   |   |-- sentit.html
|   |   |-- sentit_example_moduleset.html
|   |   |-- synthesize_interpretation.html
|   |   |-- synthesize_module.html
|   |   |-- synthetic_ModuleSet.html
|   |   |-- validate_dataset_description.html
|   |   |-- validate_evidence_fragment.html
|   |   |-- validate_interpretation.html
|   |   |-- write_evidence_packet.html
|   |   |-- write_fragment_tables.html
|   |   |-- write_interpretation.html
|   |   |-- write_review_queue.html
|   |   `-- write_synthesis_manifest.html
|   |-- tutorials
|   |-- .DS_Store
|   |-- 2026-07-10.html
|   |-- 2026-07-13.html
|   |-- 404.html
|   |-- CLAUDE.html
|   |-- LICENSE-text.html
|   |-- LICENSE.html
|   |-- STYLE.html
|   |-- authors.html
|   |-- index.html
|   |-- katex-auto.js
|   |-- lightswitch.js
|   |-- link.svg
|   |-- pkgdown.js
|   |-- pkgdown.yml
|   |-- search.json
|   `-- sitemap.xml
|-- scripts
|   |-- run_csf.R
|   `-- run_synthesis_csf.R
|-- tests
|   `-- testthat
|       |-- setup.R
|       |-- synthetic_extensibility.R
|       |-- synthetic_moduleset.R
|       |-- test-confidence.R
|       |-- test-faithfulness.R
|       |-- test-fragment.R
|       |-- test-import_fragment.R
|       |-- test-interpretation.R
|       |-- test-moduleset_adapter.R
|       |-- test-moduleset_components.R
|       |-- test-moduleset_gene_list.R
|       |-- test-prompt.R
|       |-- test-registry.R
|       |-- test-render.R
|       |-- test-spike_in.R
|       |-- test-synthesis.R
|       |-- test-tool_signature_correlation.R
|       `-- test-tools.R
|-- vignettes
|   `-- getting-started.Rmd
|-- .DS_Store
|-- .Rbuildignore
|-- .gitignore
|-- CLAUDE.md
|-- CLAUDE_old.md
|-- DESCRIPTION
|-- LICENSE
|-- LICENSE.md
|-- NAMESPACE
|-- NEWS.md
|-- README.Rmd
|-- README.md
|-- STYLE.md
`-- _pkgdown.yml

29 directories, 294 files
```

Note: `pkgdown_site` has since been rebuilt on `llegir` naming. `R/`, `man/`, and the pkgdown site are all consistent.

---

*Last updated: 2026-07-16*
