# SNS-EXT: Seq-N-Slide Extended for Minerva HPC

![Minerva Logo](assets/minerva-logo-ver2.png)

A specialized adaptation of the Seq-N-Slide (SNS) pipeline optimized for Mount Sinai's Minerva High Performance Computing (HPC) environment with LSF job scheduling.

## Overview

SNS-EXT provides automated workflows for common Illumina sequencing-based protocols, including:

- **RNA-seq**: Differential gene expression analysis
- **ChIP-seq**: Chromatin immunoprecipitation sequencing
- **ATAC-seq**: Assay for transposase-accessible chromatin
- **WGBS/RRBS**: Whole genome and reduced representation bisulfite sequencing
- **WES/WGS**: Whole exome/genome variant detection
- **Species identification**: Contaminant screening and quality control

## Key Features

- ✅ **Minerva-optimized**: Configured for LSF job scheduler and Minerva-specific resources
- ✅ **Modular design**: Individual segments for flexible workflow construction
- ✅ **Quality control**: Comprehensive QC metrics and reporting
- ✅ **Standardized outputs**: Consistent file formats and directory structures
- ✅ **Resource management**: Optimized memory and CPU allocation for HPC environment

## Prerequisites

This pipeline requires **Pixi** for dependency management and environment isolation. Pixi provides reproducible, cross-platform package management using conda-forge packages.

### Install Pixi

Visit the [official Pixi website](https://pixi.sh) for detailed installation instructions, or use the quick install:

```bash
# Quick install (Linux/macOS)
curl -fsSL https://pixi.sh/install.sh | bash

# Restart your shell or source your shell configuration
source ~/.bashrc  # or ~/.zshrc for zsh
```

For more installation options, see: [https://pixi.sh/latest/getting_started/installation/](https://pixi.sh/latest/getting_started/installation/)

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/Naiklab/sns-ext.git
cd sns-ext
```

### 2. Allocate a compute node

`pixi install` downloads ~10–20 GB of packages and must run on a compute node, not a login node. You will need your **LSF project account** (format: `acc_<labname>`) for this and all future job submissions.

```bash
bsub -Is -P <your-lsf-account> -q premium -n 4 -W 4:00 -R 'rusage[mem=64000]' -R span[hosts=1] bash
module load proxies
```

> `module load proxies` is required to enable internet access on Minerva compute nodes.

### 3. Run setup

The setup script will ask you two questions — your **LSF project account** and your **project directory** (the base folder in `/sc/arion/projects/` where your data and pipeline cache will live). It then configures the pixi cache, installs all dependencies, and verifies the environment.

```bash
bash setup.sh
```

The script will prompt:
```
Enter your LSF project account: acc_naiklab
Enter your project directory: /sc/arion/projects/naiklab/myuser
```

Setup takes 10–30 minutes on first run (package downloads). When it completes successfully you will see:

```
==========================================
  SETUP COMPLETE
==========================================
```

### Troubleshooting: "Quota exceeded" or corrupted environment

If `pixi install` fails with a quota or corrupted environment error:

```bash
# Clear any partial cache from the failed attempt
rm -rf ~/.cache/rattler

# Reset the pixi environment and retry
pixi clean && pixi install
```

If `pixi clean` itself fails with permission errors, remove the environment manually:

```bash
chmod -R u+rwX .pixi/envs/default && rm -rf .pixi/envs && pixi install
```

## Quick Start

After setup, all pipeline commands use the `sns-ext` directory as a prefix. In the examples below, replace `/path/to/sns-ext` with your actual clone location.

1. **Create a project settings file** in your analysis directory:

   ```bash
   cd /path/to/your/analysis
   /path/to/sns-ext/generate-settings hg38   # or mm10 for mouse
   ```

   | Genome | Description |
   |--------|-------------|
   | `hg38` | Human genome (GRCh38) |
   | `mm10` | Mouse genome (GRCm39) |

2. **Gather FASTQ files**:

   ```bash
   /path/to/sns-ext/gather-fastqs /path/to/fastq/directory
   ```

3. **Submit the pipeline**:

   ```bash
   /path/to/sns-ext/run <route>
   ```

## Available Routes

| Route | Description |
|-------|-------------|
| `rna-star` | RNA-seq with STAR alignment |
| `rna-salmon` | RNA-seq with Salmon quantification |
| `rna-rsem` | RNA-seq with RSEM quantification |
| `chip` | ChIP-seq analysis |
| `atac` | ATAC-seq analysis |
| `wgbs` | Whole genome bisulfite sequencing |
| `rrbs` | Reduced representation bisulfite sequencing |
| `wes` | Whole exome sequencing |
| `species` | Species identification and contamination screening |

## Directory Structure

```text
sns-ext/
├── routes/           # Main analysis workflows
├── segments/         # Individual processing steps
├── scripts/          # Utility and analysis scripts
├── run              # Main execution script
├── generate-settings # Project configuration utility
└── gather-fastqs    # FASTQ file organization utility
```

## Configuration

The pipeline uses a settings file to configure analysis parameters. Key settings include:

- Reference genome paths
- Tool-specific parameters
- Resource allocation (memory, CPU)
- Output directory structure

## Verifying the Environment

`setup.sh` runs this automatically at the end of installation. If you need to re-verify at any time:

```bash
bash /path/to/sns-ext/test-pixi-env.sh
```

This checks all CLI tools (STAR, bowtie2, samtools, salmon, etc.) and R packages in one pass. A passing run ends with:

```
====================================================
  PASSED: N   FAILED: 0
====================================================
```

If any checks fail, the tool name and error are listed at the bottom. All pipeline dependencies are managed by pixi — if something is missing, `pixi install` in the sns-ext directory is the fix.

## Dependencies

All dependencies are automatically managed by Pixi and include:

- **Pixi package manager** (required - see Prerequisites section)
- **LSF job scheduler** (Minerva HPC)
- **Bioinformatics tools**: STAR, Salmon, MACS2, BWA, Bowtie2, SAMtools, etc.
- **R environment**: R 4.4+ with Bioconductor and CRAN packages
- **Python environment**: Python 3.11+ with data science libraries
- **System tools**: Java, ImageMagick, UCSC utilities

## Repository Information

**Current Repository**: [Naiklab/sns-ext](https://github.com/Naiklab/sns-ext) (development branch)  
**Pixi Documentation**: [https://pixi.sh](https://pixi.sh)

## Original SNS Pipeline

This project is based on the original Seq-N-Slide pipeline:

**GitHub**: [igordot/sns](https://github.com/igordot/sns)  
**Documentation**: [https://igordot.github.io/sns](https://igordot.github.io/sns)  
**DOI**: [![DOI](https://zenodo.org/badge/66501450.svg)](https://zenodo.org/badge/latestdoi/66501450)

## Citation

If you use SNS-EXT in your research, please cite both this adaptation and the original SNS pipeline.

## License

See [LICENSE](LICENSE) file for details.

## Support

For issues specific to this Minerva adaptation, please open an issue in the [development branch](https://github.com/Naiklab/sns-ext/tree/development). For general SNS questions, refer to the [original documentation](https://igordot.github.io/sns).
