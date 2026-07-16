## spike-in ground-truth fixtures, CSF-specific (docs/milestone_1.md task 5).
## synthetic_ModuleSet() itself now lives in R/example_moduleset.R (exposed
## as the backend for llegir_example_moduleset() per
## docs/milestone_packaging.md task 4); only the CSF-specific gene lists
## below stay test-only.

# positive control: canonical pDC lineage markers, all present in the CSF
# object. Raw expression check (not just the synthetic score) confirms these
# separate cleanly: mean expression in the 'pDC' cluster is ~2.6, vs. ~0.5 in
# the next-highest cluster (DC ITGAX) — a clean, unambiguous ground truth.
# (an earlier draft used interferon-stimulated genes against the
# 'Macrphages IFN producing' cluster, but raw expression showed ISGs actually
# peak in Monocytes classical, not that cluster — the label reflects IFN
# *production*, not ISG *response*, so it was the wrong ground truth, not a
# tool bug. pDC markers avoid that ambiguity.)
pdc_genes <- c(
    'LILRA4', 'CLEC4C', 'GZMB', 'JCHAIN', 'MZB1', 'SPIB', 'IRF7', 'TCF4', 'IL3RA', 'PLD4'
)

# negative control: a random gene set of matched size, fixed seed for
# reproducibility. Drawn from the full feature space, not from any real module.
random_control_genes <- function(so, n = length(pdc_genes), seed = 1){
    set.seed(seed)
    sample(rownames(so), n)
}
