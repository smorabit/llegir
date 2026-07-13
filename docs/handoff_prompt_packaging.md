# Claude Code handoff prompt — experimental package + pkgdown

← [Project home](../README.md) · [Packaging milestone](milestone_packaging.md)

Handoff for a fresh Claude Code instance: turn the working codebase into an installable, documented, experimental R package with pkgdown. Paste the block below from the repo root.

*Logged 2026-07-12.*

---

## Prompt

```
The Module Interpretation Engine is functionally complete and live-verified through
Milestone 2 (deterministic core + synthesis + guardrails + multi-provider backends,
tested offline via a mock backend). Your job is a STRUCTURAL packaging pass: make it
an installable, documented, EXPERIMENTAL R package with a pkgdown site. You are NOT
changing any behavior.

First, read: docs/milestone_packaging.md (this is the task, authoritative), CLAUDE.md,
docs/schemas.md, and STYLE.md.

Package name: use `<<I'll give you the name at kickoff>>` throughout.

Environment: activate the conda env `hdWGCNA`. This milestone needs `usethis`,
`devtools`, `roxygen2`, and `pkgdown` — if any are missing, STOP and tell me (do not
install). No API keys are needed for this milestone at all: the vignette and every
test use the MOCK backend, so the whole thing builds and checks offline.

Two hard constraints:
  - NO behavior change. Same inputs -> same evidence packets, interpretations, and
    paragraphs. If an existing test's expectation would change, something is wrong —
    stop and flag it.
  - Vignette + tests + examples must build/run OFFLINE (mock backend, no network, no
    key), because R CMD check builds vignettes and runs examples.

Tasks (full detail in docs/milestone_packaging.md):
  0. Scaffold: DESCRIPTION (Version 0.0.0.9000, Authors@R = Sam Morabito, License),
     roxygen NAMESPACE, LICENSE (MIT unless I say otherwise), README.Rmd, NEWS.md,
     .Rbuildignore (exclude docs/, output/, data/CSF*.rds, dev scripts).
  1. Namespace hygiene: remove all in-function library()/require()/setwd()/top-level
     side effects; move them to DESCRIPTION Imports + ::/@importFrom. Imports:
     hdWGCNA, Seurat, WGCNA, jsonlite, digest, dplyr, tidyr, GeneOverlap, fgsea,
     ellmer. Suggests: testthat, knitr, rmarkdown, pkgdown.
  2. Public API + roxygen: @export only the intended public surface (ModuleSet
     constructor, evidence_fragment/import_fragment, the tools + how they're
     run/registered, the orchestrators, synthesize_interpretation + the backends
     mock/gemini/github, interpretation constructor/validator, renderer); everything
     else stays internal. Add roxygen to exported functions — this is the ONE place
     STYLE.md's "no roxygen" flips, exported functions only. @examples run offline
     (mock) or \dontrun{} for live calls.
  3. Move schemas/*.json to inst/schemas/; read via system.file().
  4. Self-contained example fixture: expose the small synthetic ModuleSet already used
     in tests (helper and/or inst/extdata) for examples + the vignette. Do NOT ship
     data/CSF_Myeloid_hdWGCNA.rds.
  5. Vignette (pkgdown centerpiece): getting-started walkthrough on the synthetic
     fixture — ModuleSet -> tools -> packet -> synthesize_interpretation(backend =
     mock_backend()) -> interpretation + paragraph. Builds with no network/key.
     Mention the live GitHub-Models/Gemini path in prose only.
  6. pkgdown: _pkgdown.yml (reference grouped by concept; articles = the vignette +
     the design notes overview/implementation_guide/schemas); build the site.
  7. R CMD check to 0 errors / 0 warnings (notes OK). Add an experimental lifecycle
     badge + "API unstable" note to the README.
  8. Update CLAUDE.md's layout section to the package layout (now that it IS a
     package).

Non-negotiables: NO functional change (if you find a bug, flag it, don't silently
fix behavior here); package code has no library()/side effects; vignette + tests +
examples run fully offline via the mock backend; do NOT ship the big CSF .rds; mark
the package experimental / API-unstable; follow STYLE.md (roxygen on exported
functions is the only change).

Out of scope: custom-tool registry redesign, a second ModuleSet adapter, literature,
reconciliation, eval harness, CRAN submission — all later.

Start by restating your plan and confirming the package name + license with me. Then
check in once the package skeleton installs and `R CMD check` loads clean (before the
vignette + pkgdown polish).
```

---

## Notes

- Package name + license are the two decisions to confirm at kickoff (suggested: name from `modulet`/`moduleInterpreter`/`interpretr`/`mie`; license MIT).
- No API keys needed this milestone — everything builds/checks offline via the mock backend.
- Deliberate check-in: after the skeleton installs + clean `R CMD check` load, before vignette/pkgdown.
- After this: the path-to-stable-v1 work (custom-tool registry, second adapter), then M3 features (literature, reconciliation, eval).

---

*Last updated: 2026-07-12*
