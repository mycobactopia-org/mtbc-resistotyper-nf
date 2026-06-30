# mtbc-resistotyper-nf — Validation & Test Strategy

Mirrors the `xbs-variant-calling` validation layering (`xbs-variant-calling/docs/VALIDATION.md`) but with **three integration tiers** because the resistotyper sits downstream of variant callers — failures can originate anywhere in the chain.

---

## The three integration tiers (THE testing surface)

| Tier | What's tested | Where it lives | Cost |
|---|---|---|---|
| **T1: Standalone resistotyper** | Backend (TB-Profiler / Mykrobe / …) runs on a fixed reference VCF and produces the canonical DR table. Catches: module signature mismatch, backend container break, schema parsing drift. | `tests/` in this repo | minutes |
| **T2: XBS → resistotyper chain** | Run XBS standalone on the 3-sample EXIT-RIF set → feed its `snp_filtered` + `indel_filtered` → resistotyper produces expected DR predictions. Catches: XBS-output / resistotyper-input shape drift, merge-adapter (bcftools concat) issues. | `tests/integration/` here + reciprocal stub in `xbs-variant-calling/tests/` | hours (uses XBS's own test profile) |
| **T3: MAGMA → resistotyper chain** | Run MAGMA (post Plan-3 §11, which includes XBS as `gatk_vqsr` substrate) → feed its filtered VCFs → resistotyper. Catches: MAGMA-side wrapping of XBS introducing breakage (the "two test points" the founder flagged). | `tests/integration/` in MAGMA repo + `tests/integration/` here | hours |

**The two test points the founder flagged:**

1. **Test XBS independently** — covered by T1 in `xbs-variant-calling/tests/` + by T2 here (which uses XBS as upstream).
2. **Test XBS again after MAGMA includes it** — covered by T3 here + by MAGMA's own SciVer suite once Plan-3 §11 lands. We want both tests because MAGMA wraps XBS (adds BQSR, picks particular `*_filter_mode` values, threads its samplesheet into XBS) and any of those choices can produce different downstream resistotyper outputs even if XBS itself is unchanged.

If T1 passes but T2 fails → the XBS-to-resistotyper adapter is broken.
If T2 passes but T3 fails → MAGMA's wrapping of XBS is producing different VCFs.
If T1 fails alone → the backend module itself is broken.

---

## Layer 0 — Static (cost ≈ 0; runs in CI)

| Test | What it catches |
|---|---|
| `nextflow lint .` | Syntax, deprecated patterns |
| `nf-core lint` | nf-core conformance |
| `tests/conformance/check_dr_schema.sh` (planned) | Sanity-checks every backend module's `ext.args` to confirm the catalogue version + canonical-schema field-names are pinned |

---

## Layer 1 — T1 standalone backend test (cost ≈ 5 min on a laptop)

The `-profile test` runs the single Phase-1 backend (TB-Profiler) against a **fixed reference VCF** with **known resistance phenotype** and asserts the canonical DR table matches expected output.

Choice of reference VCF for the test (Phase-1):
- Per-sample VCF from one EXIT-RIF sample (PRJNA1026351) with phenotypically-confirmed RIF-R + INH-R
- Tiny — only the SNPs in the WHO catalogue region (~50 records); ships in `resources/test/`

Assertions in `tests/default.nf.test`:
- DR table exists, parses as TSV with the canonical columns
- RIF row: `prediction == 'R'`
- INH row: `prediction == 'R'`
- A known susceptible-drug row (e.g. STR for a non-STR-R isolate): `prediction == 'S'`
- The `mutations` column non-empty for resistant rows

---

## Layer 2 — T2 XBS-upstream integration (cost ≈ 1 h on abc-cluster)

Runs the **XBS test profile** then this resistotyper's test profile on XBS's outputs.

```
# T2 orchestration sketch (lives in tests/integration/t2_xbs_chain.sh):
1. Run XBS:        nextflow run mycobactopia-org/xbs-variant-calling -profile test --outdir xbs-out/
2. Build samplesheet from xbs-out/ paths
3. Run resistotyper: nextflow run . -profile test --input <built samplesheet> --outdir res-out/
4. Assert: res-out/dr_table.tsv has expected resistance calls for the 3 EXIT-RIF samples
```

Why this matters: surfaces shape drift between XBS's `snp_filtered`/`indel_filtered` emit and the resistotyper's `ch_variants` input contract.

Gates: T1 passing. Requires XBS at a tagged release (`v0.3.0+` once `feat/contract-and-magma-flags` lands).

---

## Layer 3 — T3 MAGMA-upstream integration (cost ≈ 2 h on abc-cluster)

After Plan-3 §11 lands MAGMA's XBS integration:

```
1. Run MAGMA on EXIT-RIF test profile (MAGMA already calls XBS internally for the GATK chain)
2. Pull MAGMA's filtered SNP + INDEL VCFs (the *_exc-rRNA outputs after MAGMA's region exclusion)
3. Build samplesheet from MAGMA outputs
4. Run resistotyper: assert DR table matches expected (and matches T2's output — MAGMA's wrapping shouldn't change resistance calls)
```

If T3 disagrees with T2 → MAGMA is wrapping XBS in a way that changes downstream variants. Investigate `bwa_extra_args="-k 100"`, `skip_bqsr=false`, MAGMA's rRNA exclusion, etc.

Gates: T2 passing AND MAGMA Plan-3 §11 integration merged at MAGMA `v0.4.0`.

---

## Reproducibility check (cross-cutting; weekly cron)

Run T1 twice, hash the DR table:

```bash
diff <(sort run1/dr_table.tsv) <(sort run2/dr_table.tsv)
```

Catches non-deterministic backend behavior (TB-Profiler's lineage assignment can be sensitive to read order).

---

## Storage budget

Layer 1: < 100 MB (one reference VCF + reference index + backend container). Fits on a laptop.
Layer 2 + 3: depends on upstream pipeline; the resistotyper portion adds < 50 MB.

---

## Deferred — out of MVP scope (gated on compute / phase)

- **Multi-backend consensus** (TB-Profiler + Mykrobe + SAM-TB + GenTB) — Phase 2
- **CRyPTIC v3.4.0 catalogue overlay** — Phase 2 (using the published Zenodo release; CC-BY only, no DUA)
- **`mtb-resistotyper-ml` backend slot** — Phase 3 (when the ML tool ships as a Bioconda-installable module)
- **Compute-cost table** (T2 + T3 wall-clock + memory) — Phase 3
- **Benchmark against `tb-resistance-prediction-benchmark`** — out of scope here (that's the benchmark repo's job; this repo just provides the runner)
