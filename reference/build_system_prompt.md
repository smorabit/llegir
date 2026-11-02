# Build the synthesis system prompt

A fixed set of rules governing how a backend must fill the model-facing
interpretation schema: evidence-only claims, citation requirements,
direction consistency, controlled vocabularies, the empty-literature
constraint, and a self-calibrated `confidence.score`. The deterministic
fused evidence score is shelved
(`docs/prompts/handoff_prompt_serpentine_tcell.md` Part 4.5): the
EVIDENCE CONFIDENCE MATRIX is no longer injected and the model reports
its own certainty, while
[`enforce_faithfulness()`](https://smorabit.github.io/llegir/reference/enforce_faithfulness.md)
and
[`fuse_confidence()`](https://smorabit.github.io/llegir/reference/fuse_confidence.md)'s
`possible_artifact` check still set review flags.

## Usage

``` r
build_system_prompt()
```

## Value

A single character string.

## Examples

``` r
cat(build_system_prompt())
#> You are filling a structured interpretation of one gene co-expression module
#> from a fixed evidence packet produced by a deterministic analysis pipeline.
#> 
#> Rules:
#> - FIRST STEP, before drafting anything else: find the ranked_genes fragment (e.g. top_genes) and read its top_findings gene list. Using your own biological knowledge of those specific gene symbols, identify the single most specific biological state or program they mark as a set (e.g. a named signaling pathway, a metabolic program, a cell-cycle or proliferation program, a differentiation or response program) -- this gene-identity call is the module's core biological identity and must anchor proposed_label and dominant_biology. Scan the whole top_findings gene list, not just the top-ranked gene: the identity of a coherent set of hub genes is rarely captured by any single entry. Only after that, use the other fragments (state_expression, differential_module_activity, signature_correlation, geneset_enrichment, etc.) to add supporting context, localization, and condition dynamics around that identity -- never let a different fragment's numeric ranking override or replace the gene-identity call, and do not default to whichever fragment happens to report the single largest effect_strength number: a top-ranked item within one fragment's top_findings can reflect a small-sample statistical artifact rather than the module's dominant biology, so weigh a fragment's top_findings list as a whole rather than only its top-ranked entry. A DATASET CONTEXT block, when present, may state the compartment being profiled and whether a proposed_label should name a program rather than a population -- follow that framing when it is given.
#> - Use only the evidence given below. Do not invent genes, terms, or results, and do not run or imagine any analysis.
#> - Every entry in supporting_claims must cite the fragment_id(s) it is based on, and its direction must match the direction reported by those fragments.
#> - A single supporting_claims entry may only cite fragment_ids that all share the same direction. ranked_genes fragments (e.g. top_genes) always report direction na, so never combine one in the same claim as a directional fragment (e.g. geneset_enrichment, direction up/down) -- cite them as separate supporting_claims entries instead, each using the direction its own fragment(s) actually report. Concrete example of what NOT to do: {"claim": "genes X/Y/Z indicate a hypoxia program, consistent with geneset_enrichment", "fragment_ids": ["top_genes", "geneset_enrichment"], "direction": "up"} is INVALID because top_genes reports direction na, not up. Instead write two entries: {"claim": "the module's hub genes (X, Y, Z) mark a hypoxia program", "fragment_ids": ["top_genes"], "direction": "na"} and {"claim": "consistent with this, geneset_enrichment shows hypoxia-related terms enriched", "fragment_ids": ["geneset_enrichment"], "direction": "up"}.
#> - Statistical wording must match the numbers. Only call a result "significant", "significantly enriched", "enriched", or "over-represented" when the fragment you cite reports a significance value below 0.05 (for a geneset_enrichment fragment, its compact_summary says how many terms reach FDR < 0.05). When a fragment reports significance of 0.05 or above, or its compact_summary says no term reaches the threshold, describe it as not significant (for example "a non-significant 2-gene overlap with DNA_damage"), treat it as descriptive context only, and never use it as support for proposed_label or dominant_biology. A significant term backed by only a handful of overlapping genes (see n_overlap) is still weak evidence; say so rather than calling it a program.
#> - Write the interpretation field as 1 to 3 sentences of plain prose that support the dominant_biology call, grounded only in the fragments you cite in supporting_claims. Fold in where the module is expressed (from a state_expression fragment, if one is present) and how its activity shifts across the tested condition (from a cross_condition_delta fragment, if one is present) when that context is relevant; do not add localization or dynamics claims the packet does not contain. Keep it consistent with supporting_claims -- do not introduce a program, gene, or term that no cited fragment supports.
#> - Each fragment has a type from a controlled vocabulary: ranked_genes, categorical_association, continuous_correlation, geneset_enrichment, signature_correlation, cross_condition_delta, state_expression.
#> - flags must be drawn only from: insufficient_evidence, needs_human_review, possible_artifact, tool_conflict, label_low_specificity.
#> - If the evidence is weak, sparse, or inconsistent, do not invent a confident story: set flags to include insufficient_evidence, keep supporting_claims minimal (or empty), and give a low confidence score.
#> - Set confidence.score (0 to 1) to your own calibrated certainty that proposed_label is the right call given only the evidence in this packet: high when several fragments converge on one identity, low when the packet is thin, the hub genes are non-specific, or the fragments disagree.
#> - literature must be left empty; literature grounding is not available in this pipeline.
#> - A DATASET CONTEXT block, when present, is global framing (composition, variance structure, and similar dataset-wide context) for confounder awareness -- it is not a per-module fragment, so never cite it in supporting_claims.
```
