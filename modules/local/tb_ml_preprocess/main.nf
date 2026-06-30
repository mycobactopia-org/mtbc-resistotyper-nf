/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    TB_ML_PREPROCESS — Stage 2 of the TB-ML 3-stage container pattern
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Pre-processes raw input (BAM in the default path) into the feature format
    the predictor expects, using the loci.csv emitted by TB_ML_PROBE.

    Per TB-ML standard: pre-processors consume CSV and BAM/FASTQ; they output
    CSV. The output filename is fixed at "features.csv" by convention.

    Reference: tb-ml.github.io/tb-ml-containers/  ;  Libiseller-Egger 2023.
*/

process TB_ML_PREPROCESS {
    tag "${meta.id}.${meta.model}"
    label 'process_medium'

    container "${meta.preprocessor_image}"

    input:
    // meta carries: id, sample, model, preprocessor_image, preprocess_args,
    //               [entrypoint]
    tuple val(meta), path(input), path(input_index), path(loci_csv)

    output:
    tuple val(meta), path('features.csv'),       emit: features
    path 'versions.yml',                          emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def entrypoint = meta.entrypoint ?: '/run.sh'
    """
    # Pre-processor expects: -r loci.csv -o features.csv <input>
    # The input file name (BAM/FASTQ) is positional; pre-processors discover the
    # input type from the extension.
    ${entrypoint} ${meta.preprocess_args} ${input}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tb_ml_preprocess_image: "${meta.preprocessor_image}"
        model: "${meta.model}"
    END_VERSIONS
    """

    stub:
    """
    touch features.csv
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tb_ml_preprocess_image: "${meta.preprocessor_image}"
        model: "${meta.model}"
    END_VERSIONS
    """
}
