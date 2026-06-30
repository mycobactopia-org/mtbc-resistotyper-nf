# mycobactopia-org/mtbc-resistotyper-nf

[![GitHub Actions Linting Status](https://github.com/mycobactopia-org/mtbc-resistotyper-nf/actions/workflows/linting.yml/badge.svg)](https://github.com/mycobactopia-org/mtbc-resistotyper-nf/actions/workflows/linting.yml)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)
[![Nextflow](https://img.shields.io/badge/version-%E2%89%A525.10.4-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-4.0.2-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https%3A%2F%2Fnf-co.re)](https://github.com/nf-core/tools/releases/tag/4.0.2)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

**mycobactopia-org/mtbc-resistotyper-nf** is one block of the [`mtbc-*-nf` building-block family](https://github.com/mycobactopia-org) — a generalisable, multi-backend Nextflow pipeline for one analytical step of MTBC genomics. This block runs **MTBC resistance prediction**: given per-sample variant calls, it runs one or more published resistance predictors (TB-Profiler in Phase 1; Mykrobe / SAM-TB / GenTB later) and normalises their outputs into a canonical per-sample drug-resistance table. A slot is reserved for [`mtb-resistotyper-ml`](https://github.com/abhi18av-phd-projects/pub-mtb-resistotyper-ml) as the future ML default backend.

The pipeline exposes an importable subworkflow `MTBC_RESISTOTYPER` with a stable interface contract (see [`docs/CONTRACT.md`](docs/CONTRACT.md)) — consumed by tbanalyzer, MAGMA-v2, and any downstream pipeline that needs drug-resistance calls without re-implementing predictor invocation.

### First upstream integration: XBS

The Phase-1 release accepts variant calls from **[mycobactopia-org/xbs-variant-calling](https://github.com/mycobactopia-org/xbs-variant-calling)** — the canonical Heupink 2021 GATK-VQSR caller — as the first documented upstream chain. Two consumption patterns:

| Pattern | When | How |
|---|---|---|
| **Standalone** (decoupled batch) | Variant calls already exist on disk | `--input samplesheet.csv` with `sample,vcf,tbi` columns |
| **Chained** (consumer pipeline) | End-to-end Nextflow run | `include { XBS_VARIANT_CALLING }` + `include { MTBC_RESISTOTYPER }` in your consumer pipeline; pass XBS's `snp_filtered` + `indel_filtered` emits through a small adapter |

XBS is pinned by commit; future releases will swap to a `--upstream xbs|magma|mtbc-varcaller-nf` flag once additional upstream callers are wired in. The contract (`docs/CONTRACT.md`) is the same regardless of upstream.

### Pipeline outputs

- **Per-sample DR table** (`*.dr_table.tsv`) — canonical schema: `sample, drug, prediction (R|S|U), confidence, mutations, catalogue, backend, backend_version`. One row per drug per sample.
- **Per-sample DR JSON** (`*.dr.json`) — backend-native output for downstream tooling that needs the raw predictor structure
- **(Phase 2)** Cohort summary — resistance prevalence per drug across the cohort

### Pipeline stages (Phase 1)

1. **Resolve upstream input** — samplesheet (`sample,vcf,tbi`) or chained subworkflow output
2. **Run resistance backend** — TB-Profiler against the WHO catalogue v2 (Phase 1; multi-backend voting from Phase 2)
3. **Normalise to canonical table** — convert backend-native output to the canonical DR table schema
4. **Stamp provenance** — every DR record carries backend name, version, container digest, catalogue version

### Position in the family

| Block | Step | Status |
|---|---|---|
| `mtbc-qc-nf` | read QC / trim | future |
| `mtbc-aligner-nf` | read alignment | future |
| `mtbc-varcaller-nf` | variant calling (small + SV + minority) | Phase-1 in progress (Task 2 of current handoff) |
| **`mtbc-resistotyper-nf`** | **resistance prediction** | **Phase-1 scaffold (this repo)** |
| `mtbc-lineage-nf` | lineage / typing | future |
| `mtbc-phylo-nf` | phylogenetics | future |
| `mtbc-cluster-nf` | SNP-distance clustering | future |
| `mtbc-transmission-nf` | transmission inference | future |

The family vision: `abc-universe/brainstorms/mtbc-building-blocks/2026-06-30-mtbc-nf-building-block-family.md`.

## Usage

> [!NOTE]
> If you are new to Nextflow, refer to [the nf-core docs](https://nf-co.re/docs/get_started/environment_setup/overview).

Prepare a samplesheet with per-sample VCFs (Pattern A — decoupled):

```csv
sample,vcf,tbi
SAMPLE_A,/path/to/SAMPLE_A.vcf.gz,/path/to/SAMPLE_A.vcf.gz.tbi
SAMPLE_B,/path/to/SAMPLE_B.vcf.gz,/path/to/SAMPLE_B.vcf.gz.tbi
```

Run:

```bash
nextflow run mycobactopia-org/mtbc-resistotyper-nf \
    -profile <docker|singularity|conda>,test \
    --input samplesheet.csv \
    --outdir results/
```

The `test` profile bundles a fixed-VCF / known-phenotype EXIT-RIF sample for the Layer-1 standalone test.

## Validation

Three integration tiers — see [`docs/VALIDATION.md`](docs/VALIDATION.md) for the full plan:

| Tier | Tests | Cost |
|---|---|---|
| **T1** | resistotyper standalone on fixed VCF | minutes (laptop) |
| **T2** | XBS → resistotyper end-to-end | hours (abc-cluster) |
| **T3** | MAGMA (which wraps XBS) → resistotyper end-to-end | hours (abc-cluster) |

T2 and T3 are the **"two test points"** that catch (a) XBS-output / resistotyper-input drift and (b) MAGMA-side wrapping that changes downstream resistance calls even when XBS itself is unchanged.

## Credits

mycobactopia-org/mtbc-resistotyper-nf was developed by Abhinav Sharma as part of the `mtbc-*-nf` building-block family.

Resistance predictors wrapped:
- **TB-Profiler** (Phelan lab) — Phase 1 default backend; the de-facto standard
- **Mykrobe**, **SAM-TB**, **GenTB** — Phase 2 backends

ML default backend slot reserved for [`mtb-resistotyper-ml`](https://github.com/abhi18av-phd-projects/pub-mtb-resistotyper-ml) (Sharma et al., in preparation — glass-box epistasis in MTB drug resistance on CRyPTIC v3.4.0).

## Contributions and Support

If you would like to contribute, please see [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md).

## Citations

This pipeline is part of the `mtbc-*-nf` family. Cite the building-block family architecture (Sharma A et al., in preparation) and the predictor backends used — see [`CITATIONS.md`](CITATIONS.md) for the full list.

This pipeline reuses scaffolding from the [nf-core](https://nf-co.re) community framework under the [MIT license](https://github.com/nf-core/tools/blob/main/LICENSE):

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> *Nat Biotechnol.* 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
