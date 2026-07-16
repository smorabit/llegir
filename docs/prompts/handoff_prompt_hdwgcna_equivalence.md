# Claude Code handoff prompt — hdWGCNA ↔ components equivalence test

← [Project home](../README.md) · [Extensibility milestone](milestone_extensibility.md)

A quick, standalone task: add a regression test proving the hdWGCNA adapter and a generic components adapter produce identical evidence. Paste the block below from the repo root.

*Logged 2026-07-14.*

---

## Prompt

```
Quick standalone task for `llegir` (installed experimental R package). After the
Part 1 extensibility refactor, hdWGCNA_ModuleSet delegates to a components_ModuleSet
internally, and we assert "no behavior change for hdWGCNA" only manually. Add a
testthat regression test that PROVES it.

First read: R/moduleset_hdwgcna.R (esp. .hdwgcna_components), R/moduleset_components.R,
tests/testthat/setup.R (the csf_data_available guard + so_test/ms_test), and
tests/testthat/test-moduleset_components.R (test conventions). Follow STYLE.md.

Environment: conda env `hdWGCNA`. This test uses the real CSF object at
data/CSF_Myeloid_hdWGCNA.rds (present locally). Guard the whole test with
skip_if_not(csf_data_available) exactly like setup.R already does — reuse so_test /
ms_test where useful.

The test:
  1. Build a components_ModuleSet from tables extracted from the hdWGCNA Seurat object
     using the public hdWGCNA/Seurat accessors (GetHubGenes/kME, GetMEs, expression,
     meta.data) — i.e. reconstruct what a USER would hand to components_ModuleSet.
     Do NOT just call the internal .hdwgcna_components() and compare it to itself
     (that's tautological); the point is that the generic path from independently
     extracted tables matches the hdWGCNA convenience adapter.
  2. Assert gene_membership() and module_scores() are identical between the hdWGCNA
     adapter (ms_test) and this components adapter (expect_equal / expect_identical),
     for a representative module (mod_test) and overall.
  3. Build an evidence packet from EACH adapter with the same tool_config (run_module)
     and assert the evidence is identical per fragment: result tables + top_findings +
     effect_strength + significance + direction. IGNORE provenance fields that
     legitimately differ (timestamp, pkg_versions, and any source/adapter identity).
     If packet_hash is content-only (there is already a test that packets hash
     identically regardless of timestamp), assert packet_hash equality too — that's
     the cleanest single check.

Non-negotiables: this is TEST-ONLY. Do not change package behavior. If the equivalence
does NOT hold, STOP and tell me exactly where they diverge — do not "fix" it silently;
a real divergence means the Part 1 refactor changed hdWGCNA output and I need to know.
Keep R CMD check clean (a guarded/skipped test is fine in CI).

Optional, only if quick: also saveRDS a reference hdWGCNA packet as a small stored
fixture and add an offline regression test against it. Primary deliverable is the
equivalence test above.

Run the test and report whether the equivalence holds.
```

---

## Notes

- Guarded by `csf_data_available` (uses the local CSF `.rds`); it's a dev/local regression check, skipped in CI.
- Build the components adapter from *independently extracted* tables, not the internal `.hdwgcna_components()`, so the test isn't tautological.
- Compare evidence content, not provenance (timestamps / pkg_versions / adapter identity legitimately differ); `packet_hash` equality is the clean check if the hash is content-only.
- Test-only change; a real divergence must be reported, not silently fixed.

---

*Last updated: 2026-07-14*
