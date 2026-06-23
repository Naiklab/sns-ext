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

```bash
# Clone the repository (development branch)
git clone -b development https://github.com/Naiklab/sns-ext.git
cd sns-ext

# Allocate a bash interactive job for installation step (Please edit the project to match your project account)
bsub -Is -P  <add-project-account> -q premium -n 4 -W 24:00 -R 'rusage[mem=64000]' -R span[hosts=1] bash

#Load Proxies module to enable internet access
module load proxies

# IMPORTANT: Redirect pixi cache to your project space to avoid home directory quota issues.
# Pixi downloads large packages (~several GB) into ~/.cache/rattler by default, which will
# exceed the home directory quota on Minerva. Set PIXI_CACHE_DIR before running pixi install.
export PIXI_CACHE_DIR=/sc/arion/projects/<your-project-dir>/.pixi-cache

# Install all dependencies using pixi
pixi install

# Make scripts executable
chmod -R 777 /path/to/your/sns-ext
```

> **Note**: Add `export PIXI_CACHE_DIR=/sc/arion/projects/<your-project-dir>/.pixi-cache` to your
> `~/.bashrc` so you don't need to set it every session. The cache can be 10–20 GB, so project
> space is the right home for it on Minerva.

### Troubleshooting: "Quota exceeded" during `pixi install`

If you see an error like:
```
Error: × failed to fetch qt6-main-...conda
  ╰─▶ Quota exceeded (os error 122)
```

Your home directory (`/hpc/users/<username>/`) has hit its disk quota. Pixi's package cache
defaults to `~/.cache/rattler/`, which can grow to 10–20 GB during installation.

**Fix**: Point the cache to your project space (which has a much larger quota):

```bash
# Set cache location to your project directory
export PIXI_CACHE_DIR=/sc/arion/projects/<your-project-dir>/.pixi-cache

# Optional: clear any partial cache from the failed attempt
rm -rf ~/.cache/rattler

# Retry installation
pixi install
```

To make this permanent, add the export line to your `~/.bashrc`:

```bash
echo 'export PIXI_CACHE_DIR=/sc/arion/projects/<your-project-dir>/.pixi-cache' >> ~/.bashrc
source ~/.bashrc
```

## Quick Start

1. **Activate pixi environment** (required before running any pipeline commands):

   ```bash
   cd /path/to/your/sns-ext
   eval "$(pixi shell-hook)"
   ```

2. **Generate project settings**:

   ```bash
   /path/to/your/sns-ext/generate-settings <Genome>
   ```

## Genome Configuration Options

| Genome Build | Description |
|-------|-------------|
| `mm10` | Mouse genome (GRCm38/mm10) - for mouse/murine samples |
| `hg38` | Human genome (GRCh38/hg38) - for human samples |

3. **Gather FASTQ files**:

   ```bash
   /path/to/your/sns-ext/gather-fastqs /path/to/fastq/directory
   ```

4. **Run analysis pipeline**:

   ```bash
   /path/to/your/sns-ext/run [route]
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

## Testing R Package Environment

To verify that all required R packages are properly installed and accessible, use the comprehensive testing script:

```bash

# Allocate a bash interactive job for testing (Please edit the project to match your project account)
bsub -Is -P  <add-project-account> -q premium -n 4 -W 2:00 -R 'rusage[mem=32000]' -R span[hosts=1] bash

#Load Proxies module to enable internet access
module load proxies

# Navigate to your SNS-EXT project directory
cd /path/to/your/sns-ext

# Activate the pixi environment and run the R package test
eval "$(pixi shell-hook)"

# For missing Bioconductor packages, run the following command
Rscript install-bioconductor-packages.R

# Test run to check if all packages are installed and can be loaded successfully
Rscript test-load-install-packages.R


```

This script will:
- ✅ Test all required R and Bioconductor packages
- 📍 Show the installation location of each package using `find.package()`
- 📊 Generate a summary report with success/failure status
- 💾 Save detailed results to `r-package-test-results.csv`

**Key packages tested include:**
- **Bioconductor**: DESeq2, DiffBind, ChIPseeker, org.Hs.eg.db, org.Mm.eg.db
- **TxDb packages**: TxDb.Hsapiens.UCSC.hg38.knownGene, TxDb.Mmusculus.UCSC.mm10.knownGene
- **CRAN packages**: tidyverse, ggplot2, pheatmap, BiocManager

**Installing missing packages:**

If the test reveals missing packages, use the automated installation script:

```bash
# After running the test script above, install missing packages
Rscript scripts/install-missing-r-packages.R

# Verify the installations worked by running the test again
Rscript scripts/test-all-r-packages.R
```

The installation script will:
- 🔍 Read the test results from `r-package-test-results.csv`
- 📦 Automatically install all missing packages using BiocManager
- ✅ Verify each installation by testing if the package loads
- 📊 Generate an installation report in `r-package-installation-results.csv`
- 💡 Provide manual installation suggestions for problematic packages

**Troubleshooting missing packages:**
- Check if packages are listed in `pixi.toml`
- Reinstall pixi environment: `pixi install`
- For packages not available via conda, they can be installed directly in R using BiocManager
- Some packages (like TxDb databases) may need manual installation due to conda availability

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
