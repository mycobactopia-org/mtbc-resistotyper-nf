/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    TB_ML_PROBE — Stage 1 of the TB-ML 3-stage container pattern
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Invokes the predictor container in metadata mode (e.g. `--get-target-loci`)
    to obtain the loci it expects the upstream pre-processor to extract.

    Per the TB-ML standard: predictors should expose a metadata invocation that
    emits a CSV of target loci, so any conformant pre-processor can produce the
    right features without baking-in model assumptions.

    Reference: tb-ml.github.io/tb-ml-containers/  ;  Libiseller-Egger 2023.
*/

process TB_ML_PROBE {
    tag "${meta.model}"
    label 'process_single'

    // Dynamic container per model — from conf/tb_ml_models.config.
    // Nextflow runs `bash -c "<script>"` inside the container; we invoke the
    // container's own entrypoint (default /run.sh, override via meta.entrypoint).
    container "${meta.predictor_image}"

    input:
    // meta carries: model, predictor_image, probe_args, [entrypoint]
    tuple val(meta), val(probe_args)

    output:
    tuple val(meta), path('loci.csv'),           emit: loci
    path 'versions.yml',                          emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def entrypoint = meta.entrypoint ?: '/run.sh'
    """
    ${entrypoint} ${probe_args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tb_ml_probe_image: "${meta.predictor_image}"
        model: "${meta.model}"
    END_VERSIONS
    """

    stub:
    """
    touch loci.csv
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tb_ml_probe_image: "${meta.predictor_image}"
        model: "${meta.model}"
    END_VERSIONS
    """
}
