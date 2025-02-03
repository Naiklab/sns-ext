#!/bin/bash

##
## RNA-seq using STAR aligner
##

source ~/.bashrc  # Reload the bashrc file

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
# Allocation account and time
account_name="acc_naiklab"
alloc_time="48:00"

# standard route arguments
proj_dir=$(readlink -f "$1")
sample=$2

# paths
code_dir=$(dirname $(dirname "$script_path"))

# reserve a thread for overhead
threads=6
threads=$(( threads - 1 ))

# specify maximum runtime for bsub job

#BSUB_RUNTIME=48:00

# display settings
echo
echo " * proj_dir: $proj_dir "
echo " * sample: $sample "
echo " * code_dir: $code_dir "
echo " * bsubthreads: $threads "
echo " * command threads: $threads "
echo " * alloc_account: $account_name "
echo " * alloc_time: $alloc_time "
echo




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
eval "$bash_cmd"
if [ -n "$fastq_R2" ] ; then
	bash_cmd="bash ${code_dir}/segments/${segment_qc_fastqc}.sh $proj_dir $sample $threads $fastq_R2"
	eval "$bash_cmd"
fi

# fastq_screen 
bash_cmd="bash ${code_dir}/segments/qc-fastqscreen.sh $proj_dir $sample $threads $fastq_R1"
eval "$bash_cmd"

# trim FASTQs with Trimmomatic
segment_fastq_trim="fastq-trim-trimmomatic"
fastq_R1_trimmed=$(grep -s -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_trim}.csv" | cut -d ',' -f 2)
fastq_R2_trimmed=$(grep -s -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_trim}.csv" | cut -d ',' -f 3)
if [ -z "$fastq_R1_trimmed" ] ; then
	bash_cmd="bash ${code_dir}/segments/${segment_fastq_trim}.sh $proj_dir $sample $threads $fastq_R1 $fastq_R2"
	eval "$bash_cmd"
	fastq_R1_trimmed=$(grep -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_trim}.csv" | cut -d ',' -f 2)
	fastq_R2_trimmed=$(grep -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_trim}.csv" | cut -d ',' -f 3)
fi

# if trimmed FASTQ is not set, there was a problem
if [ -z "$fastq_R1_trimmed" ] ; then
	echo -e "\n $script_name ERROR: SEGMENT $segment_fastq_trim DID NOT FINISH \n" >&2
	exit 1
fi

# run FastQC again after trimming (separately for paired-end reads)
segment_qc_fastqc="qc-fastqc"
bash_cmd="bash ${code_dir}/segments/${segment_qc_fastqc}.sh $proj_dir $sample $threads $fastq_R1_trimmed"
($bash_cmd)
if [ -n "$fastq_R2_trimmed" ] ; then
	bash_cmd="bash ${code_dir}/segments/${segment_qc_fastqc}.sh $proj_dir $sample $threads $fastq_R2_trimmed"
	($bash_cmd)
fi

# run STAR
segment_align="align-star"
bam_star=$(grep -s -m 1 "^${sample}," "${proj_dir}/samples.${segment_align}.csv" | cut -d ',' -f 2)
if [ -z "$bam_star" ] ; then
	bash_cmd="bash ${code_dir}/segments/${segment_align}.sh $proj_dir $sample $threads $fastq_R1_trimmed $fastq_R2_trimmed"
	($bash_cmd)
	bam_star=$(grep -m 1 "^${sample}," "${proj_dir}/samples.${segment_align}.csv" | cut -d ',' -f 2)
fi

# if STAR BAM is not set, there was a problem
if [ -z "$bam_star" ] ; then
	echo -e "\n $script_name ERROR: SEGMENT $segment_align DID NOT FINISH \n" >&2
	exit 1
fi

# generate BigWig (deeptools)
segment_bw_deeptools="bigwig-deeptools"
bash_cmd="bash ${code_dir}/segments/${segment_bw_deeptools}.sh $proj_dir $sample 4 $bam_star"
bsub_cmd="bsub -W 48:00 -R rusage[mem=16000] -R span[hosts=1] -R himem -P ${account_name}  -n ${threads} -q premium -J sns.${segment_bw_deeptools}.${sample} ${bash_cmd}"
echo "CMD: $bsub_cmd"
(eval $bsub_cmd)

# Picard CollectRnaSeqMetrics
segment_qc_picard="qc-picard-rnaseqmetrics"
bash_cmd="bash ${code_dir}/segments/${segment_qc_picard}.sh $proj_dir $sample $bam_star"
(eval $bash_cmd)

# determine run type for featurecounts
if [ -n "$fastq_R2" ] ; then
	run_type="PE"
else
	run_type="SE"
fi

# determine strand
exp_strand=$(bash "${code_dir}/scripts/get-set-setting.sh" "${proj_dir}/settings.txt" EXP-STRAND);

# generate counts
segment_quant="quant-featurecounts"
bash_cmd="bash ${code_dir}/segments/${segment_quant}.sh $proj_dir $sample $threads $bam_star $run_type $exp_strand"
($bash_cmd)

# generate unstranded counts just in case
if [ "$exp_strand" != "unstr" ] ; then
	bash_cmd="bash ${code_dir}/segments/${segment_quant}.sh $proj_dir $sample $threads $bam_star $run_type unstr"
	($bash_cmd)
fi


#########################


# combine summary from each step

sleep 5

summary_csv="${proj_dir}/summary-combined.${route_name}.csv"

bash_cmd="
bash ${code_dir}/scripts/join-many.sh , X \
${proj_dir}/summary.${segment_fastq_clean}.csv \
${proj_dir}/summary.${segment_fastq_trim}.csv \
${proj_dir}/summary.${segment_align}.csv \
${proj_dir}/summary.${segment_quant}-unstr.csv \
${proj_dir}/summary.${segment_quant}-${exp_strand}.csv \
${proj_dir}/summary.${segment_qc_picard}.csv \
> $summary_csv
"
(eval $bash_cmd)


#########################


# generate groups sample sheet template

samples_groups_csv="${proj_dir}/samples.groups.csv"

if [ ! -s "$samples_groups_csv" ] ; then
	echo "#SAMPLE,group" > $samples_groups_csv
	sed 's/\,.*/,NA/g' ${proj_dir}/samples.fastq-raw.csv | LC_ALL=C sort -u >> $samples_groups_csv
fi


#########################


date



# end

