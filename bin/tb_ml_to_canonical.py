#!/usr/bin/env python3
"""
tb_ml_to_canonical.py — convert TB-ML predictor output to the PHA4GE-aligned
canonical resistance-report TSV used by mtbc-resistotyper-nf.

Per docs/BACKEND_WIRING_PLAN.md §2, the canonical schema is long-format —
one row per (sample, drug, backend) — with these columns:

    sample_id                              study_id
    antimicrobial_agent                    drug_class
    predicted_phenotype                    predicted_phenotype_confidence_level
    who_catalogue_grade                    lineage
    evidence_mutations                     evidence_genes
    analysis_software_name                 analysis_software_version
    reference_database_name                reference_database_version
    reference_accession
    coverage_depth_mean                    coverage_breadth
    notes

Each TB-ML predictor outputs its own format. This script holds per-adapter
parsers, dispatched on --adapter-id. Phase-1 default: tb_amr_cnn.

Usage:
    tb_ml_to_canonical.py \\
        --adapter-id tb_amr_cnn \\
        --sample-id  EXITRIF.SRR26331590 \\
        --study-id   EXITRIF \\
        --backend                tb_ml:tb_amr_cnn \\
        --backend-version        v0.7.0 \\
        --catalogue-name         TB-AMR-CNN_neural_net_v0.7.0 \\
        --catalogue-version      v0.7.0 \\
        --predictor-image        julibeg/tb-ml-neural-net-...:v0.7.0 \\
        --stdout                 stdout.txt \\
        [--predictions predictions.csv] \\
        --output                 EXITRIF.SRR26331590.tb_amr_cnn.dr.tsv
"""
import argparse
import csv
import sys
from pathlib import Path


# PHA4GE-aligned canonical column list (see docs/BACKEND_WIRING_PLAN.md §2.1)
CANONICAL_COLUMNS = [
    "sample_id",
    "study_id",
    "antimicrobial_agent",
    "drug_class",
    "predicted_phenotype",
    "predicted_phenotype_confidence_level",
    "who_catalogue_grade",
    "lineage",
    "evidence_mutations",
    "evidence_genes",
    "analysis_software_name",
    "analysis_software_version",
    "reference_database_name",
    "reference_database_version",
    "reference_accession",
    "coverage_depth_mean",
    "coverage_breadth",
    "notes",
]


# Drug-class lookup (first-line vs second-line vs new/repurposed).
# Drawn from WHO TB drug classifications — see docs/BACKEND_WIRING_PLAN.md.
DRUG_CLASS = {
    "rifampicin":   "first_line",
    "isoniazid":    "first_line",
    "ethambutol":   "first_line",
    "pyrazinamide": "first_line",
    "streptomycin": "first_line",
    "amikacin":         "second_line",
    "capreomycin":      "second_line",
    "kanamycin":        "second_line",
    "ethionamide":      "second_line",
    "levofloxacin":     "second_line",
    "moxifloxacin":     "second_line",
    "ofloxacin":        "second_line",
    "linezolid":        "new_repurposed",
    "bedaquiline":      "new_repurposed",
    "clofazimine":      "new_repurposed",
    "delamanid":        "new_repurposed",
    "pretomanid":       "new_repurposed",
}


def normalise_phenotype(s):
    """Convert various backend phenotype strings to canonical R/S/U enum."""
    if s is None:
        return "U"
    s = str(s).strip().lower()
    if s in ("r", "resistant", "1", "true"):
        return "R"
    if s in ("s", "susceptible", "0", "false"):
        return "S"
    return "U"


def normalise_drug_name(s):
    """Lowercase, strip; canonical lowercase Latin name. Conservative —
    a fuller lookup table can live in assets/drug_names.tsv (Phase 1.1)."""
    if s is None:
        return ""
    return str(s).strip().lower()


# =============================================================================
# Per-adapter parsers
# Each returns a list of dicts (one per drug) with the columns the predictor
# can populate; the generic emit() function stamps the rest from CLI args.
# =============================================================================

def parse_tb_amr_cnn(stdout_path, predictions_path):
    """TB-AMR-CNN — 13 drugs; predictor writes per-drug R/S to stdout AND/OR a
    predictions.csv. Convention (per julibeg/tb-ml-neural-net-...): one row per
    drug with columns `drug` and `prediction` (0/1)."""
    rows = []
    src = predictions_path if predictions_path and predictions_path.exists() else stdout_path
    if not src.exists():
        return rows
    with src.open() as f:
        # Try CSV with header first; fall back to whitespace-delimited.
        reader = csv.DictReader(f)
        for r in reader:
            keys_lower = {k.lower(): v for k, v in r.items()}
            drug = keys_lower.get("drug") or keys_lower.get("antimicrobial_agent")
            pred = keys_lower.get("prediction") or keys_lower.get("predicted_phenotype")
            if drug is None:
                continue
            rows.append({
                "antimicrobial_agent": normalise_drug_name(drug),
                "predicted_phenotype": normalise_phenotype(pred),
                "predicted_phenotype_confidence_level": "",
                "who_catalogue_grade": "",
                "evidence_mutations": "",
                "evidence_genes": "",
                "notes": "",
            })
    return rows


def parse_rf_streptomycin(stdout_path, predictions_path):
    """RF-streptomycin — single drug; stdout is a single R/S."""
    rows = []
    if stdout_path.exists():
        with stdout_path.open() as f:
            pred = f.read().strip().split()[0] if f.read().strip() else ""
        rows.append({
            "antimicrobial_agent": "streptomycin",
            "predicted_phenotype": normalise_phenotype(pred),
            "predicted_phenotype_confidence_level": "",
            "who_catalogue_grade": "",
            "evidence_mutations": "",
            "evidence_genes": "",
            "notes": "",
        })
    return rows


def parse_generic(stdout_path, predictions_path):
    """Last-resort generic parser: assume predictions.csv has `drug,prediction`."""
    return parse_tb_amr_cnn(stdout_path, predictions_path)


ADAPTERS = {
    "tb_amr_cnn":       parse_tb_amr_cnn,
    "tb_dr_pred_nn":    parse_tb_amr_cnn,
    "aggreen_mtb_cnn":  parse_tb_amr_cnn,
    "rf_streptomycin":  parse_rf_streptomycin,
    # mykrobe wired in a separate parser when its backend lands (parses JSON)
}


# =============================================================================
# Emit canonical TSV
# =============================================================================

def emit_canonical(rows, args, out_path):
    """Stamp every row with the per-sample / per-backend metadata + emit TSV."""
    out_path = Path(out_path)
    with out_path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=CANONICAL_COLUMNS, delimiter="\t")
        w.writeheader()
        for r in rows:
            drug = r.get("antimicrobial_agent", "")
            row = {col: "" for col in CANONICAL_COLUMNS}
            row.update({
                "sample_id":                 args.sample_id,
                "study_id":                  args.study_id,
                "antimicrobial_agent":       drug,
                "drug_class":                DRUG_CLASS.get(drug, ""),
                "predicted_phenotype":       r.get("predicted_phenotype", "U"),
                "predicted_phenotype_confidence_level": r.get("predicted_phenotype_confidence_level", ""),
                "who_catalogue_grade":       r.get("who_catalogue_grade", ""),
                "lineage":                   r.get("lineage", ""),
                "evidence_mutations":        r.get("evidence_mutations", ""),
                "evidence_genes":            r.get("evidence_genes", ""),
                "analysis_software_name":    args.backend,
                "analysis_software_version": args.backend_version,
                "reference_database_name":   args.catalogue_name,
                "reference_database_version": args.catalogue_version,
                "reference_accession":       "NC_000962.3",
                "coverage_depth_mean":       r.get("coverage_depth_mean", ""),
                "coverage_breadth":          r.get("coverage_breadth", ""),
                "notes":                     r.get("notes", ""),
            })
            w.writerow(row)


# =============================================================================
# CLI
# =============================================================================

def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--adapter-id",        required=True, help="Which adapter parser to dispatch on")
    p.add_argument("--sample-id",         required=True)
    p.add_argument("--study-id",          default="na")
    p.add_argument("--backend",           required=True, help="e.g. tb_ml:tb_amr_cnn")
    p.add_argument("--backend-version",   required=True)
    p.add_argument("--catalogue-name",    required=True)
    p.add_argument("--catalogue-version", required=True)
    p.add_argument("--predictor-image",   required=True, help="Recorded in notes for provenance")
    p.add_argument("--stdout",            type=Path, required=True, help="Predictor STDOUT capture file")
    p.add_argument("--predictions",       type=Path, default=None, help="Optional predictions CSV from predictor")
    p.add_argument("--output",            type=Path, required=True, help="Output TSV path")
    args = p.parse_args()

    parser = ADAPTERS.get(args.adapter_id, parse_generic)
    rows = parser(args.stdout, args.predictions)

    if not rows:
        # Always emit at least a header so downstream consumers don't fail on
        # missing file; first row is empty-ish (predicted_phenotype = U).
        rows = [{
            "antimicrobial_agent": "",
            "predicted_phenotype": "U",
            "predicted_phenotype_confidence_level": "",
            "who_catalogue_grade": "",
            "evidence_mutations": "",
            "evidence_genes": "",
            "notes": "no records parsed from predictor output",
        }]

    emit_canonical(rows, args, args.output)
    print(f"emitted {len(rows)} canonical record(s) to {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
