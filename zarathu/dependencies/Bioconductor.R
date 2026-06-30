install.packages("BiocManager")

packages <- c("BiocGenerics", 
  "BiocVersion", 
  "Biostrings", 
  "IRanges", 
  "KEGGREST", 
  "S4Vectors", 
  "Seqinfo", 
  "XVector")

BiocManager::install(packages)