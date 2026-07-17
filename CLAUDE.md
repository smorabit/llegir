# CLAUDE.md

## System Commands
- **Run Tests**: `devtools::test()` or `testthat::test_dir('tests/testthat')`
- **Run Package Check**: `devtools::check()`
- **Build Documentation**: `devtools::document()`
- **Build Pkgdown Site**: `pkgdown::build_site()`

## Coding Guidelines
@STYLE.md

## Core Architecture Contracts
- **Framework**: `llegir` is an R package utilizing `ellmer` for LLM orchestration.
- **No Direct Imports**: Core tools must depend strictly on the `ModuleSet` adapter, never directly on `hdWGCNA` or `Seurat`.
- **Contracts**: Every tool output must strictly validate against the `evidence_fragment` schema.
- **Boilerplate Prose**: Programmatic synthesis outputs must strictly match the `interpretation` schema. No free-form prose generation.
- **Style Rules**: Follow `STYLE.md` exactly (tidyverse, snake_case, 4-space indent, single quotes, no roxygen comments unless explicitly asked).

## Environment & Budget Rules
- **Environment**: Always use the active `hdWGCNA` conda environment. Do not install new packages.
- **API Budget Constraints (Strict)**: 
  - Iteration should be run offline using the mock backend or response cache.
  - For live validation, iterate using **exactly ONE** module. Do not call full pipeline syntheses.
  - Default development provider is Github (`ellmer::chat_github(model = 'gpt-4o-mini')` or Google Gemini `chat_google_gemini(model = 'gemini-1.5-flash')`).
  - Never prompt for API keys.

## Conversational Guidelines (Strict Token-Saving)
- **Be highly concise.** Skip all conversational filler, pleasantries, or framing (e.g., do not say "Certainly, let's write a spec" or "I can help with that").
- **No explanations/summaries:** Deliver code, scripts, markdown updates, and specs directly with zero wrapping explanatory text.
- **Limit output prose:** Keep chat responses under 3 sentences unless specifically asked to explain reasoning.
## Git & Commit Guidelines (Strict)
- **Automated Commits**: When asked to commit code, always use a highly detailed, descriptive title and body.
- **Commit Format**: Use Conventional Commits style (e.g., `feat: ...`, `fix: ...`, `refactor: ...`).
- **No Self-Attribution**: Do NOT add "Co-authored-by: Claude", "Created by AI", or any text referring to yourself as a contributor, assistant, or author. The commit message must read purely as though written by a human developer. Do not add conversational wrap-ups like "Everything is working great!".
- **Commit Body**: Explicitly list all new functions added, modified data contracts, or newly passed test files in the body of the commit message. 
- *Example*:
```
 feat: implement format-specific evidence ingestion runners
  - Added format-specific column mappings for Seurat, DESeq2, and edgeR in import_fragment.R
  - Added hdWGCNA DME table mappings to state_expression fragments
  - Updated tests in test-import_fragment.R; all 14 tests passing.```
```

## Reference Docs (Static Anchors)
- Design Principles: `docs/overview.md`
- Current Architectural Plan: `docs/implementation_guide.md`
- State Contracts: `docs/schemas.md`