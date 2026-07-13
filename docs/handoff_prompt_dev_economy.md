# Claude Code handoff prompt — dev-economy pass

← [Project home](../README.md) · [Dev economy](dev_economy.md)

Handoff for a fresh Claude Code instance: make the synthesis layer cheap to iterate on under free-tier API limits. Paste the block below from the repo root.

*Logged 2026-07-12.*

---

## Prompt

```
The Module Interpretation Engine is built and live-verified through Milestone 2:
the deterministic core (M1/M1.5) produces evidence packets, the synthesis layer
works, a full 14-module Gemini run is saved in output/interpretations/, and the
biology spot-check passed. Your job is a small DEV-ECONOMY pass so I can keep
iterating without burning my tiny free-tier API budget. No new science.

First, read: docs/dev_economy.md (this is the task, authoritative), CLAUDE.md,
docs/milestone_2.md, and docs/schemas.md. Follow STYLE.md.

Environment: activate the conda env `hdWGCNA`. `ellmer` is installed. Two live
providers, both with API keys ALREADY CONFIGURED in the R environment:
  - GitHub Models (DEFAULT for dev): chat_github(model = "gpt-4o-mini")   ~150/day
  - Google Gemini (occasional checks): chat_google_gemini(model = 'gemini-3.5-flash') ~20/day
TRUST that both keys are configured. Do NOT search the R environment for them, print
them, inspect them, or set anything up — just call the functions and they work.

Tasks:
  1. GitHub Models backend + provider config. Add a backend for
     chat_github(model = "gpt-4o-mini") satisfying the SAME backend contract as the
     existing mock and Gemini backends. Make provider + model config-selected
     (mock | github | gemini), with GitHub Models gpt-4o-mini as the default dev
     provider. Keep ONE ellmer type_object() schema (provider-agnostic) — do not
     fork it per provider.
  2. Module subsetting. Add an option to the synthesis run (e.g. run_synthesis_csf.R
     modules = c("MM2") or n_modules) so internal testing synthesizes 1-2 modules,
     not all 14. Default the dev run to a small subset.
  3. Response caching. Cache each live model response keyed by
     packet_hash + provider + model + prompt_template_version, under output/cache/
     (already gitignored via output/). On a cache hit, skip the API call. Add a
     force-refresh flag. Goal: iterating on faithfulness/confidence/rendering must
     re-run for FREE, spending calls only when the packet/provider/model/prompt
     actually change.
  4. Recalibrate tool_conflict. In the first live run it fired on ALL 14 modules,
     which is useless. Cause: after the M1.5 pseudoreplication fix the metadata tool
     is (correctly) non-significant on most modules, and cross-tool-agreement reads
     that as a conflict. Fix the concept: absence of a metadata effect must NOT count
     as a conflict with a present enrichment/cluster effect. Tune against the existing
     saved run in output/interpretations/ + the cache — do NOT spend new API calls
     for this.

Non-negotiables: do NOT touch the deterministic core, the mock backend, or the
offline test suite — they must all still pass unchanged. Do NOT hunt for, modify, or
print API keys (trust they're set). The provider switch is confined to the backend;
the model still only fills the schema, never runs analysis code. Follow STYLE.md;
still NO formal R package.

Budget discipline: verify with at MOST 1-2 live calls total — e.g. synthesize ONE
module via GitHub Models to confirm the new backend + cache + subset work end to end.
Everything else (the tool_conflict recalibration, tests) runs offline or against the
cache. Prefer GitHub Models over Gemini for any live check.

Start by restating your plan and confirming with me. Then check in once the GitHub
Models backend synthesizes one module and the cache hit works (a second run of the
same module makes no API call), before the tool_conflict recalibration.
```

---

## Notes

- Default dev provider: **GitHub Models `gpt-4o-mini`** (`chat_github(model = "gpt-4o-mini")`); Gemini only for occasional cross-checks; mock for tests.
- Keys are configured — the instance must trust that and not go looking.
- Fixtures for tuning: the saved 14-module run in `output/interpretations/` and the response cache. Measure 4 needs no live calls.
- Check-in: after one GitHub-Models module + a confirmed cache hit, before recalibrating `tool_conflict`.

---

*Last updated: 2026-07-12*
