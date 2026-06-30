/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    TB_ML_PREDICT — Stage 3 of the TB-ML 3-stage container pattern
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Runs the predictor container on the pre-processed features and writes the
    per-drug resistance predictions. The TB-ML standard says predictors:
      - write the final report to STDOUT
      - may also write a CSV with predictions to disk

    We capture both: STDOUT to `<model>.stdout.txt`; the CSV is conventionally
    named `predictions.csv` (some predictors emit other names — adjust per
    model in tb_ml_models.config if needed).

    Reference: tb-ml.github.io/tb-ml-containers/  ;  Libiseller-Egger 2023.
*/

process TB_ML_PREDICT {
    tag "${meta.id}.${meta.model}"
    label 'process_medium'

    container "${meta.predictor_image}"

    input:
    // meta carries: id, sample, model, predictor_image, predict_args,
    //               [entrypoint]
    tuple val(meta), path(features)

    output:
    tuple val(meta), path('predictions.csv'),    emit: predictions, optional: true
    tuple val(meta), path('stdout.txt'),         emit: stdout
    path 'versions.yml',                          emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def entrypoint = meta.entrypoint ?: '/run.sh'
    """
    # Predict; capture STDOUT (TB-ML convention: final report on STDOUT).
    ${entrypoint} ${meta.predict_args} > stdout.txt

    # Some predictors write their own CSV; conform to predictions.csv if so.
    if [ -f features.csv.predictions ];   then mv features.csv.predictions predictions.csv; fi
    if [ -f resistance_predictions.csv ]; then mv resistance_predictions.csv predictions.csv; fi
    if [ -f predictions.csv ]; then :; fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tb_ml_predict_image: "${meta.predictor_image}"
        model: "${meta.model}"
    END_VERSIONS
    """

    stub:
    """
    touch predictions.csv stdout.txt
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tb_ml_predict_image: "${meta.predictor_image}"
        model: "${meta.model}"
    END_VERSIONS
    """
}
