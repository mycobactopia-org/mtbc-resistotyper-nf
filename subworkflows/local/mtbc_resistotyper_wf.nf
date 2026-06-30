/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    MTBC_RESISTOTYPER — building-block subworkflow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Runs one or more MTBC resistance-prediction backends and emits canonical
    PHA4GE-aligned DR tables.

    Phase-1 backends wired:
      - tb_ml     →  TB-ML 3-stage container chain (Libiseller-Egger 2023)
                     Configurable model registry in conf/tb_ml_models.config.
                     params.tb_ml_models_enabled selects which models run.

    Pending follow-ups:
      - tbprofiler (Phase 1.1) — see docs/BACKEND_WIRING_PLAN.md §3.1
      - mykrobe    (Phase 1.2) — reads-input path; not the TB-ML BAM-input chain
      - SAM-TB / GenTB (Phase 2)
      - mtb-resistotyper-ml (Phase 3 — TB-ML-compliant container slot)

    See docs/CONTRACT.md for the stable interface contract.
*/

include { BACKEND_TB_ML } from './backend_tb_ml'


workflow MTBC_RESISTOTYPER {

    take:
    ch_bams         // channel: [ meta(sample, ...), bam, bai ]
                    //          per-sample BAMs from upstream (e.g. XBS's
                    //          sample_bam emit, or a chained mtbc-varcaller-nf
                    //          run, or a samplesheet of pre-aligned BAMs)
    ch_reference    // value:   [ meta(id:'ref'), fasta, fai ]
                    //          reference FASTA + index; resistance catalogues
                    //          are coordinate-dependent on this reference
                    //          (typically NC_000962.3 H37Rv)

    main:

    // Selected backends — comma-separated list (matches mtbc-varcaller-nf §E pattern).
    def selected_backends = (params.backends ?: 'tb_ml').tokenize(',').collect { name -> name.trim() }

    def ch_dr_records = channel.empty()
    def ch_dr_native  = channel.empty()

    if ('tb_ml' in selected_backends) {
        BACKEND_TB_ML(ch_bams, ch_reference)
        ch_dr_records = ch_dr_records.mix(BACKEND_TB_ML.out.dr_records)
        ch_dr_native  = ch_dr_native.mix(BACKEND_TB_ML.out.dr_native)
    }

    // TODO (Phase 1.1): BACKEND_TBPROFILER
    // TODO (Phase 1.2): BACKEND_MYKROBE (reads-input flavour)
    // TODO (Phase 2):   BACKEND_SAMTB, BACKEND_GENTB
    //
    // Each follows the same pattern: emits canonical TSV records on the
    // dr_records channel; mtbc_resistotyper_wf mixes them all into a single
    // per-(sample, drug, backend) stream that the consensus stage will
    // aggregate (Phase 1.3 — see BACKEND_WIRING_PLAN §4).

    // Concatenate all backends' canonical records into the cohort-level
    // dr_table_per_call.tsv. Consensus + per-sample summary land in Phase 1.3.
    def ch_dr_table_per_call = ch_dr_records
        .map { _meta, tsv -> tsv }
        .collectFile(
            name:       'dr_table_per_call.tsv',
            storeDir:   "${params.outdir}/resistotyper",
            keepHeader: true,
            skip:       1,
        )

    emit:
    // ============= STABLE INTERFACE CONTRACT (see docs/CONTRACT.md) =============
    dr_records        = ch_dr_records          // [ meta+backend_stamp, *.dr.tsv ]   per-call long-format
    dr_native         = ch_dr_native           // [ meta+backend_stamp, *.raw    ]   backend-native preserved
    dr_table_per_call = ch_dr_table_per_call   // cohort-level concatenated per-call TSV
    versions          = channel.empty()
}
