#!/usr/bin/env Rscript


##
## Differential gene expression with DESeq2.
##
## usage: Rscript --vanilla dge-deseq2.R genome_build genes.gtf counts.txt groups.csv
##


# increase output width
options(width = 120)
# print warnings as they occur
options(warn = 1)
# java heap size
options(java.parameters = "-Xmx8G")

# get scripts directory (directory of this file) and load relevant functions
args_all = commandArgs(trailingOnly = FALSE)
scripts_dir = normalizePath(dirname(sub("^--file=", "", args_all[grep("^--file=", args_all)])))
# Note: load-install-packages.R not needed - using pixi environment packages directly
source(paste0(scripts_dir, "/deseq2-pca.R"))
source(paste0(scripts_dir, "/deseq2-compare.R"))
source(paste0(scripts_dir, "/plot-volcano.R"))
source(paste0(scripts_dir, "/plot-heatmap.R"))
source(paste0(scripts_dir, "/gse-fgsea.R"))

# relevent arguments
args = commandArgs(trailingOnly = TRUE)
genome_build = args[1]
genes_gtf = args[2]
counts_table_file = args[3]
groups_table_file = args[4]

# check for arguments
if (length(args) < 4) stop("not enough arguments provided")

# check that input files exist
if (!file.exists(counts_table_file)) stop("file does not exist: ", counts_table_file)
if (!file.exists(groups_table_file)) stop("file does not exist: ", groups_table_file)

# create separate directories for certain output files
r_dir = "r-data"
if (!dir.exists(r_dir)) dir.create(r_dir)

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
print(paste0("R library paths: ", paste(.libPaths(), collapse = "; ")))

# for general data manipulation
library("magrittr")
library("tibble")
library("dplyr")
library("tidyr")
library("readr")
library("glue")
library("stringr")

# for differenial expression
library("DESeq2")
library("ashr")
library("genefilter")

# for genomic annotations
library("rtracklayer")
library("GenomicRanges")

# for exporting Excel xlsx files
library("writexl")

# for color scheme
library("RColorBrewer")

# for standard plotting
library("ggplot2")
library("ggrepel")
library("cowplot")

# for heatmaps
library("pheatmap")

# for gene set enrichment (pathways)
library("msigdbr")
library("fgsea")
library("sessioninfo")

message(" ========== import inputs ========== ")

# import counts table
counts_table = read.delim(file = counts_table_file, header = TRUE, row.names = 1, check.names = FALSE, stringsAsFactors = FALSE)
message("input counts table gene num:      ", nrow(counts_table))
message("input counts table sample num:    ", ncol(counts_table))
message("input counts table sample names:  ", toString(colnames(counts_table)))
message("")

# import groups table
groups_table = read.csv(file = groups_table_file, header = TRUE, row.names = 1, colClasses = "factor")
message("sample groups table sample num:   ", nrow(groups_table))
message("sample groups table sample names: ", toString(rownames(groups_table)))
message("sample groups table group names:  ", toString(colnames(groups_table)))
message("")

# check that all samples from the groups table are found in the counts table
diff_samples = setdiff(rownames(groups_table), colnames(counts_table))
if (length(diff_samples)) stop("some samples not in counts table: ", toString(diff_samples))

# subset to samples in groups table (also sets samples to be in the same order)
counts_table = counts_table[, rownames(groups_table)] %>% rownames_to_column(var = "gene")

# Removing pseudo genes
counts_table = counts_table %>% dplyr::filter(!grepl("^Gm", gene) & !grepl("Rik$", gene)) %>% column_to_rownames(var = "gene")

message("subset counts table gene num:     ", nrow(counts_table))
message("subset counts table sample num:   ", ncol(counts_table))
message("")

# group info (use the first column for grouped comparisons)
group_name = colnames(groups_table)[1]
message("group name: ", group_name)
# reorder groups based on the input groups table (alphabetical by default)
group_levels = groups_table[, group_name] %>% as.character() %>% unique()
groups_table[, group_name] = factor(groups_table[, group_name], levels = group_levels)
message("group levels: ", toString(group_levels))
message("")

# design formula
design_formula = formula(glue("~ {group_name}"))
if (length(group_levels) == 1) { design_formula = formula("~ 1") }
message("design formula: ", design_formula)

message(" ========== import GTF genes annotations ========== ")

# import GTF using rtracklayer
genes_gr = rtracklayer::import(genes_gtf)
message("GTF total entries:      ", length(genes_gr))

# genes list (remove genes without a "gene_name" since they can't be properly identified)
genes_gr = subset(genes_gr, type == "gene" & !is.na(gene_name))
genes_gr = genes_gr[!duplicated(genes_gr$gene_name)]
names(genes_gr) = genes_gr$gene_name
genes_gr = sortSeqlevels(genes_gr)
genes_gr = sort(genes_gr)
message("GTF num genes:          ", length(genes_gr))
message("GTF gene names:         ", toString(names(genes_gr)[1:4]))
message("GTF gene IDs:           ", toString(genes_gr$gene_id[1:4]))
message("")

# export gene info table
genes_tbl = genes_gr %>% as.data.frame()
genes_tbl = genes_tbl %>% select(gene_name, gene_id, chr = seqnames, start, end, strand, gene_type)
write_csv(genes_tbl, "genes.csv")

# extract exons for gene length calculations (for TPM/FPKM)
exons_gr = rtracklayer::import(genes_gtf)
exons_gr = subset(exons_gr, type == "exon" & !is.na(gene_name))
message("GTF num exons:          ", length(exons_gr))

# get gene lengths as the sum of non-overlapping exon lengths for each gene
exons_gr_list = split(exons_gr, exons_gr$gene_name)
exons_gr_merged = GenomicRanges::reduce(exons_gr_list)
gene_lengths = sum(width(exons_gr_merged))
message("GTF num genes w/ length info: ", length(gene_lengths))
message("GTF mean gene length:   ", round(mean(gene_lengths), 2))
message("GTF median gene length: ", median(gene_lengths))
message("")

message(" ========== normalize ========== ")

# import raw counts and create DESeq object
# since v1.16 (11/2016), betaPrior is set to FALSE and shrunken LFCs are obtained afterwards using lfcShrink
dds = DESeqDataSetFromMatrix(countData = counts_table, colData = groups_table, design = design_formula)
dds = DESeq(dds, parallel = FALSE)

# Check gene lengths coverage (gene_lengths will be used later for TPM calculation)
genes_in_dds = rownames(dds)
genes_with_length = intersect(genes_in_dds, names(gene_lengths))
message("Genes in DDS:                  ", length(genes_in_dds))
message("Genes with length info:        ", length(genes_with_length))
message("Genes missing length info:     ", length(genes_in_dds) - length(genes_with_length))

# VST
vsd = varianceStabilizingTransformation(dds, blind = TRUE)

message(" ========== save data ========== ")

# save session information
#sessioninfo::session_info(to_file = paste("r-data/session-info.txt"))

# save DESeqDataSet and VST DESeqTransform objects
saveRDS(dds, file = paste0("r-data/deseq2.dds.rds"))
saveRDS(vsd, file = paste0("r-data/deseq2.vsd.rds"))
Sys.sleep(1)

message(" ========== export counts ========== ")

# export counts
raw_counts_table = counts(dds, normalized = FALSE) %>% as_tibble(rownames = "gene")
write_csv(raw_counts_table, "counts.raw.csv.gz")
norm_counts_table = counts(dds, normalized = TRUE) %>% round(3) %>% as_tibble(rownames = "gene")
write_csv(norm_counts_table, "counts.normalized.csv.gz")
write_xlsx(list(normalized_counts = norm_counts_table), "counts.normalized.xlsx")
Sys.sleep(1)

# export average counts per group
if (length(group_levels) > 1) {
  norm_counts_mat = counts(dds, normalized = TRUE)
  norm_counts_table = sapply(group_levels, function(x) rowMeans(norm_counts_mat[, colData(dds)[, group_name] == x, drop = FALSE]))
  norm_counts_table = norm_counts_table %>% round(3) %>% as_tibble(rownames = "gene")
  write_csv(norm_counts_table, glue("counts.normalized.{group_name}.csv"))
  Sys.sleep(1)
}

# export FPMs/CPMs (fragments/counts per million mapped fragments)
# robust version uses size factors to normalize rather than taking the column sums of the raw counts
# not using the robust median ratio method to generate the classic values (comparable across experiments)
cpm_matrix = fpm(dds, robust = FALSE)
cpm_table = cpm_matrix %>% round(3) %>% as_tibble(rownames = "gene")
write_csv(cpm_table, "counts.cpm.csv.gz")
write_xlsx(list(CPMs = cpm_table), "counts.cpm.xlsx")
Sys.sleep(1)

# Calculate TPMs directly from normalized counts and gene lengths
# TPM = (count / gene_length) * 1e6 / sum(count / gene_length)
norm_counts_mat = counts(dds, normalized = TRUE)

# Subset gene_lengths to match genes in dds
gene_lengths_subset = gene_lengths[rownames(norm_counts_mat)]

# Calculate TPM for genes with known lengths
tpm_matrix = apply(norm_counts_mat, 2, function(counts_col) {
  # Divide by gene length (in kb) 
  rpk = counts_col / (gene_lengths_subset / 1000)
  # Normalize to per million
  tpm = rpk / sum(rpk, na.rm = TRUE) * 1e6
  return(tpm)
})

tpm_table = tpm_matrix %>% round(3) %>% as_tibble(rownames = "gene")
write_csv(tpm_table, "counts.tpm.csv.gz")
write_xlsx(list(TPMs = tpm_table), "counts.tpm.xlsx")
Sys.sleep(1)
message("TPM counts calculated successfully without FPKM intermediate")
message("")

# export variance stabilized counts
vsd_table = assay(vsd) %>% round(3) %>% as_tibble(rownames = "gene")
write_csv(vsd_table, "counts.vst.csv.gz")
Sys.sleep(1)

message(" ========== QC ========== ")

# sparsity plot
# png("plot.sparsity.png", width = 6, height = 6, units = "in", res = 300)
# print(plotSparsity(dds, normalized = TRUE))
# dev.off()
# Sys.sleep(1)

# PCA plot
pca_plot = deseq2_pca(vsd, intgroup = group_name, ntop = 1000, point_labels = TRUE)
save_plot("plot.pca.png", pca_plot, base_height = 6, base_width = 8, units = "in")
Sys.sleep(1)
save_plot("plot.pca.pdf", pca_plot, base_height = 6, base_width = 8, units = "in")
Sys.sleep(1)

# PCA plot without labels for larger projects
if (ncol(dds) > 10) {
  pca_plot = deseq2_pca(vsd, intgroup = group_name, ntop = 1000, point_labels = FALSE)
  save_plot("plot.pca.nolabels.png", pca_plot, base_height = 6, base_width = 8, units = "in")
  Sys.sleep(1)
  save_plot("plot.pca.nolabels.pdf", pca_plot, base_height = 6, base_width = 8, units = "in")
  Sys.sleep(1)
}

message(" ========== differential expression ========== ")

# perform comparisons for all combinations of group levels
if (length(group_levels) > 1) {
  group_levels_combinations = combn(group_levels, m = 2, simplify = TRUE)
  for (combination_num in 1:ncol(group_levels_combinations)) {
    # numerator is second in order (order should match the input table group order)
    level_numerator = group_levels_combinations[2, combination_num]
    level_denominator = group_levels_combinations[1, combination_num]
    message(glue("comparison : {group_name} : {level_numerator} vs {level_denominator}"))
    deseq2_compare(deseq_dataset = dds, contrast = c(group_name, level_numerator, level_denominator), genome = genome_build)
  }
}

# delete Rplots.pdf (left by some plotting functions)
if (file.exists("Rplots.pdf")) file.remove("Rplots.pdf")



# end
