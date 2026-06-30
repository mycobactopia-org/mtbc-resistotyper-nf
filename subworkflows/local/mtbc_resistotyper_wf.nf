/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    MTBC_RESISTOTYPER — building-block subworkflow (Phase-1 scaffold)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Runs one or more MTBC resistance-prediction backends over per-sample
    variant calls and emits a canonical drug-resistance table.

    Phase-1: single backend (TB-Profiler), first upstream integration is XBS.
    Phase-2: Mykrobe / SAM-TB / GenTB + consensus voting.
    Phase-3: `mtb-resistotyper-ml` slot.

    See docs/CONTRACT.md for the stable interface contract that consumer
    pipelines (tbanalyzer, MAGMA-v2) bind to.

    Phase-1 backends not yet wired — this file documents the interface
    surface that follow-up commits will populate.
*/

// Backend modules will be wired in follow-up commits.
// Phase-1 first: tbprofiler/profile + tbprofiler/collate (or equivalent).

workflow MTBC_RESISTOTYPER {

    take:
    ch_variants     // channel: [ meta(sample, ...), vcf, tbi ]
                    //          per-sample VCFs from upstream caller (XBS for Phase 1)
    ch_reference    // value:   [ meta(id:'ref'), fasta, fai ]
                    //          reference FASTA + index; resistance catalogues
                    //          are coordinate-dependent on this reference
                    //          (typically NC_000962.3 H37Rv)

    main:

    // TODO (Phase 1.1): wire TB-Profiler backend module
    //   - install nf-core module: tbprofiler/profile
    //   - run per sample: TBPROFILER_PROFILE(ch_variants, ch_reference)
    //   - parse JSON output → canonical DR table TSV
    //   - emit dr_table + dr_json

    // TODO (Phase 2): add Mykrobe / SAM-TB / GenTB backends + consensus voting
    //   driven by params.backends list (mirrors mtbc-varcaller-nf §B contract)

    // Placeholder empty channels so the interface compiles + can be imported
    // by consumers that want to wire integration tests against the contract
    // before any backend is live.
    def ch_dr_table       = channel.empty()
    def ch_dr_json        = channel.empty()
    def ch_cohort_summary = channel.empty()

    emit:
    // ============= STABLE INTERFACE CONTRACT (see docs/CONTRACT.md) =============
    dr_table       = ch_dr_table       // [ meta, *.dr_table.tsv ]   canonical per-sample DR table
    dr_json        = ch_dr_json        // [ meta, *.dr.json ]        backend-native raw output
    cohort_summary = ch_cohort_summary // [ cohort_meta, *.tsv ]     Phase-2; empty in Phase-1
}
