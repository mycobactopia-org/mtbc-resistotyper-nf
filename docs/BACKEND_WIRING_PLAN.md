# Backend wiring plan — TB-Profiler, Mykrobe, and beyond, with a standardised resistance report

**Status:** plan / decision-record. Not yet implemented.
**Goal:** wire multiple TB resistance-prediction tools (TB-Profiler, Mykrobe, SAM-TB, GenTB; later `mtb-resistotyper-ml`) into `mtbc-resistotyper-nf` so they emit reports in a **single, standards-aligned canonical schema** — even though each tool's native output is different. Heavy reuse of the **PHA4GE / hAMRonization** field spec, the **WHO Catalogue v2 (2023)** grading framework, and the **TB-ML (Libiseller-Egger 2023)** containerised-backend pattern.

---

## 1. Standards survey — what we adopt and why

### 1.1 PHA4GE / hAMRonization — the gene/variant field-name spec

Published canonical column names for AMR detection records: [pha4ge/hAMRonization](https://github.com/pha4ge/hAMRonization) — the PHA4GE AMR Gene & Variant Specification. Required fields:

| Field | Type | What it captures |
|---|---|---|
| `Analysis Software Name` | string | the backend (e.g. `tbprofiler`, `mykrobe`) |
| `Analysis Software Version` | string | version + container digest |
| `Gene Name` / `Gene Symbol` | string | e.g. `rpoB` / `Rv0667` |
| `Genetic Variation Type` | enum | `snp`, `insertion`, `deletion`, … |
| `Input File Name` | string | sample VCF path |
| `Reference Accession` | string | e.g. `NC_000962.3` for H37Rv |
| `Reference Database Name` | string | e.g. `WHO_Catalogue_v2_2023`, `Coll2018`, `CRyPTIC_v3.4.0` |
| `Reference Database Version` | string | exact catalogue version |

Plus optional but **clinically important for TB**:

| Field | Used for |
|---|---|
| `Antimicrobial Agent` | the drug (`rifampicin`, `isoniazid`, …) |
| `Drug Class` | first-line / second-line / new-and-repurposed |
| `Predicted Phenotype` | `R` (resistant), `S` (susceptible), `U` (uncertain) |
| `Predicted Phenotype Confidence Level` | maps onto WHO catalogue tiers (§1.2) |
| `Nucleotide mutation` / `Amino acid mutation` | HGVS-style notation |
| `Resistance mechanism` | catalogued mechanism (e.g. target modification) |
| `Coverage (depth)` / `Coverage (percentage)` | per-gene depth / breadth |

**Adoption:** PHA4GE field names become the **canonical column names** in our default TSV output. We extend with TB-specific fields where the spec doesn't capture them (§3).

### 1.2 WHO Catalogue v2 (2023) — the grading framework

The 2nd edition of the WHO Catalogue of Mutations in Mycobacterium tuberculosis Complex ([WHO 9789240082410](https://www.who.int/publications/i/item/9789240082410)) covers 13 anti-TB medicines with > 30,000 graded variants. The grading system (5 tiers; gleaned from TB-Profiler's catalogue ingestion):

| Group | Label | Interpretation |
|---|---|---|
| 1 | "Associated with R" | High-confidence resistance marker |
| 2 | "Associated with R — Interim" | Moderate confidence; flagged for revision |
| 3 | "Uncertain significance" | Insufficient evidence either way |
| 4 | "Not associated with R — Interim" | Moderate confidence not-resistant |
| 5 | "Not associated with R" | High-confidence non-resistance |

**Adoption:** the canonical `Predicted Phenotype Confidence Level` field carries one of these five labels (or backend-native fallback) — clinically interpretable across tools.

### 1.3 TB-Profiler — the de facto MTB native schema

[TB-Profiler](https://github.com/jodyphelan/TBProfiler) is the field's gold standard (Phelan lab; LSHTM). Its native JSON output is the closest existing thing to a per-sample MTB resistance report and ingests the WHO Catalogue v2 directly. Structure (per-sample JSON):

```
{
  "id": "<sample>",
  "lineage": [{"lineage": "lineage4.10", "family": "Euro-American (X-type)"}],
  "dr_variants": [
    {"gene": "rpoB", "change": "p.Ser450Leu", "depth": 87, "freq": 1.0,
     "drugs": [{"drug": "rifampicin", "confidence": "Assoc w R"}], ...},
    ...
  ],
  "drug_resistance": [...]
}
```

**Adoption:** TB-Profiler's `dr_variants` records map almost 1:1 onto PHA4GE fields (after small renames). We make TB-Profiler the **Phase-1 default backend** and the **schema reference implementation** — every other backend's adapter targets the same canonical shape.

### 1.4 CRyPTIC v3.4.0 PREDICTIONS — the parquet target

The CRyPTIC v3.4.0 release ([10.5281/zenodo.16041005](https://zenodo.org/records/16041005)) ships a `PREDICTIONS.parquet` table (1.9 MB) intended for ML-feature ingestion (e.g. `mtb-resistotyper-ml`). Same per-(sample, drug) grain as PHA4GE. **Cross-references the family-level `--export_cryptic` flag** documented in `mtbc-varcaller-nf/docs/OUTPUT_STANDARDIZATION.md`.

**Adoption:** under `--export_cryptic`, emit a parquet matching the CRyPTIC `PREDICTIONS` schema in addition to the default canonical TSV. Open question: actual `PREDICTIONS.parquet` column list lives in the bundled `DATA_SCHEMA.pdf` — blocker on the same PDF read flagged in the varcaller doc.

### 1.5 TB-ML framework — the containerised-backend pattern

[Libiseller-Egger et al. 2023, *Bioinformatics Advances*](https://academic.oup.com/bioinformaticsadvances/article/3/1/vbad040/7084765) ([PMC10074023](https://pmc.ncbi.nlm.nih.gov/articles/PMC10074023/)) packages ML resistance models into Docker containers with **standardised pre-processing + prediction** stages, orchestrated by a CLI. From the Phelan lab — same authors as TB-Profiler. Notable for *comparability*: the framework's whole premise is that different ML models become directly swappable when they share input/output contracts.

**Adoption:** TB-ML's "containerised pre-processing + prediction" pattern is exactly how we wire each backend (one nf-core module per backend; standardised channel shape on both ends). When `mtb-resistotyper-ml` ships, it slots in as a backend module with the same input contract — no consumer code changes. This makes our pipeline a **superset** of TB-ML for the resistance step: same comparability framing, but composable into broader Nextflow workflows.

---

## 2. Canonical output schema (the standard)

Each row = one (sample, drug, backend) triple. Long format. PHA4GE-aligned column names where possible; TB-specific extensions documented:

### 2.1 Per-sample × per-drug × per-backend record

| Column | PHA4GE / source | Type | Required | Notes |
|---|---|---|---|---|
| `sample_id` | PHA4GE `Input File Name` (derived) | string | ✓ | Our samplesheet `sample` field |
| `study_id` | extension | string | optional | From samplesheet `study` field |
| `antimicrobial_agent` | PHA4GE `Antimicrobial Agent` | string | ✓ | Standardised drug name (rifampicin, isoniazid, …) |
| `drug_class` | PHA4GE `Drug Class` | string | optional | `first_line` \| `second_line` \| `repurposed` \| `new` |
| `predicted_phenotype` | PHA4GE `Predicted Phenotype` | enum | ✓ | `R` \| `S` \| `U` |
| `predicted_phenotype_confidence_level` | PHA4GE | enum | optional | One of WHO tiers (`Assoc with R`, `Assoc with R — Interim`, `Uncertain`, `Not assoc — Interim`, `Not assoc`) — falls back to backend's native confidence string |
| `who_catalogue_grade` | TB extension | int 1-5 | optional | Direct WHO grouping (1=highest confidence R, 5=highest confidence S); only populated when backend reads WHO v2 |
| `lineage` | TB extension | string | optional | TBProfiler-style (e.g. `lineage4.10`) |
| `evidence_mutations` | PHA4GE `Nucleotide mutation` + `Amino acid mutation` joined | string | ✓ when phenotype != U | Semicolon-separated list of mutations supporting the call. Format: `rpoB:p.Ser450Leu;rpoB:c.1349C>T` |
| `evidence_genes` | PHA4GE `Gene Symbol` joined | string | optional | Semicolon-separated unique gene set |
| `analysis_software_name` | PHA4GE | string | ✓ | `tbprofiler` \| `mykrobe` \| `samtb` \| `gentb` \| `mtb_resistotyper_ml` |
| `analysis_software_version` | PHA4GE | string | ✓ | tool version + container digest |
| `reference_database_name` | PHA4GE | string | ✓ | e.g. `WHO_Catalogue_v2_2023`, `mykrobe_panel_v0.10.0` |
| `reference_database_version` | PHA4GE | string | ✓ | Exact catalogue version |
| `reference_accession` | PHA4GE | string | ✓ | `NC_000962.3` for H37Rv |
| `coverage_depth_mean` | PHA4GE `Coverage (depth)` | float | optional | Per-gene depth across evidence genes |
| `coverage_breadth` | PHA4GE `Coverage (percentage)` | float | optional | Per-gene breadth |
| `notes` | extension | string | optional | Backend-specific free text (e.g. quality warnings) |

**Three emitted files per cohort:**
- `dr_table_per_call.tsv` — the long-format above; one row per (sample × drug × backend)
- `dr_table_per_sample.tsv` — consensus across backends (§4); one row per (sample × drug)
- `dr_table_summary.tsv` — per-sample overall susceptibility tier (§4.2)

### 2.2 Backend-native raw output preserved (always)

Each backend also emits its **raw native output** (TB-Profiler JSON, Mykrobe JSON, etc.) under `${outdir}/${backend}/${sample}.raw.json`. Reasons:
- Backend-specific richness (lineage subtyping, NTM detection, …) shouldn't be lost
- Lets downstream tooling that already speaks one tool's native format keep using it
- Audit trail — consumers can re-derive the canonical TSV if they doubt our adapter

### 2.3 CRyPTIC parquet export (opt-in)

`--export_cryptic` emits `PREDICTIONS.parquet` in addition. Same per-(sample, drug) grain. Column mapping derived from the CRyPTIC `DATA_SCHEMA.pdf` once read locally (open question — same blocker as in the varcaller doc).

---

## 3. Per-backend wrapping — the same pattern for every tool

Each backend = **one nf-core subworkflow** following a stable internal contract (mirrors the family `mtbc-*-nf` contract):

```groovy
workflow BACKEND_<NAME> {
    take:
    ch_variants   // [meta, vcf, tbi]  — per-sample from upstream (XBS / MAGMA / mtbc-varcaller-nf)
    ch_reference  // [meta(id:'ref'), fasta, fai]

    main:
    // Stage 1: pre-process input into backend-native format if needed
    // Stage 2: run the backend tool (nf-core or local module)
    // Stage 3: parse backend-native output → canonical PHA4GE-aligned records
    // Stage 4: stamp [analysis_software_name, analysis_software_version,
    //                 reference_database_name, reference_database_version]
    //          into meta

    emit:
    dr_records  // [meta+stamp, dr_long.tsv]  — canonical TSV, one record per (sample, drug)
    dr_native   // [meta+stamp, raw.json]    — backend-native preserved
    versions    // standard nf-core versions topic
}
```

Each tool gets its **own parser** in `bin/<backend>_to_canonical.py` (Python; pandas + jsonschema validation against the canonical schema). The parser is the contract translator — different per tool, output identical.

### 3.1 Phase-1.1 — TB-Profiler (default backend; schema reference implementation)

| Concern | Resolution |
|---|---|
| nf-core module exists? | Yes: `tbprofiler/profile` (already used by MAGMA) |
| Input shape | `[meta, vcf, tbi]` or `[meta, bam, bai]` (we use VCF for the per-call path) |
| Native output | JSON per sample |
| Catalogue | WHO Catalogue v2 (2023) — bundled in container |
| Adapter | `bin/tbprofiler_to_canonical.py` parses `dr_variants` + `drug_resistance` into canonical TSV |
| WHO grade mapping | Direct — TB-Profiler's `confidence` field IS the WHO grade label |
| Lineage | Populated from TB-Profiler's `lineage` block |

Phase-1.1 is the **schema reference implementation** — every other backend adapter is tested by producing the same canonical TSV from the same inputs.

### 3.2 Phase-1.2 — Mykrobe (kmer-based alternative)

| Concern | Resolution |
|---|---|
| nf-core module | `mykrobe/predict` exists |
| Input | reads (Mykrobe is read-based, not VCF) — different upstream wiring |
| Native output | JSON per sample |
| Catalogue | Mykrobe's own panel (`panel-tb-202309` or similar; needs version pinning) |
| Adapter | `bin/mykrobe_to_canonical.py` — maps Mykrobe's `susceptibility` block to canonical |
| WHO grade mapping | Indirect — Mykrobe doesn't use WHO grades; we map its `R/S/r/N` categories to PHA4GE phenotype + Mykrobe's own "high/medium/low confidence" to `predicted_phenotype_confidence_level` |

Mykrobe is read-input, so the `take:` signature differs from TB-Profiler's VCF-input. We handle this by making the backend take **`ch_reads OR ch_variants`** (whichever is supplied) and the composer picks the right input per backend.

### 3.3 Phase-2 — SAM-TB and GenTB

| Backend | Type | Status |
|---|---|---|
| SAM-TB | ML model (variant-input) | Yang et al. 2022; needs Docker image; not in nf-core; will need local module |
| GenTB | Ensemble / rule-based hybrid | Gröschel et al. 2021; Docker image available |

For both: same backend contract, same canonical-TSV adapter pattern.

### 3.4 Phase-3 — `mtb-resistotyper-ml` (the future ML default)

Slots in as a backend following the same interface. Per the family vision, this becomes the **default backend** when it ships as a Bioconda-installable module. The TB-ML pattern (pre-processing container + prediction container) maps directly: pre-processing = our `bin/` parsers; prediction = the ML model module.

---

## 4. Consensus across backends

### 4.1 Per-drug consensus (Phase 1 — `best_single` default + `majority` Phase 2)

Mirrors `mtbc-varcaller-nf`'s consensus contract (spec §D). Modes:

| Mode | Behaviour |
|---|---|
| `best_single` | Pick the named backend's call per (sample, drug) — default; "TB-Profiler said X" |
| `majority` | Per-drug vote — if ≥ N of M backends say `R`, output `R` with `evidence_mutations` = union, `analysis_software_name` = `consensus_majority`; ties resolve to `U` |
| `union` | If any backend says `R`, output `R` (high-sensitivity) |
| `intersection` | Output `R` only if ALL backends say `R` (high-specificity) |
| `external` | Hook for `mtb-resistotyper-ml` as a meta-caller across backend outputs |

### 4.2 Per-sample summary tier

Single column on `dr_table_summary.tsv`. Derived from the per-drug consensus:

| Sample tier | Definition |
|---|---|
| `S` (susceptible) | All first-line drugs `S` |
| `RR-TB` | `R` to rifampicin, `S` to isoniazid (rifampicin-resistant) |
| `MDR-TB` | `R` to BOTH rifampicin AND isoniazid |
| `Pre-XDR-TB` | MDR + `R` to any fluoroquinolone (moxifloxacin / levofloxacin) |
| `XDR-TB` | Pre-XDR + `R` to bedaquiline OR linezolid |
| `Mono-resistant` | `R` to one drug only |
| `Poly-resistant` | `R` to multiple drugs but not both INH+RIF |
| `Indeterminate` | Any first-line drug `U` |

These tier definitions follow [WHO TB definitions for surveillance (2021)](https://www.who.int/publications/i/item/9789240018662) — citable, not invented.

---

## 5. Phased implementation

| Phase | Scope | Deliverables | Estimate |
|---|---|---|---|
| **1.1** | TB-Profiler backend + canonical TSV adapter | `subworkflows/local/backend_tbprofiler.nf` + `bin/tbprofiler_to_canonical.py` + `MTBC_RESISTOTYPER` wiring + test against XBS-output samplesheet | 2 days |
| **1.2** | Mykrobe backend (kmer / read-input path) | `subworkflows/local/backend_mykrobe.nf` + `bin/mykrobe_to_canonical.py` + per-backend choice of input shape | 2 days |
| **1.3** | Consensus implementation (`best_single` mandatory; `majority` Phase-1.3.b) | `subworkflows/local/consensus_*.nf` + `bin/per_sample_summary.py` (WHO surveillance-tier classifier) | 1 day for best_single; 2 days for majority + summary |
| **1.4** | `--export_cryptic` parquet emit (resistance-side) | `bin/canonical_to_cryptic_predictions.py` — gated on the same CRyPTIC PDF read as the varcaller's | 1 day (after PDF read) |
| **2** | SAM-TB + GenTB backends | Local modules for SAM-TB (Yang 2022) + GenTB (Gröschel 2021); same canonical adapter pattern | 3-4 days each |
| **3** | `mtb-resistotyper-ml` as backend module | TB-ML-style containerised pre-processing + prediction; slot replaces the others as default once benchmarked | depends on `mtb-resistotyper-ml` shipping a Bioconda module |

**Net Phase-1 effort to runnable-end-to-end on real samples: ~6 days** (TB-Profiler + Mykrobe + best_single consensus + per-sample summary tiers). Phase-2 + Phase-3 are additive without breaking the contract.

---

## 6. Three integration tiers (testing strategy)

Picks up directly from `docs/VALIDATION.md` § Three integration tiers:

| Tier | What changes vs current VALIDATION.md |
|---|---|
| **T1** standalone resistotyper | Now exercises 2 backends + canonical TSV adapter on a fixed VCF; assertions on the canonical schema instead of free-form output |
| **T2** XBS-upstream chain | `xbs-variant-calling -profile test` → `mtbc-resistotyper-nf -profile test` end-to-end; the canonical TSV's `R` calls for known-resistant EXIT-RIF samples should agree with phenotypic ground truth |
| **T3** MAGMA-upstream chain | Same but with MAGMA (post Plan-3 §11) as the upstream; tests that MAGMA's wrapping of XBS doesn't change downstream DR predictions |

### 6.1 Cross-backend concordance (a NEW test class enabled by multi-backend)

With ≥ 2 backends, T1 also verifies:
- Cohen's κ between TB-Profiler and Mykrobe per drug (sanity threshold: > 0.7 for first-line drugs on clean clinical samples)
- No backend produces NaN / null `predicted_phenotype`
- All backends produce the same SET of (sample, drug) keys (every backend reports every drug)

Backed by a tiny Python test in `tests/cross_backend_concordance.py` (uses the canonical TSV — no backend-specific parsing).

---

## 7. Open questions for review

1. **Default backend** — TB-Profiler (Phase-1 plan) or `best_single = consensus across all configured`? TB-Profiler is the de facto standard but Mykrobe catches some markers TB-Profiler misses on novel-resistance variants. Recommend TB-Profiler default; users override via `--consensus_backend mykrobe`.

2. **Drug name canonicalisation** — `rifampicin` vs `RIF` vs `R` vs `rifampin` (US spelling). WHO uses full lowercase Latin name (`rifampicin`); TB-Profiler emits the WHO names; some Mykrobe panels use 3-letter codes. Recommend full lowercase Latin in canonical TSV; ship a lookup table `assets/drug_names.tsv` for conversions.

3. **Mutation-name canonicalisation** — TB-Profiler emits `p.Ser450Leu` (HGVS p.); Mykrobe emits `rpoB_S450L` (gene_AA shorthand). Both are well-known; we keep the HGVS p./c. forms from PHA4GE as canonical and let backend-specific shorthand live in `notes`.

4. **`U` (uncertain)** — when a backend reports a variant that is in the catalogue but as "uncertain significance" (WHO Group 3), what is `predicted_phenotype`? Recommend `U` per PHA4GE; some clinicians want a `R-uncertain` distinct from `S` — open for clinical input.

5. **Sample-level summary tier file** — emit it always, or only when ≥ 2 backends + `majority` consensus? Recommend always (single-backend summary still useful; just attribute it to the single backend).

6. **Lineage assignment** — do we emit it as a column on every row, or in a separate `lineage_table.tsv`? Recommend a separate file (lineage is per-sample, not per-drug, so it duplicates poorly in the long-format DR table).

7. **WHO 2024 update** — WHO published an update to the catalogue in late 2024. Pin v2 (2023) or follow the GitHub-tracked catalogue? Recommend pin v2 with `reference_database_version` field, allow override via `--who_catalogue_version`.

---

## 8. What this plan contributes back to the field

- **PHA4GE × TB-specific extension** — first canonical schema layout that unifies the PHA4GE field-name spec, the WHO Catalogue v2 grading, the TB-Profiler native JSON conventions, and the CRyPTIC PREDICTIONS parquet shape. None of the surveyed prior art (§1) has this single-document mapping; the canonical column list in §2 is a small standardisation contribution in itself.
- **TB-ML extended to multi-tool consensus** — TB-ML's containerised-model framework was designed for ML-model swap; we extend the same pattern to rule-based + ML backends being directly comparable, with a consensus layer on top.
- **Canonical adapter contract** — the `bin/<backend>_to_canonical.py` pattern (one parser per tool, identical output schema, validated against a single JSON Schema) makes adding a new backend a self-contained PR that doesn't touch consumer code. Reusable for any future MTBC resistance predictor.

---

## 9. Cross-references

- [`docs/CONTRACT.md`](CONTRACT.md) — current `MTBC_RESISTOTYPER` interface; this plan refines it
- [`docs/RELATED_WORK.md`](RELATED_WORK.md) — funcscan / bacannot / TB-Profiler / MTBseq architectural lineage
- [`docs/VALIDATION.md`](VALIDATION.md) — three integration tiers (T1 / T2 / T3)
- `mtbc-varcaller-nf/docs/OUTPUT_STANDARDIZATION.md` — family-wide CRyPTIC parquet export design
- `mtbc-varcaller-nf/docs/RELATED_WORK.md` — family-level survey
- Family vision: `abc-universe/brainstorms/mtbc-building-blocks/2026-06-30-mtbc-nf-building-block-family.md`
- ML default backend slot: `abc-universe/manuscripts/mtb-resistotyper-ml-manuscript-anchor.md`

### Standards cited

- **PHA4GE / hAMRonization AMR Gene & Variant Specification**: [github.com/pha4ge/hAMRonization](https://github.com/pha4ge/hAMRonization)
- **WHO Catalogue of Mutations in MTBC, 2nd ed (2023)**: [WHO 9789240082410](https://www.who.int/publications/i/item/9789240082410)
- **WHO definitions for TB surveillance (2021)**: [WHO 9789240018662](https://www.who.int/publications/i/item/9789240018662)
- **TB-ML**: Libiseller-Egger J, Wang L, Deelder W, Campino S, Clark TG, Phelan JE. *TB-ML — a framework for comparing machine learning approaches to predict drug resistance of M. tuberculosis.* Bioinformatics Advances 2023;3(1):vbad040. [doi:10.1093/bioadv/vbad040](https://doi.org/10.1093/bioadv/vbad040). PMCID: [PMC10074023](https://pmc.ncbi.nlm.nih.gov/articles/PMC10074023/).
- **TB-Profiler**: Phelan JE et al. *Integrating informatics tools and portable sequencing technology for rapid detection of resistance to anti-tuberculous drugs.* Genome Med 2019;11(1):41. [doi:10.1186/s13073-019-0650-x](https://doi.org/10.1186/s13073-019-0650-x).
- **Mykrobe**: Hunt M et al. *Antibiotic resistance prediction for Mycobacterium tuberculosis from genome sequence data with Mykrobe.* Wellcome Open Res 2019;4:191. [doi:10.12688/wellcomeopenres.15603.1](https://doi.org/10.12688/wellcomeopenres.15603.1).
- **CRyPTIC v3.4.0**: The CRyPTIC Consortium + Fowler P. *The CRyPTIC Consortium Dataset.* Zenodo. [doi:10.5281/zenodo.16041005](https://doi.org/10.5281/zenodo.16041005). CC-BY-4.0.
