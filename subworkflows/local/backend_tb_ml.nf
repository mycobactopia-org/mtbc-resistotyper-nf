/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    BACKEND_TB_ML — TB-ML 3-stage container pattern (Libiseller-Egger 2023)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Implements the canonical TB-ML container chain as a Nextflow subworkflow:

      1. TB_ML_PROBE       — predictor container in `--get-target-loci` mode
                             emits target loci CSV (model-specific)
      2. TB_ML_PREPROCESS  — pre-processor container converts BAM + loci.csv
                             into feature CSV the predictor consumes
      3. TB_ML_PREDICT     — predictor container reads features.csv and writes
                             per-drug resistance calls (STDOUT + CSV)
      4. TB_ML_TO_CANONICAL — Python adapter maps the predictor's output to
                             the PHA4GE-aligned canonical schema documented in
                             docs/CONTRACT.md + docs/BACKEND_WIRING_PLAN.md

    One backend instance per enabled model. params.tb_ml_models_enabled drives
    which models run; the registry in conf/tb_ml_models.config defines them.

    Gated on params.backends containing 'tb_ml'.
*/

include { TB_ML_PROBE        } from '../../modules/local/tb_ml_probe/main'
include { TB_ML_PREPROCESS   } from '../../modules/local/tb_ml_preprocess/main'
include { TB_ML_PREDICT      } from '../../modules/local/tb_ml_predict/main'
include { TB_ML_TO_CANONICAL } from '../../modules/local/tb_ml_to_canonical/main'


workflow BACKEND_TB_ML {

    take:
    ch_bams         // channel: [ meta(sample, ...), bam, bai ]
                    //          per-sample BAMs (e.g. XBS's sample_bam emit)
    ch_reference    // value:   [ meta(id:'ref'), fasta, fai ]

    main:

    // ---- which models to actually run ----
    def enabled = (params.tb_ml_models_enabled ?: 'tb_amr_cnn').tokenize(',').collect { name -> name.trim() }
    def registry = params.tb_ml_models ?: [:]

    // Filter to known + valid models; warn (silently skip) on misspellings.
    def models = enabled.findAll { name -> registry.containsKey(name) && registry[name].input_format != 'reads' }
    if (models.isEmpty()) {
        error("BACKEND_TB_ML: no enabled models found in registry. " +
              "Check params.tb_ml_models_enabled and conf/tb_ml_models.config. " +
              "Note: 'reads'-input models (e.g. mykrobe_tb_ml) are wired in a separate code path.")
    }

    // ---- build per-(sample, model) channel ----
    // Cross every sample with every enabled model so each combination runs as
    // its own (probe, preprocess, predict) chain. The model identity is stamped
    // into meta so downstream stages know which container to use + adapter to run.
    def ch_per_sample_per_model = ch_bams.combine(channel.fromList(models))
        .map { sample_meta, bam, bai, model_name ->
            def model = registry[model_name]
            def model_meta = sample_meta + [
                model              : model_name,
                predictor_image    : model.predictor_image,
                preprocessor_image : model.preprocessor_image,
                probe_args         : model.probe_args,
                preprocess_args    : model.preprocess_args,
                predict_args       : model.predict_args,
                adapter_id         : model.adapter_id,
                catalogue_name     : model.catalogue_name,
                catalogue_version  : model.catalogue_version,
                analysis_software_name    : "tb_ml:${model_name}",
                analysis_software_version : model.catalogue_version,
                reference_database_name   : model.catalogue_name,
                reference_database_version: model.catalogue_version,
            ]
            [ model_meta, bam, bai ]
        }

    // ---- Stage 1: probe target loci (per model — runs once per sample/model pair) ----
    def ch_probe_in = ch_per_sample_per_model.map { meta, _bam, _bai ->
        [ meta, meta.probe_args ]
    }
    TB_ML_PROBE(ch_probe_in)

    // ---- Stage 2: preprocess BAM + loci → features ----
    // Join the probe output with the original sample BAM+BAI on the (sample, model) key.
    def ch_preprocess_in = ch_per_sample_per_model
        .map { meta, bam, bai -> [meta.id + ':' + meta.model, meta, bam, bai] }
        .join(
            TB_ML_PROBE.out.loci.map { meta, loci -> [meta.id + ':' + meta.model, loci] }
        )
        .map { _key, meta, bam, bai, loci -> [meta, bam, bai, loci] }

    TB_ML_PREPROCESS(ch_preprocess_in)

    // ---- Stage 3: predict ----
    TB_ML_PREDICT(TB_ML_PREPROCESS.out.features)

    // ---- Stage 4: canonical TSV adapter ----
    // Adapter receives the predictor's CSV/STDOUT + the full meta map (with
    // backend identity + catalogue info) and emits the PHA4GE-aligned long-format
    // table consumers bind to.
    def ch_adapter_in = TB_ML_PREDICT.out.stdout
        .join(TB_ML_PREDICT.out.predictions, remainder: true)
        .map { meta, stdout, predictions ->
            [ meta, stdout, predictions ?: file("${projectDir}/assets/NO_FILE") ]
        }
    TB_ML_TO_CANONICAL(ch_adapter_in)

    emit:
    // Stable per-backend interface (see docs/CONTRACT.md and docs/BACKEND_WIRING_PLAN.md).
    dr_records = TB_ML_TO_CANONICAL.out.canonical   // [ meta+stamp, *.dr.tsv ]   canonical long-format per (sample, drug, backend)
    dr_native  = TB_ML_PREDICT.out.stdout           // [ meta+stamp, stdout.txt ] backend-native preserved
    versions   = channel.empty()                     // versions via topic
}
