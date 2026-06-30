# Related work — prior art informing `mtbc-resistotyper-nf`

Short companion to the family-level survey at `mtbc-varcaller-nf/docs/RELATED_WORK.md` — narrowed to **resistance-prediction-relevant** prior art.

## Primary references

### [nf-core/funcscan](https://github.com/nf-core/funcscan) — *the closest architectural cousin*

funcscan runs multiple AMR / AMP / BGC backends (AMRFinderPlus, RGI, ABRicate, fARGene, DeepARG, AMPlify, comBGC, …) in parallel and aggregates their outputs via **[hAMRonization](https://github.com/pha4ge/hAMRonization)** + **argNorm** onto the **Antibiotic Resistance Ontology (ARO)**. Same parallel-backend pattern we use; the difference is funcscan operates on assembled contigs while we operate on per-sample MTBC variant calls.

**Patterns we adopt verbatim:**
- **Parallel per-backend module wrapping** — exactly our `BACKEND_<name>` pattern (see family `docs/CONTRACT.md`)
- **Optional backend gating** via flags / list (funcscan: `--run_arg_screening`; us: `--backends tbprofiler,mykrobe`)
- **MultiQC integration** for per-tool version + methods aggregation across the cohort (Phase-2 deliverable)

**Patterns to adopt (pending follow-up):**

- 🔄 **Canonical output via hAMRonization / ARO** instead of our custom DR-table schema in `docs/CONTRACT.md`. The current schema (sample / drug / prediction / confidence / mutations / catalogue / backend / backend_version) is **structurally correct** but uses ad-hoc drug names and confidence tiers. Mapping to ARO + hAMRonization makes the output:
  - Drop-in compatible with funcscan-trained downstream tooling
  - Aligned with the PHA4GE community standards
  - Cross-referenceable with downstream variant databases that use ARO

  Phase 1.1 follow-up: revise `docs/CONTRACT.md § dr_table schema` to make hAMRonization the canonical layer; keep the simpler TSV as a derived "user-friendly" view.

### [bacannot](https://github.com/fmalmeida/bacannot) — *parallel-tool aggregation reference*

bacannot runs Prokka, Bakta, AMRFinderPlus, antiSMASH, etc. concurrently and merges outputs into a unified GFF3 / JBrowse track set — but **deliberately avoids cross-tool voting**. It emits everything in parallel and lets downstream consumers interpret disagreements.

**Patterns we adopt:**
- **Parallel tool execution** (same as funcscan)
- **Per-tool container isolation** (avoids dependency conflicts)

**Patterns we diverge from:**
- We **do** support cross-backend consensus voting (see family `docs/CONTRACT.md § Consensus`) — bacannot's "let downstream decide" remains the safer default but our spec mandates testing whether voting beats best-single. If the resistotyper benchmark says no, we fall back to bacannot's pattern.

### [TB-Profiler](https://github.com/jodyphelan/TBProfiler) — *the Phase-1 default backend*

The de-facto standard MTB resistance predictor (Phelan lab, LSHTM). Catalogue-driven (WHO Catalogue v2, 2023). What `mtbc-resistotyper-nf` Phase-1 wraps as a backend module. Already cited in `CITATIONS.md`.

### [TBprofiler-service](https://github.com/jodyphelan/TBProfiler) (anchor: `manuscripts/tbprofiler-service-manuscript-anchor.md`)

The companion service / API around TB-Profiler. Different scope from ours (we're a Nextflow batch pipeline, that's a hosted service) — no architectural overlap, but worth noting for users who want low-latency single-sample resistance prediction rather than batch.

### [TBSeq](https://github.com/ngs-fzb/MTBseq_source) / [MTBseq-nf](https://github.com/dnaiac/mtbseq-nf) — *competitor for the variant-calling-to-resistance chain*

MTBseq includes its own `classifyDR` step. We do not wrap MTBseq's DR module — they're an upstream-pipeline alternative (their variant caller, their DR catalogue, their classifier all coupled together), and the value of `mtbc-resistotyper-nf` is precisely **decoupling** the resistance step so any upstream variant caller (XBS, MAGMA, mtbc-varcaller-nf) can feed it.

The benchmark surface that *compares* MTBseq's predictions to ours lives in `manuscripts/tb-resistance-prediction-benchmark-manuscript-anchor.md` — separate from this block.

## Cross-reference

For the full family-level architectural lineage (Bactopia, nf-core/bacass, nf-core/funcscan, bacannot, and the design decisions that flow from them), see [`mtbc-varcaller-nf/docs/RELATED_WORK.md`](https://github.com/mycobactopia-org/mtbc-varcaller-nf/blob/master/docs/RELATED_WORK.md).

## Pending follow-up logged here (TODO for Phase 1.1)

- [ ] Revise `docs/CONTRACT.md § dr_table schema` to use **hAMRonization / ARO terms** as the canonical layer
- [ ] Install / use the hAMRonization aggregator module (or its Python wrapper) once available as an nf-core module
- [ ] Match `--run_X_screening` ↔ `--backends X` opt-out semantics: choose one consistent pattern across the family
- [ ] Methods text in Phase-1.1 README should explicitly credit funcscan as the architectural cousin and explain the divergence rationale
