# MM2 working notes

Network-wide gene assignment table: `queries/_network/01_gene_assignment.R`, run as
`Rscript queries/_network/01_gene_assignment.R > queries/_network/01_gene_assignment.out 2>&1`.

## Artifact screen
- module_size 360; dissociation_stress 0/25, 0 in module; depth rho 0.32 / 0.32 (below 0.5); top sample P05 39.1% (below 50%).
- Housekeeping note: 25% ribosomal genes among top 20 hubs.
- Gate: uncertain. No threshold met and no glycolytic hubs (so no glycolysis+OXPHOS depth reading), but hubs are generic high-abundance transcripts.

## Hubs weighed
Top 10: RPL8, RPS15, PTMA, RPLP1, RPLP2, EIF1, HLA-C, RPS28, ARPC1B, HLA-B. Ranks 11-25: UQCR11, COX8A, SH3BGRL3, SLC25A6, H3F3A, CYBA, CHCHD2, OAZ1, APRT, COX5B, HLA-A, SELENOH, NDUFB11, ATP5F1B, RPL36.
Ribosomal paralogs = one line of evidence; HLA-A/B/C = one line; OXPHOS = one line.

## Queries
1. `queries/MM2/01_hub_list.R` (output `queries/MM2/01_hub_list.out`). Command:
   `Rscript queries/MM2/01_hub_list.R > queries/MM2/01_hub_list.out 2>&1`.
   Top 40 hubs; kME median 0.24, max 0.80; ranks 26-40 add more NDUF subunits, LY6E, GRN, ALDOA (rank 40, only glycolytic gene).
2. `queries/MM2/02_marker_status.R` (output `queries/MM2/02_marker_status.out`). Command:
   `Rscript queries/MM2/02_marker_status.R > queries/MM2/02_marker_status.out 2>&1`.
   Status for MHC I, translation, glycolysis, MHC II and proliferation markers.

## Expected markers
- in_module: HLA-A, HLA-E.
- in_network: B2M, TAP1 (MM4); RPL10 (MM8 rank 1), RPS3, RPS27A, EEF1A1, COX4I1 (MM8).
- unassigned: TPT1. not_tested: MKI67, TOP2A (so proliferation cannot be judged; not cited).
- Glycolysis GAPDH, PKM, TPI1 (MM10), ENO1, LDHA (MM7): in_network, against a depth axis.
- MHC II HLA-DRA, CD74 in MM13.
Obligate partners of both halves sit elsewhere, so downgraded to low.

## Alternative
Sequencing-depth axis: rejected, rho 0.32 and no glycolytic hubs.

## Call
"Ribosomal and MHC class I high-expresser housekeeping program (RPL8, HLA-C, HLA-B)", low, 0.38. Display hubs RPL8, HLA-C, EIF1 (one ribosomal, one MHC I, one translation factor).
