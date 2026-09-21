## geneset_enrichment: offline GO/pathway enrichment over hub genes via
## GeneOverlap, against local GMT gene-set libraries (fgsea::gmtPathways()).
## No runtime network -- recycled from SERPENTINE's run_geneoverlap.R, adapted
## to a single module's hub genes vs. a background of all genes in the
## ModuleSet. Deterministic and CI-clean by construction.

# one db's pathways flattened against `hub_genes`; mirrors the go.nested.list
# loop from run_geneoverlap.R (outer = input_list, inner = pathways), here
# specialized to a single input set so only the inner loop is needed
.geneoverlap_flatten <- function(gmt_file, db_name, hub_genes, genome_size){
    pathways <- fgsea::gmtPathways(gmt_file)
    gom <- GeneOverlap::newGOM(pathways, list(module = hub_genes), genome.size = genome_size)

    do.call(rbind, lapply(seq_along(gom@go.nested.list[[1]]), function(j){
        cur <- gom@go.nested.list[[1]][[j]]
        data.frame(
            term = names(pathways)[j],
            overlap = paste0(length(cur@intersection), '|', length(cur@listA)),
            genes = paste(cur@intersection, collapse = ','),
            pval = cur@pval,
            odds_ratio = cur@odds.ratio,
            jaccard = cur@Jaccard,
            ngenes = length(cur@intersection),
            db = db_name
        )
    }))
}

# shared by geneset_enrichment_tool() and the imported geneset_enrichment
# normalizer. The summary always says whether ANY term passes `alpha`: a term
# list ranked by FDR/odds ratio reads as "enrichment" to the model even when
# every FDR is 1, so the non-significant case is named explicitly and the
# per-term overlap size (and Jaccard / odds ratio when known) is spelled out
# so a 2-gene overlap can't pass for a program-level signal
.enrichment_compact_summary <- function(terms, fdr, n_overlap = NULL, jaccard = NULL,
                                        odds_ratio = NULL, n_tested = length(terms),
                                        alpha = 0.05, prefix = '', n_show = 5){
    if (length(terms) == 0) return(paste0(prefix, 'no gene-set overlap found'))

    # Jaccard rides along in top_findings rather than the prose: the overlap
    # count and odds ratio already carry the magnitude, and this block is
    # rendered into an 8k-token prompt twice per packet
    describe_term <- function(i){
        term_stats <- c(
            if (!is.null(n_overlap) && !is.na(n_overlap[i])) paste0(n_overlap[i], ' genes overlap'),
            if (!is.null(odds_ratio) && !is.na(odds_ratio[i])) paste0('OR ', format(odds_ratio[i], digits = 3)),
            paste0('FDR ', format(fdr[i], digits = 2))
        )
        paste0(terms[i], ' (', paste(term_stats, collapse = ', '), ')')
    }

    sig_idx <- which(!is.na(fdr) & fdr < alpha)
    # nothing passed alpha: the terms are context, not findings, so fewer are listed
    if (length(sig_idx) == 0) n_show <- min(n_show, 3)
    if (length(sig_idx) > 0) {
        shown <- utils::head(sig_idx, n_show)
        return(paste0(
            prefix, length(sig_idx), ' of ', n_tested, ' tested terms reach FDR < ', alpha, ': ',
            paste(vapply(shown, describe_term, character(1)), collapse = '; ')
        ))
    }

    shown <- utils::head(seq_along(terms), n_show)
    paste0(
        prefix, 'no term reaches FDR < ', alpha, ' (best FDR ', format(min(fdr, na.rm = TRUE), digits = 2),
        ' across ', n_tested, ' tested terms), so these overlaps are NOT significant enrichment and are ',
        'descriptive only: ', paste(vapply(shown, describe_term, character(1)), collapse = '; ')
    )
}

# enrichment is only directional when something actually passes alpha; a
# non-significant overlap table reports 'na' so it can't back an 'up' claim
.enrichment_direction <- function(fdr, alpha = 0.05){
    if (any(!is.na(fdr) & fdr < alpha)) 'up' else 'na'
}

#' Evidence tool: gene-set enrichment among a module's hub genes
#'
#' Offline GO/pathway enrichment ([GeneOverlap::newGOM()]) over hub genes
#' against local GMT gene-set libraries ([fgsea::gmtPathways()]) -- no
#' runtime network access, so the tool is deterministic and CI-clean by
#' construction. Touches the `ModuleSet` adapter contract
#' ([gene_membership()], [expression()], [pkg_versions()]) plus
#' `ctx$params$db_files`, a named vector of local GMT file paths.
#'
#' @param ctx A tool context list: `list(ms, module_id, params)`, as built by
#'   [run_module()]. `ctx$params$n_hubs` (default 25) is the number of hub
#'   genes tested. `ctx$params$alpha` (default 0.05) is the FDR threshold
#'   below which a term counts as significant: the fragment's
#'   `compact_summary` states whether any term passes it, and `direction` is
#'   `'up'` only when one does (`'na'` otherwise). Each `top_findings` entry
#'   carries the term's FDR, odds ratio, overlap size (`n_overlap`) and
#'   Jaccard index. `ctx$params$db_files` (required for a non-empty result) is
#'   a named character vector of local GMT file paths, e.g.
#'   `c(GO_BP = 'path/to/GO_Biological_Process.txt')`.
#' @return An `evidence_fragment` of type `'geneset_enrichment'`, or `NULL` if
#'   `ctx$ms` lacks the `expression` capability (see [capabilities()]) -- a
#'   graceful skip, not an error.
#' @examples
#' \dontrun{
#' ms <- llegir_example_moduleset()
#' geneset_enrichment_tool(list(
#'     ms = ms, module_id = modules(ms)[1],
#'     params = list(n_hubs = 10, db_files = c(GO_BP = 'path/to/gene_sets.gmt'))
#' ))
#' }
#' @export
geneset_enrichment_tool <- function(ctx){
    n_hubs <- ctx$params$n_hubs %||% 25
    alpha <- ctx$params$alpha %||% 0.05
    db_files <- ctx$params$db_files %||% c(GO_BP = 'data/GO_Biological_Process_2026.txt')

    if (!has_capability(ctx$ms, 'expression')) {
        message('geneset_enrichment: skipped, module set lacks the expression capability')
        return(NULL)
    }

    gm <- gene_membership(ctx$ms, ctx$module_id)
    hub_genes <- utils::head(gm$gene_name, n_hubs)
    genome_size <- nrow(expression(ctx$ms))

    provenance <- make_provenance(
        tool_version = '0.2',
        params = list(n_hubs = n_hubs, alpha = alpha, db_files = unname(db_files), network_required = FALSE),
        pkg_versions = pkg_versions(ctx$ms),
        module_method = ctx$module_method %||% NA_character_
    )

    overlap_df <- do.call(rbind, lapply(names(db_files), function(db_name){
        .geneoverlap_flatten(db_files[[db_name]], db_name, hub_genes, genome_size)
    }))
    overlap_df <- subset(overlap_df, ngenes > 0)

    if (nrow(overlap_df) == 0) {
        return(evidence_fragment(
            fragment_id = 'geneset_enrichment',
            tool_id = 'geneset_enrichment',
            module_id = ctx$module_id,
            type = 'geneset_enrichment',
            result = data.frame(),
            compact_summary = 'no gene-set overlap found among hub genes',
            top_findings = list(),
            effect_strength = 0,
            direction = 'na',
            provenance = provenance
        ))
    }

    overlap_df$fdr <- stats::p.adjust(overlap_df$pval, method = 'fdr')
    overlap_df <- overlap_df[order(overlap_df$fdr, -overlap_df$odds_ratio), ]
    rownames(overlap_df) <- NULL
    top <- utils::head(overlap_df, 20)

    # 3 rather than 5: each entry now carries two extra overlap statistics, and
    # compact_summary already names the same terms
    top_findings <- lapply(seq_len(min(3, nrow(top))), function(i){
        list(
            term = top$term[i], fdr = top$fdr[i], odds_ratio = top$odds_ratio[i],
            n_overlap = top$ngenes[i], jaccard = top$jaccard[i]
        )
    })

    compact_summary <- .enrichment_compact_summary(
        top$term, top$fdr, n_overlap = top$ngenes, jaccard = top$jaccard,
        odds_ratio = top$odds_ratio, n_tested = nrow(overlap_df), alpha = alpha,
        prefix = paste0('gene-set overlap of ', length(hub_genes), ' hub genes: ')
    )

    # floor to avoid -log10(0) = Inf, which jsonlite can't round-trip
    min_fdr <- max(min(top$fdr), 1e-300)

    evidence_fragment(
        fragment_id = 'geneset_enrichment',
        tool_id = 'geneset_enrichment',
        module_id = ctx$module_id,
        type = 'geneset_enrichment',
        result = top,
        compact_summary = compact_summary,
        top_findings = top_findings,
        effect_strength = -log10(min_fdr),
        significance = min(top$fdr),
        direction = .enrichment_direction(top$fdr, alpha),
        provenance = provenance
    )
}
