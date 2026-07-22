# llegir

**llegir** is a package for LLM-enabled gene-program interpretations in R. In transcriptomics data analysis, we often work with groups of genes that are somehow related to one another, and **llegir** aims to automate the interpretation of these interrelated groups of genes, which we refer to as "*gene modules*". **llegir** is completely agnostic to the sequencing technology (e.g. bulk RNA-seq, single-cell RNA-seq, sequencing or imaging based spatial transcriptomics, etc), and it is agnostic to the method used to group genes into modules (e.g. WGCNA, matrix factorization, literature-derived gene lists, etc).

**llegir** takes as input a gene expression matrix and a set of *gene modules*, for instance coming from our other tool ![hdWGCNA](https://smorabit.github.io/hdWGCNA/). Next, **llegir** compiles a set of "evidence" for each module by running a user-defined chain of analysis tools, flexibly defined to suit the specific needs of each dataset. The results of these analysis tools are then assembled into an "evidence packet" that is given to an LLM of the user's choice for synthesis, summarization, and interpretation. Finally, **llegir** compiles an .html report for the interpretation of all modules.   

**llegir** means "to read" in the Catalan language.

## Development stage

**llegir** is in an experimental development stage, and at this point it is subject to major changes until we have pushed a more stable release, proceed with caution! 

## Installation

```r
remotes::install_github("smorabit/llegir")
```

See the [Getting Started](vignettes/getting-started.Rmd) vignette for a full quick start walkthrough.