#!/usr/bin/env Rscript

# Test script to verify all R packages load correctly in pixi environment

# Force R to use pixi environment packages + system library paths
pixi_lib = .libPaths()[grep("\\.pixi/envs/default/lib/R/library", .libPaths())]
system_site = "/hpc/packages/minerva-rocky9/rpackages/4.4.1/site-library"
system_bioc = "/hpc/packages/minerva-rocky9/rpackages/bioconductor/3.20"

if (length(pixi_lib) > 0) {
  # Set library paths: pixi first, then system libraries for missing packages
  .libPaths(c(pixi_lib, system_site, system_bioc))
  message("Using R libraries:")
  message("  1. Pixi environment: ", pixi_lib)
  message("  2. System site library: ", system_site)
  message("  3. System Bioconductor: ", system_bioc)
} else {
  warning("Could not find pixi R library in .libPaths()")
  .libPaths(c(.libPaths(), system_site, system_bioc))
}

message("")
message("R library paths: ", paste(.libPaths(), collapse = "; "))
message("")

# List of all packages to test
packages_to_test = c(
  # Data manipulation
  "magrittr", "tibble", "dplyr", "tidyr", "readr", "glue", "stringr",
  
  # Differential expression
  "DESeq2", "ashr",
  
  # GTF processing
  "rtracklayer",
  
  # Export
  "writexl",
  
  # Plotting
  "RColorBrewer", "ggplot2", "ggrepel", "cowplot", "pheatmap",
  
  # Gene set enrichment
  "msigdbr", "fgsea",
  
  # Session info
  "sessioninfo"
)

message("Testing package loading...")
message(paste(rep("=", 60), collapse = ""))

failed_packages = c()
loaded_packages = c()

for (pkg in packages_to_test) {
  tryCatch({
    suppressPackageStartupMessages(library(pkg, character.only = TRUE))
    loaded_packages = c(loaded_packages, pkg)
    message(sprintf("✓ %s loaded successfully", pkg))
  }, error = function(e) {
    failed_packages = c(failed_packages, pkg)
    message(sprintf("✗ %s FAILED: %s", pkg, e$message))
  })
}

message("")
message(paste(rep("=", 60), collapse = ""))
message(sprintf("Results: %d/%d packages loaded successfully", 
                length(loaded_packages), length(packages_to_test)))

if (length(failed_packages) > 0) {
  message("")
  message("Failed packages:")
  for (pkg in failed_packages) {
    message("  - ", pkg)
  }
  quit(status = 1)
} else {
  message("")
  message("All packages loaded successfully! ✓")
  message("")
  message("R version:")
  print(R.version.string)
  message("")
  message("Key package versions:")
  message("  DESeq2: ", packageVersion("DESeq2"))
  message("  rtracklayer: ", packageVersion("rtracklayer"))
  quit(status = 0)
}
