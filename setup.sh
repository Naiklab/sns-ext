#!/bin/bash

##
## SNS-EXT setup script for Minerva HPC.
## Run once per user account after cloning the repository.
##
## Usage: bash setup.sh
##

set -uo pipefail

SNS_DIR=$(dirname "$(readlink -f "$0")")

echo ""
echo "=========================================="
echo "  SNS-EXT SETUP"
echo "=========================================="
echo ""

# ── Prerequisite checks ───────────────────────────────────────────────────────

# Check pixi is installed
if ! command -v pixi &>/dev/null; then
    echo "ERROR: pixi is not installed or not in PATH."
    echo ""
    echo "Install pixi first:"
    echo "  curl -fsSL https://pixi.sh/install.sh | bash"
    echo "  source ~/.bashrc"
    echo ""
    exit 1
fi

# Warn if running on a login node (hostname starts with li or lc on Minerva)
hostname=$(hostname -s)
if [[ "$hostname" =~ ^(li|lc) ]]; then
    echo "WARNING: You appear to be on a login node ($hostname)."
    echo "  pixi install downloads ~10-20 GB and should run on a compute node."
    echo ""
    echo "  Allocate an interactive job first:"
    echo "    bsub -Is -P <account> -q premium -n 4 -W 4:00 -R 'rusage[mem=64000]' -R span[hosts=1] bash"
    echo ""
    read -r -p "Continue anyway? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        exit 0
    fi
    echo ""
fi

# Warn if proxies module is not loaded (needed for internet access on compute nodes)
if ! module list 2>&1 | grep -q proxies; then
    echo "WARNING: The 'proxies' module does not appear to be loaded."
    echo "  Internet access is required for pixi install."
    echo "  Load it with: module load proxies"
    echo ""
    read -r -p "Continue anyway? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        exit 0
    fi
    echo ""
fi

# ── Collect user inputs ───────────────────────────────────────────────────────

echo "This script will configure your pixi environment and install all"
echo "pipeline dependencies. It needs two pieces of information from you."
echo ""

# 1. LSF project account
echo "--- Step 1 of 2: LSF Project Account ---"
echo ""
echo "  Your LSF project account is used to submit jobs to the Minerva cluster."
echo "  It is typically in the format: acc_<labname>"
echo "  Example: acc_naiklab"
echo ""
read -r -p "  Enter your LSF project account: " lsf_account
if [[ -z "$lsf_account" ]]; then
    echo "ERROR: LSF project account cannot be empty."
    exit 1
fi
echo ""

# 2. Project directory
echo "--- Step 2 of 2: Project Directory ---"
echo ""
echo "  Your project directory is the base folder in Minerva's project space"
echo "  where your data, reference files, and pipeline cache will be stored."
echo "  It should be a path under /sc/arion/projects/."
echo "  Example: /sc/arion/projects/naiklab/\$USER"
echo ""
read -r -p "  Enter your project directory: " project_dir
if [[ -z "$project_dir" ]]; then
    echo "ERROR: Project directory cannot be empty."
    exit 1
fi
if [[ ! -d "$project_dir" ]]; then
    echo "ERROR: Directory does not exist: $project_dir"
    echo "  Please create it first or check the path."
    exit 1
fi
project_dir=$(readlink -f "$project_dir")
echo ""

# ── Summary and confirmation ──────────────────────────────────────────────────

pixi_cache_dir="${project_dir}/pixi-cache"

echo "=========================================="
echo "  SETUP SUMMARY"
echo "=========================================="
echo ""
echo "  SNS-EXT location : $SNS_DIR"
echo "  LSF account      : $lsf_account"
echo "  Project directory: $project_dir"
echo "  Pixi cache       : $pixi_cache_dir"
echo "  Pixi config      : ~/.config/pixi/config.toml"
echo ""
read -r -p "Proceed with setup? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi
echo ""

# ── Configure pixi cache ──────────────────────────────────────────────────────

echo "--- Configuring pixi cache ---"

mkdir -p "$pixi_cache_dir"

mkdir -p ~/.config/pixi
existing_root=$(pixi config get cache.root --global 2>/dev/null || true)
if [[ -n "$existing_root" ]]; then
    echo "  cache.root already set to: $existing_root"
    echo "  Leaving it unchanged."
else
    pixi config set --global cache.root "$pixi_cache_dir"
    echo "  Set cache.root = $pixi_cache_dir"
fi
echo ""

# ── Write run config for the pipeline ────────────────────────────────────────

run_config="${SNS_DIR}/.run-config"
cat > "$run_config" << EOF
LSF_ACCOUNT=${lsf_account}
PROJECT_DIR=${project_dir}
EOF
echo "--- Saved pipeline config to .run-config ---"
echo "  LSF_ACCOUNT=${lsf_account}"
echo "  PROJECT_DIR=${project_dir}"
echo ""

# ── Enable post-link scripts ──────────────────────────────────────────────────

# Required for Bioconductor annotation packages (org.Mm.eg.db, TxDb.*) to install correctly.
# These packages use post-link scripts to create SQLite databases — without this they are
# silently absent from the R library after pixi install.
echo "--- Enabling post-link scripts ---"
pixi config set --local run-post-link-scripts insecure --manifest-path "${SNS_DIR}/pixi.toml"
echo "  Done."
echo ""

# ── Install pixi environment ──────────────────────────────────────────────────

echo "--- Installing pixi environment ---"
echo "  This will download and install all pipeline dependencies (~10-20 GB)."
echo "  This may take 10-30 minutes depending on network speed."
echo ""

if ! pixi install --manifest-path "${SNS_DIR}/pixi.toml"; then
    echo ""
    echo "ERROR: pixi install failed."
    echo "  If you see 'failed to collect prefix records', run:"
    echo "    pixi clean && pixi install"
    echo "  If you see 'Quota exceeded', check that your pixi cache is set correctly:"
    echo "    cat ~/.config/pixi/config.toml"
    exit 1
fi
echo ""

# ── Set permissions ───────────────────────────────────────────────────────────

echo "--- Setting script permissions ---"
chmod -R 755 "$SNS_DIR"
echo "  Done."
echo ""

# ── Install annotation packages via BiocManager ───────────────────────────────

# These Bioconductor annotation packages (large SQLite databases) are not reliably
# installed by pixi's post-link scripts on Lustre/network filesystems. BiocManager
# installs them directly into the pixi R library as a reliable alternative.
echo "--- Installing Bioconductor annotation packages ---"
pixi_r_lib="${SNS_DIR}/.pixi/envs/default/lib/R/library"
pixi run --manifest-path "${SNS_DIR}/pixi.toml" Rscript --vanilla -e "
  pixi_lib <- '${pixi_r_lib}'
  pkgs <- c('org.Mm.eg.db', 'TxDb.Hsapiens.UCSC.hg38.knownGene', 'TxDb.Mmusculus.UCSC.mm10.knownGene')
  missing <- pkgs[!sapply(pkgs, requireNamespace, quietly = TRUE)]
  if (length(missing) > 0) {
    message('Installing: ', paste(missing, collapse = ', '))
    BiocManager::install(missing, lib = pixi_lib, update = FALSE, ask = FALSE, force = TRUE)
  } else {
    message('All annotation packages already installed.')
  }
" 2>&1
echo ""

# ── Verify environment ────────────────────────────────────────────────────────

echo "--- Verifying environment ---"
echo ""
if bash "${SNS_DIR}/test-pixi-env.sh"; then
    echo ""
    echo "=========================================="
    echo "  SETUP COMPLETE"
    echo "=========================================="
    echo ""
    echo "  To run the pipeline:"
    echo "    cd /path/to/your/project"
    echo "    ${SNS_DIR}/generate-settings hg38   # or mm10"
    echo "    ${SNS_DIR}/gather-fastqs /path/to/fastqs"
    echo "    ${SNS_DIR}/run rna-star"
    echo ""
else
    echo ""
    echo "=========================================="
    echo "  SETUP COMPLETED WITH WARNINGS"
    echo "=========================================="
    echo ""
    echo "  Some environment checks failed — see output above."
    echo "  The pipeline may not work correctly until these are resolved."
    echo ""
    exit 1
fi
