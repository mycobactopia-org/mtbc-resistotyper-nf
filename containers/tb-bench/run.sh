#!/usr/bin/env bash
#
# TB-Bench TB-ML-conformance wrapper entrypoint.
#
# Implements the 3-stage CLI contract from Libiseller-Egger et al. 2023:
#
#   Probe mode    (Stage 1):  /run.sh --get-target-loci -o loci.csv
#                              Emits the variant-call loci the predictor's
#                              feature matrix expects.
#
#   Predict mode  (Stage 3):  /run.sh --model <ModelName> features.csv
#                              Reads features.csv (X.csv per TB-Bench
#                              convention), runs `python main.py -m <ModelName>
#                              -r test`, emits predictions.csv (per-drug R/S)
#                              and writes the final report to STDOUT.
#
# Pre-processor mode (Stage 2) is NOT in this container — it lives in a
# separate companion image (tb_bench_preprocessor:*) that handles BAM →
# X.csv feature engineering. See registry tb_ml_models.config.

set -euo pipefail

cd "${TB_BENCH_HOME:-/opt/tb-bench}"

usage() {
    cat <<'EOF'
TB-Bench TB-ML wrapper. Two modes:

  --get-target-loci -o loci.csv
        Emit the loci file the predictor's features expect.

  --model <ModelName> [--features features.csv] [-o predictions.csv]
        Run the named TB-Bench model on the given feature matrix.
        STDOUT carries the per-drug summary; predictions.csv carries
        the structured per-(sample, drug) records.

Available models (any module under TB-Bench's ./models/):
  DeepAMR, WDNN, MTB_SD_CNN, ANN_Ankita, XGBoost_Ankita,
  BernoulliNB_Yang2018, LogisticRegressionL1_Yang2018,
  LogisticRegressionL2_Yang2018, RandomForest_Yang2018,
  SVCLinear_Yang2018, SVCRBF_Yang2018,
  LR_MLiAMR, RF_MLiAMR, SVC_MLiAMR, CNN_1D_MLiAMR, CNN_2D_MLiAMR,
  DecisionTree, Treeresist, Deep
EOF
}

if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    usage
    exit 0
fi

# ------------------------------------------------------------
# Probe mode — emit loci.csv
# ------------------------------------------------------------
if [[ "$1" == "--get-target-loci" ]]; then
    shift
    out="loci.csv"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output) out="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    # TB-Bench ships its loci file as data/_Tier12_Genes/loci.csv (per
    # README). Resolve at runtime; fall back to a stub if the data
    # directory hasn't been populated in this image.
    if [[ -f data/_Tier12_Genes/loci.csv ]]; then
        cp data/_Tier12_Genes/loci.csv "$out"
    elif [[ -f data/_Tier12_Genes/X.csv ]]; then
        # Some TB-Bench distributions expose loci as the X header row.
        head -1 data/_Tier12_Genes/X.csv | tr ',' '\n' > "$out"
    else
        echo "WARN: no loci.csv shipped with this image; emitting empty file. " \
             "Pre-processor will need to be configured with the loci by hand." >&2
        : > "$out"
    fi
    echo "wrote $out ($(wc -l < "$out") lines)"
    exit 0
fi

# ------------------------------------------------------------
# Predict mode — wrap TB-Bench main.py
# ------------------------------------------------------------
MODEL=""
FEATURES="features.csv"
OUT="predictions.csv"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)       MODEL="$2";    shift 2 ;;
        --features|-f) FEATURES="$2"; shift 2 ;;
        -o|--output)   OUT="$2";      shift 2 ;;
        --)            shift; break ;;
        -*)            echo "Unknown flag: $1" >&2; usage; exit 2 ;;
        *)             FEATURES="$1"; shift ;;
    esac
done

if [[ -z "${MODEL}" ]]; then
    echo "ERROR: --model <ModelName> is required for predict mode" >&2
    usage
    exit 2
fi

if [[ ! -f "${FEATURES}" ]]; then
    echo "ERROR: features file not found: ${FEATURES}" >&2
    exit 2
fi

# TB-Bench's main.py wants a "dataset folder" with X.csv + Y.csv. Create
# a one-shot scratch folder symlinking the user's features as X.csv.
SCRATCH="$(mktemp -d -t tb-bench-XXXXXX)"
cp "${FEATURES}" "${SCRATCH}/X.csv"

# Y.csv is required by TB-Bench's loader even at test time (it's only
# used for metrics, but the loader fails fast without it). Synthesise a
# single-column Y.csv with one zero per X row.
N_ROWS=$(( $(wc -l < "${SCRATCH}/X.csv") - 1 ))
{ echo "target"; yes 0 | head -n "${N_ROWS}"; } > "${SCRATCH}/Y.csv"

cd /opt/tb-bench
python main.py \
    -s "${SCRATCH}" \
    -m "${MODEL}" \
    -r test \
    2>&1 | tee /tmp/tb-bench.stdout

# TB-Bench writes results to results/output_*_<MODEL>_*.csv. Find the
# most recent for this model and conform to predictions.csv.
LATEST=$(ls -t results/output_*_"${MODEL}"_*.csv 2>/dev/null | head -1 || true)
if [[ -n "${LATEST}" ]]; then
    cp "${LATEST}" "${OUT}"
    echo "wrote ${OUT} (copied from ${LATEST})"
else
    echo "WARN: TB-Bench did not write a results CSV for ${MODEL}; " \
         "see /tmp/tb-bench.stdout for diagnostics." >&2
    : > "${OUT}"
fi
