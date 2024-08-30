#!/bin/bash


# run STAR
bsub -J "STAR" -o "${star_logs_dir}/star.log" -e "${star_logs_dir}/star.err" -n ${threads} -R "span[hosts=1]" -M 32G -W 24:00 -q normal "STAR \
--runThreadN ${threads} \
--genomeDir ${ref_star} \
--genomeLoad NoSharedMemory \
--outFilterMismatchNoverLmax 0.2 \
--outFilterMultimapNmax 1 \
--outFilterType BySJout \
--outSAMstrandField intronMotif \
--outSAMattributes NH HI AS nM NM MD XS \
--outSAMattrRGline ID:${sample} SM:${sample} LB:${sample} PL:ILLUMINA \
--outSAMmapqUnique 60 \
--twopassMode Basic \
--readFilesCommand zcat \
--readFilesIn ${fastq_R1} ${fastq_R2} \
--outFileNamePrefix ${star_prefix} \
--quantMode GeneCounts \
--outSAMtype BAM Unsorted \
--outStd BAM_Unsorted | \
samtools sort -m 32G -T ${sample}.samtools -o ${bam} -"
"
echo "CMD: $bash_cmd"
eval "$bash_cmd"

sleep 5

# index bam
bash_cmd="samtools index $bam"
echo "CMD: $bash_cmd"
eval "$bash_cmd"

sleep 5


#########################


# delete tmp directories (_STARtmp should be empty at this point)
rm -rfv ${star_prefix}_STAR*


#########################


# check that output generated

# check if BAM file is present
if [ ! -s "$bam" ] ; then
	echo -e "\n $script_name ERROR: BAM $bam not generated \n" >&2
	exit 1
fi

# check if BAM index is present (generated only if BAM is valid)
if [ ! -s "$bai" ] ; then
	echo -e "\n $script_name ERROR: BAM index $bai not generated \n" >&2
	# delete BAM since something went wrong and it might be corrupted
	rm -fv "$bam"
	exit 1
fi

# check if gene counts file is present
if [ ! -s "${star_prefix}ReadsPerGene.out.tab" ] ; then
	echo -e "\n $script_name ERROR: counts ${star_prefix}ReadsPerGene.out.tab not generated \n" >&2
	# delete BAM and BAI since something went wrong and they might be corrupted
	rm -fv "$bam"
	rm -fv "$bai"
	exit 1
fi


#########################


# STAR counts
# not using the counts downstream since the file is hard to filter and uses gene ids instead of gene names

# STAR outputs read counts per gene into ReadsPerGene.out.tab file with 4 columns which correspond to strandedness:
# column 1: gene ID
# column 2: counts for unstranded RNA-seq
# column 3: counts for the 1st read strand aligned with RNA (htseq-count option -s yes)
# column 4: counts for the 2nd read strand aligned with RNA (htseq-count option -s reverse)

# move counts file to a separate bam-only directory
CMD="mv -v ${star_prefix}ReadsPerGene.out.tab $counts_txt"
echo "CMD: $CMD"
eval "$CMD"

# strand:
# fwd | transcript             | cufflinks "fr-secondstrand" | htseq "yes"     | picard "FIRST_READ"
# rev | rev comp of transcript | cufflinks "fr-firststrand"  | htseq "reverse" | picard "SECOND_READ"

# top 1000 genes (useful to determine strandness)
echo -e "#gene_id,unstr,fwd,rev" > "${star_quant_dir}/${sample}.top1000.csv"
cat "$counts_txt" | LC_ALL=C sort -k2,2nr | head -n 1000 | tr '\t' ',' >> "${star_quant_dir}/${sample}.top1000.csv"


#########################


# determine strand

# get total counts for each strand
counts_unstr=$(cat $counts_txt | grep -v 'N_' | awk -F $'\t' '{sum+=$2} END {print sum}')
echo "counts unstr: $counts_unstr"
counts_fwd=$(cat $counts_txt | grep -v 'N_' | awk -F $'\t' '{sum+=$3} END {print sum}')
echo "counts fwd: $counts_fwd"
counts_rev=$(cat $counts_txt | grep -v 'N_' | awk -F $'\t' '{sum+=$4} END {print sum}')
echo "counts rev: $counts_rev"

lib_strand="unstr"

if [ "$(echo "${counts_fwd}/${counts_rev}" | bc)" -gt 5 ] ; then
	lib_strand="fwd"
fi

if [ "$(echo "${counts_rev}/${counts_fwd}" | bc)" -gt 5 ] ; then
	lib_strand="rev"
fi

# set experiment strand if the file meets some quality standards (strand not set if previously set)
if [ "$counts_unstr" -gt 10000 ] ; then
	exp_strand=$(bash "${code_dir}/scripts/get-set-setting.sh" "${proj_dir}/settings.txt" EXP-STRAND "$lib_strand");
fi

# generate an error for low quality files
if [ "$counts_unstr" -lt 1000 ] || [ "$counts_fwd" -lt 10 ] || [ "$counts_rev" -lt 10 ] ; then
	echo -e "\n $script_name ERROR: low counts \n" >&2
fi

echo "sample strand: $lib_strand"
echo "experiment strand: $exp_strand"


#########################


# generate alignment summary

# header for summary file
echo "#SAMPLE,INPUT READS,UNIQUELY MAPPED,MULTI-MAPPED,UNIQUELY MAPPED %,MULTI-MAPPED %" > "$summary_csv"

# print the relevant numbers from log file
star_log_final="${star_prefix}Log.final.out"
paste -d ',' \
<(echo "$sample") \
<(cat "$star_log_final" | grep "Number of input reads"                   | head -1 | tr -d "[:blank:]" | cut -d "|" -f 2) \
<(cat "$star_log_final" | grep "Uniquely mapped reads number"            | head -1 | tr -d "[:blank:]" | cut -d "|" -f 2) \
<(cat "$star_log_final" | grep "Number of reads mapped to too many loci" | head -1 | tr -d "[:blank:]" | cut -d "|" -f 2) \
<(cat "$star_log_final" | grep "Uniquely mapped reads %"                 | head -1 | tr -d "[:blank:]" | cut -d "|" -f 2) \
<(cat "$star_log_final" | grep "% of reads mapped to too many loci"      | head -1 | tr -d "[:blank:]" | cut -d "|" -f 2) \
>> "$summary_csv"

sleep 5

# combine all sample summaries
cat ${summary_dir}/*.${segment_name}.csv | LC_ALL=C sort -t ',' -k1,1 | uniq > "${proj_dir}/summary.${segment_name}.csv"


#########################


# add sample and BAM to sample sheet
echo "${sample},${bam}" >> "$samples_csv"

sleep 5


#########################



# end
