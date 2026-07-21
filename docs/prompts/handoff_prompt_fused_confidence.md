# Claude Code handoff prompt — deterministic fused evidence confidence score

← [Project home](../../README.md) · [Fused confidence milestone](../milestones/milestone_fused_confidence.md)

Handoff for a fresh Claude Code instance (Sonnet). Paste the block below from the repo root.

*Logged 2026-07-21.*

---

## Prompt

```
You're implementing the deterministic Fused Evidence Confidence Score for `llegir`
(installed experimental R package). Today the fusion string is driven by the LLM's
heuristic via `.evidence_score()` and a flat `0.5*model + 0.5*evidence` blend in
`fuse_confidence()`. We are replacing that with a reproducible formula computed from the
raw evidence packet BEFORE synthesis, whose matrix is injected into the prompt to ground
the model. The math is fully specified — do not redesign it.

First read (authoritative): docs/milestones/milestone_fused_confidence.md — it has the
exact equations, defaults, pseudo-code, and acceptance criteria. Then read CLAUDE.md,
STYLE.md, R/confidence.R (what you're refactoring), R/fragment.R (the evidence_fragment
contract + .bounded_effect_types), R/registry.R (register_tool/tool_spec + .onLoad core
registration), R/prompt.R (build_user_prompt/build_system_prompt/render_packet_compact),
and R/synthesis.R (where fuse_confidence is called in the pipeline). Note `%||%` is
already used in confidence.R.

Environment: conda env `hdWGCNA`. Do NOT install packages — the formula is base R only.
If something's missing, STOP and tell me. Everything runs OFFLINE on the mock backend;
do not make live API calls (API budget — if you must sanity-check live, ONE module only).

SCOPE — four threads, all in R/:

THREAD A — normalization + fusion core (R/confidence.R):
  - Add the internal helpers exactly as specified in milestone §5: .scale_family and
    .tier_weights constants, .hill(), .magnitude_score(), .reliability_score(),
    .fragment_score(), .tool_weight(), .pool_evidence(), .directional_coherence().
  - Add the EXPORTED calculate_fusion_score(fragments, user_weights = list(),
    beta = 0.5, lambda = 0.35, kappa = 0.5) returning the list contract in §5 (e_evidence,
    e_pool, p_agree, c_dir, lambda, params, matrix). Full roxygen (matches confidence.R).
  - Refactor fuse_confidence() to consume calculate_fusion_score() instead of
    .evidence_score(): fused_score <- model_score^lambda * e_evidence^(1 - lambda).
    PRESERVE model_score for audit, PRESERVE all four flags (insufficient_evidence +
    cap at theta_low, needs_human_review on |model - e_evidence| gap, tool_conflict,
    possible_artifact via unchanged .artifact_flagged()). Thread a user_weights argument
    through fuse_confidence() (default list()).
  - Update the fusion-string rationale to the new deterministic terms (milestone §6):
    [fusion: model=.., evidence=.. (E_pool=.., P_agree=.., C_dir=..), lambda=.., fused=..].
  - You may keep compute_evidence_signals() for the categorical convergent/conflicting
    label (still used for the tool_conflict flag + display), but the SCORE path must go
    through calculate_fusion_score(). Do not leave .evidence_score() wired into the score.

THREAD B — tool importance tiers (R/registry.R):
  - Add a `tier` field to register_tool() (arg `tier = 'medium'`) and the tool_spec; a
    tool with no tier resolves to 'medium'. Validate tier in c('high','medium','low').
  - Set tiers on the six core tools in .onLoad() per milestone §4: high = cluster_dme,
    differential_module_activity, pseudobulk_de_limma; medium = top_genes,
    signature_correlation; low = geneset_enrichment.

THREAD C — prompt grounding (R/prompt.R):
  - Add a renderer for the EVIDENCE CONFIDENCE MATRIX block (compact fixed-width table +
    E_pool/C_dir/P_agree/E_evidence/lambda scalars + the CONSTRAINTS lines) from a
    calculate_fusion_score() result, per milestone §6.
  - Inject it into build_user_prompt() (append after the compact packet). Add the matching
    rules to build_system_prompt(): confidence.score bounded by the computed band, cite
    E_evidence, never assert a direction contradicting the coherence sign. Bump
    PROMPT_TEMPLATE_VERSION.

THREAD D — tests (tests/testthat, offline, mock backend):
  Cover, per milestone acceptance criteria: normalization bounds + monotonicity per
  family; enrichment saturation (FDR=0.05 -> ~0.5, cannot dominate an equal-weight bounded
  corr); the geometric veto (E_evidence~0 -> fused~0 at model=1); directional penalty with
  a STRONG opposed pair (C_dir collapses) vs a WEAK dissenter (C_dir stays ~1); tier +
  user_weights application incl. u=0 muting a tool and unknown-tool -> medium; all four
  flags still fire on their conditions; fusion-string shape preserved. Build fragments
  with evidence_fragment() directly — no network. Confirm all existing M1/M1.5/M2 tests
  still pass.

Non-negotiables: base R only (no new deps); core logic depends only on the
evidence_fragment + ModuleSet contracts; everything offline; roxygen + devtools::document()
for the new export; R CMD check clean; STYLE.md exactly (snake_case, single quotes,
4-space indent, `<-`, magrittr `%>%`, intent-based comments, no aligned assignments, no
over-defensive stopifnot walls). Commit per CLAUDE.md git rules (Conventional Commits,
NO self-attribution, body lists new functions / changed contracts / test files).

Start by restating your implementation plan AND the exact signatures of the new helpers +
the calculate_fusion_score() return contract, and confirm with me before writing. Then
check in (a) once Thread A passes its unit tests on hand-built fragments, and (b) once the
prompt block + tiers are wired and the full suite is green, before finalizing.
```

---

## Notes

- The math is frozen in `docs/milestones/milestone_fused_confidence.md` — the Claude Code instance implements, it does not redesign. Point it there first.
- Key behavioral shift vs. current code: the score path moves from arithmetic-mean `.evidence_score()` + linear blend to `calculate_fusion_score()` (power-mean pool + mass-weighted directional penalty) + geometric model blend. `compute_evidence_signals()` survives only for the categorical agreement label / `tool_conflict` flag.
- `geneset_enrichment` is no longer special-cased out of the pool — the Hill link on its `-log10(FDR)` puts it on a comparable scale, so it re-enters as a normal (low-tier) fragment.
- Flags and the fusion-string contract are preserved on purpose so downstream review-queue code and `milestone2_verification.md` expectations don't break.
- Check-ins: after Thread A unit tests pass, and after the prompt block + tiers land with a green suite.
- Next (not this handoff): calibrate $\beta$, $\lambda$, $\kappa$ against the pDC positive / random negative spike-in controls; expose them in the run config.

---

*Last updated: 2026-07-21*
