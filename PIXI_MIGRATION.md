# Pixi Migration Guide for SNS-EXT

This document describes the migration from conda environments to Pixi for the SNS-EXT pipeline.

## What Changed

### Before (Conda)
```bash
# Individual conda environments
conda activate /sc/arion/projects/naiklab/ikjot/conda_envs/atac-star
conda activate /sc/arion/projects/naiklab/ikjot/conda_envs/deeptools
conda activate /sc/arion/projects/naiklab/ikjot/conda_envs/rna-star
module add condaenvs/2023/macs3
```

### After (Pixi)
```bash
# Unified Pixi environments
pixi run -e atac <command>
pixi run -e deeptools <command>
pixi run -e rna <command>
pixi run -e macs3 <command>
```

## Environment Mapping

| Old Conda Environment | New Pixi Environment | Purpose |
|----------------------|---------------------|---------|
| `atac-star` | `atac` | ATAC-seq analysis, sambamba |
| `deeptools` | `deeptools` | BigWig generation |
| `rna-star` | `rna` | RNA-seq analysis, dos2unix |
| `condaenvs/2023/macs3` | `macs3` | MACS3 peak calling |

## Updated Files

The following files were automatically updated:

1. `scripts/fix-csv.sh` - RNA environment
2. `segments/align-bowtie2-atac.sh` - ATAC environment
3. `segments/bam-dedup-sambamba.sh` - ATAC environment
4. `segments/bigwig-deeptools.sh` - DeepTools environment
5. `segments/peaks-macs2.sh` - ATAC environment
6. `segments/peaks-macs3-hmmratac.sh` - MACS3 environment
7. `segments/qc-fastqscreen.sh` - RNA environment

## Installation

### 1. Install Pixi
```bash
curl -fsSL https://pixi.sh/install.sh | bash
# Restart your shell or source your profile
source ~/.bashrc  # or ~/.zshrc
```

### 2. Initialize Environments
```bash
cd /path/to/sns-ext
pixi install
```

### 3. Verify Installation
```bash
# Test each environment
pixi run -e atac sambamba --version
pixi run -e deeptools deeptools --version
pixi run -e rna dos2unix --version
pixi run -e macs3 macs3 --version
```

## Usage Examples

### Running Individual Tools
```bash
# ATAC-seq analysis
pixi run -e atac sambamba markdup input.bam output.bam

# BigWig generation
pixi run -e deeptools bamCoverage -b input.bam -o output.bw

# RNA-seq preprocessing
pixi run -e rna dos2unix file.txt

# Peak calling
pixi run -e macs3 macs3 callpeak -t treatment.bam -c control.bam
```

### Running Complete Workflows
```bash
# Use the complete environment for development
pixi run -e complete ./run rna-star sample-001

# Use specific environments for production
./run rna-star sample-001  # Scripts will use pixi internally
```

## Script Updates Required

The migration script has commented out old conda commands and added Pixi alternatives. You'll need to manually update the scripts to use the new pattern:

### Example Update
**Before:**
```bash
conda activate /sc/arion/projects/naiklab/ikjot/conda_envs/atac-star
sambamba markdup input.bam output.bam
```

**After:**
```bash
# Using Pixi - wrap commands that need the environment
pixi run -e atac sambamba markdup input.bam output.bam
```

## Environment Features

The `pixi.toml` defines several specialized environments:

- **atac**: ATAC-seq tools (bowtie2, sambamba, macs2, picard)
- **rna**: RNA-seq tools (star, salmon, rsem, fastq-screen)
- **deeptools**: Visualization tools (deeptools, pybigwig)
- **macs3**: Peak calling (macs3)
- **complete**: All tools combined (for development)

## Advantages of Pixi

1. **Faster**: More efficient dependency resolution
2. **Reproducible**: Lock files ensure exact versions
3. **Cross-platform**: Works on Linux, macOS, Windows
4. **Project-based**: Environment defined in project directory
5. **Task-based**: Built-in task runner for common operations

## Troubleshooting

### Environment Not Found
```bash
# List available environments
pixi info

# Install missing dependencies
pixi install
```

### Tool Not Available
```bash
# Check what's installed in an environment
pixi list -e atac

# Add missing tools to pixi.toml and reinstall
pixi install
```

### Performance Issues
```bash
# Use solve groups for faster resolution
# Already configured in pixi.toml
```

## Migration Checklist

- [x] Create `pixi.toml` configuration
- [x] Run migration script
- [x] Update conda activation commands
- [ ] Install Pixi
- [ ] Test all environments
- [ ] Update script execution patterns
- [ ] Validate pipeline functionality
- [ ] Update documentation

## Next Steps

1. Install Pixi on Minerva HPC
2. Test environments with sample data
3. Update LSF job submission scripts
4. Train team on new workflow
5. Deprecate old conda environments
