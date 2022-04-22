#!/bin/bash

# Collects QC data for SV VCF output by SV pipeline
# Cohort-level benchmarking comparisons to external dataset

set -e

###USAGE
usage(){
cat <<EOF

usage: collectQC.external_benchmarking.sh [-h] [-r REF] STATS SVTYPES COMPARATOR BENCHDIR OUTDIR

Helper tool to collect cohort-level bechmarking data for a VCF output by sv-pipeline vs. an external dataset

Positional arguments:
  STATS           VCF stats file generated by collectQC.vcf_wide.sh
  SVTYPES         List of SV types to evaluate. Two-column, tab-delimited file.
                  First column: sv type. Second column: HEX color for sv type.
  COMPARATOR      Comparison dataset used in benchmarking. Specify one of the
                  following: 'ASC_Werling', 'HGSV_Chaisson', or '1000G_Sudmant'
  BENCHDIR        Directory containing benchmark archives
  OUTDIR          Output directory for all QC data

Optional arguments:
  -h  HELP        Show this help message and exit
  -q  QUIET       Silence all status updates

EOF
}


###PARSE ARGS
QUIET=0
while getopts ":qh" opt; do
	case "$opt" in
		h)
			usage
			exit 0
			;;
    q)
      QUIET=1
      ;;
	esac
done
shift $(( ${OPTIND} - 1))
STATS=$1
SVTYPES=$2
COMPARATOR=$3
BENCHDIR=$4
OUTDIR=$5


###PROCESS ARGS & OPTIONS
#Check for required input
if [ -z ${STATS} ]; then
  echo -e "\nERROR: input VCF stats file not specified\n"
  usage
  exit 0
fi
if ! [ -s ${STATS} ]; then
  echo -e "\nERROR: input VCF stats file either empty or not found\n"
  usage
  exit 0
fi
if [ ${COMPARATOR} != "ASC_Werling" ] && [ ${COMPARATOR} != "HGSV_Chaisson" ] && \
   [ ${COMPARATOR} != "1000G_Sudmant" ]; then
  echo -e "\nERROR: COMPARATOR must be one of 'ASC_Werling', 'HGSV_Chaisson', or '1000G_Sudmant'\n"
  usage
  exit 0
fi
if [ -z ${OUTDIR} ]; then
  echo -e "\nERROR: output directory not specified\n"
  usage
  exit 0
fi


###SET BIN
BIN=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


###PREP INPUT FILES
#Print status
if [ ${QUIET} == 0 ]; then
  echo -e "$( date ) - VCF QC STATUS: Preparing input files for external benchmarking"
fi
#Prep directories
QCTMP=`mktemp -d`
if ! [ -e ${OUTDIR} ]; then
  mkdir ${OUTDIR}
fi
if ! [ -e ${OUTDIR}/data ]; then
  mkdir ${OUTDIR}/data
fi
mkdir ${QCTMP}/perSample
#Gather SV types to process
cut -f1 ${SVTYPES} | sort | uniq > ${QCTMP}/svtypes.txt


###GATHER EXTERNAL BENCHMARKING
#Print status
if [ ${QUIET} == 0 ]; then
  echo -e "$( date ) - VCF QC STATUS: Starting external benchmarking"
fi
#1000G (Sudmant) with allele frequencies
if [ ${COMPARATOR} == "1000G_Sudmant" ]; then
  for pop in ALL AFR AMR EAS EUR SAS; do
    #Print status
    if [ ${QUIET} == 0 ]; then
      echo -e "$( date ) - VCF QC STATUS: Benchmarking ${pop} samples in ${COMPARATOR}"
    fi
    ${BIN}/compare_callsets.sh \
      -O ${QCTMP}/1000G_Sudmant.SV.${pop}.overlaps.bed \
      -p 1000G_Sudmant_${pop}_Benchmarking_SV \
      ${STATS} \
      ${BENCHDIR}/1000G_Sudmant.SV.${pop}.bed.gz
  cp ${QCTMP}/1000G_Sudmant.SV.${pop}.overlaps.bed \
     ${OUTDIR}/data/1000G_Sudmant.SV.${pop}.overlaps.bed
  bgzip -f ${OUTDIR}/data/1000G_Sudmant.SV.${pop}.overlaps.bed
  tabix -f ${OUTDIR}/data/1000G_Sudmant.SV.${pop}.overlaps.bed.gz
  done
fi
#ASC (Werling) with carrier frequencies
if [ ${COMPARATOR} == "ASC_Werling" ]; then
  for pop in ALL EUR OTH; do
    #Print status
    if [ ${QUIET} == 0 ]; then
      echo -e "$( date ) - VCF QC STATUS: Benchmarking ${pop} samples in ${COMPARATOR}"
    fi
    ${BIN}/compare_callsets.sh -C \
      -O ${QCTMP}/ASC_Werling.SV.${pop}.overlaps.bed \
      -p ASC_Werling_${pop}_Benchmarking_SV \
      ${STATS} \
      ${BENCHDIR}/ASC_Werling.SV.${pop}.bed.gz
  cp ${QCTMP}/ASC_Werling.SV.${pop}.overlaps.bed \
     ${OUTDIR}/data/ASC_Werling.SV.${pop}.overlaps.bed
  bgzip -f ${OUTDIR}/data/ASC_Werling.SV.${pop}.overlaps.bed
  tabix -f ${OUTDIR}/data/ASC_Werling.SV.${pop}.overlaps.bed.gz
  done
fi
#HGSV (Chaisson) with carrier frequencies
if [ ${COMPARATOR} == "HGSV_Chaisson" ]; then
  for pop in ALL AFR AMR EAS; do
    #Print status
    if [ ${QUIET} == 0 ]; then
      echo -e "$( date ) - VCF QC STATUS: Benchmarking ${pop} samples in ${COMPARATOR}"
    fi
    ${BIN}/compare_callsets.sh -C \
      -O ${QCTMP}/HGSV_Chaisson.SV.${pop}.overlaps.bed \
      -p HGSV_Chaisson_${pop}_Benchmarking_SV \
      ${STATS} \
      ${BENCHDIR}/HGSV_Chaisson.SV.hg19_liftover.${pop}.bed.gz
  cp ${QCTMP}/HGSV_Chaisson.SV.${pop}.overlaps.bed \
     ${OUTDIR}/data/HGSV_Chaisson.SV.${pop}.overlaps.bed
  bgzip -f ${OUTDIR}/data/HGSV_Chaisson.SV.${pop}.overlaps.bed
  tabix -f ${OUTDIR}/data/HGSV_Chaisson.SV.${pop}.overlaps.bed.gz
  done
fi


###CLEAN UP
rm -rf ${QCTMP}
