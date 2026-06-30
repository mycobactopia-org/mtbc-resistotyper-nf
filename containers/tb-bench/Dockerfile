# TB-Bench TB-ML-conformance wrapper container
#
# Wraps github.com/BIRDSgroup/TB-Bench (LGPL-v3) as a Docker image that
# follows the TB-ML 3-stage container contract — `/run.sh` is the entrypoint.
#
# Reference:
#   TB-Bench: A Systematic Benchmark of ML/DL Methods for Second-Line TB
#   Drug Resistance Prediction. BIRDSgroup, IIT-Madras. bioRxiv 2025.
#   github.com/BIRDSgroup/TB-Bench
#
# This wrapper builds a PREDICTOR-only container. The pre-processor step
# (BAM → feature matrix X.csv) is run by a SEPARATE container — see the
# `tb_bench_preprocessor` registry entry. The full TB-ML chain becomes:
#
#     TB_ML_PROBE       (this image: --get-target-loci)
#     TB_ML_PREPROCESS  (separate preprocessor image)
#     TB_ML_PREDICT     (this image: --predict -m <ModelName>)
#
# This single image hosts every TB-Bench predictor model — pass
# `--model <ModelName>` to select. Available models (see tb_ml_models.config):
#   DeepAMR, WDNN, MTB_SD_CNN, BernoulliNB_Yang2018, LR_MLiAMR, RF_MLiAMR,
#   SVC_MLiAMR, CNN_1D_MLiAMR, CNN_2D_MLiAMR, XGBoost_Ankita, ANN_Ankita,
#   DecisionTree, Treeresist, ... (19 total)

FROM tensorflow/tensorflow:2.19.0

LABEL org.opencontainers.image.title="tb-bench-tb-ml-wrapper"
LABEL org.opencontainers.image.description="TB-ML-conformance wrapper around BIRDSgroup/TB-Bench (LGPL-v3)"
LABEL org.opencontainers.image.licenses="LGPL-3.0"
LABEL org.opencontainers.image.source="https://github.com/BIRDSgroup/TB-Bench"

ARG TB_BENCH_REF=main

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN git clone --depth=1 --branch="${TB_BENCH_REF}" https://github.com/BIRDSgroup/TB-Bench.git tb-bench

WORKDIR /opt/tb-bench
RUN pip install --no-cache-dir -r requirements.txt \
    && python -c "import sklearn, pandas, numpy, tensorflow; print('TB-Bench deps OK')"

# Wrapper entrypoint conforms to the TB-ML 3-stage CLI contract.
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Bring a minimal `loci.csv` resource into the image so probe mode works
# without external state. The actual file ships in TB-Bench's data/ dir as
# `_Tier12_Genes/loci.csv` (or similar); we resolve it at runtime.
ENV TB_BENCH_HOME=/opt/tb-bench

ENTRYPOINT ["/run.sh"]
CMD ["--help"]
