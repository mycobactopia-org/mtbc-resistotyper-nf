# Model candidate roster — ML/DL MTB drug-resistance predictors

Living catalogue of TB resistance predictors evaluated for inclusion in `mtbc-resistotyper-nf`. Sourced from a 2022–2026 literature survey + the TB-ML community + the [BIRDSgroup/TB-Bench](https://github.com/BIRDSgroup/TB-Bench) benchmark.

Status legend per `conf/tb_ml_models.config` entries:

| `wrapper_status` | Meaning | Runtime behaviour |
|---|---|---|
| `wired` | Predictor + pre-processor containers are published or in this repo; runs end-to-end | Executed by `BACKEND_TB_ML` |
| `wired-reads-input` | Runnable, but takes FASTQ rather than the 3-stage CSV pattern (Mykrobe) | Skipped by `BACKEND_TB_ML`; handled in the separate reads-input branch (Phase 1.2) |
| `planned` | Wrapper container designed in this repo but not yet built / pushed | Filtered out at runtime; emits a diagnostic |
| `wrapper_needed` | No TB-ML-conformant container exists yet; upstream code is available | Filtered out at runtime; documentation-only entry |

## Catalogue

### Phase 1.0 — original TB-ML containers (`wired`)

Pulled directly from [tb-ml.github.io/tb-ml-containers](https://tb-ml.github.io/tb-ml-containers/). Published by [Libiseller-Egger et al. 2023, *Bioinformatics Advances*](https://academic.oup.com/bioinformaticsadvances/article/3/1/vbad040/7084765).

| Registry key | Model | Source | Drugs |
|---|---|---|---|
| `tb_amr_cnn` | TB-AMR-CNN (one-hot CNN) | Phelan lab | 13 |
| `tb_dr_pred_nn` | Alternative one-hot CNN | Linfeng Wang | 13 |
| `aggreen_mtb_cnn` | MTB-CNN (Green 2022, *Nat Commun*) | Green/MTB-CNN team | 13 |
| `rf_streptomycin` | Random Forest from variants | TB-ML | 1 (streptomycin) |
| `mykrobe_tb_ml` | Mykrobe wrapped as TB-ML container | Phelan lab | 15 (`wired-reads-input`) |

### Phase 1.0a — TB-Bench wrapped models (`planned`)

One Dockerfile in [`containers/tb-bench/`](../containers/tb-bench/README.md) unlocks 19 ML/DL predictors from [BIRDSgroup/TB-Bench](https://github.com/BIRDSgroup/TB-Bench) (LGPL-v3; bioRxiv 2025). All entries share the same predictor container; the model is selected via `--model <ModelName>` in `predict_args`. Eight curated as registry entries here; the remaining 11 come for free once the image is built.

| Registry key | TB-Bench model | Architecture | Provenance |
|---|---|---|---|
| `tb_bench_deepamr` | `DeepAMR` | Denoising autoencoder + multi-task classifier | Yang 2019 |
| `tb_bench_wdnn` | `WDNN` | Wide & Deep neural net | Chen-Farhat 2019 |
| `tb_bench_mtb_sd_cnn` | `MTB_SD_CNN` | Spatial-dropout CNN | Chen / Green / Yoon |
| `tb_bench_xgboost` | `XGBoost_Ankita` | Gradient-boosted trees | TB-Bench (Ankita) |
| `tb_bench_rf_yang2018` | `RandomForest_Yang2018` | Random forest | Yang et al. 2018 |
| `tb_bench_lr_l1_yang2018` | `LogisticRegressionL1_Yang2018` | LR (L1) | Yang et al. 2018 |
| `tb_bench_cnn_1d_mliamr` | `CNN_1D_MLiAMR` | 1D CNN | ML-iAMR |
| `tb_bench_cnn_2d_mliamr` | `CNN_2D_MLiAMR` | 2D CNN (FCGR) | ML-iAMR |

Remaining TB-Bench models — registerable with one extra entry each: `BernoulliNB_Yang2018`, `LogisticRegressionL2_Yang2018`, `SVCLinear_Yang2018`, `SVCRBF_Yang2018`, `LR_MLiAMR`, `RF_MLiAMR`, `SVC_MLiAMR`, `ANN_Ankita`, `Deep`, `DecisionTree`, `Treeresist`.

### Phase 1.0b — candidates needing standalone wrappers (`wrapper_needed`)

Recognised models with available code but no TB-ML container. Each needs its own Dockerfile + entrypoint.

| Registry key | Model | Source | Notes |
|---|---|---|---|
| `tb_drop` | TB-DROP — MLP/DNN | [Wang et al. 2024, *BMC Genomics*](https://pmc.ncbi.nlm.nih.gov/articles/PMC10860279/); [`nottwy/TB-DROP`](https://github.com/nottwy/TB-DROP) | Apache-2.0. Upstream packages a Flask web service; needs a CLI-extraction wrapper. 4 first-line drugs. Hardest of the three. |
| `md_wdnn_farhat` | MD-WDNN — Wide-and-Deep NN | Chen, Doddi, Farhat 2019, *Scientific Reports*; [`farhat-lab/wdnn`](https://github.com/farhat-lab/wdnn) | Python + TF code, no container. Heavily-cited reference comparator. 11 drugs (first + second line). Note: TB-Bench's `WDNN` is similar but not identical — both could co-exist as separate registry entries. |

Possibly also worth wrapping in a future phase (no clear available container today):

- **DeepAMR** (Yang 2019, autoencoder) — handled via TB-Bench's `DeepAMR` module above
- **HANN** (Yang 2022, *Briefings in Bioinformatics*) — code availability TBD
- **CRyPTIC catalogue + ML hybrid** (Walker 2025) — embedded in CRyPTIC's PREDICTIONS parquet, not a standalone tool
- **GenTB**, **SAM-TB** — separate backend subworkflows (Phase 2)

### Phase 2 — separate backend wirings (not the TB-ML 3-stage chain)

Models too architecturally different from the TB-ML CSV pattern to retrofit cleanly. Each becomes its own `BACKEND_<NAME>` subworkflow.

- **TB-Profiler** (Phelan lab) — catalogue + ML hybrid; native JSON output. See `docs/BACKEND_WIRING_PLAN.md` §3.1 (Phase 1.1).
- **GenTB** (Gröschel 2021) — Snakemake bundle.
- **SAM-TB** (Yang 2022) — NN model.
- **`mtb-resistotyper-ml`** (future, this group's ML default) — drops in as a TB-ML-compliant container once it ships.

## Selection criteria — what qualifies for inclusion

A model is added to this catalogue when it meets at least one of:

1. **Published in a peer-reviewed journal** (preprint flagged as such)
2. **Code publicly available** (GitHub link required)
3. **Used as a comparator** in the resistotyper-ml manuscript anchor (`abc-universe/manuscripts/mtb-resistotyper-ml-manuscript-anchor.md`)
4. **Listed in a recent systematic review** (e.g. [Big Data Mining & Analytics 2025](https://www.sciopen.com/article/10.26599/BDMA.2025.9020063))

A registry entry is added when it meets at least one of:

5. The container is published with a 3-stage TB-ML CLI (→ `wired`)
6. We've built the container in this repo (→ `planned` initially, then `wired` post-build)
7. We commit to building the container in this repo within Phase 1 (→ `wrapper_needed`)

## How users interact with this catalogue

```bash
# See what's runnable today
nextflow run mycobactopia-org/mtbc-resistotyper-nf -profile test
# → uses the default params.tb_ml_models_enabled = 'tb_amr_cnn'

# Run multiple models in parallel (consensus across backends)
nextflow run … --tb_ml_models_enabled tb_amr_cnn,tb_dr_pred_nn,aggreen_mtb_cnn

# Try enabling a 'planned' entry — pipeline fails fast with a diagnostic
nextflow run … --tb_ml_models_enabled tb_bench_deepamr
# → ERROR: BACKEND_TB_ML: tb_bench_deepamr: wrapper_status='planned' …
```

The error message tells the user exactly why the entry was filtered + points to this document.

## Cross-references

- `containers/tb-bench/README.md` — TB-Bench wrapper container build instructions
- `docs/BACKEND_WIRING_PLAN.md` — full backend wiring plan (PR #1) including TB-Profiler / Mykrobe / SAM-TB / GenTB / `mtb-resistotyper-ml`
- `docs/CONTRACT.md` — `MTBC_RESISTOTYPER` stable interface
- `conf/tb_ml_models.config` — the live registry

## Citations

- Libiseller-Egger J, Wang L, Deelder W, Campino S, Clark TG, Phelan JE. *TB-ML — a framework for comparing machine learning approaches to predict drug resistance of M. tuberculosis.* Bioinformatics Advances 2023;3(1):vbad040. [doi:10.1093/bioadv/vbad040](https://doi.org/10.1093/bioadv/vbad040). PMCID: [PMC10074023](https://pmc.ncbi.nlm.nih.gov/articles/PMC10074023/).
- **TB-Bench**: BIRDSgroup, IIT-Madras. *A Systematic Benchmark of ML/DL Methods for Second-Line TB Drug Resistance Prediction*, bioRxiv 2025. [github.com/BIRDSgroup/TB-Bench](https://github.com/BIRDSgroup/TB-Bench).
- **TB-DROP**: Wang Y, Jiang Z, Liang P, Liu Z, Cai H, Sun Q. *TB-DROP: deep learning-based drug resistance prediction of M. tuberculosis utilizing whole genome mutations.* BMC Genomics 2024;25:48. [doi:10.1186/s12864-024-10066-y](https://doi.org/10.1186/s12864-024-10066-y).
- **MD-WDNN**: Chen ML, Doddi A, Royer J, Freschi L, Schito M, Ezewudo M, Kohane IS, Beam A, Farhat M. *Beyond multidrug resistance: Leveraging rare variants with machine and statistical learning models in M. tuberculosis resistance prediction.* eBioMedicine 2019;43:356-369. Code: [github.com/farhat-lab/wdnn](https://github.com/farhat-lab/wdnn).
- **MTB-CNN** (aggreen): Green A, Yoon C, Chen M, et al. *A convolutional neural network highlights mutations relevant to antimicrobial resistance in M. tuberculosis.* Nat Commun 2022;13:3817. [doi:10.1038/s41467-022-31236-0](https://doi.org/10.1038/s41467-022-31236-0).
- Systematic review (2025): *Machine Learning for Predicting Drug Resistance in Tuberculosis*, Big Data Mining & Analytics. [sciopen.com 10.26599/BDMA.2025.9020063](https://www.sciopen.com/article/10.26599/BDMA.2025.9020063).
