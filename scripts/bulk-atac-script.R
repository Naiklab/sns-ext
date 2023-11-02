## ATAC-SEQ - Differential Peak analysis and annotation

# Needed for preinstalling R packages.
#BiocManager::install(c("DiffBind","TxDb.Hsapiens.UCSC.hg38.knownGene","org.Hs.eg.db","TxDb.Mmusculus.UCSC.mm10.knownGene","org.Mm.eg.db","ChIPpeakAnno","tidyverse","enrichR","batchtma"),)

library(DiffBind) # Differential peaks 
library(TxDb.Hsapiens.UCSC.hg38.knownGene) # For Human 
library(org.Hs.eg.db)

library(TxDb.Mmusculus.UCSC.mm10.knownGene) # For Mouse
library(org.Mm.eg.db)

library(ChIPpeakAnno)
library(ChIPseeker)
library(tidyverse)
library(enrichR)
library(batchtma)

  

# relevent arguments
args = commandArgs(trailingOnly = TRUE)
genome_build = args[1]
groups_table_file = args[2]

## Load in the sample sheet

samplesheet <- read.csv(groups_table_file)

# Number of samples
num_samples <- len(samplesheet$SampleID)

# Number of Groups
num_groups <- len(unique(samplesheet$Condition))

# create a main-directory for ATAC-seq data analysis with subfolders
atac_dir=paste("DPE-ATAC-data-",num_groups,"-groups-",num_samples,"-samples")
if (!dir.exists(atac_dir)) dir.create(atac_dir)

# Set the ATAC data folder as working directory
setwd(atac_dir)

# create sub-directories for secondary output files
r_dir = "r-data"
if (!dir.exists(r_dir)) dir.create(r_dir)
heatmaps_dir = "ATAC-heatmaps"
if (!dir.exists(heatmaps_dir)) dir.create(heatmaps_dir)
volcano_dir = "ATAC-volcano-plots"
if (!dir.exists(volcano_dir)) dir.create(volcano_dir)

#gse_dir = "gene-set-enrichment" - Don't need this at the moment
#if (!dir.exists(gse_dir)) dir.create(gse_dir)

# check for arguments
if (length(args) < 2) stop("not enough arguments provided")

# create separate directories for certain output files
r_dir = "r-data"
if (!dir.exists(r_dir)) dir.create(r_dir)


## Check genome build to import the correct TxDb file
if (genome_build=="hg38"){
  txdb <- TxDb.Hsapiens.UCSC.hg38.knownGene:::TxDb.Hsapiens.UCSC.hg38.knownGene
  annoData <- toGRanges(txdb, feature="gene")
  set_annoDB ="org.Hs.eg.db"
} else if (genome_build=="mm10"){
  txdb <- TxDb.Mmusculus.UCSC.mm10.knownGene:::TxDb.Mmusculus.UCSC.mm10.knownGene
  annoData <- toGRanges(txdb, feature="gene")
  set_annoDB ="org.Mm.eg.db"
} else {
    print("Incorrect genome build or missing genome build. Please choose between: hg38 or mm10")
}

# Import and convert the ATAC data for DiffBind (using sample sheet) 

Samples <- dba(sampleSheet = samplesheet)

atac.counts <- dba.count(Samples,summits = TRUE)
atac_data <- dba.normalize(atac.counts,method = DBA_DESEQ2)

saveRDS(atac_data,file.path("r-data/",paste("ATAC-counts.RDS")))

## SIZE 10*14
pdf("ATAC-DATA-PCA-PLOTS.pdf",width=8,height=8)
dba.plotPCA(atac_data,
            attributes = DBA_ID,
            th=0.1,
            vColors =c("deepskyblue4","firebrick1","firebrick4",
                       "deepskyblue","gold", "gold3"))
dba.plotPCA(atac_data,
            attributes = DBA_TISSUE,
            th=0.1,
            vColors =c("deepskyblue4","firebrick1","firebrick4",
                       "deepskyblue","gold", "gold3"))
dba.plotPCA(atac_data,
            attributes = DBA_FACTOR,
            th=0.1,
            vColors =c("deepskyblue4","firebrick1","firebrick4",
                       "deepskyblue","gold", "gold3"))
dba.plotPCA(atac_data,
            attributes = DBA_CONDITION,
            vColors =c("deepskyblue4","firebrick1","firebrick4",
                       "deepskyblue","gold", "gold3"),
            th=0.1)
dba.plotPCA(atac_data,
            attributes = DBA_TREATMENT,
            th=0.1,
            vColors =c("deepskyblue4","firebrick1","firebrick4",
                       "deepskyblue","gold", "gold3"))
dba.plotPCA(atac_data,
            attributes = DBA_REPLICATE,
            th=0.1,
            vColors =c("deepskyblue4","firebrick1","firebrick4",
                       "deepskyblue","gold", "gold3"))
dev.off()




annotate_and_bed <- function(res,txdb){
  res.annotated <- res %>% annotatePeak(tssRegion=c(-5000,5000),TxDb=txdb, annoDb=set_annoDB) 
  
  res.annotated <- as.data.frame(res.annotated)
  write_csv(res.annotated,paste0(substitute(res),".annotated.csv"))
  
  res.peaks <- res.annotated %>% dplyr::select(c("seqnames","start","end"))
  write.table(res.peaks,paste0(substitute(res),".peaks.bed"), sep = "\t", quote = FALSE, row.names = FALSE, col.names = FALSE)
  
  # Openning peaks
  up.peaks <- res.annotated %>% filter(Fold>0)
  write.table(up.peaks,paste0(substitute(res),".up.peaks.bed"), sep = "\t", quote = FALSE, row.names = FALSE, col.names = FALSE)
  
  ## Closing Peaks
  down.peaks <- res.annotated %>% filter(Fold<0)
  write.table(down.peaks,paste0(substitute(res),".down.peaks.bed"), sep = "\t", quote = FALSE, row.names = FALSE, col.names = FALSE)
  
}

# Design formula assumes the "Tissue" column is the batch variable that needs to be regressed out and the Condition column is the column to be contrasted.
Batch.controlled.contrasts <- dba.contrast(atac_data,design="~Tissue + Condition") %>% dba.analyze()
contrasts <- bind_rows(lapply(Batch.controlled.contrasts[["contrasts"]], function(my.list){return(data.frame("name.1"= my.list$name1,"name.2"= my.list$name2))}))
contrast.df <- dba.show(Batch.controlled.contrasts, bContrasts = T)
contrasts <- left_join(contrasts, contrast.df, by = c("name.1"="Group","name.2"="Group2"))
unique.ID <- paste(contrasts$name.1, contrasts$name.2, contrasts$Factor, sep =";")

dba.reports <- lapply(unique.ID,function(contrast.ID){
  contrast.number <- match(contrast.ID, unique.ID)
  res <- dba.report(Batch.controlled.contrasts, contrast.number, bUsePval=TRUE,
                    th=100,bNormalized=TRUE,bFlip=F,precision=0)
  res <- annotate_and_bed(res)
  return(res)
})

names(dba.reports) <- unique.ID
str(dba.reports, max.level = 1)

dba.reports <- lapply(unique.ID,function(contrast.ID){
  contrast.number <- match(contrast.ID, unique.ID)
  res <- dba.report(Batch.controlled.contrasts, contrast.number, bUsePval=TRUE,
                    th=100,bNormalized=TRUE,bFlip=F,precision=0)
  return(res)
})
names(dba.reports) <- unique.ID

# dba report summary
file.name <- paste0("JD-analysis-part-2/",fileID, "/ATAC-DATA-VOLCANO-DATA-",fileID,"-jd.csv")
dba.report.df <- 
  lapply(dba.reports, as.data.frame) %>%
  bind_rows(., .id = "comparison") %>%
  mutate(bin = ifelse(Fold > 0, "pos", "neg"),
         sig = ifelse(FDR < 0.1, "sig", "ns")) %>%
  group_by(comparison, bin, sig) %>%
  summarise(counts = n())
write.csv(dba.report.df, file = file.name)


## Volcano plots
pt.color.vector <- c("FDR < 0.1 & abs(Fold) > 1" = "red",
                     "FDR < 0.1" = "blue",
                     "FDR > 0.1" = "gray")


pdf(file = file.path("ATAC-volcano-plots/",paste("ATAC-VOLCANO-PLOTS.pdf")), height = 8, width = 8)
lapply(unique.ID,function(contrast.ID){
  contrast.number <- match(contrast.ID, unique.ID)
  Group1 <- strsplit(contrast.ID, split = ";")[[1]][1]
  Group2 <- strsplit(contrast.ID, split = ";")[[1]][2]
  Comp <- strsplit(contrast.ID, split = ";")[[1]][3]
  
  # ymax <- 1.01*max(-log(dba.reports[[contrast.ID]]$FDR))
  # if(ymax < 0.1){ymax < 0.1}
  
  dba.reports[[contrast.ID]] %>%
    as.data.frame() %>%
    mutate(color = ifelse(FDR < 0.1 & abs(Fold) > 1,"FDR < 0.1 & abs(Fold) > 1",
                          ifelse(FDR < 0.05, "FDR < 0.1", "FDR > 0.1"))) %>%
    ggplot(aes(x = Fold,
               y = -log10(FDR),
               color = color)) +
    geom_point(size = 0.5) +
    ggpubr::theme_classic2() +
    scale_color_manual(values = pt.color.vector) +
    ggtitle(paste(toupper(Comp),":",toupper(Group1), "vs", toupper(Group2))) +
    theme(axis.text = element_text(color = "black"),
          plot.title = element_text(hjust = 0.5, color = "black")) 
  # ylim(c(0,ymax))
})
dev.off()
