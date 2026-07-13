# Milestone 2 — Synthesis layer: evidence → interpretation → paragraph

← [Overview](overview.md) · [Implementation guide](implementation_guide.md) · [Schemas](schemas.md) · [Milestone 1](milestone_1.md) · [Project home](../README.md)

*Status: not started. The next task after M1 (deterministic core, complete).*

---

## Goal

Turn each **evidence packet** (from M1) into a validated **interpretation object** and a rendered **boilerplate paragraph**, with two guardrails: a deterministic **faithfulness check** (every claim must be backed by a real fragment) and **confidence-gated review flags** (fuse model confidence with deterministic evidence strength). Model-agnostic synthesis via `ellmer`.

This is where the LLM enters — but bounded: the model *only* fills a structured schema from a fixed evidence packet. It does not run analysis code, and the paragraph is rendered deterministically from the schema, not free-generated.

## Builds on M1

- Inputs are the packets in `output/evidence_packets/MM*.json` (14 CSF modules), each a list of validated `evidence_fragment`s with `compact_summary`, `top_findings`, `effect_strength`, `direction`, `significance`.
- Reuses the M1 spike-in controls (pDC positive, random negative) as the evaluation seed.

## Tasks

**0. Finalize the interpretation contract.** Promote the `interpretation` object in [schemas.md](schemas.md) from draft to concrete: constructor + validator + JSON (de)serialization, and add `schemas/interpretation.schema.json`. Enforce the faithfulness invariant fields (`supporting_claims[].fragment_ids`, `direction`).

**1. Prompt assembly (packet → model input).** Build a compact, token-efficient rendering of a packet for the model: use each fragment's `compact_summary` + `top_findings` + `effect_strength`/`significance`; **do not** dump raw result tables. Prepend a **dataset-description context** — a *required* config object (species, tissue, condition/disease, treatment, assay, cell types) — so the model interprets programs in the right biological frame (the same module means different things in CSF myeloid vs. a tumor, and it disambiguates gene function, e.g. microglia vs. macrophage). Define the system prompt that instructs the model to: fill the interpretation schema, cite `fragment_ids` on every claim, use the controlled `type`/`flags` vocab, and return `insufficient_evidence` when the evidence is weak.

**2. Synthesis call via `ellmer` (structured output).** One call per packet → interpretation object, using `ellmer`'s structured-output/type system so the schema is enforced by construction. Define the interpretation schema **once as an `ellmer` `type_object()`** (provider-agnostic — drives structured output for any backend), not a provider-specific raw-JSON mode. Model is config-selected (provider + model id); `temperature = 0`. **Prototyping provider: Google Gemini** — `chat_google_gemini(model = 'gemini-3.5-flash')`, free tier, no out-of-pocket cost; the CSF data is public so the free-tier data-use terms are fine. The `GEMINI_API_KEY` is already configured in the R environment, so nothing needs to be set up. Include a **mock backend** that returns a canned interpretation object so tests and CI run with **no network / no API key** (mirrors M1's offline principle). Real runs use a `scripts/` entry point. Note providers differ in how strictly they honor complex `responseSchema`, so **verify the nested schema (`supporting_claims` array-of-objects, `direction`/`flags` enums) round-trips on one packet before running all 14**.

**3. Faithfulness auto-check.** For every `fragment_id` referenced in `supporting_claims` (and `metadata_associations`): assert it exists in the module's packet and its `direction` matches the fragment's `direction`. A mismatch is a **hard failure**, not a warning — either reject/repair or flag `tool_conflict`/`needs_human_review`.

**4. Confidence fusion.** Do not trust the model's self-reported confidence alone. Combine it with deterministic signals from the packet: max `effect_strength`, count of significant enrichment terms, cross-tool agreement (do `cluster_dme` + `geneset_enrichment` + `module_by_metadata` point the same way). Emit a final confidence score + `flags` (`needs_human_review`, `insufficient_evidence`, `tool_conflict`, `possible_artifact`, `label_low_specificity`). Route flagged modules to a review list.

**5. Paragraph renderer.** A **deterministic, versioned template** that maps the interpretation object → the boilerplate results paragraph. No additional model call; same interpretation object → identical paragraph.

**6. Provenance (extend the M1 manifest).** Log model + version, prompt-template version, `temperature`/seed, the input packet hash, and `ellmer` call metadata alongside the existing tool provenance. Reproducibility remains anchored on the evidence packet; the paragraph is a versioned draft over it.

**7. Outputs + review queue.** Per module, write the interpretation object (JSON) and rendered paragraph (md) to `output/interpretations/`, plus a `review_queue` summary table (module, confidence, flags, reason) so a human can triage the flagged ones.

## Acceptance criteria (done =)

- Runs over all 14 CSF packets → a validated interpretation object + rendered paragraph for each.
- The dataset-description config is **required**, injected into every prompt, and logged in provenance; a missing/empty description is a hard error.
- **Faithfulness:** a test that injects a fabricated `fragment_id` / wrong direction is caught and fails/flags; all real-run interpretations pass the check.
- **Confidence behaves on the controls:** the negative (random) spike-in → low confidence / `insufficient_evidence`; the positive (pDC) → high confidence with a correct interferon/pDC-type label.
- **Model-agnostic + offline CI:** the whole pipeline runs end-to-end with the mock backend (no network); config can point at a real provider for live runs.
- **Deterministic rendering:** identical interpretation object → byte-identical paragraph.
- `testthat` covers: interpretation validator, faithfulness check (pass + fail cases), confidence fusion, renderer determinism, and a mock-backend synthesis run.
- Follows [STYLE.md](../STYLE.md); still no formal R package.

## Explicitly out of scope for M2 (→ M3+)

- **Literature / PubMed grounding.** The `literature` slot stays empty/optional in M2; retrieval + citation is a later milestone (with its own guardrails against motivated search).
- **Custom-tool registry.** Deferred until a dataset needs a custom tool — CSF has none.
- **Global cross-module reconciliation** (harmonize labels, dedupe across all 14).
- **A real review UI**, calibration against a blind human-labeled sample, consistency-across-reruns study, and additional `ModuleSet` adapters.

## Design notes

- **Bounded model role:** fill a schema from a fixed packet; never run analysis code. This is what keeps synthesis standardized and reviewable.
- **Mock backend is a first-class citizen**, not an afterthought — it's how the pipeline stays testable and deterministic without an API key, and it doubles as the CI backend.
- The faithfulness check + confidence fusion are the two things that make LLM output defensible in a paper; treat them as core, not polish.

## Conventions

- R style: [STYLE.md](../STYLE.md).
- **Functionality first — still no formal R package** (no `DESCRIPTION`/`NAMESPACE`). Plain sourced functions under `R/` (`synthesis.R`, `faithfulness.R`, `confidence.R`, `render.R`, `interpretation.R`), entry point under `scripts/`, `testthat` tests under `tests/`, schemas under `schemas/`.
- Keep everything except live model calls runnable with no network.

---

*Last updated: 2026-07-10*
