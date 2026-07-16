# Module Interpretation Engine — Implementation Guide

← [Overview](overview.md) · [Schemas](schemas.md) · [Milestone 1](milestone_1.md) · [Project home](../README.md)

*Status: Design, 2026-07.*

---

This guide details the architecture, the tool system, confidence/review routing, evaluation, and the phased roadmap. The two data contracts have their own note: [schemas](schemas.md). This is a living design doc.

---

## 1. The two data contracts

Defined concretely in [schemas.md](schemas.md). In brief:

- **Evidence fragment** — the standard object *every* tool returns (core or custom). The synthesis layer only ever sees a list of fragments; it does not know which tool produced them.
- **Interpretation object** — the structured slots the model fills. The boilerplate paragraph is rendered deterministically from it. Every claim must cite the `fragment_ids` that support it.

---

## 2. Tool system

A **tool** is `function(ctx) -> evidence_fragment`. `ctx` carries: the `ModuleSet` (§5), the current `module_id`, expression matrix, metadata, a shared cache, and project config.

### Core tools (dataset-agnostic; port from the SERPENTINE dossier)

| Tool | Returns |
|---|---|
| `hub_genes` | ranked genes by kME |
| `module_by_metadata` | ME vs. a declared metadata column: categorical → group enrichment; continuous → correlation; paired → Δ |
| `cluster_dme` | `FindAllDMEs` across a grouping (which cell states express the module) |
| `geneset_enrichment` | GO / Enrichr / MSigDB over hub genes |
| `signature_overlap` | overlap of module genes with supplied reference signatures |

`module_by_metadata` is the generalizable engine: the user declares *which* metadata columns matter and their type, and it emits one fragment per column. This is how "flexible user-provided metadata" is handled — via config, not hard-coding. For the CSF dataset that means `diagnosis` (categorical), `Sample.ID` (categorical), and `lv2_annot` as the `cluster_dme` grouping.

### Custom tools (registered per project)

Anything returning the standard fragment. Registration is config-driven:

```r
register_tools(core_tools, my_custom_tool)
# project config lists which tools run for this dataset
```

Custom tools **must** emit provenance and pin the versions of any external inputs, or the tool silently loses reproducibility. (SERPENTINE's CancerSEA and cross-lineage T-cell tools are the motivating examples; not needed for CSF.)

---

## 3. Confidence → human-in-the-loop routing

Do not trust the model's self-reported confidence alone. **Fuse** it with deterministic signals from the fragments.

Route to human review when any of:

- confidence score is low;
- model confidence **disagrees** with evidence strength (fluent label over weak evidence);
- tools **contradict** each other;
- an **artifact** pattern fires (e.g. immediate-early / dissociation genes: FOS/JUN/EGR1/NR4A1).

Everything else gets a lighter review. The disagreement and conflict signals are where the real failures hide.

---

## 4. Evaluation

Most modules have no ground truth; anchor eval on cases that do, via **synthetic spike-ins**.

- **Positive controls.** Inject a known gene set as a fake module (e.g. `HALLMARK_E2F_TARGETS` → must be called proliferation/cell-cycle; a ribosome set; an ISG/IFN set) and check recovery with high confidence. Objective accuracy, no hand-labeling.
- **Negative control (equally important).** Feed a random gene set — the engine must return "insufficient evidence / low confidence," not a confident story. Catches the critical failure of confidently interpreting noise.
- **Faithfulness auto-check.** Because each claim cites `fragment_ids` + direction, programmatically verify the cited fragment exists and its effect direction matches the claim.
- **Calibration.** Does low confidence correlate with human disagreement on a blind sample?
- **Consistency.** Label stability across reruns.

Build the spike-in harness **early** — it is how confidence thresholds get tuned rather than guessed.

---

## 5. `ModuleSet` adapter (design now, generalize later)

The core tools talk to a thin adapter, not to hdWGCNA directly, so other module sources can be swapped in later.

```
ModuleSet interface:
  modules()                 # list of module ids
  gene_membership(module)   # genes + weights (e.g. kME)
  module_scores()           # per-cell / per-sample module scores (e.g. MEs)
  expression()              # underlying expression object
  metadata()                # cell / sample metadata
```

Implement `hdWGCNA_ModuleSet` now (backed by `GetModules`, `GetMEs`, `GetHubGenes`, `seurat@meta.data`). Later: cNMF/NMF factors, Hotspot, metaprograms, or plain DE gene lists implement the same interface and every tool just works. The discipline now is only that tools depend on the adapter, never on hdWGCNA directly.

---

## 6. Provenance & reproducibility

Reproducibility is anchored on the **evidence packet**, not the prose. The manifest records: evidence packet hash; model + version, prompt template + version, seeds, temperature; package + tool versions, external input hashes; and the full code log of every tool invocation with parameters.

Honest claim: *the evidence is fully reproducible; the paragraph is a versioned draft over it.*

---

## 7. Model-agnostic orchestration

- Light **R orchestrator**; candidate `ellmer` (Anthropic/OpenAI/Google/Ollama, structured output, tool calls) so the user picks the model.
- The deterministic core (tools → evidence packets) is useful **without any LLM** — good for adoption and a fallback.
- Claude Code remains the option for an exploratory, fully-autonomous variant; the production path stays bounded.

---

## 8. Roadmap

**Done:** contracts + `ModuleSet` ([schemas.md](schemas.md)); core tools on hdWGCNA → evidence packets ([milestone_1.md](milestone_1.md)); rigor/offline hardening ([milestone_1_5.md](milestone_1_5.md)); synthesis + confidence + faithfulness + review queue ([milestone_2.md](milestone_2.md)); dev-economy (multi-provider, subsetting, caching — [dev_economy.md](dev_economy.md)); experimental R package + pkgdown ([milestone_packaging.md](milestone_packaging.md)); extensibility Part 1 — general `ModuleSet` adapters + `capabilities()`.

**In progress:** extensibility Parts 2–3 — `signature_correlation` core tool + custom-tool registry, then evidence ingestion ([milestone_extensibility.md](milestone_extensibility.md)).

**Backlog & future** *(captured from dev notes 2026-07-13):*

- **Shared scoring wrapper.** UCell + decoupleR scoring should be **one reusable utility** used by both the gene-list adapter (scoring modules with no precomputed scores) and `signature_correlation` (cell-level signature scores) — not duplicated. Expose sensible defaults + a pass-through options arg.
- **HTML summary report.** A standard EDA + per-tool-plot report *summarizing across all modules* (e.g. module × cluster dot plot; DME volcano; overlap heatmap; hdWGCNA hub-gene networks), with customization (plot on/off, custom plots). Design tension: these are **cross-module** views, whereas the orchestrator runs per-module — so decide which summaries are computed dataset-wide vs. aggregated from per-module fragments.
- **Cross-dataset evidence reconciliation.** Run the pipeline on two datasets for the *same* programs (e.g. SERPENTINE single-cell + TCGA bulk), then interpret the combined packets together. Niche but high-value for the maintainer; generalization of global cross-module reconciliation.
- **Local-model backend** (`chat_ollama()`) once the maintainer has GPU access — the durable answer to the API-budget constraint.
- Literature grounding (PubMed, with guardrails); calibration/consistency eval harness; additional `ModuleSet` adapters (NMF/cNMF, spatial).

---

## 9. Design considerations & open decisions

- **Output-table hygiene:** tables live under `output/tables/<module>/<tool>.tsv`; include the module name in the filename (or otherwise) so tables are self-describing when browsed.
- **Pseudobulk approach:** for sample-level tests/aggregation, consider the SERPENTINE `SummarizedExperiment`/`MultiAssayExperiment` pattern. Caveat: **CSF is a poor pseudobulk test case** (low sample count, many conditions) — validate the approach on a better-powered dataset.
- **Bulk RNA-seq:** should work by config — a bulk dataset simply lacks the `clusters` capability, so cluster-level tools skip gracefully (the `capabilities()` system already handles this).
- **User-supplied inputs:** which inputs to *disallow*, and what format enforcement / compatibility-check helpers to provide (Part 3 — evidence ingestion).
- **Packaging:** experimental R package chosen (done).
- **Literature access:** bounded live PubMed call vs. pre-retrieved deterministic literature.
- **Name:** finalized as `llegir`. Package, `DESCRIPTION`, `NAMESPACE`, `man/`, docs, and the rebuilt pkgdown site are all on `llegir` naming; `prismatic`-family alternatives considered and dropped (`prism`/`prismatic` are taken).

---

*Last updated: 2026-07-16*
