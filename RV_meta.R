library(argparser, quietly = TRUE)
#Num cohorts : 
#CHR : 
#LD_mat : info file path * num cohorts 
#GWAS summary : GWAS summary path * num cohorts
#Output prefix : 
p <- arg_parser('Run Meta-Analysis using rare variants')
p <- add_argument(p, '--anno_file', help = 'annotation file')
p <- add_argument(p, '--annos', help = 'annotations to include', nargs= Inf)
p <- add_argument(p, '--num_cohorts', help = 'number of cohorts')
p <- add_argument(p, '--chr', help = 'chromosome number')
p <- add_argument(p, '--info_file_path', help = 'LD matrix (GtG) marker information file path', nargs = Inf)
p <- add_argument(p, '--gene_file_prefix', help = 'File name for sparse GtG file excluding gene name', nargs = Inf)
p <- add_argument(p, '--gwas_path', help = 'path to GWAS summary', nargs = Inf)
p <- add_argument(p, '--output_prefix', help = 'output prefix')
p <- add_argument(p, '--mem', help='high memory mode - improves performance at the cost of memory usage')

argv <- parse_args(p)

library(SKAT, quietly = TRUE)
library(data.table, quietly = TRUE)
library(dplyr, quietly = TRUE)

source('./Lib_v3.R')


#Loading the list of genes to analyze

genes <- c()
gwases <- c()
SNP_infos <- c()

for (i in 1:argv$num_cohorts){
    SNP_info = fread(argv$info_file_path[i])
    SNP_infos[[i]] <- SNP_info
    genes <- c(genes, SNP_info$Set)
    gwases[[i]] <- fread(argv$gwas_path[i])
}

filter_annos <- function(gwases, anno_file, annotations){
	con = file(anno_file, "r")
	i = 0

	#variant_annos = data.table(var=character(), anno=character())
	row_dfs = list()
	while ( TRUE ) {
		line = readLines(con, n = 1)
		if ( length(line) < 1 ){ break }
		line = strsplit(line, split=" ")
		if ( length(line[[1]]) < 3 ) {
			next	
		}
		if ( i %% 2 == 0 ){
			variants = line[[1]][3:length(line[[1]])]
		} else {
			row_dfs = append(row_dfs, list(data.table(var=variants, anno=line[[1]][3:length(line[[1]])])))
		}
		i = i + 1
	}

	print("binding rows")	
	variant_annos = bind_rows(row_dfs)
	
	print("annofile read")
	close(con)

	print(variant_annos)
	variant_annos = variant_annos[anno == annotations]
	
	print(variant_annos)
	for (i in 1:argv$num_cohorts){
		gwases[[i]]$MarkerID <- gsub("chr","",as.character(gwases[[i]]$MarkerID))
		variant_annos$var <- gsub("chr","",as.character(variant_annos$var))
		print(variant_annos)
                cat("\nprefilter variants remaining: ", nrow(gwases[[i]]))
		gwases[[i]] = gwases[[i]][MarkerID %in% variant_annos$var]
		cat("\nvariants remaining: ", nrow(gwases[[i]]))
		cat("\nfiltered gwas cohort", i)
	}	
	return(gwases)
}

gwases = filter_annos(gwases, argv$anno_file, argv$annos)

cat("N genes: ", length(genes), "\n")
genes = unique(genes)
cat("N unique genes: ", length(genes), "\n")

res_chr <- c()
res_gene <- c()

res_pval_adj <- c()
res_pval_0.00_adj <- c()
res_pval_0.01_adj <- c()
res_pval_0.04_adj <- c()
res_pval_0.09_adj <- c()
res_pval_0.25_adj <- c()
res_pval_0.50_adj <- c()
res_pval_1.00_adj <- c()

res_pval_noadj <- c()
res_pval_0.00_noadj <- c()
res_pval_0.01_noadj <- c()
res_pval_0.04_noadj <- c()
res_pval_0.09_noadj <- c()
res_pval_0.25_noadj <- c()
res_pval_0.50_noadj <- c()
res_pval_1.00_noadj <- c()


load_cohort <- function(cohort, gene, SNPinfos, gwases){
    ############Loading Cohort1 LD and GWAS summary###############
    
    SNPinfo <- SNPinfos[[cohort]]
    cat("\nSNPinfo rows", nrow(SNPinfo), "\n")
    print(nrow(SNPinfo))
    SNP_info_gene = SNPinfo[which(SNPinfo$Set == gene)]
    print(nrow(SNP_info_gene))
    gwas = gwases[[i]]
    cat("\ngwas rows", nrow(gwas))
    n.vec <<- c(n.vec, gwas$N_case[1] + gwas$N_ctrl[1])

    SNP_info_gene$Index <- SNP_info_gene$Index + 1
    
    SNP_info_gene <- SNP_info_gene %>%
	mutate(POS=as.character(POS))

    print("SNPvsGWAS")
    print(nrow(SNP_info_gene))
    print(nrow(gwas))

    SNP_info_gene$POS <- as.numeric(SNP_info_gene$POS)
    gwas$POS <- as.numeric(gwas$POS)

    merged <- left_join(SNP_info_gene, gwas[,c('POS', 'MarkerID', 'Allele1', 'Allele2', 'Tstat', 'var', 'p.value', 'p.value.NA')], by = c('POS' = 'POS', 'Major_Allele' = 'Allele1', 'Minor_Allele' = 'Allele2'))
    #merged <- left_join(SNP_info_gene, gwas[,c('POS', 'MarkerID', 'Allele1', 'Allele2', 'Tstat', 'var', 'p.value', 'p.value.NA')], by = c('POS' = 'POS'))
    merged$adj_var <- merged$Tstat^2 / qchisq(1 - merged$p.value, df = 1)

    cat("\nmerged nrows: ", nrow(merged), "\n")

    #### Using p.value.NA if higher than 0.05
    idx<-which(merged$p.value.NA >= 0.05)
    if(length(idx)> 0){
        merged$adj_var[idx]<-merged$var[idx]
    }
    ####
    

    merged <- merged[complete.cases(merged[,c("p.value")]),]
    cat("\ncleaned merged nrows: ", nrow(merged), "\n")

    merged <- merged %>% distinct()
	
    print(merged)
    if(nrow(merged) > 0){
        IsExistSNV.vec <<- c(IsExistSNV.vec, 1)
    } else{
        IsExistSNV.vec <<- c(IsExistSNV.vec, 0)
    }

    sparseMList = read.table(paste0(argv$gene_file_prefix[cohort], gene, '.txt'), header=F)
    sparseGtG = Matrix:::sparseMatrix(i = as.vector(sparseMList[,1]), j = as.vector(sparseMList[,2]), x = as.vector(sparseMList[,3]), index1= FALSE)
    sparseGtG <- sparseGtG[merged$Index, merged$Index]

    Info_adj.list[[cohort]] <<- data.frame(SNPID = merged$MarkerID, MajorAllele = merged$Major_Allele, MinorAllele = merged$Minor_Allele, S = merged$Tstat, MAC = merged$MAC, Var = merged$adj_var, stringsAsFactors = FALSE)
    SMat.list[[cohort]] <<- as.matrix(sparseGtG)

}

x1 = 0
x2 = 0
n = 0
for (gene in genes){
    skip_to_next <- FALSE

    n = n + 1 
    start <- Sys.time()
    cat('Analyzing chr ', argv$chr, ' ', gene, ' ....\n')
    
    SMat.list<-list()
    Info_adj.list<-list()

    n.vec <- c()
    IsExistSNV.vec <- c()
    end = FALSE
    for (i in 1:argv$num_cohorts){
	
        if (file.size(paste(argv$gene_file_prefix[i], gene, '.txt', sep="")) == 0L){
                end = TRUE
                print("empty file")
		break
        }

    	load_cohort(i, gene, SNP_infos, gwases)
	    # if (nrow(Info_adj.list[[i]]) == 0 | nrow(Info_adj.list[[i]]) == 1) skip_to_next = TRUE
    }
	
    if (skip_to_next){
        x1 = x1 + 1
    	print("finished, empty rows")
    	next
    }

    ###########Meta-analysis##################
    start_MetaOneSet <- Sys.time()

    tryCatch(out_adj<-Run_Meta_OneSet(SMat.list, Info_adj.list, n.vec=n.vec, IsExistSNV.vec=IsExistSNV.vec,  n.cohort=argv$num_cohorts), error = function(e) { print(e); skip_to_next <<- TRUE })
  
    if(skip_to_next) { 
        x2 = x2 + 1
        cat("Skipped the gene", gene, "\n")
        next 
    } 

    cat("Number of skipped genes: ", x1, "/", n, "\n")

    end_MetaOneSet <- Sys.time()
    cat('elapsed time for Run_Meta_OneSet ', end_MetaOneSet - start_MetaOneSet , '\n')

    res_chr <- append(res_chr, argv$chr)
    res_gene <- append(res_gene, gene)


    if ('param' %in% names(out_adj)){
        res_pval_adj <- c(res_pval_adj, out_adj$p.value)
        res_pval_0.00_adj <- c(res_pval_0.00_adj, out_adj$param$p.val.each[1])
        res_pval_0.01_adj <- c(res_pval_0.01_adj, out_adj$param$p.val.each[2])
        res_pval_0.04_adj <- c(res_pval_0.04_adj, out_adj$param$p.val.each[3])
        res_pval_0.09_adj <- c(res_pval_0.09_adj, out_adj$param$p.val.each[4])
        res_pval_0.25_adj <- c(res_pval_0.25_adj, out_adj$param$p.val.each[5])
        res_pval_0.50_adj <- c(res_pval_0.50_adj, out_adj$param$p.val.each[6])
        res_pval_1.00_adj <- c(res_pval_1.00_adj, out_adj$param$p.val.each[7])
    }else{
        res_pval_adj <- c(res_pval_adj, out_adj$p.value)
        res_pval_0.00_adj <- c(res_pval_0.00_adj, NA)
        res_pval_0.01_adj <- c(res_pval_0.01_adj, NA)
        res_pval_0.04_adj <- c(res_pval_0.04_adj, NA)
        res_pval_0.09_adj <- c(res_pval_0.09_adj, NA)
        res_pval_0.25_adj <- c(res_pval_0.25_adj, NA)
        res_pval_0.50_adj <- c(res_pval_0.50_adj, NA)
        res_pval_1.00_adj <- c(res_pval_1.00_adj, NA)
    }

    end <- Sys.time()
    cat('Total time elapsed', end - start, '\n')
}

out <- data.frame(res_chr, res_gene, res_pval_adj, res_pval_0.00_adj, res_pval_0.01_adj, res_pval_0.04_adj, res_pval_0.09_adj, res_pval_0.25_adj, res_pval_0.50_adj, res_pval_1.00_adj)
colnames(out)<- c('CHR', 'GENE', 'Pval', 'Pval_0.00', 'Pval_0.01', 'Pval_0.04', 'Pval_0.09', 'Pval_0.025', 'Pval_0.50', 'Pval_1.00')

outpath <- argv$output_prefix
write.table(out, outpath, row.names = F, col.names = T, quote = F)

cat("FINAL number of genes: ", nrow(out), x1, x2, n)