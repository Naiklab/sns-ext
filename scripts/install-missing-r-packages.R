#!/usr/bin/env Rscript

##
## Install missing R packages based on test results
##

# Print R library paths
cat("R library paths:\n")
print(.libPaths())
cat("\n")

# Check if test results file exists
results_file <- "r-package-test-results.csv"
if (!file.exists(results_file)) {
  stop("Error: ", results_file, " not found. Please run test-all-r-packages.R first.")
}

# Read the test results
cat("Reading test results from:", results_file, "\n")
results <- read.csv(results_file, stringsAsFactors = FALSE)

# Filter for failed packages
failed_packages <- results[results$status == "FAILED", "package"]

if (length(failed_packages) == 0) {
  cat("✅ All packages are already installed successfully!\n")
  quit(status = 0)
}

cat("Found", length(failed_packages), "missing packages:\n")
for (pkg in failed_packages) {
  cat("-", pkg, "\n")
}
cat("\n")

# Install BiocManager if not available
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  cat("Installing BiocManager...\n")
  install.packages("BiocManager", repos = "https://cloud.r-project.org")
}

# Function to install packages with better error handling
install_package_safely <- function(pkg_name) {
  cat("Installing", pkg_name, "... ")
  
  tryCatch({
    # Try BiocManager first (works for both CRAN and Bioconductor)
    BiocManager::install(pkg_name, update = FALSE, ask = FALSE)
    
    # Test if installation was successful
    if (requireNamespace(pkg_name, quietly = TRUE)) {
      cat("SUCCESS\n")
      return(TRUE)
    } else {
      cat("FAILED - package not loadable after installation\n")
      return(FALSE)
    }
  }, error = function(e) {
    cat("FAILED -", e$message, "\n")
    return(FALSE)
  })
}

# Install each missing package
installation_results <- data.frame(
  package = character(),
  installation_status = character(),
  stringsAsFactors = FALSE
)

for (pkg in failed_packages) {
  success <- install_package_safely(pkg)
  status <- if (success) "SUCCESS" else "FAILED"
  installation_results <- rbind(installation_results, 
                               data.frame(package = pkg, 
                                        installation_status = status, 
                                        stringsAsFactors = FALSE))
}

# Print summary
cat("\n=== INSTALLATION SUMMARY ===\n")
successful_installs <- sum(installation_results$installation_status == "SUCCESS")
failed_installs <- sum(installation_results$installation_status == "FAILED")

cat("Total packages attempted:", nrow(installation_results), "\n")
cat("Successfully installed:", successful_installs, "\n")
cat("Failed to install:", failed_installs, "\n")

if (failed_installs > 0) {
  cat("\nPackages that failed to install:\n")
  failed_install_pkgs <- installation_results[installation_results$installation_status == "FAILED", "package"]
  for (pkg in failed_install_pkgs) {
    cat("-", pkg, "\n")
  }
  
  cat("\n📝 Manual installation suggestions for failed packages:\n")
  cat("For TxDb packages, try:\n")
  cat("  BiocManager::install('TxDb.Hsapiens.UCSC.hg38.knownGene')\n")
  cat("  BiocManager::install('TxDb.Mmusculus.UCSC.mm10.knownGene')\n")
  cat("\nFor org.db packages, try:\n")
  cat("  BiocManager::install('org.Hs.eg.db')\n")
  cat("  BiocManager::install('org.Mm.eg.db')\n")
  cat("\nFor GO.db package, try:\n")
  cat("  BiocManager::install('GO.db')\n")
}

# Save installation results
install_results_file <- "r-package-installation-results.csv"
write.csv(installation_results, install_results_file, row.names = FALSE)
cat("\nInstallation results saved to:", install_results_file, "\n")

if (successful_installs > 0) {
  cat("\n🎉 Some packages were successfully installed!")
  cat("\n   Run test-all-r-packages.R again to verify all installations.\n")
}

# End