# Milestone 1.5 — Rigor & reproducibility hardening

← [Overview](overview.md) · [Implementation guide](implementation_guide.md) · [Milestone 1](milestone_1.md) · [Milestone 2](milestone_2.md) · [Project home](../README.md)

*Status: not started. A short pass between M1 (done) and M2 (synthesis).*

---

## Goal

Harden the deterministic core so the evidence it produces is **statistically honest and reproducible before any model interprets it**. No new user-facing capability — this is about trustworthiness. It matters because M2's synthesis model will confidently narrate whatever the evidence says: an inflated p-value or a flaky enrichment call becomes a fluent, wrong paragraph. Fix the inputs first.

Derived from Sam's post-M1 notes (`2026-07-10.md`).

## Tasks

**1. Fix pseudoreplication in `module_by_metadata` (highest priority).** Testing module eigengenes across a sample-level variable (e.g. `diagnosis`) at the **cell level** is pseudoreplication — cells within a sample are correlated, so a cell-level Kruskal/Wilcoxon inflates significance. Fix:
- For any variable that varies at the **sample** level, aggregate the ME to `Sample.ID` first (mean ME per sample), then test across the variable at the **sample** level (Kruskal / linear model on the per-sample means). Reuse SERPENTINE's pseudobulk machinery (`AggregatePseudobulk` → `SummarizedExperiment`) where it fits.
- `Sample.ID` itself is the aggregation unit, not a group test — for it, report between-sample variance / which samples express the module (descriptive), not an inflated association.
- Record in the fragment which level the test was run at (`cell` vs `sample`) in `provenance.params`.
- (Gene-level within-module pseudobulk DE — limma/DESeq2 on counts — is optional and future; the M1.5 fix is at the module-score level.)

**2. Local, offline gene-set enrichment via GeneOverlap (recycle SERPENTINE `run_geneoverlap.R`).** Replace the current `geneset_enrichment` internals with the SERPENTINE approach, which is **fully offline** — no Enrichr web API:
- Recycle `SERPENTINE/DEG_snakemake_v4/scripts/analysis/run_geneoverlap.R`: load gene-set libraries from **local `.gmt` files** with `fgsea::gmtPathways()` (GO/pathway libraries downloaded once from the EnrichR site and stored locally; paths in a config field like `enrichment$db_files`), then `GeneOverlap::newGOM(pathways, input_list, genome.size = <n genes in the ModuleSet>)` for a Fisher/hypergeometric overlap test.
- Input = the module's hub genes (top N by kME). Background / `genome.size` = number of genes in the `ModuleSet` expression matrix.
- Flatten the `GOM` object to the tidy table the script builds (`term, overlap, genes, pval, odds_ratio, jaccard, db, ngenes`), BH-adjust to `fdr`, drop `ngenes == 0`.
- Emit as the `geneset_enrichment` `evidence_fragment`: `top_findings` = top terms by fdr/odds ratio; `effect_strength` = top `-log10(p)` (or odds ratio); `significance` = fdr; `direction = "up"`.
- Ship/point to the local `.gmt` libraries via the repo config and document where to obtain them (static files). Because there is no runtime network, runs are deterministic and CI-clean **by construction** — no retry, no caching.
- (Optional, later) `simplifyEnrichment::simplifyGO()` to collapse redundant GO BP terms — nice for interpretation but an extra dependency; defer.

Recycled overlap loop from `run_geneoverlap.R`, adapted to a single module's hub genes (self-contained so the SERPENTINE repo isn't required). Local library for CSF: `data/GO_Biological_Process_2026.txt` (GMT-format despite the `.txt` extension).

```r
pathways <- fgsea::gmtPathways(gmt_file)          # e.g. data/GO_Biological_Process_2026.txt
input_list <- list(module = hub_genes)            # top-N hub genes for this module
gom <- GeneOverlap::newGOM(pathways, input_list, genome.size = n_genes_in_moduleset)

overlap_df <- data.frame()
for(i in seq_along(gom@go.nested.list)){          # outer = input_list (the module)
    for(j in seq_along(gom@go.nested.list[[i]])){ # inner = pathways
        cur <- gom@go.nested.list[[i]][[j]]
        overlap_df <- rbind(overlap_df, data.frame(
            term = names(pathways)[j],
            overlap = paste0(length(cur@intersection), '|', length(cur@listA)),
            genes = paste(cur@intersection, collapse = ','),
            pval = cur@pval,
            odds_ratio = cur@odds.ratio,
            jaccard = cur@Jaccard,
            ngenes = length(cur@intersection)
        ))
    }
}
overlap_df <- subset(overlap_df, ngenes > 0)
overlap_df$fdr <- p.adjust(overlap_df$pval, 'fdr')
```

**3. Import pre-existing evidence.** Let users inject already-computed results (DMEs, GO enrichment, etc.) instead of recomputing. Add an `import_fragment` path per evidence `type` that normalizes a user-supplied table into the `evidence_fragment` schema, and tag `provenance.source = "user_supplied"` (vs `"computed"`) so faithfulness and reproducibility can distinguish them. The synthesis layer treats imported and computed fragments identically.

**4. Persist all tabular outputs.** The orchestrator already holds each fragment's full `result` table — also write it to CSV/TSV under `output/tables/<module>/<tool>.tsv` alongside the JSON packets, so a human can audit every DME table, enrichment result, and overlap directly. Reinforces "reproducibility anchored on the evidence."

## Acceptance criteria (done =)

- `module_by_metadata` runs sample-level tests for sample-linked variables; a test confirms cell-level vs sample-level p-values differ as expected on the CSF data (sample-level is more conservative), and the fragment records the level used.
- `geneset_enrichment` uses local `.gmt` libraries via `GeneOverlap` (no network); results are deterministic across runs; the pDC positive-control module recovers interferon/DC-type terms and the random negative control does not.
- `import_fragment` ingests a user table for at least one evidence type and produces a valid fragment tagged `user_supplied`; it flows through the orchestrator unchanged.
- Every fragment's table is written to `output/tables/...`; all 14 CSF modules re-run clean.
- Existing M1 tests still pass; new tests cover the pseudobulk path, the enrichment cache, and `import_fragment`.
- Follows [STYLE.md](../STYLE.md).

## Out of scope (later)

- Module preservation (NetRep) as evidence — optional tool, needs a declared comparison group; watch the cross-technology confound.
- Additional `ModuleSet` adapters (SCE / Seurat / `.mtx`; user gene lists scored via UCell/decoupleR).
- Dataset-description config → handled in [Milestone 2](milestone_2.md) (feeds the synthesis prompt).
- pkgdown / formal packaging.

## Conventions

- R style: [STYLE.md](../STYLE.md); still **no formal R package**.
- Keep the core fully offline: gene-set libraries are local `.gmt` files (no runtime network). Everything deterministic and local.

---

*Last updated: 2026-07-10*
