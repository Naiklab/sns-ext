#!/bin/bash

source ~/.bashrc  # Reload the bashrc file

##
## ATAC-seq using Bowtie 2
##

# Allocation account and time
account_name="acc_naiklab"
alloc_time="48:00"

# specify maximum runtime for bsub job

#BSUB_RUNTIME=48:00

# script filename
script_path="${BASH_SOURCE[0]}"
script_name=$(basename "$script_path")
route_name=${script_name/%.sh/}
echo -e "\n ========== ROUTE: $route_name ========== \n" >&2

# check for correct number of arguments
if [ ! $# == 2 ] ; then
	echo -e "\n $script_name ERROR: WRONG NUMBER OF ARGUMENTS SUPPLIED \n" >&2
	echo -e "\n USAGE: $script_name project_dir sample_name \n" >&2
	exit 1
fi

# standard route arguments
proj_dir=$(readlink -f "$1")
sample=$2

# paths
code_dir=$(dirname $(dirname "$script_path"))

# reserve a thread for overhead
threads=6
threads=$(( threads - 1 ))

# display settings
echo
echo " * proj_dir: $proj_dir "
echo " * sample: $sample "
echo " * code_dir: $code_dir "
echo " * slurm threads: 6"
echo " * command threads: $threads "
echo

# specify maximum runtime for sbatch job
# SBATCHTIME=24:00:00


#########################


# segments

# rename and/or merge raw input FASTQs
segment_fastq_clean="fastq-clean"
fastq_R1=$(grep -s -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_clean}.csv" | cut -d ',' -f 2)
fastq_R2=$(grep -s -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_clean}.csv" | cut -d ',' -f 3)
if [ -z "$fastq_R1" ] ; then
	bash_cmd="bash ${code_dir}/segments/${segment_fastq_clean}.sh $proj_dir $sample"
	($bash_cmd)
	fastq_R1=$(grep -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_clean}.csv" | cut -d ',' -f 2)
	fastq_R2=$(grep -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_clean}.csv" | cut -d ',' -f 3)
fi

# if FASTQ is not set, there was a problem
if [ -z "$fastq_R1" ] ; then
	echo -e "\n $script_name ERROR: SEGMENT $segment_fastq_clean DID NOT FINISH \n" >&2
	exit 1
fi

# run FastQC (separately for paired-end reads)
segment_qc_fastqc="qc-fastqc"
bash_cmd="bash ${code_dir}/segments/${segment_qc_fastqc}.sh $proj_dir $sample $threads $fastq_R1"
($bash_cmd)
if [ -n "$fastq_R2" ] ; then
	bash_cmd="bash ${code_dir}/segments/${segment_qc_fastqc}.sh $proj_dir $sample $threads $fastq_R2"
	($bash_cmd)
fi

# run alignment
segment_align="align-bowtie2-atac"
bam_bt2=$(grep -s -m 1 "^${sample}," "${proj_dir}/samples.${segment_align}.csv" | cut -d ',' -f 2)
if [ -z "$bam_bt2" ] ; then
	bash_cmd="bash ${code_dir}/segments/${segment_align}.sh $proj_dir $sample $threads $fastq_R1 $fastq_R2"
	($bash_cmd)
	bam_bt2=$(grep -m 1 "^${sample}," "${proj_dir}/samples.${segment_align}.csv" | cut -d ',' -f 2)
fi

# if BAM is not set, there was a problem
if [ -z "$bam_bt2" ] ; then
	echo -e "\n $script_name ERROR: SEGMENT $segment_align DID NOT FINISH \n" >&2
	exit 1
fi

# remove duplicates
segment_dedup="bam-dedup-sambamba"
bam_dd=$(grep -s -m 1 "^${sample}," "${proj_dir}/samples.${segment_dedup}.csv" | cut -d ',' -f 2)
if [ -z "$bam_dd" ] ; then
	bash_cmd="bash ${code_dir}/segments/${segment_dedup}.sh $proj_dir $sample $threads $bam_bt2"
	($bash_cmd)
	bam_dd=$(grep -m 1 "^${sample}," "${proj_dir}/samples.${segment_dedup}.csv" | cut -d ',' -f 2)
fi

# if BAM is not set, there was a problem
if [ -z "$bam_dd" ] ; then
	echo -e "\n $script_name ERROR: SEGMENT $segment_dedup DID NOT FINISH \n" >&2
	exit 1
fi

# generate BigWig (deeptools)
segment_bw_deeptools="bigwig-deeptools"
bash_cmd="bash ${code_dir}/segments/${segment_bw_deeptools}.sh $proj_dir $sample 4 $bam_star"
bsub_cmd="bsub -W 48:00 -R rusage[mem=16000] -R span[hosts=1] -R himem -P ${account_name}  -n ${threads} -q premium -J sns.${segment_bw_deeptools}.${sample} ${bash_cmd}"
echo "CMD: $bsub_cmd"
(eval $bsub_cmd)

# fragment size distribution
segment_qc_frag_size="qc-fragment-sizes"
bash_cmd="bash ${code_dir}/segments/${segment_qc_frag_size}.sh $proj_dir $sample $bam_dd"
($bash_cmd)

# call peaks with MACS2
segment_peaks_macs2="peaks-macs2"
bash_cmd="bash ${code_dir}/segments/${segment_peaks_macs2}.sh $proj_dir atac 0.05 $sample $bam_dd"
($bash_cmd)

# call peaks with HMMRATAC (original Java implementation) - Disregard this step
#segment_peaks_hmmratac="peaks-hmmratac"
#bash_cmd="bash ${code_dir}/segments/${segment_peaks_hmmratac}.sh $proj_dir $sample $bam_dd 30"
#($bash_cmd)

# call peaks with MACS3 HMMRATAC
#segment_peaks_macs3_hmmratac="peaks-macs3-hmmratac"
#bash_cmd="bash ${code_dir}/segments/${segment_peaks_macs3_hmmratac}.sh $proj_dir $sample $bam_dd"
#($bash_cmd)

# call nucleosomes
# segment_nuc="nucleosomes-nucleoatac"
# bash_cmd="bash ${code_dir}/segments/${segment_nuc}.sh $proj_dir $sample $threads $bam_dd"
# ($bash_cmd)


#########################


# combine summary from each step

sleep 5

summary_csv="${proj_dir}/summary-combined.${route_name}.csv"

bash_cmd="
bash ${code_dir}/scripts/join-many.sh , X \
${proj_dir}/summary.${segment_fastq_clean}.csv \
${proj_dir}/summary.${segment_align}.csv \
${proj_dir}/summary.${segment_dedup}.csv \
${proj_dir}/summary.${segment_peaks_macs2}-atac-q-0.05.csv \
${proj_dir}/summary.${segment_peaks_hmmratac}-score-30.csv \
${proj_dir}/summary.${segment_peaks_macs3_hmmratac}.csv \
> $summary_csv
"
(eval $bash_cmd)


#########################


date



# end
