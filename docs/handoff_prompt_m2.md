# Claude Code handoff prompt — Milestone 2

← [Project home](../README.md) · [Milestone 2](milestone_2.md)

The prompt originally used to build Milestone 2 (synthesis layer). Kept as a record.

> **M2 is now implemented.** For the next step — wiring the live Gemini backend and running verification — use [handoff_prompt_m2_run.md](handoff_prompt_m2_run.md), not this build prompt.

*Logged 2026-07-11.*

---

## Prompt

```
You're picking up the Module Interpretation Engine at Milestone 2 — the synthesis
layer (the LLM step). Milestones 1 and 1.5 are done: the deterministic core produces
validated evidence packets per module (see output/evidence_packets/MM*.json for the
14 CSF modules, and output/tables/ for the human-readable versions).

First, read: CLAUDE.md, docs/milestone_2.md (this is the task and is authoritative),
docs/schemas.md (the interpretation-object contract — finalize it), and
docs/milestone_1_5.md (what evidence now exists). Follow STYLE.md.

Environment: activate the conda env `hdWGCNA` before running any R
(`conda activate hdWGCNA`). M2 uses `ellmer` for model calls — if `ellmer` is not
installed, STOP and tell me (do not install). Live runs use Google Gemini
(chat_google_gemini(model = 'gemini-3.5-flash'); GEMINI_API_KEY already configured in
the R env), but the pipeline and ALL tests must run with a MOCK backend and no
network / no key.

Scope: Milestone 2 ONLY. The model's role is bounded — it fills a structured schema
from a fixed evidence packet; it does NOT run analysis code, and the paragraph is
rendered deterministically from the schema. OUT of scope: literature/PubMed
(deferred to M3), the custom-tool registry, global reconciliation, a real review UI,
and any formal R package. Plain sourced functions, same as before.

Tasks (full detail in docs/milestone_2.md):
  0. Finalize the interpretation object: constructor + validator + JSON
     (de)serialization; add schemas/interpretation.schema.json. Enforce the
     faithfulness-invariant fields (supporting_claims[].fragment_ids, direction).
  1. Prompt assembly: compact rendering of a packet (each fragment's compact_summary
     + top_findings + effect_strength/significance; NOT raw tables). Prepend the
     REQUIRED dataset-description context (config object; suggested CSF version in my
     notes below). System prompt: fill the schema, cite fragment_ids on every claim,
     use the controlled type/flags vocab, return insufficient_evidence when weak.
  2. Synthesis via ellmer structured output -> interpretation object (temperature 0).
     Include a MOCK backend (returns a canned interpretation object) as a first-class
     citizen so tests/CI run offline; live runs use a scripts/ entry point.
  3. Faithfulness auto-check: every cited fragment_id must exist in the module's
     packet and its direction must match the fragment; a mismatch is a HARD
     failure/flag, not a warning.
  4. Confidence fusion: combine the model's self-reported confidence with
     deterministic signals (max effect_strength, count of significant enrichment
     terms, cross-tool agreement) -> final confidence + flags; route flagged modules
     to a review list.
  5. Paragraph renderer: deterministic, versioned template; same interpretation
     object -> byte-identical paragraph.
  6. Provenance + outputs: extend the manifest (model + version, prompt-template
     version, temperature/seed, input packet hash); write interpretation JSON +
     rendered paragraph md to output/interpretations/, plus a review_queue summary
     (module, confidence, flags, reason).

Non-negotiables: bounded model role (fill schema only, never run analysis code);
mock backend runs fully offline; dataset-description is required (hard error if
missing); every claim cites a real fragment; a faithfulness mismatch is a hard fail;
follow STYLE.md; NO formal R package; all M1 + M1.5 tests still pass.

Reuse the M1 spike-ins as the eval seed: the random negative control must come out
low-confidence / insufficient_evidence; the pDC positive control must get a
confident, correct label.

Start by restating your plan for tasks 0-2 and confirming with me before writing any
synthesis code. Then check in (a) once the mock-backend synthesis runs end-to-end
over the 14 packets, and (b) after the faithfulness check + confidence fusion, before
the renderer and final outputs.
```

---

## Notes

- Env: `hdWGCNA`. `ellmer` may need to be present — if missing, the instance must stop and flag, not install. Live runs need an API key; tests/CI use the mock backend (offline).
- Deliberate check-ins: after mock end-to-end works, and after the guardrails (faithfulness + confidence).
- Suggested **dataset-description** config for the CSF dev dataset (refine as needed):

```yaml
dataset:
  species: human
  tissue: cerebrospinal fluid (CSF)
  cell_compartment: myeloid cells (microglia / monocyte-derived macrophages / DCs)
  assay: single-cell RNA-seq (10x)
  conditions:
    - Glioblastoma
    - Brain Metastasis
    - Primary CNS lymphoma
    - Secondary CNS lymphoma
    - Inflammatory / other neuroinflammatory
  notes: >
    Modules are CSF-myeloid co-expression programs; interpret in a CNS-myeloid,
    neuro-oncology / neuroinflammation context.
```

- Next after M2: M3 — literature grounding (PubMed, with its own guardrails), custom-tool registry, and calibration/consistency evaluation.

---

*Last updated: 2026-07-11*
