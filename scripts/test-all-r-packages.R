#!/usr/bin/env Rscript

##
## Test and install all R packages needed for SNS-EXT pipeline
##

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

# Print R library paths
cat("\nR library paths:\n")
print(.libPaths())
cat("\n")

# List of all required packages
required_packages <- c(
  # Bioconductor packages
  "DESeq2",
  "DiffBind", 
  "EnhancedVolcano",
  "fgsea",
  "genefilter",
  "GenomeInfoDbData",
  "limma",
  "org.Hs.eg.db",
  "org.Mm.eg.db",
  "ChIPpeakAnno",
  "ChIPseeker",
  "rtracklayer",
  "TxDb.Hsapiens.UCSC.hg38.knownGene",
  "TxDb.Mmusculus.UCSC.mm10.knownGene",
  
  # CRAN packages
  "tidyverse",
  "ggplot2",
  "dplyr",
  "readr",
  "stringr",
  "tibble",
  "tidyr",
  "ggrepel",
  "cowplot",
  "pheatmap",
  "RColorBrewer",
  "magrittr",
  "glue",
  "writexl",
  "msigdbr",
  "enrichR",
  "optparse",
  "mnormt",
  "ashr",
  "BiocManager",
  "devtools"
)

# Test each package
results <- data.frame(
  package = character(),
  status = character(),
  location = character(),
  error = character(),
  stringsAsFactors = FALSE
)

for (pkg in required_packages) {
  cat("Testing package:", pkg, "... ")
  
  tryCatch({
    # Try to load the package
    suppressPackageStartupMessages(library(pkg, character.only = TRUE))
    
    # Get package location
    pkg_location <- tryCatch({
      find.package(pkg)
    }, error = function(e) {
      "Location not found"
    })
    
    cat("OK - Location:", pkg_location, "\n")
    results <- rbind(results, data.frame(package = pkg, status = "OK", location = pkg_location, error = "", stringsAsFactors = FALSE))
  }, error = function(e) {
    cat("FAILED -", e$message, "\n")
    results <<- rbind(results, data.frame(package = pkg, status = "FAILED", location = "Not installed", error = as.character(e$message), stringsAsFactors = FALSE))
  })
}

# Print summary
cat("\n=== SUMMARY ===\n")
cat("Total packages tested:", nrow(results), "\n")
cat("Successful:", sum(results$status == "OK"), "\n")
cat("Failed:", sum(results$status == "FAILED"), "\n")

if (sum(results$status == "FAILED") > 0) {
  cat("\nFailed packages:\n")
  failed_pkgs <- results[results$status == "FAILED", ]
  for (i in 1:nrow(failed_pkgs)) {
    cat("-", failed_pkgs$package[i], ":", failed_pkgs$error[i], "\n")
  }
}

if (sum(results$status == "OK") > 0) {
  cat("\nSuccessful packages and their locations:\n")
  success_pkgs <- results[results$status == "OK", ]
  for (i in 1:nrow(success_pkgs)) {
    cat("-", success_pkgs$package[i], ":", success_pkgs$location[i], "\n")
  }
}

# Save results to file
write.csv(results, "r-package-test-results.csv", row.names = FALSE)
cat("\nResults saved to: r-package-test-results.csv\n")