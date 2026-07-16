# llegir — Overview

← [Project home](../README.md) · [Implementation guide](implementation_guide.md) · [Schemas](schemas.md) · [Milestone 1](milestone_1.md)

*Status: Concept / design, started 2026-07.*

---

## The problem

In transcriptomics analysis (e.g., scRNA-seq), we often leverage algorithms to identify concerted gene expression programs, for example gene co-expression modules derived from hdWGCNA. Interpreting a single gene module currently requires manually synthesizing many disjoint pieces of evidence. For instance, this may include the module's constituent genes, the module's highly connected hub genes, which cell cluster/state expresses the module, differential expression of the module across conditions and metadata, pathway/GO enrichment, overlap with external signatures, and further dataset-specific analyses. With dozens up to hundreds of modules per study, this is slow, inconsistent between analysts, and hard to reproduce or standardize for a manuscript.

## The solution

We propose **llegir** (Catalan: to read), an R package that takes as input a gene expression dataset and a set of gene modules, systematically gathers a standardized bundle of evidence for each module, and then leverages an LLM to produce a short, evidence-backed interpretation paragraph, with a human-in-the-loop review step and a full reproducibility log. For extensibility, **llegir** is completely technology agnostic and should work on any gene expression data type (e.g. bulk RNA-seq, single-cell, and spatial), and for any gene module identification method (e.g. WGCNA, non-negative matrix factorization, gene sets from the literature or from public databases like GO). **llegir**: **LL**M-**e**nabled **g**ene module **i**nterpretation in R.

We are first and foremost testing and developing this pipeline using a scRNA-seq dataset which has been analyzed using hdWGCNA to identify gene modules, and as we develop the pipeline we will move towards the interoperability goal.


Pipeline, at a glance:

```
[exp mat] + [modules] ──▶ [evidence tools] ──▶ evidence packet (per module)
                                              │
                                              ▼
                              [synthesis: structured slots] ──▶ interpretation object
                                              │
                                     confidence + flags
                                              │
                        ┌─────────────────────┴─────────────────────┐
                        ▼                                             ▼
              boilerplate paragraph                        human review queue
```

## Design principles

1. **Deterministic evidence core, bounded model layer.** All quantitative analysis is done by versioned R functions (reproducible, auditable). The model only *interprets* a fixed evidence packet and *drafts* prose — it does not free-write and run arbitrary analysis code in the production path. This reconciles "agentic" with "standardized + reproducible."
2. **Everything flows through two contracts.** A common *evidence fragment* shape (what every tool returns) and a structured *interpretation object* (the slots the model fills). These make tools pluggable and the model swappable. See [schemas](schemas.md).
3. **Toolbox, core + custom.** Dataset-agnostic core tools (hub genes, cluster DME, metadata associations, enrichment) plus **bespoke custom tools** registered per project.
4. **Structured slots → rendered paragraph.** The model emits typed fields; the boilerplate paragraph is rendered deterministically from them. No free-form paragraph generation.
5. **Every claim cites its evidence.** Each statement references the fragment(s) that support it — the anti-hallucination guarantee and the basis for automated faithfulness checks.
6. **Confidence-gated human review.** Modules are flagged for deeper review when confidence is low, when model confidence disagrees with deterministic evidence strength, when tools contradict, or when an artifact pattern (e.g. immediate-early / dissociation) is detected.
7. **Reproducibility anchored on evidence, not prose.** LLM text is not bit-reproducible across model versions; the *evidence packet* is. The provenance manifest logs the evidence hash, model + version, prompt, seeds, package versions, and the full code log.
8. **Model-agnostic and open-source.** A light R orchestrator (candidate: `ellmer`) so the user picks the model. Built for community extension via registered tools and data-source adapters.
9. **Generalizable by design.** hdWGCNA first, but the core tools talk to a thin `ModuleSet` adapter, so other module/factor sources (NMF/cNMF, Hotspot, metaprograms, DE gene lists) can be swapped in later without rewriting the tools.

---

*Last updated: 2026-07-16*
