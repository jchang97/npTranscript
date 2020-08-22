#!/bin/bash

#SBATCH --job-name=VERO
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --mem=31800 # mb
#SBATCH --time=100:00:00
#SBATCH --output=corona1.stdout
#SBATCH --error=corona1.stderr
#SBATCH --cpus-per-task=8


##script for running 
##tip - use symbolic link to put this in the directory with bam files
export JSA_MEM=30000m

if [ ! $reference_virus ]; then
  export reference_virus="${npTranscript}/data/SARS-Cov2/VIC01/wuhan_coronavirus_australia.fasta.gz"
  export coord_file_virus="${npTranscript}/data/SARS-Cov2/VIC01/Coordinates.csv"
fi

species=$1
shift;
if [ $species == "human" ]; then
	reference="/DataOnline/Data/Projects/corona_invitro/host_analysis/db/merged/human_virus_sequin_ensembl_pri_merged_genome.fasta"
	coord_file="/DataOnline/Data/Projects/corona_invitro/host_analysis/db/human/ensembl/Homo_sapiens.GRCh38.100.gtf.gz"
#coord_file="/home/lcoin/Homo_sapiens.GRCh38.100.gtf.gz"
	GFF_features="--GFF_features=gene_name:description:gene_id:gene_biotype:gene_id"
elif [ $species =="monkey" ]; then
	reference="/DataOnline/Data/Projects/corona_invitro/host_analysis/db/merged/monkey_virus_sequin_genome.fasta"
	coord_file="/DataOnline/Data/raw_external/Coronavirus/monkey/newdb/Chlorocebus_sabaeus.ChlSab1.1.99.gff3.gz"
	GFF_features="-GFF_features=Name:description:ID:biotype:Parent"
else 
	print("first command needs to be monkey or human")
fi


if [ ! $npTranscript ] ; then
	npTranscript=${HOME}/github/npTranscript
fi 

dat=$(date +%Y%m%d%H%M%S)
mm2_path="/sw/minimap2/current/minimap2"

mode=$1
shift
if [ ! $mode ];then
 mode="combined"
fi

bamdir="."
bamfiles=$(ls ${bamdir} | grep '.bam$' | xargs -I {} echo ${bamdir}/{})
bamfiles_="--bamFile=${bamfiles}"
bamfiles1=$(echo $bamfiles_ | sed 's/ /:/g')

##SPECIFY LOCATION OF COMBINED AND VIRUS ONLY DB
cov_chr=$(zcat ${reference_virus} | head -n 1 | cut -f 1 -d ' ' | sed 's/>//g')
echo "coronavirus chr id ${cov_chr}" 
resdir="results_${dat}"
opts="--bin=100 --breakThresh=100 --coronavirus=false --maxThreads=8 --extra_threshold=100 --writePolyA=true --msaDepthThresh=1000 --doMSA=false --numExonsMSA=1:2:3:4:5 --msa_source=RNA --useExons=true --span=protein_coding --includeStart=false --isoformDepthThresh 50"

#for dRNA datasets
opts="${opts} --RNA=true"
opts2="--fail_thresh=0  --chromsToRemap=${cov_chr}  --mm2_memory=10g --recordDepthByPosition=true"

opts="${opts} $@"
echo $opts
bash ${npTranscript}/scripts/run.sh ${bamfiles1}   --reference=${reference} --annotation=${coord_file} --resdir=${resdir} ${opts} ${opts1} ${opts2} ${GFF_features}

cd ${resdir}

bash ${npTranscript}/scripts/run_slurm_virus_fastq.sh
