# MM1 working notes

Network-wide gene assignment table (used for marker status): `queries/_network/01_gene_assignment.R`, run as
`Rscript queries/_network/01_gene_assignment.R > queries/_network/01_gene_assignment.out 2>&1`.

## Artifact screen
- module_size 252; dissociation_stress 0/25 top hubs, 0 in module; depth rho nCount 0.15, nFeature 0.20 (below 0.5).
- sample_concentration 55.5% of top-decile cells from P08: MEETS threshold. Not technical; caps confidence at moderate and adds label_low_specificity.
- Gate: pass. Hubs are cell-type-specific macrophage genes, no glycolysis/OXPHOS co-occurrence.

## Hubs weighed
Top 10: FCGBP, A2M, DOCK4, C1QB, C1QC, C1QA, TREM2, MSR1, EPB41L3, C5AR1. Top 25 adds SLCO2B1, SELENOP, F13A1, FOLR2, LYVE1, CH25H.
C1QA/B/C count as one line of evidence (one complex). LYVE1, FOLR2, F13A1, SELENOP point to border-associated / perivascular macrophages. FCGBP, A2M, DOCK4 are less specific.

## Queries
1. `queries/MM1/01_hub_list.R` (output `queries/MM1/01_hub_list.out`). Command:
   `Rscript queries/MM1/01_hub_list.R > queries/MM1/01_hub_list.out 2>&1`.
   Returned the top 40 hubs; kME median 0.33, max 0.83. Ranks 26-40 add GPR34, MAF, C3, APOC1, COLEC12.
2. `queries/MM1/02_marker_status.R` (output `queries/MM1/02_marker_status.out`). Command:
   `Rscript queries/MM1/02_marker_status.R > queries/MM1/02_marker_status.out 2>&1`.
   Returned status for BAM, complement and microglia markers (below).

## Expected markers
- in_module: C1QA, C1QB, C1QC, LYVE1, FOLR2, F13A1 (APOE rank 57).
- in_network: CD163 (MM10 rank 5), STAB1 (MM10), MS4A7 (MM10), CD14 (MM10 rank 1), SIGLEC1 (MM9).
- unassigned: MRC1.
- Microglia check: P2RY12, TMEM119 unassigned; CX3CR1 in MM13; SALL1 not_tested.
The BAM signature is split: the complement/LYVE1/FOLR2 arm is here, the CD163/STAB1/MS4A7 arm in MM10. Downgraded to moderate (also capped by sample concentration).

## Alternative
Microglia-like TAM: rejected, homeostatic microglia markers unassigned or elsewhere; score peaks in Border TAMs / pvBAMs, not Microglia TAM.

## Call
"C1Q complement-high border-associated macrophage program (LYVE1, FOLR2, F13A1)", moderate, 0.62. Display hubs C1QB, TREM2, MSR1.
