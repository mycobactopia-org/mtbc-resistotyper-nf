# MTBC_RESISTOTYPER — Building-Block Contract

This document is the **stable interface contract** for the `MTBC_RESISTOTYPER` subworkflow. It follows the `mtbc-*-nf` family contract (`abc-universe/brainstorms/mtbc-building-blocks/2026-06-30-mtbc-nf-building-block-family.md` §2) and is consumed by tbanalyzer, MAGMA, and any pipeline that needs to call resistance predictions on MTBC variant calls.

**Status:** Phase-1 — single backend (TB-Profiler), single upstream integration (XBS). The contract holds across future backends and consensus.

---

## Building-block conformance

Per the `mtbc-*-nf` family contract, this block satisfies:

| Requirement | How |
|---|---|
| **Backends** = published tools, pinned, configurable | TB-Profiler (Phase 1); Mykrobe, SAM-TB, GenTB (later); slot reserved for `mtb-resistotyper-ml` |
| **Normalise** to canonical representation | Each backend's per-sample output → canonical DR table (TSV + JSON), schema in `docs/output_schema.md` |
| **Converge/select** (optional) | `--consensus` = `best_single` (Phase 1) ; `majority`/`union`/`intersection` (Phase 2+); `external` for `mtb-resistotyper-ml` |
| **Provenance** per call | Each emitted DR record carries `BACKENDS=…` + `BACKEND_VERSION=…` + `CATALOGUE=…` |
| **Importable subworkflow** | `include { MTBC_RESISTOTYPER } from '…'` ; standalone mode via `main.nf` |
| **ML slot** | Reserved as `--backends mtb_resistotyper_ml` once `mtb-resistotyper-ml` ships as a backend module |
| **Benchmarked** | Against WHO catalogue v2 + CRyPTIC v3.4.0 phenotypes (out of scope here; lives in `tb-resistance-prediction-benchmark`) |

---

## `take:` channels (subworkflow inputs)

```
workflow MTBC_RESISTOTYPER {
    take:
    ch_variants     // channel  [ meta(sample, …), vcf, tbi ]
    ch_reference    // value    [ meta(id:'ref'),  fasta, fai ]
}
```

### Required channels

| Channel | Shape | Source |
|---|---|---|
| `ch_variants` | `[ meta, vcf, tbi ]` per sample | Any upstream variant caller that emits a per-sample VCF. **First integration: XBS** (`snp_filtered` + `indel_filtered` emits; see "Wiring XBS upstream" below). |
| `ch_reference` | `[ meta(id:'ref'), fasta, fai ]` | Reference FASTA + index used during variant calling. Resistance catalogues are coordinate-dependent on the reference (typically NC_000962.3 H37Rv). |

### What's NOT in the input contract

- BAMs — Phase-1 backends (TB-Profiler) accept VCF input only. BAM-input mode (`tb-profiler profile --bam`) is a Phase-2 backend variant.
- FASTQs — read-input mode is the upstream caller's job, not this block's.

This keeps the resistotyper a **pure downstream consumer** of the `mtbc-varcaller-nf` family — it does not re-implement read processing.

---

## `emit:` channels (subworkflow outputs)

```
emit:
dr_table          // [ meta, dr.tsv ]      — canonical per-sample DR table (one row per drug)
dr_json           // [ meta, dr.json ]     — backend-native per-sample output (raw)
cohort_summary    // [ cohort_meta, summary.tsv ] — cohort-level resistance prevalence (Phase-2)
versions          // standard nf-core versions topic
```

### `dr_table` schema (the canonical output)

| Column | Type | Description |
|---|---|---|
| `sample` | string | Sample ID from input meta.sample |
| `drug` | string | Standardised drug name (RIF, INH, EMB, PZA, BDQ, LZD, DLM, MXF, …) |
| `prediction` | enum | `R` (resistant), `S` (susceptible), `U` (unknown / insufficient evidence) |
| `confidence` | enum | `high` / `moderate` / `low` (catalogue-specific tier) |
| `mutations` | string | Comma-separated list of resistance-conferring mutations identified |
| `catalogue` | string | Catalogue source (e.g. `WHO_v2_2023`, `CRyPTIC_v3.4.0`) |
| `backend` | string | Which backend emitted this call (e.g. `tbprofiler`, `mykrobe`) |
| `backend_version` | string | Version string + container digest |

Files are TSV with these columns. The canonical schema is fixed across backends — backend-specific extras live in `dr_json`.

---

## Wiring XBS upstream (the first integration)

XBS's stable emit contract (`mycobactopia-org/xbs-variant-calling docs/CONTRACT.md`) emits:

```
snp_filtered      // [ meta, vcf, tbi ]
indel_filtered    // [ meta, vcf, tbi ]
```

To feed both into resistotyper, merge SNP + INDEL per sample (using `bcftools concat` in a small adapter module), then pass as `ch_variants`. Two consumption patterns are supported:

### Pattern A — standalone, samplesheet of pre-computed VCFs (Phase-1 default)

```bash
nextflow run mycobactopia-org/mtbc-resistotyper-nf \
    -profile docker \
    --input samplesheet.csv \   # sample,vcf,tbi columns
    --reference_dir resources/genome --reference_basename NC-000962-3-H37Rv \
    --outdir results/
```

Decoupled: upstream variant calling (XBS, MAGMA, mtbc-varcaller-nf, …) writes VCFs first; resistotyper picks them up. Simplest for batch / surveillance workflows.

### Pattern B — chained via `MTBC_RESISTOTYPER` import (consumer-side)

A consumer pipeline (tbanalyzer, MAGMA-v2) does:

```groovy
include { XBS_VARIANT_CALLING } from '<xbs-path>/subworkflows/local/xbs_variant_calling_wf'
include { MTBC_RESISTOTYPER   } from '<this-path>/subworkflows/local/mtbc_resistotyper_wf'

workflow {
    XBS_VARIANT_CALLING(ch_reads, ch_reference, ch_snp_truth, ch_indel_truth, ch_dbsnp)

    // Merge SNP + INDEL per sample before passing to resistotyper
    def ch_variants = XBS_VARIANT_CALLING.out.snp_filtered
        .join(XBS_VARIANT_CALLING.out.indel_filtered)
        .map { meta, snp_vcf, snp_tbi, indel_vcf, indel_tbi ->
            // (small adapter — bcftools concat → single per-sample VCF)
            [meta, /* merged vcf, tbi */]
        }

    MTBC_RESISTOTYPER(ch_variants, ch_reference)
}
```

End-to-end in a single Nextflow run. Both XBS and resistotyper pinned by commit.

---

## Version semantics

Same as XBS's contract:

| Change type | Version bump |
|---|---|
| Add new backend, new emit channel, new opt-in flag (default = current behaviour) | minor |
| Rename emit channel, change channel shape, flip a default that changes outputs | **major** |

Pin against tagged commits, not against `master`.

---

## Backend roadmap

| Backend | Status | Phase |
|---|---|---|
| **TB-Profiler** | Phase-1 default | now |
| **Mykrobe** | planned | Phase 2 |
| **SAM-TB** | planned | Phase 2 |
| **GenTB** | planned | Phase 2 |
| **`mtb-resistotyper-ml`** | future ML default backend slot reserved | when `mtb-resistotyper-ml` ships as a Bioconda-installable module |

Backend selection: `--backends tbprofiler` (single) or `--backends tbprofiler,mykrobe` (multi → consensus mode).
