.metapv<-function(pvi){
  nonNA = which(!is.na(pvi))
  if(length(nonNA)==0) return(NA)
  pchisq(sum(unlist(lapply(pvi[nonNA],qchisq,lower.tail=F, df=1 ))),df=length(nonNA), lower.tail=F)
  
}
readH5<-function(h5file, df, thresh =500,log=F){
  IDS = df$ID
  header = h5read(h5file,"header")
  names = h5ls(h5file)$name
  if(header[2]!="base") header = c(header[1], "base", header[-1])
  dinds  = grep("depth", header)
  einds  = grep("error", header)
  
  countT = apply(df[,grep("count[0-9]", names(df)),drop=F],1,sum)
  pos_ind = which(header=="pos")
  inds = which(countT>thresh & df$ID %in% names)
  if(length(inds)==0) return(NULL)
  
  mat_all = data.frame(matrix(nrow = 0, ncol = length(header)+3))
  for(i in 1:length(inds)){
    print(paste(i, length(inds), sep=" of "))
    ID = as.character(IDS[inds[i]])
    
    mat = t(h5read(h5file,as.character(ID)))
    
    countT1 = apply(mat[,grep("depth[0-9]", header),drop=F],1,sum)
    indsi = which(countT1>thresh)
    if(length(indsi)>0){
    mat1 = mat[indsi,,drop=F]
    pv1 = t(apply(mat1,1,betaBinomialP2, grep("depth[0-9]", header),grep("errors[0-9]", header) , control=1, case=2, binom=F,log=log))
    #dimnames(pv1) = list(mat$pos[indsi],c("pv1","pv2"))
    IDv = rep(ID, length(indsi))
  #  chrv=rep(df$chrs[i], length(indsi))
    mat2 = data.frame(IDv ,mat1,pv1)
    #print(head(mat2))
    mat_all = rbind(mat_all,mat2)
    }
  } 
  names(mat_all) = c("IDS",header, "pv1","pv2")
  mat_all
}

DE_err<-function(DE, inds_control=1, inds_case=2, sum_thresh = 100){
  
  inds2 = grep("error_ratio[0-9]", names(DE))
  inds1 = grep("count[0-9]", names(DE))
  if(length(inds2)>0){
    m = max(DE[,inds2,drop=F],na.rm=T)
    if(m<=1.01){
    for(j in 1:length(inds2)){
      DE[,inds2[j]] =  DE[,inds2[j]] * DE[,inds1[j]] 
    } 
    }
  }
  
  countT = apply(DE[,grep("sum_", names(DE)),drop=F],1,sum)
#  print(head(sort(countT, decreasing=T),20))
  inds_ = which(countT>sum_thresh)
 # print(head(inds_),20)
  if(length(inds_)==0) return (NULL)
  inds2 = grep("error_ratio[0-9]", names(DE))
  inds1 = grep("count[0-9]", names(DE))
  DE_a = DE[,c(inds1,inds2),drop=F]
  inds1 = 1:length(inds1)
  inds2 = (1:length(inds2))+length(inds1)
  pv_res = t(apply(DE_a[inds_,,drop=F],1,betaBinomialP2, inds1,inds2, 1, 2))
  dimnames(pv_res) =  list(inds_, c("pv1","pv2"))
  pv_res
}


betaBinomialP2<-function(v, indsDepth, indsError, control, case,binom=F, lower.tail=T,log=F){
  pv1 = rep(NA, length(control))
  pv2 = rep(NA, length(control))
  
  for(j in 1:length(control)){
    pv1[j] = betaBinomialP1(v, c(indsDepth[control[j]], indsError[control[j]], indsDepth[case[j]], indsError[case[j]]), binom=binom, lower.tail=lower.tail, log=log)
    pv2[j] = betaBinomialP1(v, c(indsDepth[case[j]], indsError[case[j]], indsDepth[control[j]], indsError[control[j]]), binom=binom, lower.tail=lower.tail, log=log)
  }
  pv1m =chisqCombine(pv1,log=log)
  pv2m = chisqCombine(pv2,log=log)
  c(pv1m,pv2)
#  2*min(pv1m, pv2m, na.rm=T)
}



betaBinomialP1<-function(v, ord, binom=F, lower.tail=T,log=F){
 # v = as.numeric(v1)
 # print(v)
  if(length(which(is.na(v)))!=0) return (NA)
  #matr1 = matr[nonNA,]
 # print(v[ord])
  #print(ord)
  size = v[ord[1]];
  shape1 = v[ord[2]]
  y = shape1
  shape2 = size-shape1
  sizex = v[ord[3]]
  shape1x = v[ord[4]]
  x = shape1x
  
  shape2x = sizex -shape1x
  if(binom){
    pv_res = pbinom(x,size = sizex,prob = y/size,log.p=log, lower.tail=TRUE)
  }else{
    pv_res = pbetabinom.ab(x,size = sizex,shape1 = shape1,shape2 =shape2,log=log)
  }
  pv_res
}
  

betaBinomialP<-function(x,y, binom=F, lower.tail=T,log=F){
  size = ceiling(sum(y))
  # geneID = df$geneID
  
  shape1 = y 
  shape2 = size -y 
  proby = y/size;
  zeros = y==0 & x== 0
  sizex = ceiling(sum(x))
  shape1x = x 
  shape2x = sizex -x 
  probx = x/sizex
  
  pbb =rep(NA, length(x))
  if(binom){
    if(lower.tail==FALSE){
      pbb_lower =1- pbinom(x[!zeros],size = sizex,prob = proby[!zeros],log.p=F, lower.tail=lower.tail)
      pbb_lower[pbb_lower<=0] = 0
      point =  dbinom(x[!zeros],size = sizex,prob = proby[!zeros],log.p=F)
      pbb[!zeros] =   pbb_lower + point; 
      if(log) pbb[!zeros] = log(pbb[!zeros,1] )
    }else{
      pbb[!zeros] = pbinom(x[!zeros],size = sizex,prob = proby[!zeros],log.p=log, lower.tail=lower.tail)
      
    }
  }else{
    if(lower.tail==FALSE){
      pbb_lower =1- pbetabinom.ab(x[!zeros],size = sizex,shape1 = shape1[!zeros],shape2 =shape2[!zeros],log=F)
      pbb_lower[pbb_lower<=0] = 0
      point = dbetabinom.ab(x[!zeros],size = sizex,shape1 = shape1[!zeros],shape2 =shape2[!zeros],log=F)
      pbb[!zeros] = pbb_lower + point;
      if(log) pbb[!zeros] = log(pbb[!zeros] )
    }else{
      pbb[!zeros] = pbetabinom.ab(x[!zeros],size = sizex,shape1 = shape1[!zeros],shape2 =shape2[!zeros],log=log)
    }
  }
  if(log){
    pbb[!zeros] =  pbb[!zeros]/log(10)
  }
else{
  pbb[pbb>1] = 1
} 
  pbb
}

chisqCombine<-function(pv,log=log){
  #if(TRUE) return(pv[1])
  nonNA = which(!is.na(pv))
  
  if(length(nonNA)==0) return(NaN) else if(length(nonNA)==1) return (pv[nonNA]);
  if(log){
    resp = pchisq(sum(unlist(lapply(exp(pv[nonNA]),qchisq,lower.tail=F, df=1 ))),df=length(nonNA), lower.tail=F,log=T)
    
  }else{
  resp = pchisq(sum(unlist(lapply(pv[nonNA],qchisq,lower.tail=F, df=1 ))),df=length(nonNA), lower.tail=F)
  }
}



#which x is significiantly more or less than expected given y
#if(lower.tail=T returns p(x<=y) else p(x>=y)
##ASSUMES MATCHED DATA BETWEEN CONTROL  AND INFECTED
DEgenes<-function(df,control_inds,infected_inds, edgeR = F,  type="lt",reorder=T, binom=F, log=F){
 
  lower.tail = T
  if(!edgeR){
    pvalsM1 = matrix(NA,nrow = dim(df)[1], ncol = length(inds_control))
    pvalsM2 = matrix(NA,nrow = dim(df)[1], ncol = length(inds_control))
    for(i in 1:length(inds_control)){
        x = df[,inds_control[i]]
        y = df[,inds_infected[i]]
        pvalsM1[,i] = betaBinomialP(x,y, binom=binom, lower.tail=lower.tail,log=log)
        pvalsM2[,i] = betaBinomialP(y,x, binom=binom, lower.tail=lower.tail,log=log)
        
    }
    pvals1 = apply(pvalsM1, 1, chisqCombine,log=log)
    pvals2 = apply(pvalsM2, 1, chisqCombine,log=log)
    pvals = 2*apply( cbind(pvals1,pvals2),1,min)
    lessThan = pvals2<pvals1
  }else{
    qlf = DE_egdeR(df, inds_control, inds_infected)
    pvals = qlf$table$P
    lessThan = qlf$coefficients[,2]<0
  }
 FDR = p.adjust(pvals, method="BH");
 x = apply(df[,inds_control,drop=F],1,sum)
 y = apply(df[,inds_infected,drop=F],1,sum)
 
  tpm_control = (x/sum(x))*1e6
  tpm_infected = (y/sum(y))*1e6
  probX1 = (x+0.5)/sum(x+.5)
  probY1 = (y+0.5)/sum(y+.5)
  ratio1 = probX1/probY1
  
  
 
  output =  data.frame(pvals,FDR,lessThan,tpm_control, tpm_infected, ratio1,sum_control=x,sum_infected=y, df)
 # print(names(output))

#  names(output)[names(output) %in% c("x","y") ] = names(df)[inds]
#  names(output)[names(output) %in% c("probX","probY") ] = paste( names(df)[inds]," TPM", sep="")
  if(reorder){
    orders =order(pvals)
    
    output = output[orders,]
  }
  output
#  output[orders[,1],,drop=F]
}

DE_egdeR<-function(df, inds_control, inds_infected){
  groups = c(rep(1,length(inds_control)),rep(2,length(inds_infected)))
  y <- DGEList(counts=df[,c(inds_control,inds_infected)],group=groups)
  y <- calcNormFactors(y, fdr_thresh = 0.1)
  design <- model.matrix(~groups)
  y <- estimateDisp(y,design)
  if(is.na(y$common.dispersion)) return (rep(NA, dim(df)[1]))
  #To perform quasi-likelihood F-tests:
  fit <- glmQLFit(y,design)
  qlf <- glmQLFTest(fit,coef=2)
 qlf
}

getDescr<-function(DE,mart, thresh = 1e-10, prefix="ENSCS"){
  inds = which(DE$FDR<thresh)
  print(length(inds))
  subDE = DE[inds,,drop=F]
  genenames1 = as.character(subDE$geneID)
  
  subinds = grep(prefix, genenames1)
  desc1 = rep("", dim(DE)[1])
  
  if(length(subinds)>0){
    genenames = genenames1[subinds];
    attr =  c('ensembl_gene_id','description')# 'go_id') #, "name_1006", "namespace_1003") #, "definition_1006")
    filt = c('ensembl_gene_id')
    #	goids = getBM(attributes =attr,   filters = filt,   values = list(ensg) ,    mart = mart) 
   print(genenames)
     desc =  biomaRt::getBM(attributes=attr, filters = filt, mart = mart, values = list(genenames)) 
    #FDR = DE$FDR
    desc1[inds][subinds] = desc[match(genenames, desc[,1]),2]
    
  }
  data.frame(cbind(DE,desc1))
}


getlev<-function(x, todo = NULL){
  lev = levels(as.factor(as.character(x)))
  cnts = rep(0, length(lev))
  for(i in 1:length(lev)){
    cnts[i] = length(which(x==lev[i]))
  }
  res = data.frame(lev,cnts)[order(cnts, decreasing = T),, drop=F]
  if(is.null(todo)) return(res)
  
  matr = data.frame(lev=todo, cnts=rep(0,length(todo)))
  # print(dim(matr))
  # print(dim(res))
  if(dim(res)[1]>1){
    matr[match(res[,1], matr[,1]),2] = res[res[,1] %in% matr[,1],2]
    dimnames(matr)[[2]] = dimnames(res)[[2]]
  }else{
    #print(todo)
    matr[match(res[,1], matr[,1]),2] =res
  }
  
  matr
}


getChromIDs<-function(ensg, mart){
  goids = getBM(attributes = c('ensembl_gene_id', 'chromosome_name'),   filters = c('ensembl_gene_id'),   values = list(ensg) ,    mart = mart) 
  goids = goids[goids[,2]!="",]
  lev_all = getlev(goids$chromosome)
  #dimnames(lev_all)[[1]] = goids[match(lev_all[,1], goids$chromosome),3]
  
  chromObj = list(goids=goids, lev_all = lev_all)
  chromObj
}

getGoIDs<-function(genenames, mart){
  ensg = genenames
  #genenames = exons_$GENENAME.1
  attr =  c('ensembl_gene_id', 'go_id', "name_1006", "namespace_1003") #, "definition_1006")
  filt = c('ensembl_gene_id')
  #	goids = getBM(attributes =attr,   filters = filt,   values = list(ensg) ,    mart = mart) 
  
  goids =  biomaRt::getBM(attributes=attr, filters = filt, mart = mart, values = list(genenames)) 
  goids2 = goids[goids[,2]!="",]
  
  gn = genenames[match(goids2[,1], ensg)]
  goids = cbind(goids2, gn)
  lev_all = getlev(goids$go_id)
  lev_all = cbind(lev_all,goids[match(lev_all[,1], goids$go_id),3])
  names(lev_all)[3] = "description"
  goObjs = list()
  goObjs[[1]] = list(goids=goids, lev_all = lev_all )
  ns = as.factor(goids$namespace)
  lev = levels(ns)
  
  for(i in 1:length(lev)){
    goids1 = goids[goids$namespace==lev[i],]
    lev_all1 = getlev(goids1$go_id)
     lev_all1 = cbind(lev_all1,goids1[match(lev_all1[,1], goids1$go_id),3])
     names(lev_all1)[3] = "description"
    goObjs[[i+1]] = list(goids = goids1, lev_all = lev_all1)
  }
  lev[lev==""]  = "blank"
  names(goObjs) = c("combined", lev)
  goObjs = goObjs[names(goObjs)!="blank"]
  goObjs
}

findGenesByChrom<-function(DE,chrom="MT", fdr_thresh = 1e-10){
  inds = which(DE$chrs== chrom & DE$FDR<fdr_thresh)
  print(inds)
  if(length(inds)==0) return (NULL)
  DE[inds,,drop=F]
  
}

.readFeatureCounts<-function(files){
  a = read.table(files[1], head=T)
  b = read.table(files[2], head=T)
  geneID = as.character(a$Geneid)
  chrs = unlist(lapply(a$Chr,function(x) strsplit(as.character(x),";")[[1]][1]))
  df = data.frame(control = a[,7],infected = b[,7],chrs = chrs, geneID = geneID)
  df
}

readTranscriptHostAll<-function(infilesT, 
                                combined_depth_thresh = 100,
                                target= list(count0="numeric", count1 = "numeric",chrom="character", 
                                             leftGene="character", rightGene="character", start = "numeric", 
                                             end="numeric", ID="character", isoforms="numeric" ,error_ratio0 = "numeric",error_ratio1="numeric") ){
  chroms = unlist(lapply(infilesT, function(x) strsplit(x,"\\.")[[1]][[1]]))
  chrom_names = rep("", length(chroms))
  dfs = list()
  for(i in 1:length(chroms)){
    infilesT1 = paste(chroms[i],"transcripts.txt.gz", sep=".")
    dfi = .readTranscriptsHost(infilesT1,target=target,combined_depth_thresh = combined_depth_thresh)
    if(dim(dfi)[1]>0){
      chrom_names[i] = dfi$chrs[1]
     # print(chrom_n)
      dfs[[i]] = dfi
    
      print(' not null')
    }else{
      print("is null")
      dfs[[i]] = NULL
    }
  }
  lengs = unlist(lapply(dfs,function(x) if(is.null(x)) NA else dim(x)[1]))
  
  inds = which(!is.na(lengs))
  chroms = chroms[inds]
  chrom_names = chrom_names[inds]
  dfs = dfs[inds]
  numeric_names = as.numeric(chrom_names)
  ord1 = order(numeric_names[!is.na(numeric_names)])
  ord2 = order(infile_names[is.na(numeric_names)],decreasing=T)
  ord=c(which(!is.na(numeric_names))[ord1],which(is.na(numeric_names))[ord2])
  dfs = dfs[ord]
  chroms = chroms[ord]
  chrom_names = chrom_names[ord]
  lengs = lengs[inds][ord]
  res = data.frame(matrix(nrow  =sum(lengs), ncol = dim(dfs[[1]])[2]))
  names(res) = names(dfs[[1]])
  start=1;
  ranges = matrix(nrow = length(dfs), ncol=2)
  for(i in 1:length(dfs)){
    print(i)
    lengi = dim(dfs[[i]])[1]
    ranges[i,] = c(start, start+lengi-1);
    res[ranges[i,1]:ranges[i,2],] = dfs[[i]]
    start = start+lengi
  }
  names(chroms) = chrom_names
  attr(res,"ranges") = ranges
  attr(res,"info")=attr(dfs[[1]],"info")
  attr(res,"chroms")=chroms
 # attr(res,"chroms")=chrom_
  
  res
}

.readH5All<-function(transcripts, depth_thresh = 1000,chroms= attr(transcripts,"chroms")){
  depth = NULL
  ranges = matrix(nrow = length(ord), ncol=2)
  start = 1
  depths = list()
  for(i in 1:length(chroms)){
    print(chroms[i])
    infile = paste(chroms[i],"clusters.h5", sep=".")
    depths[[i]] = readH5(infile, transcripts, thresh =depth_thresh,log=F)
    
  }
  
  
  lengs = unlist(lapply(depths,function(x) if(is.null(x)) NA else dim(x)[1]))
  inds = which(!is.na(lengs))
  chroms = chroms[inds]
  depths = depths[inds]
  lengs = lengs[inds]
  res = data.frame(matrix(nrow  =sum(lengs), ncol = dim(depths[[1]])[2]))
  names(res) = names(depths[[1]])
  start=1;
  
  ranges = data.frame(matrix(nrow = length(depths), ncol=4))
  names(ranges) = c("start","end","chrom","chrom_name");
  for(i in 1:length(depths)){
    #print(i)
    depths[[i]][,1] = as.character(depths[[i]][,1])
    lengi = dim(depths[[i]])[1]
    ranges[i,] = c(start, start+lengi-1, chroms[i], names(chroms)[i]);
    res[ranges[i,1]:ranges[i,2],] = depths[[i]]
    start = start+lengi
  }
  attr(res,"ranges") = ranges
  attr(res,"chroms")=chroms
  m1 =rep(NA, dim(res)[1])# matrix(nrow = dim(depth)[1], ncol=2)
  for(i in 1:(dim(ranges)[1])){
   ri = as.numeric(ranges[i,]) 
   m1[ri[1]:ri[2]]=ri[3]
  }
  attr(res,"chr_inds")=m1
  res
  }


.readTranscriptsHost<-function(infilesT, 
                  target= list(count0="numeric", count1 = "numeric",chrom="character", leftGene="character", rightGene="character", start = "numeric", end="numeric", ID="character")
              ,prefix="ENSC" ,combined_depth_thresh =100                                  
  ){
  header = names(read.table( infilesT,sep="\t", head=T, nrows = 3, comment.char='#'))
  inf = scan(infilesT, nlines=1, what=character())
  inf = sub('#','',inf)
  types = unlist(lapply(inf, function(x) rev(strsplit(x,"_")[[1]])[1]))
  header_inds = match(names(target),header)
  colClasses = rep(NULL, length(header));
  colClasses[header_inds] = target
  
  transcripts = read.table( infilesT,sep="\t", head=T, comment.char='#', colClasses= colClasses)
 
  
  header_inds1 = match(names(target),names(transcripts))
  head_inds1 = grep("count[0-9]", names(transcripts));

  countT = apply(transcripts[,head_inds1,drop=F],1,sum)
  #print(countT)
  transcripts = transcripts [countT>combined_depth_thresh,header_inds1] 
 # names(transcripts)[1:2] = types
  names(transcripts)  = sub("leftGene", "geneID" ,names(transcripts))
  names(transcripts)  = sub("chrom", "chrs" ,names(transcripts))
  geneID = transcripts$geneID
  type = rep(NA, length(geneID))
  type[ grep(prefix, transcripts$geneID)] = "left"
  missing = grep(prefix, transcripts$geneID,inv=T)
  if(length(missing)>0){
    have = grep(prefix,transcripts$rightGene[missing])
    transcripts$geneID[missing[have]] = transcripts$rightGene[missing[have]]
    type[missing[have]] = "right"
  }
  diff = transcripts$end - transcripts$start
  #o = order(countAll, decreasing=T)
  #transcripts = transcripts[o,]
  #err_ratio_inds = grep("error_ratio", names(transcripts))
  #transcripts[,err_ratio_inds] =apply(transcripts[,err_ratio_inds,drop=F], c(1,2), function(x) if(is.na(x)) -0.01 else x)
  attr(transcripts,"types")=types
  if(length(grep("#", inf))>0) attr(transcripts,"info") = sub("#", "",inf)
  #print(inf)
  type = as.factor(type)
  res = cbind(transcripts, type, diff)
  
  res
}


findGenes<-function(goid, goObj,DE, fdr_thresh = 1e-10, lessThan = FALSE){
  
  inds =  which(goObj$goids$go_id==goid) 
  genes = goObj$goids[inds,,drop=F]
  inds1 = which(DE$geneID %in% genes$ensembl_gene_id)
  if(!is.null(lessThan)){
    inds2 = which(DE[inds1,]$FDR<fdr_thresh & DE[inds1,]$lessThan==lessThan)
  }else{
    inds2 = which(DE[inds1,]$FDR<fdr_thresh)
    
  }
 # ge = DE$geneID[inds1[inds2]]
#  print(genes[which(genes$ensembl_gene_id %in% ge),])
  DE[inds1[inds2],]
}


getGoGenes<-function(go_categories,goObjs, lessThan = T, fdr_thresh = 1e-5){
  names(go_categories) = lapply(go_categories,function(x, goObj) as.character(goObj$lev_all[which(goObj$lev_all[,1]==x),3]), goObjs[[1]])
  go_genes1 = lapply(go_categories, findGenes, goObjs[[1]],DE1, fdr_thresh = fdr_thresh, lessThan=lessThan)
  names(go_genes1) = names(go_categories)
  go_genes1 = go_genes1[which(unlist(lapply(go_genes1,function(x) dim(x)[1]))>0)]
  go_genes1
}


findSigGo_<-function(goObj, DE1, fdr_thresh = 1e-10, go_thresh = 1e-5, prefix="ENSC", lessThan = TRUE){
  DE = DE1[DE1$lessThan==lessThan,,drop=F]
  goids = goObj$goids 
  ensg =grep(prefix, DE$geneID, v=T)
  goidx = rep(FALSE,length(goids$ensembl_gene_id ))
  
  
  pvs = DE$FDR
  sig =  which(pvs<fdr_thresh )
  goidx1 = goids$ensembl_gene_id %in% ensg[sig]
  a = data.frame(goidx1)
  lev_all = goObj$lev_all
  
  suma = apply(a,1,sum)
  subs = which(suma>0)
  go1 = goids[subs,]
  lev1 = getlev(go1[,2])  #go_ids or chromosome_name
  go_todo = lev1[,1]
  go_ = goids[goidx1,]
  
  lev_ = getlev(go_[,2], todo=go_todo)
  inds_m = match(as.character(lev_[,1]), as.character(lev_all[,1]))
  lev_ = cbind(lev_,lev_all[inds_m,1:2,drop=F])
  
  lev_1 = t(apply(lev_,1,.phyper2,  k = length(sig), mn = length(ensg)))
  #	
  if(dim(goids)[[2]]>2){
    descr = goids[match(lev_[,1], goids[,2]),3]
#      apply( cbind(lev_[,1],,1,paste,collapse=":")
  goids = as.character(lev_[,1])
   lev_1 = cbind(goids, lev_1, descr)
  #
  # lev_1[,pv_ind]=sprintf("%5.3g", lev_1[,pv_ind])
   #lev_1$pv = sprintf("%5.3g", as.numeric(as.character(lev_1$pv)))
  }else{
    
    #dimnames(lev_1)[[1]] = lev_[,1]
  }
  pv_ind = which(dimnames(lev_1)[[2]]=="pv")
  pvs = as.numeric(lev_1[,pv_ind])
  len = length(which(pvs<go_thresh))
  #lev_1[,pv_ind] = sprintf("%5.3g",pvs)
  
 # lev_1[order(pvs),,drop=F]
  outp = data.frame(lev_1)
  #outp
  outp[order(pvs)[1:len],]
 
}


findSigChrom<-function( DE1, fdr_thresh = 1e-10, go_thresh = 1e-5, lessThan=T){
  if(is.null(lessThan)) DE = DE1 else DE =DE1[DE1$lessThan==lessThan,,drop=F]
  
  ensg =DE$geneID
  pvs = DE$FDR
  sig =  which(pvs<fdr_thresh)
  lev_all =getlev(DE$chrs)
  lev_ = getlev(DE$chrs[sig])
  go_todo = lev_[,1]
  inds_m = match(as.character(lev_[,1]), as.character(lev_all[,1]))
  lev_ = cbind(lev_,lev_all[inds_m,1:2,drop=F])
  chrs = as.character(lev_[,1])
  lev_1 = cbind(chrs,t(apply(lev_,1,.phyper2,  k = length(sig), mn = length(ensg))))
  pv_ind = which(dimnames(lev_1)[[2]]=="pv")
  pvs = as.numeric(lev_1[,pv_ind])
  len = length(which(pvs<go_thresh))
  outp = data.frame(lev_1)
  outp[order(pvs)[1:len],]
  
}

#.qqplot<-function(DE1, nme="p_lt"){
#  i = which(dimnames(DE1)[[2]]==nme)[1]
#  expected = -log10(seq(1:dim(DE1)[1])/dim(DE1)[1])
#  observed = -log10(DE1[,i])
#  plot(expected,observed, main = nme)
#}


.qqplot<-function(pvals1,log=F,min.p = 1e-20){
  pvals = pvals1[!is.na(pvals1)]
  expected = -log10(seq(1:length(pvals))/length(pvals))
  observed = if(log) sort(pvals)/log(10) else log10(sort(pvals))
  observed[observed<log10(min.p)]  = log10(min.p)
  plot(expected, -observed)
}
.log10p<-function(pv, log,min.p) {
  pv1 =  if(log) pv/log(10) else  log10(pv)
  pv1[pv1<log10(min.p)] = log10(min.p)
  pv1
}
.vis<-function(depth, i,min.p = 1e-20,log=F, chroms=NULL){
  pv_inds = grep("pv", names(depth))
  pvs = depth[,pv_inds,drop=F]
#  for(i in 1:(dim(pvs)[2])){
    pvs[,i] = .log10p(pvs[,i], log=log, min.p = min.p)
 # }
    ranges = attr(depth, "ranges")
    pos=depth$pos
    
    for(j in 2:(dim(ranges)[1])){
      r2 = as.numeric(ranges[j,])
      offset =  pos[as.numeric(ranges[(j-1),2])]+10e6
      pos[r2[1]:r2[2]] = pos[r2[1]:r2[2]]+offset
     
    }
    if(!is.null(chroms)){
    chr_inds = attr(depth,'chr_inds')
    inds_ = which(chr_inds %in% chroms)
    plot(pos[inds_], pvs[inds_,i], col=0,ylim = c(0,-min(pvs[,i])))
    
    }else{
    plot(pos, -pvs[,i], col=0,ylim = c(0,-min(pvs[,i])))
    }
    for(j in 1:(dim(ranges)[1])) {
      r2 = as.numeric(ranges[j,])
      if(is.null(chroms) || r2[3] %in% chroms){      
        lines(pos[r2[1]:r2[2]], -pvs[r2[1]:r2[2],i], type="p", col=j)
      }
    }
#    invisible(minp)
}

.phyper2<-function(vec1,k,mn){
  vec = as.numeric(vec1[c(2,length(vec1))])
  #print(vec)
  m = vec[2]
  n = mn-vec[2]
  #print(c(vec[1], m,n,k))
  pv =  phyper(vec[1], m = m, n = n, k = k, lower.tail=F) + dhyper(vec[1], m = m, n = n, k=k )
  vals = qhyper(0.99, m = m, n = n, k = k)
  enrich = (vec[1]/k)/(vec[2]/mn)
  enrich1 = vec[1]/vals
  
  res = c(vec, pv, enrich, enrich1)
  names(res) = c("c1", "c2", "pv", "enrich", "enrich99") 
  res
}
