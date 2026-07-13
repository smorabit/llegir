# Milestone (packaging) — experimental R package + pkgdown

← [Overview](overview.md) · [Implementation guide](implementation_guide.md) · [Project home](../README.md)

*Status: not started. The chosen path: package the working codebase as an installable, documented, **experimental** R package (v0.x, API marked unstable), with a pkgdown site.*

---

## Goal

Turn the current plain-sourced-functions codebase into an installable R package with roxygen docs, a pkgdown site, and an offline vignette — **without changing any behavior**. This is structural, not functional. Ship it as **experimental** (lifecycle: unstable API) so the custom-tool registry and `ModuleSet` adapter can still evolve toward a stable v1.

Two hard constraints shape everything:

- **No behavior change.** Same inputs → same evidence packets, interpretations, and paragraphs. If a test's expectation changes, something is wrong.
- **Vignette + tests build offline.** `R CMD check` and pkgdown build vignettes and run examples — they must not need the network or an API key. Use the **mock backend** everywhere the docs/tests touch synthesis; live providers (GitHub Models, Gemini) are described in prose only.

## Prerequisite decision — package name

Pick one before scaffolding (candidates: `modulet`, `moduleInterpreter`, `interpretr`, `mie`). Everything below uses `<PKG>` as a placeholder.

## Tasks

**0. Scaffold.** `usethis`-style: `DESCRIPTION` (name, title, `Version: 0.0.0.9000`, `Authors@R` = Sam, `License`, `Encoding: UTF-8`, `Roxygen`), roxygen-generated `NAMESPACE`, `LICENSE` (suggest MIT — permissive for OSS; GPL-3 if you prefer copyleft), `README.Rmd` (renders README.md + pkgdown home), `NEWS.md`, `.Rbuildignore` (exclude `docs/`, `output/`, `data/CSF*.rds`, dev scripts), `.gitignore` already present.

**1. Namespace hygiene (real work).** Package code must not `library()`/`require()`/`setwd()` or have top-level side effects. Replace in-function `library(...)` calls with `DESCRIPTION` `Imports:` + `::` / `@importFrom`. Split `Imports` (hdWGCNA, Seurat, WGCNA, jsonlite, digest, dplyr, tidyr, GeneOverlap, fgsea, ellmer) vs `Suggests` (testthat, knitr, rmarkdown, pkgdown; anything used only in vignettes/tests).

**2. Public API + roxygen.** Decide the export surface and `@export` only those; everything else stays internal (unexported). Likely public: the `hdWGCNA_ModuleSet` constructor, `evidence_fragment` / `import_fragment`, the tool functions + how they're registered/run, the orchestrators, `synthesize_interpretation` + the backends (`mock_backend`, `gemini_backend`, `github_backend`), the interpretation constructor/validator, the renderer. Add roxygen docs to exported functions — **this flips the "no roxygen" rule in STYLE.md, but only for exported functions**; internal helpers keep the lean style. `@examples` must run offline (mock backend) or be wrapped in `\dontrun{}` for live calls.

**3. Schemas → `inst/schemas/`.** Move `schemas/*.json` to `inst/schemas/`; read them via `system.file('schemas/...', package = '<PKG>')`.

**4. Example fixture (self-contained).** Do NOT ship `data/CSF_Myeloid_hdWGCNA.rds` (too big / gitignored). Expose the small **synthetic ModuleSet** already used in tests as the example object (helper function and/or `inst/extdata`) so examples and the vignette are self-contained and fast.

**5. Vignette (pkgdown centerpiece).** A "Getting started" article: build a `ModuleSet` from the synthetic fixture → run the evidence tools → assemble a packet → `synthesize_interpretation(..., backend = mock_backend())` → show the interpretation + rendered paragraph. **Must build with no network / no key** (mock backend). Describe the live GitHub-Models/Gemini path in prose, not executed.

**6. pkgdown.** `_pkgdown.yml` with a reference index grouped by concept (adapters · tools · contracts · synthesis/backends · rendering) and articles: the getting-started vignette plus the design notes (overview, implementation guide, schemas) surfaced as articles. Build the site locally.

**7. `R CMD check` + CI-ready.** Get to 0 errors / 0 warnings (notes acceptable for experimental). Because tests + vignette use the mock backend, the whole check runs offline. Add a lifecycle **experimental** badge to the README and a one-line "API is unstable" note.

**8. Update `CLAUDE.md`** once packaged: the "functionality first; no formal package" section flips to the package layout (`R/`, `man/`, `inst/schemas/`, `tests/testthat/`, `vignettes/`, `DESCRIPTION`/`NAMESPACE`).

## Acceptance criteria (done =)

- Installs (`devtools::install()` / `remotes::install_github(...)`) and `library(<PKG>)` loads clean.
- `R CMD check`: 0 errors, 0 warnings (notes OK); runs fully offline.
- Exported functions are documented; internals unexported; no `library()`/side-effects in package code.
- Vignette builds with the **mock backend** (no network/key); pkgdown site builds; reference + getting-started render.
- All existing tests pass under the package harness (offline).
- **Behavior is unchanged** — evidence packets / interpretations / paragraphs match pre-packaging output.
- README shows an experimental lifecycle badge + API-unstable note.

## Out of scope (path to a stable v1, later)

Custom-tool registry redesign, a second `ModuleSet` adapter, literature/PubMed, cross-module reconciliation, the fuller eval/calibration harness, and CRAN submission. All additive after this experimental release.

## Conventions

- [STYLE.md](../STYLE.md) still governs code style; the only change is roxygen on **exported** functions.
- No functional changes. If you find a bug while packaging, note it and flag it — don't silently fix behavior in this milestone.
- Needs `usethis`, `devtools`/`R CMD`, `roxygen2`, `pkgdown` in the `hdWGCNA` env — if any are missing, STOP and flag (do not install).

---

*Last updated: 2026-07-12*
