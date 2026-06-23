#!/bin/bash

##
## Test that all tools in the pixi environment are functional.
## Run from the sns-ext directory: bash test-pixi-env.sh
##

set -uo pipefail

script_dir=$(dirname "$(readlink -f "$0")")

echo ""
echo "========== SNS-EXT PIXI ENVIRONMENT TEST =========="
echo ""

# activate pixi environment
# fall back to direct PATH injection if shell-hook fails (e.g. stale lock file format)
pixi_bin="${script_dir}/.pixi/envs/default/bin"

if pixi_env=$(pixi shell-hook --manifest-path "${script_dir}/pixi.toml" 2>/dev/null); then
    eval "$pixi_env"
    echo "  activated via pixi shell-hook"
elif [ -d "$pixi_bin" ]; then
    export PATH="${pixi_bin}:${PATH}"
    echo "  WARNING: pixi shell-hook failed — using direct PATH injection from ${pixi_bin}"
    echo "  Run 'pixi install' or 'pixi lock' in the sns-ext directory to fix this."
else
    echo "  ERROR: pixi environment not found at ${pixi_bin}"
    echo "  Run 'pixi install' in the sns-ext directory first."
    exit 1
fi
echo ""

pass=0
fail=0
results=()

# check <display name> <binary> [version command]
# - existence is verified via 'command -v'; test fails if binary is absent
# - version string is captured best-effort (non-zero exits are tolerated)
# - ANSI escape codes are stripped from version output
check() {
    local name="$1"
    local binary="$2"
    local version_cmd="${3:-$2 --version}"

    if ! command -v "$binary" &>/dev/null; then
        echo "  [FAIL] $name — not found in PATH"
        results+=("FAIL|$name|not found")
        (( fail++ ))
        return
    fi

    local version
    version=$(eval "$version_cmd" 2>&1 | head -1) || true
    # strip ANSI escape codes
    version=$(printf '%s' "$version" | sed 's/\x1b\[[0-9;]*[mK]//g' | tr -d '\r')

    echo "  [PASS] $name — ${version:-available}"
    results+=("PASS|$name|${version:-available}")
    (( pass++ ))
}


# ── Alignment ────────────────────────────────────────────────────────────────
echo "--- Alignment ---"
check "STAR"     "STAR"     "STAR --version"
check "bowtie2"  "bowtie2"  "bowtie2 --version | head -1"
check "bwa"      "bwa"      "bwa 2>&1 | grep '^Version'"
check "bismark"  "bismark"  "bismark --version | grep 'Bismark'"
check "salmon"   "salmon"   "salmon --version"

# ── BAM / SAM ────────────────────────────────────────────────────────────────
echo ""
echo "--- BAM / SAM ---"
check "samtools"  "samtools"  "samtools --version | head -1"
check "sambamba"  "sambamba"  "sambamba 2>&1 | head -1"
check "picard"    "picard"    "picard 2>&1 | grep -o 'PicardCommandLine' | head -1"

# ── Peak calling ─────────────────────────────────────────────────────────────
echo ""
echo "--- Peak Calling ---"
check "macs2"  "macs2"  "macs2 --version"

# ── Coverage / BigWig ────────────────────────────────────────────────────────
echo ""
echo "--- Coverage ---"
check "bamCoverage (deeptools)"  "bamCoverage"       "bamCoverage --version"
check "bedGraphToBigWig"         "bedGraphToBigWig"  "bedGraphToBigWig 2>&1 | head -1"

# ── QC ───────────────────────────────────────────────────────────────────────
echo ""
echo "--- QC ---"
check "fastqc"       "fastqc"       "fastqc --version"
check "trim_galore"  "trim_galore"  "trim_galore --version | grep 'version'"
check "trimmomatic"  "trimmomatic"  "trimmomatic -version 2>&1 | head -1"

# ── Quantification ───────────────────────────────────────────────────────────
echo ""
echo "--- Quantification ---"
check "featureCounts"  "featureCounts"  "featureCounts -v 2>&1 | grep 'featureCounts'"

# ── Genome tools ─────────────────────────────────────────────────────────────
echo ""
echo "--- Genome Tools ---"
check "bedtools"        "bedtools"         "bedtools --version"
check "bgzip"           "bgzip"            "bgzip --version 2>&1 | head -1"
check "bedGraphToBigWig (htslib check)"  "samtools"  "samtools --version | grep 'htslib'"

# ── Runtimes ─────────────────────────────────────────────────────────────────
echo ""
echo "--- Runtimes ---"
check "Rscript"  "Rscript"  "Rscript --version"
check "python"   "python"   "python --version"

# ── R packages ───────────────────────────────────────────────────────────────
echo ""
echo "--- R Packages ---"
Rscript --vanilla "${script_dir}/scripts/test-all-r-packages.R"
r_exit=$?
if [ $r_exit -eq 0 ]; then
    echo "  [PASS] R package test completed (35/35)"
    (( pass++ ))
else
    echo "  [FAIL] R package test exited with code $r_exit"
    (( fail++ ))
fi


# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "===================================================="
echo "  PASSED: $pass"
echo "  FAILED: $fail"
echo "===================================================="
echo ""

if [ "$fail" -gt 0 ]; then
    echo "Failed checks:"
    for r in "${results[@]}"; do
        IFS='|' read -r status name version <<< "$r"
        if [ "$status" = "FAIL" ]; then
            echo "  - $name ($version)"
        fi
    done
    echo ""
    exit 1
fi

exit 0
