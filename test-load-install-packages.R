#!/usr/bin/env Rscript

##
## Test load-install-packages.R function with key pipeline packages
##

# Force R to use pixi environment packages + system library paths
pixi_lib = .libPaths()[grep("\\.pixi/envs/default/lib/R/library", .libPaths())]
system_site = "/hpc/packages/minerva-rocky9/rpackages/4.4.1/site-library"
system_bioc = "/hpc/packages/minerva-rocky9/rpackages/bioconductor/3.20"
if (length(pixi_lib) > 0) {
  .libPaths(c(pixi_lib, system_site, system_bioc))
}

# Source the load-install-packages script
scripts_dir = "/sc/arion/projects/naiklab/ikjot/test_09_human-data/sns-ext/scripts"
source(paste0(scripts_dir, "/load-install-packages.R"))

message("============================================================")
message("Testing load_install_packages() with key pipeline packages")
message("============================================================")
message("")

# Comprehensive list of ALL packages used in the pipeline scripts
test_packages = c(
  # Tidyverse/data manipulation
  "tidyverse",
  "magrittr",
  "tibble", 
  "dplyr",
  "tidyr",
  "readr",
  "glue",
  "stringr",
  
  # Bioconductor - Differential Expression
  "DESeq2",
  "ashr",
  "limma",
  "genefilter",
  
  # Bioconductor - Genomics
  "rtracklayer",
  "GenomicRanges",
  
  # Bioconductor - ChIP/ATAC-seq
  "DiffBind",
  "ChIPpeakAnno",
  "ChIPseeker",
  "TxDb.Hsapiens.UCSC.hg38.knownGene",
  "TxDb.Mmusculus.UCSC.mm10.knownGene",
  
  # Bioconductor - Annotations
  "org.Hs.eg.db",
  "org.Mm.eg.db",
  
  # Gene Set Enrichment
  "msigdbr",
  "fgsea",
  "enrichR",
  
  # Plotting
  "ggplot2",
  "ggrepel",
  "cowplot",
  "pheatmap",
  "RColorBrewer",
  "EnhancedVolcano",
  
  # Export
  "writexl",
  
  # Utilities
  "sessioninfo",
  "matrixStats",
  "batchtma"
)

message("Library paths being used:")
for (i in seq_along(.libPaths())) {
  message(sprintf("  %d. %s", i, .libPaths()[i]))
}
message("")

# Test loading packages
tryCatch({
  load_install_packages(test_packages)
  message("")
  message("============================================================")
  message("SUCCESS: All test packages loaded successfully!")
  message("============================================================")
  message("")
  message("Package versions:")
  message(sprintf("  DESeq2:      %s", packageVersion("DESeq2")))
  message(sprintf("  rtracklayer: %s", packageVersion("rtracklayer")))
  message(sprintf("  ggplot2:     %s", packageVersion("ggplot2")))
  quit(status = 0)
}, error = function(e) {
  message("")
  message("============================================================")
  message("ERROR: Package loading failed")
  message("============================================================")
  message(e$message)
  quit(status = 1)
})
