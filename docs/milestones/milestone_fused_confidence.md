# Milestone — Deterministic Fused Evidence Confidence Score

← [Overview](../overview.md) · [Implementation guide](../implementation_guide.md) · [Schemas](../schemas.md) · [Milestone 2](milestone_2.md) · [Project home](../../README.md)

*Status: design. Replaces the LLM-heuristic evidence blend in `R/confidence.R` with a reproducible formula computed from the raw packet before synthesis, whose matrix is injected into the prompt to ground the model. Implementation handoff: [handoff_prompt_fused_confidence.md](../prompts/handoff_prompt_fused_confidence.md).*

---

## Goal

Today the fusion string

```
[fusion: model=0.70, evidence=0.96 (effect=0.87, enrichment=1.00, agreement=1.00/convergent_signal), fused=0.83]
```

is driven by `.evidence_score()` — a crude arithmetic mean of three signals — and a flat `0.5*model + 0.5*evidence` blend in `fuse_confidence()`. The weights are opaque and partly reflect the model's own heuristic. This milestone replaces that with a **formalized, deterministic calculation** run on the `evidence_fragment` packet *before* the LLM, so every certainty number is grounded in hard statistics and reproducible from the packet hash alone. The model receives the computed matrix as ground truth and *explains* the confidence rather than *inventing* it; `fuse_confidence()` then re-derives the final score deterministically so the printed string can never drift from the math.

This preserves every existing guardrail (`insufficient_evidence`, `needs_human_review`, `tool_conflict`, `possible_artifact`) and the fusion-string contract, changing only how the numbers are produced.

## Builds on

- The `evidence_fragment` contract (`R/fragment.R`): `effect_strength`, `significance`, `direction`, `tool_id`, `type`.
- The existing signals in `compute_evidence_signals()` / `.evidence_score()` / `fuse_confidence()` (`R/confidence.R`) — this milestone generalizes them, keeping the flag semantics.
- The tool registry (`R/registry.R`) — extended with importance tiers.
- Compact prompt rendering (`R/prompt.R`) — extended with the confidence matrix block.

---

## 0. Notation and the fragment set

For a module we have fragments $f_1, \dots, f_n$, each carrying contract fields:

- $s_i$ — `effect_strength`, a magnitude whose *scale depends on the fragment `type`* (a correlation, a $\log_2 FC$, or a $-\log_{10}\text{FDR}$).
- $p_i$ — `significance` (p / FDR), or `NA` for descriptive fragments.
- $d_i$ — `direction` $\in \{\texttt{up}, \texttt{down}, \texttt{mixed}, \texttt{na}\}$.
- $t_i$ — `tool_id`; $\tau(i)$ — the fragment `type`.

The pipeline produces per module: normalized per-fragment scores $e_i$, pooled empirical evidence $E_\text{evidence}$, the model's self-reported certainty $S_\text{model}$, and the final $Score_\text{fused}$.

---

## 1. Fragment score normalization → $e_i \in [0, 1]$

`effect_strength` lives on three incompatible scales. Map each to $[0,1]$ with a **type-aware magnitude link** $m_i$, then multiply by a **significance-reliability factor** $r_i$:

$$
e_i \;=\; m_i \cdot r_i, \qquad m_i, r_i \in [0,1].
$$

The multiplicative form encodes "strong evidence needs both a real effect *and* a real test." It reproduces the two guards in the current `compute_evidence_signals()` without hard thresholds: a large-$N$ test hitting $p \approx 0$ on a negligible effect gets a high $r_i$ but low $m_i$; a big effect that isn't significant gets a low $r_i$.

### 1a. Magnitude link $m_i$ by scale family

Fragments group into three scale families by `type`, extending the existing `.bounded_effect_types` constant:

| Family | Fragment types | `effect_strength` meaning |
|---|---|---|
| **Corr** (bounded) | `ranked_genes`, `state_expression`, `categorical_association`, `continuous_correlation`, `signature_correlation` | $\lvert\rho\rvert$ / rank-biserial, already $\in[0,1]$ |
| **Enrich** (log-p) | `geneset_enrichment` | top $-\log_{10}\text{FDR}$, unbounded $\ge 0$ |
| **FC** (log-ratio) | `cross_condition_delta` | top $\lvert\log_2 FC\rvert$, unbounded $\ge 0$ |

**Family Corr** — already bounded, clip (optional mild gamma to reward strong correlations):

$$
m_i = \min\!\big(\lvert s_i \rvert,\, 1\big)^{\gamma}, \qquad \gamma = 1 \text{ (default)}.
$$

**Family Enrich and Family FC** — saturating **Hill link**, monotone and bounded, with the half-saturation point $k$ placed at the biologically "meaningful" threshold and exponent $h$ setting steepness:

$$
m_i = \frac{s_i^{\,h}}{s_i^{\,h} + k_{\tau}^{\,h}}, \qquad h = 2 \text{ (default)}.
$$

- Enrich: $k_\text{enrich} = -\log_{10}(\alpha) = -\log_{10}(0.05) \approx 1.30$ → FDR at threshold maps to $m = 0.5$; FDR $= 10^{-4}$ maps to $m \approx 0.90$.
- FC: $k_\text{fc} = 1$ (a 2-fold change is the half-max) → $\lvert\log_2 FC\rvert = 2$ maps to $m = 0.80$.

This is what stops `geneset_enrichment`'s unbounded $-\log_{10}p$ from swamping the pool — the same failure the current code sidesteps by pulling enrichment into a separate `n_significant_terms` count. Here it stays a first-class fragment on a comparable scale.

### 1b. Significance-reliability factor $r_i$

Uniform link from the p-value, saturating at a "strong" reference $\alpha_\text{ref}$ (default $10^{-4}$) so merely clearing nominal significance gives partial — not full — reliability:

$$
r_i =
\begin{cases}
\operatorname{clip}\!\left(\dfrac{-\log_{10} p_i}{-\log_{10}\alpha_\text{ref}},\; 0,\; 1\right) & p_i \text{ available} \\[2ex]
r_\text{na} & p_i = \texttt{NA (descriptive fragment)}
\end{cases}
$$

Descriptive fragments with no inferential test (`ranked_genes` kME, `metadata::sample`) take $r_\text{na}$ — a parameter defaulting to $1$ (trust the structural magnitude), tunable down to discount untested signals.

---

## 2. The fusion formula

### 2a. Pooling → $E_\text{pool}$: weighted power mean

A **weighted power (generalized) mean** of the per-fragment scores with tool weights $w_i$ (§4):

$$
E_\text{pool} = \left( \frac{\sum_i w_i\, e_i^{\,\beta}}{\sum_i w_i} \right)^{1/\beta}.
$$

$\beta$ is a single **corroboration knob**: $\beta \to 1$ = arithmetic (compensatory, one strong tool offsets a weak one); $\beta \to 0$ = weighted geometric (conjunctive, confidence demands broad support); $\beta \to -\infty$ = minimum (any dissenting tool vetoes). Default $\beta = 0.5$ — leans conjunctive without letting a single inapplicable-but-run tool zero a real module. An $\epsilon = 10^{-3}$ floor on each $e_i$ keeps the geometric limit well-defined.

**Why not the alternatives.** A *bounded linear combination* is rejected as default because it is fully compensatory — a loud enrichment term papers over a total absence of DE support, the "fluent story over a random gene set" failure mode. An *optimization function* is rejected as opaque and non-reproducible, defeating the point of moving the calculation out of the LLM. The power mean gives the geometric mean's corroboration discipline with one legible tuning parameter.

### 2b. Directional penalty → $E_\text{evidence}$

$$
\boxed{\,E_\text{evidence} = P_\text{agree}\cdot E_\text{pool}\,}
$$

with $P_\text{agree}$ from §3.

### 2c. Model–evidence blend → $Score_\text{fused}$

A **weighted geometric blend**, not the current linear $0.5\,S_\text{model} + 0.5\,E_\text{evidence}$:

$$
\boxed{\,Score_\text{fused} = S_\text{model}^{\,\lambda}\cdot E_\text{evidence}^{\,1-\lambda}\,}, \qquad \lambda = 0.35 \text{ (default "model\_trust")}.
$$

The geometric form gives the empirical evidence a **multiplicative veto**: as $E_\text{evidence}\to 0$, $Score_\text{fused}\to 0$ regardless of how confident the prose sounded — the guardrail `implementation_guide.md #4` (negative control) demands, now intrinsic rather than a bolted-on `min()` cap. With $\lambda < 0.5$ evidence dominates; the model modulates within the band the evidence permits but cannot inflate past it. A convex linear blend remains available as a more forgiving fallback.

### 2d. Guardrail flags (retained)

Keyed off the new deterministic quantities: `insufficient_evidence` + score cap when $E_\text{evidence} < \theta_\text{low}$ (default $0.35$); `needs_human_review` when $\lvert S_\text{model} - E_\text{evidence}\rvert > \theta_\text{gap}$ (default $0.35$); `tool_conflict` when directional coherence is low with $\ge 2$ substantive directional fragments (§3); `possible_artifact` from the unchanged `.artifact_flagged()` IEG check.

---

## 3. Handling disagreement / penalties

Two *high-confidence* tools with opposite directions should hurt the score; a weak dissenter should barely dent it. Assign each fragment a sign $\sigma_i$ (`up` $=+1$, `down` $=-1$, `mixed`/`na` $=0$) and an **evidence mass** $a_i = w_i\, e_i$ folding in importance and strength. With $D = \{ i : \sigma_i \neq 0 \}$ the directional fragments, define **directional coherence**:

$$
C_\text{dir} = \frac{\left\lvert \sum_{i\in D} \sigma_i\, a_i \right\rvert}{\sum_{i\in D} a_i} \;\in [0,1].
$$

$C_\text{dir}=1$ when all directional mass points one way; $0$ under balanced opposition. Being *mass-weighted*, two strong opposed tools collapse it while a faint dissenter leaves it near $1$ — the "two high-confidence tools" requirement. Non-directional fragments (all `ranked_genes` are `direction = na`) never vote, matching the current agreement logic. With $\lvert D\rvert \le 1$, set $C_\text{dir}=1$.

Penalty factor, max strength $\kappa \in [0,1]$ (default $0.5$):

$$
\boxed{\,P_\text{agree} = 1 - \kappa\,(1 - C_\text{dir})\,}.
$$

A maximally conflicted module retains at most $1-\kappa = 50\%$ of its pooled evidence. The categorical label the current code emits (`convergent_signal` / `conflicting` / `convergent_null`) is recovered for display and flagging by thresholding $C_\text{dir}$ and the count of substantive directional fragments.

---

## 4. Tool importance tiers

Two composable mechanisms produce each $w_i$.

**(a) Structural tiers** declared at registration. Extend `tool_spec` in `register_tool()` with a `tier` field mapping to a base weight $\omega$:

$$
\omega_\text{high} = 1.0,\quad \omega_\text{med} = 0.6,\quad \omega_\text{low} = 0.3.
$$

Suggested: High = `pseudobulk_de_limma`, `cluster_dme`, `differential_module_activity`; Medium = `signature_correlation`, `top_genes`; Low = `geneset_enrichment`. A tool with no declared tier falls back to Medium.

**(b) Per-run user overrides** via `user_weights`, a named list keyed by `tool_id`, multiplying the structural base:

$$
\boxed{\,w_i = \omega_{\text{tier}(i)}\cdot u_{\,t_i}\,}, \qquad u_{t_i} = 1 \text{ by default}.
$$

Weights enter both the pooling (§2a) and the directional mass $a_i$ (§3), normalized by $\sum_i w_i$ inside the mean — so users retune importance without touching the formula. $u_{t_i}=0$ cleanly mutes a tool.

---

## 5. Algorithmic pseudo-code

`R/` style: `snake_case`, single quotes, 4-space indent, `<-`, intent-based comments, functional base-R consistent with `confidence.R`. Roxygen on the exported entry point.

```r
#---------------------------------------------------------
# normalization constants
#---------------------------------------------------------

# scale family per fragment type; extends .bounded_effect_types so the
# magnitude link knows which squash to apply
.scale_family <- list(
    ranked_genes = 'corr', state_expression = 'corr',
    categorical_association = 'corr', continuous_correlation = 'corr',
    signature_correlation = 'corr', geneset_enrichment = 'enrich',
    cross_condition_delta = 'fc'
)

# tier base weights; a tool with no declared tier resolves to 'medium'
.tier_weights <- list(high = 1.0, medium = 0.6, low = 0.3)


#---------------------------------------------------------
# per-fragment normalization
#---------------------------------------------------------

# hill saturation: half-max at k, steepness h, bounded [0, 1)
.hill <- function(x, k, h = 2){
    xh <- x^h
    xh / (xh + k^h)
}

# magnitude link: bounded types clip, unbounded types saturate on a
# biologically anchored half-max so enrichment's -log10p cannot swamp the pool
.magnitude_score <- function(frag, gamma = 1, k_enrich = -log10(0.05), k_fc = 1){
    family <- .scale_family[[frag$type]] %||% 'corr'
    s <- abs(frag$effect_strength)
    switch(family,
        corr = min(s, 1)^gamma,
        enrich = .hill(s, k_enrich),
        fc = .hill(s, k_fc)
    )
}

# significance reliability: partial credit at nominal alpha, saturating at a
# strong reference p; descriptive fragments (significance NA) take na_reliability
.reliability_score <- function(frag, alpha_ref = 1e-4, na_reliability = 1){
    p <- frag$significance
    if (is.null(p) || is.na(p)) return(na_reliability)
    max(min(-log10(p) / -log10(alpha_ref), 1), 0)
}

# combined per-fragment evidence: effect AND test, multiplicatively
.fragment_score <- function(frag, params){
    m <- .magnitude_score(frag, params$gamma, params$k_enrich, params$k_fc)
    r <- .reliability_score(frag, params$alpha_ref, params$na_reliability)
    m * r
}


#---------------------------------------------------------
# tool weights (tier base x user override)
#---------------------------------------------------------

.tool_weight <- function(frag, user_weights){
    # tier is read from the registry spec; unregistered/undeclared -> medium
    tier <- tryCatch(get_tool(frag$tool_id)$tier, error = function(e) NULL) %||% 'medium'
    base <- .tier_weights[[tier]] %||% .tier_weights$medium
    override <- user_weights[[frag$tool_id]] %||% 1
    base * override
}


#---------------------------------------------------------
# pooling and directional penalty
#---------------------------------------------------------

# weighted power mean; beta -> 0 approaches the corroborative geometric mean
.pool_evidence <- function(scores, weights, beta = 0.5, floor = 1e-3){
    e <- pmax(scores, floor)
    (sum(weights * e^beta) / sum(weights))^(1 / beta)
}

# mass-weighted directional coherence: two strong opposed tools collapse it,
# a faint dissenter barely moves it; non-directional fragments never vote
.directional_coherence <- function(frags, masses){
    sign_map <- c(up = 1, down = -1, mixed = 0, na = 0)
    sigma <- sign_map[vapply(frags, function(f) f$direction %||% 'na', character(1))]
    directional <- sigma != 0
    if (sum(directional) <= 1) return(1)
    a <- masses[directional]
    abs(sum(sigma[directional] * a)) / sum(a)
}


#---------------------------------------------------------
# public entry point
#---------------------------------------------------------

#' Calculate the deterministic fused evidence confidence for a packet
#'
#' Normalizes every fragment onto a unified [0, 1] scale, pools them with a
#' weighted power mean, applies a mass-weighted directional-conflict penalty,
#' and returns the empirical evidence together with its components. The result
#' is injected into the synthesis prompt and re-used by [fuse_confidence()] as
#' the ground-truth evidence term, so the printed fusion string is fully
#' reproducible rather than model-driven.
#'
#' @param fragments A list of `evidence_fragment` objects (a packet's `fragments`).
#' @param user_weights Named list of per-`tool_id` weight multipliers on top of
#'   the structural tier base. Default `list()` (all tiers unmodified).
#' @param beta Corroboration exponent for the power mean; lower is more
#'   conjunctive. Default `0.5`.
#' @param lambda Model-trust weight in the final geometric blend. Default `0.35`.
#' @param kappa Maximum directional-conflict penalty. Default `0.5`.
#' @return A list: `e_evidence`, `e_pool`, `p_agree`, `c_dir`, `lambda`,
#'   `params`, and a per-fragment `matrix` (data.frame) for prompt rendering
#'   and audit.
#' @export
calculate_fusion_score <- function(fragments, user_weights = list(), beta = 0.5,
                                    lambda = 0.35, kappa = 0.5){
    params <- list(
        gamma = 1, k_enrich = -log10(0.05), k_fc = 1,
        alpha_ref = 1e-4, na_reliability = 1
    )

    scores <- vapply(fragments, .fragment_score, numeric(1), params = params)
    weights <- vapply(fragments, .tool_weight, numeric(1), user_weights = user_weights)
    masses <- weights * scores

    e_pool <- .pool_evidence(scores, weights, beta = beta)
    c_dir <- .directional_coherence(fragments, masses)
    p_agree <- 1 - kappa * (1 - c_dir)
    e_evidence <- p_agree * e_pool

    # per-fragment audit matrix; also the block rendered into the prompt (S6)
    matrix <- data.frame(
        fragment_id = vapply(fragments, function(f) f$fragment_id, character(1)),
        type = vapply(fragments, function(f) f$type, character(1)),
        weight = round(weights, 3),
        magnitude = round(vapply(fragments, .magnitude_score, numeric(1)), 3),
        reliability = round(vapply(fragments, .reliability_score, numeric(1)), 3),
        e_score = round(scores, 3),
        direction = vapply(fragments, function(f) f$direction %||% 'na', character(1)),
        stringsAsFactors = FALSE
    )

    list(
        e_evidence = e_evidence, e_pool = e_pool, p_agree = p_agree,
        c_dir = c_dir, lambda = lambda, params = list(beta = beta, kappa = kappa),
        matrix = matrix
    )
}
```

The final blend stays in `fuse_confidence()`, which now consumes `calculate_fusion_score()` instead of `.evidence_score()`:

```r
fusion <- calculate_fusion_score(packet$fragments, user_weights)
model_score <- interp$confidence$model_score
fused_score <- model_score^fusion$lambda * fusion$e_evidence^(1 - fusion$lambda)
```

---

## 6. Rendering the matrix into the prompt

Goal: the model **explains** the confidence rather than **inventing** it. Flow: (1) compute `calculate_fusion_score()` on the packet; (2) render the matrix as an authoritative block appended in `build_user_prompt()`; (3) run synthesis; (4) `fuse_confidence()` re-derives the deterministic $Score_\text{fused}$ regardless of what the model wrote — the math is the source of truth, the prompt block only keeps the prose consistent with it.

Render a compact fixed-width table plus the pooled scalars and an explicit constraint:

```
EVIDENCE CONFIDENCE MATRIX  (computed deterministically upstream — treat as ground truth, do not recompute or contradict)

fragment_id        type                weight  magnitude  reliability  e_score  direction
cluster_dme        state_expression    1.00    0.82       0.95         0.78     up
pseudobulk_de      cross_condition_..  1.00    0.71       0.90         0.64     up
geneset_enrichment geneset_enrichment  0.30    0.61       0.88         0.54     up

pooled_evidence  E_pool  = 0.71   (weighted power mean, beta = 0.5)
directional      C_dir   = 0.93  ->  P_agree = 0.97
empirical        E_evidence      = 0.69
model_trust      lambda          = 0.35

CONSTRAINTS:
- confidence.score must be consistent with E_evidence; it may not exceed E_evidence + 0.10.
- Any directional claim must agree with the sign of the directional mass above (coherence 0.93, net "up").
- If E_evidence < 0.35, set flags to include insufficient_evidence and keep supporting_claims minimal.
- Explain what the numbers mean for this module; do not restate or recompute them.
```

Add matching rules to `build_system_prompt()`: `confidence.score` is bounded by the computed band; every quantitative certainty statement references `E_evidence`; the model may not assert a direction contradicting the reported coherence sign. The deterministic recomputation in `fuse_confidence()` guarantees the final number never drifts from the math.

The fusion string keeps its shape, every term now deterministic:

```
[fusion: model=0.70, evidence=0.69 (E_pool=0.71, P_agree=0.97, C_dir=0.93), lambda=0.35, fused=0.69]
```

---

## 7. Parameter summary

| Symbol | Meaning | Default | Where |
|---|---|---|---|
| $\gamma$ | correlation-magnitude exponent | $1$ | §1a |
| $k_\text{enrich}$ | enrichment half-max ($-\log_{10}\alpha$) | $1.30$ | §1a |
| $k_\text{fc}$ | fold-change half-max ($\lvert\log_2 FC\rvert$) | $1$ | §1a |
| $h$ | Hill steepness | $2$ | §1a |
| $\alpha_\text{ref}$ | strong-significance reference p | $10^{-4}$ | §1b |
| $r_\text{na}$ | reliability for untested fragments | $1$ | §1b |
| $\beta$ | corroboration exponent (power mean) | $0.5$ | §2a |
| $\lambda$ | model-trust weight in final blend | $0.35$ | §2c |
| $\kappa$ | max directional-conflict penalty | $0.5$ | §3 |
| $\omega_\text{tier}$ | structural tier weights | $1.0/0.6/0.3$ | §4 |
| $\theta_\text{low}, \theta_\text{gap}$ | flag thresholds | $0.35, 0.35$ | §2d |

---

## Acceptance criteria (done =)

- `calculate_fusion_score(fragments, user_weights)` exported, roxygen-documented, `devtools::document()` clean.
- Normalization is bounded and monotone per family; `geneset_enrichment` at FDR $=0.05$ maps near $0.5$ and cannot dominate a bounded correlation of equal weight.
- Geometric blend behaves as a veto: a packet with $E_\text{evidence}\approx 0$ yields $Score_\text{fused}\approx 0$ even at $S_\text{model}=1$ (negative-control property).
- Directional penalty is mass-weighted: a strong opposed pair collapses $C_\text{dir}$; a weak dissenter against strong agreement leaves it near $1$.
- Tier + `user_weights` change $w_i$ as specified; $u_{t_i}=0$ mutes a tool; unknown tools default to Medium.
- Every existing flag (`insufficient_evidence`, `needs_human_review`, `tool_conflict`, `possible_artifact`) still fires on the same conditions; the fusion-string contract is preserved.
- The confidence matrix is injected into every prompt and logged; `fuse_confidence()` re-derives the printed number deterministically.
- `testthat` covers normalization bounds/monotonicity, enrichment saturation, the geometric veto, directional penalty (strong vs weak dissenter), tier/`user_weights` application, and the retained flags. All existing M1/M1.5/M2 tests still pass.
- Runs fully offline (mock backend); no new package dependencies.

## Conventions

- R style: [STYLE.md](../../STYLE.md). Installed package: roxygen new exports, `devtools::document()`, `R CMD check` clean.
- Everything except live model calls runs with no network. Iterate on the mock backend / one module only (API budget).

---

*Last updated: 2026-07-21*
