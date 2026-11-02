# MM3 working notes

Network-wide gene assignment table: `queries/_network/01_gene_assignment.R`, run as
`Rscript queries/_network/01_gene_assignment.R > queries/_network/01_gene_assignment.out 2>&1`.

## Artifact screen
- module_size 934; dissociation_stress 0/25 top hubs, 4 in module bulk (JUNB, IER2, FOS, FOSB).
- depth rho nCount 0.35, nFeature 0.49: just under the 0.5 threshold.
- top sample P06 19.7% (below).
- Gate: uncertain. Near-threshold depth correlation, a large weakly connected module, generic high-expresser hubs (ACTB rank 1).

## Hubs weighed
Top 10: ACTB, PFN1, VIM, RPL13, CST3, ARPC2, S100A10, NME2, PYCARD, ATP6V0C. Ranks 11-25: RPS2, COX5A, SERP1, CALR, PGLS, EIF3F, PRELID1, PPDPF, MIF, FKBP1A, CALM1, DDT, AP1S2, NDUFAB1, PDIA3.
Mixed: cytoskeleton, ribosome, OXPHOS, ER chaperones, lysosomal V-ATPase. No single program.

## Queries
1. `queries/MM3/01_hub_list.R` (output `queries/MM3/01_hub_list.out`). Command:
   `Rscript queries/MM3/01_hub_list.R > queries/MM3/01_hub_list.out 2>&1`.
   Top 40 hubs; kME median 0.14, max 0.54: very low connectivity.
2. `queries/MM3/02_marker_status.R` (output `queries/MM3/02_marker_status.out`). Command:
   `Rscript queries/MM3/02_marker_status.R > queries/MM3/02_marker_status.out 2>&1`.
   Status for actin-machinery, ER-chaperone and classical-monocyte markers.

## Expected markers (for the actin-cytoskeleton reading the hubs suggest)
- in_network: CFL1, ARPC3, MYL6 (MM6 ranks 1-3), ARPC1B (MM2), TMSB4X (MM9), CAPZB (MM6).
- unassigned: ACTG1.
- ER chaperones: HSPA5 unassigned, HSP90B1 and CANX in MM4.
- Classical monocyte: S100A8, S100A9, LYZ, FCN1 lead MM9; CD14 leads MM10.
No canonical partner of any candidate program is in MM3.

## Alternative
Actin cytoskeleton / motility program: rejected, core partners lead MM6.

## Call
"Low-coherence generic high-expresser residual (PFN1, VIM, ARPC2)", very_low, 0.15, tier insufficient. Display hubs PFN1, VIM, ARPC2 (ACTB avoided as housekeeping normalizer).
