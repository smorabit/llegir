# Claude Code handoff prompt — M2 live run & verification

← [Project home](../README.md) · [M2 verification](m2_verification.md)

The prompt to hand a fresh Claude Code instance now that M2 is *implemented*: wire the live Gemini backend and run the verification. Paste the block below from the repo root.

*Logged 2026-07-12.*

---

## Prompt

```
The Module Interpretation Engine is built through Milestone 2: the deterministic
core (M1/M1.5) produces validated evidence packets, and the synthesis machinery
(interpretation schema, prompt assembly, mock backend, faithfulness check,
confidence fusion, paragraph renderer, orchestrator) is implemented and passing the
offline test suite. Your job is NOT to rebuild any of that — it is to wire the live
model backend and run the verification.

First, read: docs/m2_verification.md (this is the authoritative task), CLAUDE.md,
docs/milestone_2.md, and docs/schemas.md. Follow STYLE.md.

Environment: activate the conda env `hdWGCNA` (`conda activate hdWGCNA`). `ellmer` is
installed. The live provider is Google Gemini — call it exactly like this:

    chat <- chat_google_gemini(model = 'gemini-3.5-flash')

The GEMINI_API_KEY is ALREADY configured in the R environment. Do NOT set it up,
prompt me for it, or print it — just call the function and it works.

Do this in order, checking in where noted:

  1. Mock end-to-end (offline). Run scripts/run_synthesis_csf.R with the default
     mock_backend(). Confirm it writes a valid interpretation JSON + rendered
     paragraph for all 14 modules to output/interpretations/, plus a review_queue;
     every interpretation validates and passes the faithfulness check; provenance is
     complete; a rerun is byte-identical. --> CHECK IN with me before going live.

  2. Wire the Gemini backend. Point the live backend (ellmer_backend / the config
     provider) at chat_google_gemini(model = 'gemini-3.5-flash'), temperature = 0.
     Define the interpretation schema once as an ellmer type_object() so structured
     output is provider-agnostic. Do NOT touch the deterministic core, the mock
     backend, or the offline tests — they must all still pass unchanged.

  3. One packet first. Run a SINGLE module live and confirm the nested interpretation
     schema round-trips through Gemini's structured output (the supporting_claims
     array-of-objects and the direction/flags enums come back valid). Providers
     differ in how strictly they honor complex responseSchema; fix any mismatch here
     before spending the full run. --> CHECK IN with me.

  4. Full live run. All 14 packets via Gemini. Confirm each validates and passes
     faithfulness (a mismatch is a hard fail / needs_human_review, per design); the
     review_queue is populated with sane confidence + flags; provenance logs the real
     provider + model (gemini-3.5-flash). Add a basic 429/backoff retry (free-tier
     per-minute limits; trivial at 14 modules).

  5. Biology spot-check (docs/m2_verification.md Step 3). Score a few anchor modules
     against known biology: MM2 is dominated by Cytoplasmic Translation / RPL·RPS
     genes, so its label must clearly be ribosome/translation; pick 2-3 more obvious
     anchors. Per module: label matches the dominant evidence; cell_state matches the
     top cluster_dme cluster; no genes/pathways named that aren't in the evidence;
     the literature slot is empty (that's M3); metadata/diagnosis claims are honest
     (sample-level tests are mostly non-significant given small n — do not let it
     assert disease links the evidence doesn't support); confidence is calibrated.
     Also run the M1 random-gene-set negative control through synthesis and confirm
     it returns low confidence / insufficient_evidence.

Non-negotiables: the model only fills the schema, never runs analysis code; the
deterministic core, mock backend, and all M1/M1.5/M2 offline tests stay untouched and
passing; a faithfulness mismatch is a hard fail; do not modify or expose the API key;
follow STYLE.md; still NO formal R package.

Report back after step 1 (mock outputs) and step 3 (one-packet Gemini round-trip)
before the full run and spot-check.
```

---

## Notes

- Provider call: `chat_google_gemini(model = 'gemini-3.5-flash')`; key already in the R env — nothing to configure.
- The offline mock backend and test suite are the safety net — they must stay green through the whole live-wiring exercise.
- Check-ins: after the mock end-to-end, and after the single-packet Gemini round-trip.
- Next after this: M3 — literature grounding (PubMed), custom-tool registry, calibration/consistency evaluation.

---

*Last updated: 2026-07-12*
