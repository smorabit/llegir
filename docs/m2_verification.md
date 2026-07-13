# Milestone 2 — verification & first live run

← [Milestone 2](milestone_2.md) · [Project home](../README.md)

*Status: to do. The step after M2 implementation — confirm the machinery end-to-end, then judge whether the interpretations are actually good.*

---

## Purpose

M2's code is complete but only the *machinery* is validated (mock backend, faithfulness, confidence). This note is the plan to (1) materialize the outputs offline, (2) do a first real model run, and (3) judge interpretation quality against known biology. Run in the `hdWGCNA` conda env.

---

## Step 1 — Mock end-to-end (offline, no key)

Run `scripts/run_synthesis_csf.R` with the default `mock_backend()`.

- [ ] Produces an interpretation JSON + rendered paragraph for **all 14** modules in `output/interpretations/`, plus a `review_queue` summary.
- [ ] Every interpretation passes `validate_interpretation` and the **faithfulness** check (the mock cites real `hub_genes`/`geneset_enrichment` fragments — confirm no `direction_mismatch` for any module, which would mean the real fragment directions differ from what the mock assumes).
- [ ] Provenance manifest is present and complete (model=`mock`, prompt-template version, packet hash).
- [ ] Rerun is byte-identical (mock is deterministic).

This confirms the plumbing writes valid artifacts before spending any tokens.

## Step 2 — First live run (Google Gemini, free tier)

Provider for prototyping is **Gemini** — `chat_google_gemini(model = 'gemini-3.5-flash')`. The `GEMINI_API_KEY` is already configured in the R environment, so there is nothing to set up. Wire the Gemini backend into `run_synthesis_csf.R` (swap the `backend <-` line), `temperature = 0`.

- [ ] **One packet first:** run a single module and confirm the nested interpretation schema round-trips through Gemini's structured output (the `supporting_claims` array-of-objects and the `direction`/`flags` enums come back valid). Providers differ in how strictly they honor complex `responseSchema`; catch this before spending the full run.
- [ ] Then all 14 complete; each interpretation validates and passes faithfulness (any violation → hard fail or `needs_human_review`, per design).
- [ ] `review_queue` populated; confidence + flags look sane.
- [ ] Provenance logs the real provider + model + version (Gemini).
- [ ] Basic 429/rate-limit retry works (free tier has per-minute limits — trivial at 14 modules, but confirm the backoff path).

## Step 3 — Spot-check rubric (does the biology hold?)

Score a handful of modules against what the evidence and known CSF-myeloid biology say. Use **anchor modules with obvious biology** as positive controls — e.g. **MM2** (its enrichment is dominated by *Cytoplasmic Translation* / RPL·RPS genes → the label should clearly be ribosome/translation). Identify 2–3 more anchors before scoring (a homeostatic-microglia, an interferon-response, a complement, or an antigen-presentation/MHC module are the usual suspects in CSF myeloid).

For each scored module:

- [ ] **Label matches the dominant evidence** — the `proposed_label` reflects the top GO term(s) + hub genes, not a tangential one.
- [ ] **Cell-state is consistent** — `cell_state` matches the top cluster from `cluster_dme`.
- [ ] **No hallucinated content** — every gene/pathway named appears in the evidence; the `literature` slot is empty (literature is M3); no invented citations.
- [ ] **Metadata claims are honest** — given the M1.5 pseudoreplication fix, sample-level `diagnosis` associations are mostly non-significant; the interpretation must **not** assert a diagnosis/disease link the sample-level test doesn't support.
- [ ] **Confidence is calibrated** — strong single-program modules → high confidence; weak/ambiguous modules → lower confidence or a flag.
- [ ] **Insufficient-evidence path fires** — run the M1 negative-control spike-in (random gene set) through synthesis and confirm it returns low confidence / `insufficient_evidence`, not a fluent story.

Also eyeball across modules:

- [ ] **Cross-module consistency** — modules with the same dominant program get consistent labels (inconsistency here is the motivation for M3 global reconciliation, not an M2 bug).

## Step 4 — Reproducibility / determinism

- [ ] Same packet + `temperature = 0` → stable label/structure across reruns (note: LLM output is not bit-reproducible across model versions — the *evidence* is the reproducible anchor, the paragraph is a versioned draft).
- [ ] Paragraph renderer is byte-identical for a fixed interpretation object.

## Pass / iterate

- If labels are off or over-confident → tune the **system prompt** (task 1) and/or the **confidence fusion** thresholds (task 4), not the evidence.
- If claims cite the wrong fragments/directions → that's a faithfulness catch working; inspect whether it's a prompt issue or a real ambiguity.
- Log which modules needed human review and why — this seeds the M3 calibration/eval work.

---

*Last updated: 2026-07-12*
