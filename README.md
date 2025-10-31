# SNS-EXT: Seq-N-Slide Extended for Minerva HPC

![Athena Logo](https://img.freepik.com/premium-vector/athena-goddess-line-art-style-logo_440600-1385.jpg?w=1380)

A specialized adaptation of the Seq-N-Slide (SNS) pipeline optimized for Mount Sinai's Minerva High Performance Computing (HPC) environment with LSF job scheduling.

## Overview

SNS-EXT provides automated workflows for common Illumina sequencing-based protocols, including:

- **RNA-seq**: Differential gene expression analysis
- **ChIP-seq**: Chromatin immunoprecipitation sequencing
- **ATAC-seq**: Assay for transposase-accessible chromatin
- **WGBS/RRBS**: Whole genome and reduced representation bisulfite sequencing
- **WES/WGS**: Whole exome/genome variant detection
- **Species identification**: Contaminant screening and quality control

## Installation

```bash
# Clone the repository
git clone https://github.com/Naiklab/sns-ext.git

# Make scripts executable
chmod 777 -R sns-ext/

#Load anaconda3 module
module load anaconda3

#Activate base sns-ext environment
source activate /sc/arion/projects/naiklab/ikjot/conda_envs/sns-ext-base-environment
```

## Quick Start

1. **Generate project settings**:

   ```bash
   sns-ext/generate-settings <genome>
   ```

   - Choose between hg38 (Human) or mm10 (Mouse)

2. **Gather FASTQ files**:

   ```bash
   sns-ext/gather-fastqs /path/to/fastq-directory
   ```

3. **Run analysis pipeline**:

   ```bash
   sns-ext/run [route]
   ```

4. **Run advanced analysis pipeline for RNA-samples**:

   ```bash
   source activate /sc/arion/projects/naiklab/ikjot/conda_envs/r_env
   sns-ext/run rna-star-groups-dge
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

## Dependencies

- LSF job scheduler (Minerva HPC)
- Standard bioinformatics tools (STAR, Salmon, MACS2, etc.)
- R with required packages
- Python with necessary libraries

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

For issues specific to the Minerva adaptation, please open an issue in this repository. For general SNS questions, refer to the [original documentation](https://igordot.github.io/sns).
