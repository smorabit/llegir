# Dev economy — running the synthesis layer on a tight API budget

← [Milestone 2](milestone_2.md) · [M2 verification](m2_verification.md) · [Project home](../README.md)

*Status: to do (next Claude Code session). Prototyping-phase measures to keep iterating cheaply.*

---

## Context

Prototyping is done on **free tiers only** — no paid subscriptions:

| Provider | Call | Budget |
|---|---|---|
| GitHub Models | `chat_github(model = "gpt-4o-mini")` | ~150 / day — **default dev provider** |
| Google Gemini | `chat_google_gemini(model = 'gemini-3.5-flash')` | ~20 / day — occasional quality cross-check |
| mock | `mock_backend()` | unlimited, offline — tests / CI |

Both API keys are **already configured** in the R environment. Code should trust that and just call the functions — no key discovery, inspection, or setup.

A local model (via `chat_ollama()`) is the eventual answer but is not being set up soon.

## The four measures

1. **Provider config + GitHub Models backend.** Make provider + model config-selected across the same swappable backend contract (`mock` / `gemini` / `github`). Default the dev provider to GitHub Models `gpt-4o-mini` (the generous tier); keep Gemini for occasional cross-checks; mock stays the test/CI backend. The interpretation schema stays a single `ellmer` `type_object()` so structured output is provider-agnostic.

2. **Module subsetting.** Run 1–2 modules per invocation for internal testing instead of all 14 (e.g. a `modules = c("MM2")` / `n_modules` option on the synthesis run). One 14-module Gemini run already exists in `output/interpretations/` — that's plenty of material to iterate against.

3. **Response caching.** Cache each live model response keyed by `packet_hash + provider + model + prompt_template_version` (under `output/cache/`, already gitignored via `output/`). On a cache hit, skip the API call. This is the big saver: iterating on faithfulness / confidence / rendering re-runs for **free**, so daily calls are spent only when the packet, provider, model, or prompt actually change. Include a force-refresh flag.

4. **Recalibrate `tool_conflict`.** In the first live run, `tool_conflict` fired on all 14 modules — useless as triage. Cause: after the M1.5 pseudoreplication fix, the metadata tool is (correctly) non-significant on most modules, and the cross-tool-agreement logic reads that as a conflict. Fix the concept: **absence of a metadata effect must not count as a conflict with a present enrichment/cluster effect.** Tune against the existing saved run + cache — no new API calls.

## Principle

Measures 1–3 make dev iteration cheap; measure 4 (and any confidence tuning) should be done **against the run you already paid for** — the saved interpretations and the response cache are the fixtures. Spend live calls only to confirm a new backend works, not to re-derive things you can compute offline.

---

*Last updated: 2026-07-12*
