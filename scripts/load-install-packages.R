##
## Load packages. If missing, try installing from CRAN and Bioconductor.
##

# Force R to use pixi environment packages + system library paths
pixi_lib = .libPaths()[grep("\\.pixi/envs/default/lib/R/library", .libPaths())]
system_site = "/hpc/packages/minerva-rocky9/rpackages/4.4.1/site-library"
system_bioc = "/hpc/packages/minerva-rocky9/rpackages/bioconductor/3.20"
if (length(pixi_lib) > 0) {
  .libPaths(c(pixi_lib, system_site, system_bioc))
}

load_install_packages = function(package_list) {

  # create local user library path if not present (not present by default)
  r_libs_user_dir = Sys.getenv("R_LIBS_USER")
  if (!dir.exists(r_libs_user_dir)) {
    message("creating local R_LIBS_USER dir: ", r_libs_user_dir)
    dir.create(path = r_libs_user_dir, recursive = TRUE)
  }

  # install BiocManager if missing (used to install other packages)
  if (!requireNamespace("BiocManager", quietly = TRUE)) {
    install.packages("BiocManager", lib = r_libs_user_dir, repos = "https://cloud.r-project.org")
  }

  for (p in package_list) {

    message("loading package: ", p)

    # check if package is installed and try to install if not
    # BiocManager::install() installs both Bioconductor and CRAN packages
    # use require() instead of installed.packages() to check that package is both installed and usable
    if (!suppressPackageStartupMessages(require(p, character.only = TRUE, quietly = TRUE))) {
      message("installing package: ", p)
      BiocManager::install(p, update = FALSE, lib = r_libs_user_dir)
    }

    # package still not available (after CRAN and Bioconductor)
    if (!require(p, character.only = TRUE, quietly = TRUE)) {
      message("package not available on CRAN or Bioconductor: ", p)
    }

    # load package
    suppressPackageStartupMessages(library(p, character.only = TRUE))

  }

}



# end
