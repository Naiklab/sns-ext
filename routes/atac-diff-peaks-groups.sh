#!/bin/bash


##
## ATAC-seq differential peak analysis and annotation using Diffbind + CHIPSeeker
##



# script filename
script_path="${BASH_SOURCE[0]}"
script_name=$(basename "$script_path")
route_name=${script_name/%.sh/}
echo -e "\n ========== ROUTE: $route_name ========== \n" >&2

# check for correct number of arguments
if [ ! $# == 1 ] ; then
	echo -e "\n $script_name ERROR: WRONG NUMBER OF ARGUMENTS SUPPLIED \n" >&2
	echo -e "\n USAGE: $script_name project_dir \n" >&2
	exit 1
fi

# standard comparison route arguments

# old approach
#proj_dir=$(readlink -f "$1")
#peaks_dir=$(readlink -f "$2")
#BAM_dir=$(readlink -f "$3")
#genome=$(readlink -f "$4")

while getopts proj_dir:peaks_dir:bam_dir:genome:sheet flag
do
    case "${flag}" in
        proj_dir) proj=${OPTARG};;
        peaks_dir) peaks=${OPTARG};;
        bam_dir) bam=${OPTARG};;
        genome) genome=${OPTARG};;
        sheet) sheet=${OPTARG};;
    esac
done

# additional settings
code_dir=$(dirname $(dirname "$script_path"))

# display settings
echo
echo " * proj_dir: $proj "
echo " * peaks_dir: $peaks "
echo " * BAM_dir: $bam "
echo " * genome: $genome "
echo " * sheet: $sheet "
echo


#########################


# check that inputs exist

if [ ! -d "$proj_dir" ] ; then
	echo -e "\n $script_name ERROR: DIR $proj_dir DOES NOT EXIST \n" >&2
	exit 1
fi

if [ ! -d "$peaks_dir" ] ; then
	echo -e "\n $script_name ERROR: DIR $peaks_dir DOES NOT EXIST \n" >&2
	exit 1
fi

if [ ! -d "$BAM_dir" ] ; then
	echo -e "\n $script_name ERROR: DIR $BAM_dir DOES NOT EXIST \n" >&2
	exit 1
fi

if [ ! -d "$genome" ] ; then
	echo -e "\n $script_name ERROR: -genome not specified, choose between hg38 or mm10 \n" >&2
	exit 1
fi

groups_table="$sheet"

if [ ! -s "$groups_table" ] ; then
	echo -e "\n $script_name ERROR: GROUP TABLE $groups_table DOES NOT EXIST \n" >&2
	exit 1
fi

num_samples=$(cat "$groups_table" | grep -v "SampleID" | wc -l)

if [ "$num_samples" -lt 3 ] ; then
	echo -e "\n $script_name ERROR: $num_samples is too few samples \n" >&2
	exit 1
fi

num_groups=$(cat "$groups_table" | grep -v "SampleID" | cut -d "," -f 2 | sort | uniq | wc -l)


# unload all loaded modulefiles
module purge
module add default-environment


#########################


# settings and files

dge_dir="${proj_dir}/DE-PEAKS-DiffBind-${num_samples}samples-${num_groups}groups"
mkdir -v "$dge_dir"

dge_inputs_dir="${dge_dir}/inputs"
mkdir -v "$dge_inputs_dir"

input_groups_table="${dge_inputs_dir}/input.groups.csv"



#########################


# exit if output exits already

if [ -s "$input_groups_table" ] ; then
	echo -e "\n $script_name ERROR: TABLE $input_groups_table ALREADY EXISTS \n" >&2
	exit 1
fi


#########################


echo -e "\n ========== set up inputs ========== \n"

echo
echo " * groups table: $groups_table "
echo


bash_cmd="rsync -t $groups_table $input_groups_table"
echo "CMD: $bash_cmd"
($bash_cmd)

sleep 3


#########################


echo -e "\n ========== test R environment ========== \n"

# load relevant modules
module add r/4.1.2

echo
echo " * R: $(readlink -f $(which R)) "
echo " * R version: $(R --version | head -1) "
echo " * Rscript: $(readlink -f $(which Rscript)) "
echo " * Rscript version: $(Rscript --version 2>&1) "
echo

Rscript --vanilla "${code_dir}/scripts/test-package.R" optparse
Rscript --vanilla "${code_dir}/scripts/test-package.R" mnormt
Rscript --vanilla "${code_dir}/scripts/test-package.R" limma

sleep 5


#########################


echo -e "\n ========== start analysis ========== \n"

# extract the genome build from the genome dir
genome_build=$(basename "$genome_dir")

echo
echo " * genome: $genome_build "
echo " * GTF: $gtf "
echo

cd "$dge_dir" || exit 1

# launch the analysis R script
bash_cmd="Rscript --vanilla ${code_dir}/scripts/de-peaks-diffbind.R $genome_build  $input_groups_table"
echo "CMD: $bash_cmd"
($bash_cmd)


#########################


date



# end