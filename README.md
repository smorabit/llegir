# llegir

**llegir** is a package for LLM-enabled gene-program interpretations in R. In transcriptomics data analysis, we often work with groups of genes that are somehow related to one another, and **llegir** aims to automate the interpretation of these interrelated groups of genes, which we refer to as "*gene modules*". **llegir** is completely agnostic to the sequencing technology (e.g. bulk RNA-seq, single-cell RNA-seq, sequencing or imaging based spatial transcriptomics, etc), and it is agnostic to the method used to group genes into modules (e.g. WGCNA, matrix factorization, literature-derived gene lists, etc).

**llegir** takes as input a gene expression matrix and a set of *gene modules*, for instance coming from our other tool [hdWGCNA](https://smorabit.github.io/hdWGCNA/). Next, **llegir** compiles a set of "evidence" for each module by running a user-defined chain of analysis tools, flexibly defined to suit the specific needs of each dataset. The results of these analysis tools are assembled into an "evidence packet" per module.

The main way to interpret those packets is with a terminal coding agent such as Claude Code. `export_agent_workspace(mode = 'label')` writes a self-contained workspace: the evidence, an artifact screen for each module, and a manifest that gives the agent its labeling rules and a step-by-step review protocol. The agent writes one label per module, and can run its own read-only queries against the data to test it. `check_agent_labels()` then checks every label against the data rather than trusting it, and `collect_agent_labels()` runs the labels through the same validation, faithfulness and confidence checks as the rest of the package before **llegir** compiles an .html report. No API calls are needed for this route. See the [Labeling modules with a coding agent](vignettes/agent-labels.Rmd) vignette.

Alternatively, **llegir** can send each evidence packet to an LLM directly from R, through an API provider or a [local model](vignettes/local-llm-backend.Rmd), as shown in the [Getting Started](vignettes/getting-started.Rmd) vignette.

**llegir** means "to read" in the Catalan language.

## Development stage

**llegir** is in an experimental development stage, and at this point it is subject to major changes until we have pushed a more stable release, proceed with caution! 

## Installation

```r
remotes::install_github("smorabit/llegir")
```

Start with the [Labeling modules with a coding agent](vignettes/agent-labels.Rmd) vignette, which walks through the full workflow on a real dataset. The [Getting Started](vignettes/getting-started.Rmd) vignette covers the evidence tools in more detail and the in-R synthesis route.
