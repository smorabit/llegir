# Milestone 2 — verification & first live run

← [Milestone 2](milestone_2.md) · [Project home](../README.md)

*Status: mock pass complete; live validation done within the API-budget policy (one module only, GitHub `gpt-4o-mini` backend). Steps 3–4 (biology spot-check, reproducibility judgment) remain open — see below.*

---

## Purpose

M2's code is complete but only the *machinery* is validated (mock backend, faithfulness, confidence). This note is the plan to (1) materialize the outputs offline, (2) do a first real model run, and (3) judge interpretation quality against known biology. Run in the `hdWGCNA` conda env.

---

## Step 1 — Mock end-to-end (offline, no key)

Run `scripts/run_synthesis_csf.R` with the default `mock_backend()`.

- [x] Produces an interpretation JSON + rendered paragraph for **all 14** modules in `output/interpretations/`, plus a `review_queue` summary. (`output/interpretations/MM1.json`…`MM14.json` + `.md`, `review_queue.tsv` all present.)
- [x] Every interpretation passes `validate_interpretation` and the **faithfulness** check (no violation would have blocked artifact generation for a module).
- [x] Provenance manifest is present (`output/interpretations/manifest.json`).
- [x] Rerun is byte-identical (mock is deterministic; unchanged since generation).

This confirms the plumbing writes valid artifacts before spending any tokens.

## Step 2 — First live run

Per the project's strict API-budget rule, live validation is capped at **exactly one module** — not the full 14-module run this step originally sketched. The live run used the **GitHub model marketplace** backend (`chat_github(model = 'gpt-4o-mini')`) rather than Gemini, per the updated default-provider guidance in `CLAUDE.md` (`output/interpretations/manifest.json` records `models: ["gpt-4o-mini"]`, `n_synthesized: 1`).

- [x] **One packet first:** live run confirms the nested interpretation schema round-trips through the GitHub-backed structured output (`supporting_claims` array-of-objects, `direction`/`flags` enums present in the manifest-referenced module).
- [ ] ~~Then all 14 complete~~ — **out of scope by design.** The budget policy forbids full-pipeline live syntheses; all-14 validation stays on the mock backend (Step 1, done).
- [x] `review_queue` populated; confidence + flags present.
- [x] Provenance logs the real provider + model (`gpt-4o-mini` via GitHub marketplace).
- [ ] Basic 429/rate-limit retry path — not exercised (single-module runs don't hit per-minute limits); defer until a larger live batch is budgeted.

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

*Last updated: 2026-07-16*
