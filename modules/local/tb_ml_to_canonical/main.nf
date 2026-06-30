/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    TB_ML_TO_CANONICAL — Stage 4: adapter from TB-ML output to canonical TSV
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Parses the predictor container's STDOUT (and optionally its predictions CSV)
    and emits the PHA4GE-aligned canonical long-format table — one row per
    (sample, drug, backend) — that consumers bind to.

    Adapter logic per model lives in bin/tb_ml_to_canonical.py; the model is
    identified via meta.adapter_id (which tells the script which TB-ML output
    convention to parse).

    See docs/BACKEND_WIRING_PLAN.md §2 for the full schema.
*/

process TB_ML_TO_CANONICAL {
    tag "${meta.id}.${meta.model}"
    label 'process_single'

    // Use a python+pandas container — small and stable.
    conda     "bioconda::pandas=2.2.3"
    container "biocontainers/pandas:2.2.3"

    input:
    tuple val(meta), path(stdout), path(predictions)

    output:
    tuple val(meta), path("${meta.id}.${meta.model}.dr.tsv"),       emit: canonical
    path 'versions.yml',                                             emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    tb_ml_to_canonical.py \\
        --adapter-id            "${meta.adapter_id}" \\
        --sample-id             "${meta.sample ?: meta.id}" \\
        --study-id              "${meta.study ?: 'na'}" \\
        --backend               "tb_ml:${meta.model}" \\
        --backend-version       "${meta.catalogue_version}" \\
        --catalogue-name        "${meta.catalogue_name}" \\
        --catalogue-version     "${meta.catalogue_version}" \\
        --predictor-image       "${meta.predictor_image}" \\
        --stdout                "${stdout}" \\
        ${ predictions.name != 'NO_FILE' ? "--predictions ${predictions}" : "" } \\
        --output                "${meta.id}.${meta.model}.dr.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "\$(python --version 2>&1 | sed 's/^Python //')"
        adapter: "tb_ml_to_canonical.py v0.1.0"
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}.${meta.model}.dr.tsv"
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "stub"
    END_VERSIONS
    """
}
