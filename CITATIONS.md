# mycobactopia-org/mtbc-resistotyper-nf: Citations

## [nf-core](https://pubmed.ncbi.nlm.nih.gov/32055031/)

> Ewels PA, Peltzer A, Fillinger S, Patel H, Alneberg J, Wilm A, Garcia MU, Di Tommaso P, Nahnsen S. The nf-core framework for community-curated bioinformatics pipelines. Nat Biotechnol. 2020 Mar;38(3):276-278. doi: 10.1038/s41587-020-0439-x. PubMed PMID: 32055031.

## [Nextflow](https://pubmed.ncbi.nlm.nih.gov/28398311/)

> Di Tommaso P, Chatzou M, Floden EW, Barja PP, Palumbo E, Notredame C. Nextflow enables reproducible computational workflows. Nat Biotechnol. 2017 Apr 11;35(4):316-319. doi: 10.1038/nbt.3820. PubMed PMID: 28398311.

## Family architecture

- **`mtbc-*-nf` building-block family** (Sharma A et al., in preparation) — the contract this block follows. Vision doc: `abc-universe/brainstorms/mtbc-building-blocks/2026-06-30-mtbc-nf-building-block-family.md`.

## Upstream variant callers (first integration)

- **[mycobactopia-org/xbs-variant-calling](https://github.com/mycobactopia-org/xbs-variant-calling)** — Heupink 2021 GATK-VQSR caller; Phase-1 default upstream source.

  > Heupink TH, Verboven L, Warren RM, Van Rie A. Comprehensive and accurate genetic variant identification from contaminated and low-coverage *Mycobacterium tuberculosis* whole genome sequencing data. *Microb Genom.* 2021 Nov 18;7(11):000689. doi: 10.1099/mgen.0.000689. PMID: 34793294; PMCID: PMC8743552.

## Resistance prediction backends

### Phase 1 — TB-Profiler (default)

- **[TB-Profiler](https://github.com/jodyphelan/TBProfiler)** (Phelan lab)

  > Phelan JE, O'Sullivan DM, Machado D, Ramos J, Oppong YEA, Campino S, O'Grady J, McNerney R, Hibberd ML, Viveiros M, Huggett JF, Clark TG. Integrating informatics tools and portable sequencing technology for rapid detection of resistance to anti-tuberculous drugs. *Genome Med.* 2019 Jun 24;11(1):41. doi: 10.1186/s13073-019-0650-x. PMID: 31234910; PMCID: PMC6591868.

- **WHO Catalogue of Mutations in *M. tuberculosis* Complex** (v2, 2023) — catalogue applied by TB-Profiler

  > World Health Organization. *Catalogue of mutations in Mycobacterium tuberculosis complex and their association with drug resistance.* 2nd ed. Geneva: WHO; 2023.

### Phase 2 — additional backends (planned)

- **[Mykrobe](https://github.com/Mykrobe-tools/mykrobe)** — Hunt et al. 2019, *Wellcome Open Research*
- **SAM-TB** — Yang et al. 2022
- **GenTB** — Gröschel et al. 2021

### Phase 3 — ML default backend slot

- **[mtb-resistotyper-ml](https://github.com/abhi18av-phd-projects/pub-mtb-resistotyper-ml)** — Sharma A et al., in preparation. Glass-box epistasis in MTB drug resistance using Explainable Boosting Machines on CRyPTIC v3.4.0. Anchor: `abc-universe/manuscripts/mtb-resistotyper-ml-manuscript-anchor.md`.

## Reference data

- **CRyPTIC v3.4.0 dataset** (when Phase-2 wires the CRyPTIC catalogue overlay)

  > The CRyPTIC Consortium + Fowler P. *The CRyPTIC Consortium Dataset.* Zenodo v3.4.0, 21 May 2025. doi: [10.5281/zenodo.16041005](https://doi.org/10.5281/zenodo.16041005). Licensed CC-BY-4.0.

## Pipeline tools

## Software packaging/containerisation tools

- [Anaconda](https://anaconda.com)

  > Anaconda Software Distribution. Computer software. Vers. 2-2.4.0. Anaconda, Nov. 2016. Web.

- [Bioconda](https://pubmed.ncbi.nlm.nih.gov/29967506/)

  > Grüning B, Dale R, Sjödin A, Chapman BA, Rowe J, Tomkins-Tinch CH, Valieris R, Köster J; Bioconda Team. Bioconda: sustainable and comprehensive software distribution for the life sciences. Nat Methods. 2018 Jul;15(7):475-476. doi: 10.1038/s41592-018-0046-7. PubMed PMID: 29967506.

- [BioContainers](https://pubmed.ncbi.nlm.nih.gov/28379341/)

  > da Veiga Leprevost F, Grüning B, Aflitos SA, Röst HL, Uszkoreit J, Barsnes H, Vaudel M, Moreno P, Gatto L, Weber J, Bai M, Jimenez RC, Sachsenberg T, Pfeuffer J, Alvarez RV, Griss J, Nesvizhskii AI, Perez-Riverol Y. BioContainers: an open-source and community-driven framework for software standardization. Bioinformatics. 2017 Aug 15;33(16):2580-2582. doi: 10.1093/bioinformatics/btx192. PubMed PMID: 28379341; PubMed Central PMCID: PMC5870671.

- [Docker](https://dl.acm.org/doi/10.5555/2600239.2600241)

  > Merkel, D. (2014). Docker: lightweight linux containers for consistent development and deployment. Linux Journal, 2014(239), 2. doi: 10.5555/2600239.2600241.

- [Singularity](https://pubmed.ncbi.nlm.nih.gov/28494014/)

  > Kurtzer GM, Sochat V, Bauer MW. Singularity: Scientific containers for mobility of compute. PLoS One. 2017 May 11;12(5):e0177459. doi: 10.1371/journal.pone.0177459. eCollection 2017. PubMed PMID: 28494014; PubMed Central PMCID: PMC5426675.
