#!/usr/bin/env Rscript


##
## Try loading an R package. Install to local user library if not present.
## This standalone script allows for basic package management without modifying any code that requires those packages.
##
## usage: Rscript --vanilla test-package.R package
##

# Force R to use pixi environment packages + system library paths
pixi_lib = .libPaths()[grep("\\.pixi/envs/default/lib/R/library", .libPaths())]
system_site = "/hpc/packages/minerva-rocky9/rpackages/4.4.1/site-library"
system_bioc = "/hpc/packages/minerva-rocky9/rpackages/bioconductor/3.20"
if (length(pixi_lib) > 0) {
  .libPaths(c(pixi_lib, system_site, system_bioc))
}

# get scripts directory (directory of this file) to add load_install_packages() function
args_all = commandArgs(trailingOnly = FALSE)
scripts_dir = normalizePath(dirname(sub("^--file=", "", args_all[grep("^--file=", args_all)])))
source(paste0(scripts_dir, "/load-install-packages.R"))

# relevant arguments
args = commandArgs(trailingOnly = TRUE)
package_name = args[1]

# check for arguments
if (length(args) < 1) stop("not enough arguments provided")

# load relevant packages
message("checking R package: ", package_name)
load_install_packages(package_name)



# end
