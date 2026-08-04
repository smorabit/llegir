# Using a local open-source LLM

In this tutorial, we cover the basics of running **llegir** using a
local LLM on your own hardware. Unlike the chat-based LLM interfaces
that many are accustomed to nowadays, API calls to LLMs are typically
billed per-token and therefore they can be prohibitively expensive for
researchers. This motivates us to move away from the enterprise
ecosystems like OpenAI or Antrhropic, towards runing open-source LLMs on
our own hardware.

## Launching a local model

### Choosing a model

Pick an **instruct-tuned** model from a family with strong
structured-output behavior. The **Qwen instruct** series
(e.g. `Qwen/Qwen2.5-7B-Instruct`) is a reliable starting point: it fits
comfortably on most modern data-center GPUs and handles
schema-constrained output well. Avoid “reasoning” models, since they
emit chain-of-thought text which conflict with JSON-based structured
outputs required by **llegir**.

### Installation

In this example, the commands below run on a **GPU node** of a HPC
cluster. First, we install a new conda environment with *vLLM* which
will help us to actually launch the local model.

The following installation step only needs to be run once:

``` bash
# create the conda environment and install vllm with pip
conda create -n vllm python=3.11 -y
conda activate vllm
pip install vllm "huggingface_hub[cli]"

# select the model to download, here we use Qwen-Instruct
hf download Qwen/Qwen2.5-7B-Instruct

# define the huggingface cache directory
export HF_HOME=/path/to/scratch/hf_cache   
```

### Launching the model

In the next block, we launch the model using *vLLM*. This should run
as-is if you are on a workstation with a GPU. If you are working on a
cluster, you first need to request a GPU node (we cannot provide
specific instructions on how to do this, as it highly depends on the
configuration of your particular cluster).

``` bash
export HF_HOME=/path/to/scratch/hf_cache
export HF_HUB_OFFLINE=1          # if compute nodes have no outbound internet
export VLLM_API_KEY=EMPTY

# launch the model
vllm serve Qwen/Qwen2.5-7B-Instruct \
    --served-model-name qwen \
    --host 127.0.0.1 \
    --port 8000 \
    --max-model-len 8192 \
    --gpu-memory-utilization 0.90
```

`--served-model-name qwen` is the short alias clients use — this is the
`model` value you pass to **llegir**. Wait for
`Application startup complete` before running R.

## Connecting llegir to the local model

To connect **llegir** with the local model, set the URL of the LLM
server, and then call the
[`local_backend()`](https://smorabit.github.io/llegir/reference/local_backend.md)
function within R. On the **llegir** side, this is essentially the only
difference between using a local model vs. API calls with a remote
model.

``` r

# optional: point llegir at a non-default URL (defaults to http://127.0.0.1:8000/v1)
Sys.setenv(LLEGIR_LLM_URL = 'http://127.0.0.1:8000/v1')
```

We can check that **llegir** detects the LLM server using the
[`llm_server_status()`](https://smorabit.github.io/llegir/reference/llm_server_status.md)
funciton, which confirms connectivity and returns the list of served
models:

``` r

library(llegir)

status <- llm_server_status()
# $base_url: "http://127.0.0.1:8000/v1"
# $models:   "qwen"
```

[`local_backend()`](https://smorabit.github.io/llegir/reference/local_backend.md)
combines the connectivity check, model auto-discovery, and
[`cached_backend()`](https://smorabit.github.io/llegir/reference/cached_backend.md)
into a single call:

``` r

backend <- local_backend()
```

If more than one model is served, pass the alias explicitly:

``` r

backend <- local_backend(model = 'qwen')
```

From here, running the rest of the pipeline is the same as before.

``` r

interps <- run_synthesis_orchestrator(
    packets, desc, backend = backend,
    output_dir = 'output/interpretations',
    dataset_context = dataset_ctx
)

interp <- interps[['MM1']]
interp$proposed_label
interp$confidence$score
cat(render_paragraph(interp))
```

## End-to-end example

Here we provide a simple end-to-end example of the R code necesarry to
run **llegir** with a local model.

``` r

library(Seurat)
library(hdWGCNA)
library(tidyverse)
library(llegir)

# point llegir at the local vLLM server
Sys.setenv(LLEGIR_LLM_URL = 'http://127.0.0.1:8000/v1')

# load the CSF dataset, which has already been processed with hdWGCNA
seurat_obj <- readRDS('data/CSF_Myeloid_hdWGCNA.rds')

# initialize the ModuleSet
ms <- hdWGCNA_ModuleSet(seurat_obj)

# describe the dataset for the synthesis prompt
desc <- dataset_description(
    species = 'human',
    tissue = 'cerebrospinal fluid (CSF)',
    cell_compartment = 'myeloid cells',
    assay = 'single-cell RNA-seq (10x)',
    conditions = c(
        'Glioblastoma', 'Brain Metastasis', 'Primary CNS lymphoma',
        'Secondary CNS lymphoma', 'Inflammatory / other neuroinflammatory'
    ),
    notes = 'Modules are CSF-myeloid co-expression programs; interpret in a CNS-myeloid, neuro-oncology / neuroinflammation context.'
)

# gather global dataset context once
dataset_tool_config <- list(
    list(fn = dataset_composition_tool, params = list(group_col = 'lv2_annot', condition_col = 'diagnosis')),
    list(fn = dataset_variance_structure_tool, params = list(
        covariates = c('diagnosis', 'nUMI'), condition_col = 'diagnosis'
    ))
)
dataset_ctx <- run_dataset_context(ms, dataset_tool_config)

# run the evidence toolbox over three modules
modules_use <- c('MM1', 'MM2', 'MM3')

tool_config <- list(
    list(fn = top_genes_tool, params = list(n_hubs = 25)),
    list(fn = cluster_dme_tool, params = list(group_by = 'lv2_annot')),
    list(fn = geneset_enrichment_tool, params = list(
        n_hubs = 25,
        db_files = c(
            GO_BP = 'data/GO_Biological_Process_2026.txt',
            Hallmark = 'data/h.all.v2026.1.Hs.symbols.gmt'
        )
    ))
)

packets <- run_orchestrator(ms, tool_config, output_dir = 'output/evidence_packets', modules_use = modules_use)

# connect to the local model and run synthesis
backend <- local_backend()

interps <- run_synthesis_orchestrator(
    packets, desc, backend = backend,
    output_dir = 'output/interpretations',
    dataset_context = dataset_ctx
)

# inspect one interpretation
interp <- interps[['MM1']]
interp$proposed_label
interp$confidence$score
cat(render_paragraph(interp))
```
