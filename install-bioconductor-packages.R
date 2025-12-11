#!/usr/bin/env Rscript

##
## Install TxDb packages for R 4.4 in pixi environment
##

# Force R to use pixi environment packages + system library paths
pixi_lib = .libPaths()[grep("\\.pixi/envs/default/lib/R/library", .libPaths())]
system_site = "/hpc/packages/minerva-rocky9/rpackages/4.4.1/site-library"
system_bioc = "/hpc/packages/minerva-rocky9/rpackages/bioconductor/3.20"

if (length(pixi_lib) > 0) {
  .libPaths(c(pixi_lib, system_site, system_bioc))
  message("Using R libraries:")
  message("  1. Pixi environment: ", pixi_lib)
  message("  2. System site library: ", system_site)
  message("  3. System Bioconductor: ", system_bioc)
} else {
  stop("Could not find pixi R library")
}

message("")
message("Current R version: ", R.version.string)
message("")

# Ensure BiocManager is available
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager", lib = pixi_lib)
}

library(BiocManager)

# Set Bioconductor version to 3.20 (compatible with R 4.4)
message("Setting Bioconductor version to 3.20...")
BiocManager::install(version = "3.20", ask = FALSE, update = FALSE)
message("BiocManager version: ", BiocManager::version())
message("")

# Bioconductor packages to install
bioc_packages = c(
  "TxDb.Hsapiens.UCSC.hg38.knownGene",
  "TxDb.Mmusculus.UCSC.mm10.knownGene",
  "org.Hs.eg.db",
  "org.Mm.eg.db",
  "batchtma"
)

message("============================================================")
message("Installing Bioconductor packages")
message("============================================================")
message("")

for (pkg in bioc_packages) {
  message(sprintf("Checking package: %s", pkg))
  
  # Check if already available in any library path
  if (requireNamespace(pkg, quietly = TRUE)) {
    message(sprintf("  ✓ %s already available", pkg))
    library(pkg, character.only = TRUE)
    message(sprintf("  Version: %s", packageVersion(pkg)))
  } else {
    message(sprintf("  Installing %s to pixi environment...", pkg))
    tryCatch({
      BiocManager::install(pkg, lib = pixi_lib, update = FALSE, ask = FALSE)
      if (requireNamespace(pkg, quietly = TRUE)) {
        library(pkg, character.only = TRUE)
        message(sprintf("  ✓ Successfully installed %s", pkg))
        message(sprintf("  Version: %s", packageVersion(pkg)))
      } else {
        message(sprintf("  ✗ Failed to install %s", pkg))
      }
    }, error = function(e) {
      message(sprintf("  ✗ Error installing %s: %s", pkg, e$message))
    })
  }
  message("")
}

message("============================================================")
message("Installation complete")
message("============================================================")
