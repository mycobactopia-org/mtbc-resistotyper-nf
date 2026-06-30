# TB-Bench TB-ML-conformance wrapper container

Wraps [BIRDSgroup/TB-Bench](https://github.com/BIRDSgroup/TB-Bench) (LGPL-v3; bioRxiv 2025) as a single Docker image conforming to the TB-ML 3-stage container contract ([Libiseller-Egger et al. 2023, *Bioinformatics Advances*](https://academic.oup.com/bioinformaticsadvances/article/3/1/vbad040/7084765)). One container build unlocks **19 ML/DL TB resistance predictors** registered in `conf/tb_ml_models.config`.

## What's in the image

- TB-Bench source at `/opt/tb-bench` (pinned by `--build-arg TB_BENCH_REF=...`)
- Python 3 + TensorFlow 2.19 + scikit-learn + scipy + pandas + tqdm + optunity + openpyxl
- `/run.sh` entrypoint that adapts TB-Bench's `python main.py` CLI to the TB-ML 3-stage probe/predict pattern

## What's NOT in the image (and why)

The **pre-processor stage** (BAM → feature matrix `X.csv`) lives in a separate companion image — `tb_bench_preprocessor:*` registered alongside in `conf/tb_ml_models.config`. Splitting these honours the TB-ML contract: pre-processors stay pluggable so different feature-engineering strategies (Tier12 vs ML-iAMR vs SDCNN tensor) can be swapped without rebuilding the predictor side.

The TB-Bench preprocessor companion is in `containers/tb-bench-preprocessor/` (Phase 1.0b — Dockerfile next, since it depends on samtools/bcftools and the TB-WGS-Preprocessing-Pipeline external scripts that need their own wrap).

## Build

```bash
cd containers/tb-bench
docker build -t mycobactopia/tb-bench-tb-ml:v0.1.0 .

# or pin the upstream TB-Bench commit
docker build \
    --build-arg TB_BENCH_REF=<sha-from-BIRDSgroup/TB-Bench> \
    -t mycobactopia/tb-bench-tb-ml:v0.1.0 .
```

Push to your registry of choice once the model registry's image fields point at it:

```bash
docker push mycobactopia/tb-bench-tb-ml:v0.1.0
```

## Run (matches the TB-ML 3-stage contract)

```bash
# Stage 1 — probe: emit the loci file the predictor's features expect
docker run --rm -v $PWD:/work -w /work \
    mycobactopia/tb-bench-tb-ml:v0.1.0 \
    --get-target-loci -o loci.csv

# Stage 2 — preprocess (companion image; not in this repo yet)
docker run --rm -v $PWD:/work -w /work \
    mycobactopia/tb-bench-preprocessor:v0.1.0 \
    -r loci.csv -o features.csv sample.bam

# Stage 3 — predict (pick any TB-Bench model)
docker run --rm -v $PWD:/work -w /work \
    mycobactopia/tb-bench-tb-ml:v0.1.0 \
    --model DeepAMR --features features.csv -o predictions.csv
```

The `--model` flag accepts any module under TB-Bench's `./models/` — see the registry in `conf/tb_ml_models.config` for the curated, registered set. The 19 predictor modules currently available upstream:

| Model | Source | Architecture |
|---|---|---|
| `BernoulliNB_Yang2018` | Yang et al. 2018 | Bernoulli NB + beta prior |
| `LogisticRegressionL1_Yang2018` | Yang et al. 2018 | LR (L1) |
| `LogisticRegressionL2_Yang2018` | Yang et al. 2018 | LR (L2) |
| `RandomForest_Yang2018` | Yang et al. 2018 | Random forest |
| `SVCLinear_Yang2018` | Yang et al. 2018 | SVC (linear) |
| `SVCRBF_Yang2018` | Yang et al. 2018 | SVC (RBF) |
| `LR_MLiAMR` | ML-iAMR | Logistic regression |
| `RF_MLiAMR` | ML-iAMR | Random forest |
| `SVC_MLiAMR` | ML-iAMR | SVC |
| `CNN_1D_MLiAMR` | ML-iAMR | 1D CNN |
| `CNN_2D_MLiAMR` | ML-iAMR | 2D CNN (FCGR 200×200) |
| **`DeepAMR`** | Yang et al. 2019 | **Denoising autoencoder + multi-task classifier — comparator** |
| **`WDNN`** | Chen-Farhat 2019 | **Wide & Deep NN — comparator** |
| `Deep` | Yang et al. | Fully-connected deep network |
| `ANN_Ankita` | — | Shallow ANN |
| `XGBoost_Ankita` | — | XGBoost |
| **`MTB_SD_CNN`** | Chen/Green/Yoon | **Spatial-dropout CNN** |
| `DecisionTree` | — | CART |
| `Treeresist` | — | Custom decision tree (Treesist-TB) |

Bold = explicit comparators in the resistotyper-ml manuscript (see `manuscripts/mtb-resistotyper-ml-manuscript-anchor.md`).

## Provenance

The wrapper:
- Pins TB-Bench by `--build-arg TB_BENCH_REF=...` (default `main`; use a specific SHA in production)
- Records the source commit in the image label
- Doesn't modify TB-Bench's algorithms — only adapts the CLI

TB-Bench is **LGPL-v3** — the wrapper container is therefore LGPL-v3-derivative; redistribute under the same terms.

## Phase status

Phase 1.0a (this commit):
- ✅ Predictor wrapper Dockerfile + entrypoint
- ✅ Registry entries for ≥ 10 TB-Bench models added to `conf/tb_ml_models.config`
- ⏳ Not yet pushed to a registry; user builds locally for now

Phase 1.0b (next):
- ⏳ TB-Bench pre-processor companion container (BAM → X.csv); depends on samtools/bcftools + TB-WGS-Preprocessing-Pipeline
- ⏳ End-to-end run on the EXIT-RIF test cohort

Phase 1.0c (after benchmarking):
- ⏳ Push image to ghcr.io/mycobactopia-org/tb-bench-tb-ml
- ⏳ Pin by digest (`@sha256:...`) per spec §A
