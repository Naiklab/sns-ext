#!/bin/bash

##
## get reference of specified type for specified genome
##

# script filename
script_name=$(basename "${BASH_SOURCE[0]}")

# check for correct number of arguments
if [ $# -ne 1 ] ; then
	echo -e "\n $script_name ERROR: WRONG NUMBER OF ARGUMENTS SUPPLIED \n" >&2
	echo -e "\n USAGE: $script_name ref_type \n" >&2
	exit 1
fi

# arguments
ref_type=$1

#########################

function find_file {
	local file_name=$1

	# find the shortest result
	local result=$(find -L "$(dirname "$file_name")" -type f -name "$(basename "$file_name")" -printf '%s %p\n' | sort -n | head -1 | cut -d ' ' -f 2-)

	if [ -s "$result" ] && [ "$result" ] ; then
		echo "$(readlink -f "$result")"
	else
		echo -e "\n $script_name ERROR: $file_name RESULT $result DOES NOT EXIST \n" >&2
		exit 1
	fi
}

function find_dir {
	local dir_name=$1

	local result=$(find -L "$(dirname "$dir_name")" -type d -iname "$(basename "$dir_name")" | awk '{ print length, $0 }' | sort -n | cut -d " " -f 2 | head -1)

	if [ -s "$result" ] && [ "$result" ] ; then
		echo "$(readlink -f "$result")"
	else
		echo -e "\n $script_name ERROR: $dir_name RESULT $result DOES NOT EXIST \n" >&2
		exit 1
	fi
}

function find_basename {
	local suffix=$1

	# find the shortest result
	local result=$(find -L "$(dirname "$ref_type")" -type f -name "$(basename "$ref_type")${suffix}" -printf '%s %p\n' | sort -n | cut -d ' ' -f 2- | head -1)

	if [ -s "$result" ] && [ "$result" ] ; then
		result=$(readlink -f "$result")
		echo ${result/${suffix}/}
	else
		echo -e "\n $script_name ERROR: $(basename "$ref_type")${suffix} RESULT $result DOES NOT EXIST \n" >&2
		exit 1
	fi
}

#########################
# file references

if [ "$ref_type" == "FASTA" ] ; then
	find_basename .fa
fi

if [ "$ref_type" == "DICT" ] ; then
	 find_basename .dict
fi

if [ "$ref_type" == "REFFLAT" ] ; then
	find_file refFlat.txt.gz
fi

if [ "$ref_type" == "GTF" ] ; then
	find_basename .gtf
fi

if [ "$ref_type" == "CHROMSIZES" ] ; then
	find_basename chrom_sizes_ensembl.txt
fi

if [ "$ref_type" == "2BIT" ] ; then
	find_file genome.2bit
fi

if [ "$ref_type" == "FASTQSCREEN" ] ; then
	find_file fastq_screen.conf
fi

if [ "$ref_type" == "RRNAINTERVALLIST" ] ; then
	find_file /sc/arion/projects/naiklab/ikjot/reference_files/mm10/rRNA.interval_list
fi

if [ "$ref_type" == "BLACKLIST" ] ; then
	find_basename blacklist.bed
fi

# directory references

if [ "$ref_type" == "STAR" ] ; then
	find_dir STAR
fi

if [ "$ref_type" == "BISMARK" ] ; then
	find_dir bismark
fi

if [ "$ref_type" == "RSEM" ] ; then
	echo "$(find_dir rsem)/ref"
fi

if [ "$ref_type" == "SALMON" ] ; then
	find_dir salmon
fi

# basename (file without suffix) references

if [ "$ref_type" == "BOWTIE1" ] ; then
	find_basename .1.ebwt
fi

if [ "$ref_type" == "BOWTIE2" ] ; then
	find_basename .1.bt2*
fi

if [ "$ref_type" == "BWA" ] ; then
	echo "$(find_basename .fa.bwt).fa"
fi

#########################

# end
