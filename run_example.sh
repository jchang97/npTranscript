##script for running 
##tip - use symbolic link to put this in the directory with bam files
npTranscript=${HOME}/github/npTranscript

bamdir="."
bamfiles=$(ls ${bamdir} | grep '.bam' | xargs -I {} echo ${bamdir}/{})

reference="${npTranscript}/data/SARS-Cov2/wuhan_coronavirus_australia.fasta.gz"
coord_file="${npTranscript}/data/SARS-Cov2/Coordinates.csv"

dat=$(date +%Y%m%d%H%M%S)
resdir="results_${dat}"
opts="--bin 10 --breakThresh 1000 --cluster_by_annotation true"
bash ${npTranscript}/run.sh --bamFile=${bamfiles}   --reference=${reference}   --annotation ${coord_file}   --resdir ${resdir} ${opts}

bash ${npTranscript}/run_extract_cluster.sh --inDir ${resdir} 
