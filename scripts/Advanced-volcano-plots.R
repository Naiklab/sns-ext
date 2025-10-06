## Generate enhanced and standard Volcano
library(tidyverse)
library(DESeq2)
library(EnhancedVolcano)

## IMPORT THE PSEUDOGENES REFERENCE LIST FOR HUMAN DATA
volcano_advanced <- function(files){
  dir.create("Volcano-plots-standard")
  dir.create("Volcano-plots-enhanced")
  pseudo.genes <- read_tsv(file = "~/Projects/SHARED_DATA/Pseudogenes_Reference/Human_pseudogenes.txt")
  for (f in files){
    res <- readRDS(file =f) 
    res_tbl <-  res %>% as.data.frame() %>% rownames_to_column("gene") %>% dplyr::filter(!(gene %in% pseudo.genes$`Approved symbol`))
    
    # Import group comparison info from DESEQresults object
    comp <- res@elementMetadata$description
    comp <- strsplit(unlist(strsplit(comp[2],'[:]'))[2]," ")
    contrast <- c(comp[[1]][3],comp[[1]][5])
    
    res_name = paste(contrast[1],"_vs_",contrast[2])
    file_suffix = gsub(pattern = " ", replacement = "-", x = res_name)
    plot_volcano(res_tbl,gene_col = "gene",fc_col="log2FoldChange",p_col="padj",
                 fc_cutoff = 0,
                 p_cutoff = 0.05,
                 fc_label = "Fold Change",
                 p_label = "P-Value",
                 title = "Volcano Plot",
                 n_top_genes = 10,
                 file_prefix = file.path("Volcano-plots-standard/",paste(contrast[1],"_vs_",contrast[2],"_volcano",sep ="")))
    
    pos_results = res_tbl %>% dplyr::filter(log2FoldChange>2,padj<=0.05)
    neg_results = res_tbl %>% dplyr::filter(log2FoldChange<(-2),padj<=0.05)
    
    pdf(file = file.path("Volcano-plots-enhanced/",paste(contrast[1],"_vs_",contrast[2],"_enhanced-volcano(0.05-FDR,2-L2FC).pdf",sep ="")),height = 10,width = 15)
    print(EnhancedVolcano(res_tbl,lab = res_tbl$gene,x="log2FoldChange",y="padj",FCcutoff = 2,pCutoff = 0.05,subtitle = NULL,caption = paste("total upregulated genes = ", nrow(pos_results),"and downregulated genes =",nrow(neg_results))))
    dev.off()
    
    ## Update gene count results with new filter
    pos_results = res_tbl %>% dplyr::filter(log2FoldChange>1,padj<=0.1)
    neg_results = res_tbl %>% dplyr::filter(log2FoldChange<(-1),padj<=0.1)
    
    pdf(file = file.path("Volcano-plots-enhanced/",paste(contrast[1],"_vs_",contrast[2],"_enhanced-volcano(0.10-FDR,1-L2FC).pdf",sep ="")),height = 10,width = 15)
    print(EnhancedVolcano(res_tbl,lab = res_tbl$gene,x="log2FoldChange",y="padj",FCcutoff = 1,pCutoff = 0.1,subtitle = NULL,caption = paste("total upregulated genes = ", nrow(pos_results),"and downregulated genes =",nrow(neg_results))))
    dev.off()
  }
}