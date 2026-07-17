# llegir Code Style Guidelines

Style conventions for development inside the `llegir` R package. Follow these when writing or editing `.R` source files and test suites.

---

## Architecture & Structure

`llegir` is a structured R package (pkgdown).
- **Production Files**: Code lives inside `R/`. Functions must be clean, modular, and decoupled.
- **Roxygen2 is Mandatory**: Aall **exported** package functions must carry full `Roxygen2` headers so `devtools::document()` can map them into the namespace and generate documentation. Internal local helpers do not need Roxygen headers but they should have detailed descriptions as well.

---

## Naming

- **Variables & Arguments**: Use `snake_case` (e.g., `cur_mod`, `plot_df`, `evidence_packet`).
- **Functions**: Use `snake_case` / lowercase (e.g., `validate_schema`, `scale_values`).
- **Short Variable Conventions**: `p` for a plot, `plot_df` for a dataframe bound to a plot, `ctx` for tool contexts.

---

## Formatting

- **Indentation**: 4 spaces for the contents of every `{}` block. 
- **No Alignment Padding**: Do not add spaces to vertically align assignment operators (`<-` or `=`) across lines. One space on each side is sufficient.
- **Assignment**: Always use `<-` for assignment. Use `=` exclusively for assigning arguments inside function calls.
- **Strings**: Prefer **single quotes** (`'string'`) for standard strings.
- **One Verb Per Line**: Break lines at tidyverse pipes (`%>%`) and ggplot additions (`+`) so each logical operation sits on its own line:
  ```r
  plot_df <- cur_df %>%
      group_by(module) %>%
      summarise(mean_expr = mean(expr))
- Pipes: Use magrittr %>% pipes (not the native |> pipe).

## Comments & Documentation
- **Interactive Dev/Test Scripts (`scripts/`)**: Comments must act as a narrative walkthrough for a human developer running the code line-by-line, prompting them on what to inspect in the console.
- **Production Files (`R/`)**: Use **Intent-Based Commenting**. Aim for a density of roughly one short comment per 5–10 lines of complex logic. 
  - *Do NOT comment on plain syntax*: (e.g., `# loop over modules` or `# check if file exists`).
  - *DO comment on non-obvious logic, structural assumptions, or data contracts*:
    ```r
    # good production comment example:
    # use the fallback user-defined map because seurat markers lack explicit delta columns
    if (is.null(format_defaults)) {
        return(apply_manual_mapping(table, user_map))
    }
    ```
- **Section Dividers**: Avoid excessive use of decorated `## ===== BANNER ===== ##` blocks. If you need to separate major logical code blocks inside a file, use exactly this clean, single-line, lowercase comment structure:
  ```r
  #---------------------------------------------------------
  # environment setup
  #---------------------------------------------------------
- Numbered # 1. / # 2. comments are reserved for multi-step algorithmic sequences, generally they should be avoided.
- Avoid comments that come after code on the same line.
- Section Dividers: Avoid excessive use of decorated `## ===== BANNER ===== ##` blocks. If you need to separate major logical code blocks inside a file, use exactly this clean, single-line, lowercase comment structure:

#---------------------------------------------------------
# section title
#---------------------------------------------------------

## Anti-Patterns to Avoid
- No Aligned Assignments: Avoid padding code blocks to align arrows or equal signs.
- No Over-Defensive Coding: Avoid packing every internal helper with dozens of stopifnot() statements or heavy type-checks unless validating a critical public data contract/schema.
- Clean Tidyverse Syntax: Avoid using complex Base-R vapply / setNames combinations where a straightforward dplyr mutation reads cleaner.