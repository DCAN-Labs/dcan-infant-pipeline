#!/bin/bash

# get source directory
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# --------------------------------------------------------------------------------
#  Load Function Libraries
# --------------------------------------------------------------------------------

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions

########################################## SUPPORT FUNCTIONS ##########################################

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

show_usage() {
    echo "Usage information To Be Written"
    exit 1
}

# --------------------------------------------------------------------------------
#   Establish tool name for logging
# --------------------------------------------------------------------------------
log_SetToolName "hcp_fnl_prep.sh"

################################################## OPTION PARSING #####################################################

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
    show_usage
fi

log_Msg "Parsing Command Line Options"

# Input Variables
StudyFolder=`opts_GetOpt1 "--path" $@`
Subject=`opts_GetOpt1 "--subject" $@`
StudyAtlasHead=`opts_GetOpt1 "--sshead" $@`
StudyAtlasBrain=`opts_GetOpt1 "--ssbrain" $@`
StudyAtlasAseg=`opts_GetOpt1 "--ssaseg" $@`
FieldMapType=`opts_GetOpt1 "--fieldmap" $@`
MultiAtlasDir=`opts_GetOpt1 "--mtdir" $@`
DOF=`opts_GetOpt1 "--dof" $@`
NCores=`opts_GetOpt1 "--ncores" $@`


# preset naming conventions
MultiAtlasT1wBrain="T1w_brain.nii.gz"
MultiAtlasSeg="Segmentation.nii.gz"

WD=${StudyFolder}/${Subject}/masks

Council=($(cd ${MultiAtlasDir}; ls -d */ | cut -f1 -d'/'))
cd ${StudyFolder}/${Subject}

# Defaults
DOF=${DOF:-6} # adding default behavior

# create prep directory
# commenting out rewrite method...
#if [ -e masks ]; then rm -rf masks; fi

mkdir -p "$WD"
cp unprocessed/NIFTI/* "$WD"
pushd "$WD" > /dev/null

# identify images, denoise them
a=0
for i in `ls ${Subject}_T1w_MPR?.nii.gz`; do 
T1w_files[${a}]=${i}
${ANTSPATH}${ANTSPATH:+/}DenoiseImage -d 3 -i $i -v -o $i
a=`expr $a + 1`
done
numT1s=${#T1w_files[*]}
a=0
for i in `ls ${Subject}_T2w_SPC?.nii.gz`; do 
T2w_files[${a}]=${i}
${ANTSPATH}${ANTSPATH:+/}DenoiseImage -d 3 -i $i -v -o $i
a=`expr $a + 1`
done
numT2s=${#T2w_files[*]}


# generate average structural volumes and bias field correct them
if [ $numT1s -gt 1 ]; then 
	flirt_average ${numT1s} ${T1w_files[*]} ${Subject}_T1w_MPR_average.nii.gz
else 
	cp ${T1w_files[0]} ${Subject}_T1w_MPR_average.nii.gz
fi
if [ $numT2s -gt 1 ]; then 
	flirt_average ${numT2s} ${T2w_files[*]} ${Subject}_T2w_SPC_average.nii.gz
else 
	cp ${T2w_files[0]} ${Subject}_T2w_SPC_average.nii.gz
fi


# run bias field correction
mv ${Subject}_T1w_MPR_average.nii.gz ${Subject}_T1w_MPR_average_biased.nii.gz
${ANTSPATH}${ANTSPATH:+/}N4BiasFieldCorrection -v -d 3 -s 2 -i ${Subject}_T1w_MPR_average_biased.nii.gz -o ${Subject}_T1w_MPR_average.nii.gz
mv ${Subject}_T2w_SPC_average.nii.gz ${Subject}_T2w_SPC_average_biased.nii.gz
${ANTSPATH}${ANTSPATH:+/}N4BiasFieldCorrection -v -d 3 -s 2 -i ${Subject}_T2w_SPC_average_biased.nii.gz -o ${Subject}_T2w_SPC_average.nii.gz


# get skull stripped image and freesurfer segmentations
mkdir -p antsSkullStrip
pushd antsSkullStrip > /dev/null

echo ${DIR}/scripts/antsSkullStrip.sh --input="$WD"/${Subject}_T1w_MPR_average.nii.gz --output="$WD"/${Subject}_T1w_MPR_average_brain.nii.gz \
		--folder="$WD"/antsSkullStrip --atlas-head="$StudyAtlasHead" --atlas-brain="$StudyAtlasBrain" \
		--keep-files --refine ${DOF:+"--dof="}$DOF

${DIR}/scripts/antsSkullStrip.sh --input="$WD"/${Subject}_T1w_MPR_average.nii.gz --output="$WD"/${Subject}_T1w_MPR_average_brain.nii.gz \
		--folder="$WD"/antsSkullStrip --atlas-head="$StudyAtlasHead" --atlas-brain="$StudyAtlasBrain" \
		--keep-files --refine ${DOF:+"--dof="}$DOF

popd > /dev/null
# apply T1w mask to T2w image
fslmaths ${Subject}_T1w_MPR_average_brain.nii.gz -bin ${Subject}_T1w_MPR_average_mask.nii.gz
flirt -dof 6 -cost mutualinfo -in ${Subject}_T1w_MPR_average.nii.gz -ref ${Subject}_T2w_SPC_average.nii.gz -omat ${Subject}_T1toT2.mat
flirt -interp nearestneighbour -in ${Subject}_T1w_MPR_average_mask.nii.gz -ref ${Subject}_T2w_SPC_average.nii.gz -init ${Subject}_T1toT2.mat -applyxfm -o ${Subject}_T2w_SPC_average_mask.nii.gz
fslmaths ${Subject}_T2w_SPC_average.nii.gz -mas ${Subject}_T2w_SPC_average_mask.nii.gz  ${Subject}_T2w_SPC_average_brain.nii.gz

# if DFM is being used, create a DFM mask from the T2
if [ $FieldMapType = "FIELDMAP" ]; then 
flirt -dof 6 -in ${Subject}_T1w_MPR_average.nii.gz -ref ${Subject}_FieldMap_Magnitude.nii.gz -omat ${Subject}_T1toDFM.mat; flirt -interp nearestneighbour -in ${Subject}_T1w_MPR_average_mask.nii.gz -ref ${Subject}_FieldMap_Magnitude.nii.gz -init ${Subject}_T1toDFM.mat -applyxfm -o ${Subject}_DFM_mask.nii.gz; 
fi

# apply all masks
for i in ${T1w_files[*]}; do charstop=`expr ${#i} - 7`; mask_T1=${i:0:${charstop}}_masked.nii.gz; fslmaths ${i} -mas ${Subject}_T1w_MPR_average_mask.nii.gz ${mask_T1}; done
if $useT2; then
    for i in ${T2w_files[*]}; do charstop=`expr ${#i} - 7`; mask_T2=${i:0:${charstop}}_masked.nii.gz; fslmaths ${i} -mas ${Subject}_T2w_SPC_average_mask.nii.gz ${mask_T2}; done
fi

# this is our only parallel script, so perhaps we should isolate its call?
echo "Running Baby Council Script"
mkdir -p "$WD"/JLF
cmd="${DIR}/scripts/run_JLF.sh --working-dir=${StudyFolder}/${Subject}/masks/JLF \
		--target=$WD/${Subject}_T1w_MPR_average_brain.nii.gz \
		--refdir=${MultiAtlasDir} --output=$WD/${Subject}_aseg.nii.gz --ncores=$OMP_NUM_THREADS"
for (( i=0; i<${#Council[@]}; i++ )); do
	cmd=${cmd}" -g ${Council[$i]}/$MultiAtlasT1wBrain -l ${Council[$i]}/$MultiAtlasSeg"
done
echo $cmd
$cmd

if ${CrudeHistogramMatching:-false}; then
	#  Running T1w aseg-based intensity setting
	echo "Running crude Histogram Matching for easy Freesurfer results"
	mkdir -p "$WD"/FS_Avg_Matching
	cp ${Subject}_T1w_MPR_average.nii.gz ${Subject}_aseg.nii.gz "$WD"/FS_Avg_Matching/
	${DIR}/scripts/hypernormalize.sh "$WD"/FS_Avg_Matching ${Subject}_T1w_MPR_average.nii.gz ${Subject}_aseg.nii.gz "$WD"/T1wN.nii.gz

	fslmaths T1wN.nii.gz -mas ${Subject}_T1w_MPR_average_mask.nii.gz T1wN_brain.nii.gz
	mkdir -p ${StudyFolder}/${Subject}/T1wN
	cp T1wN.nii.gz T1wN_brain.nii.gz ${StudyFolder}/${Subject}/T1wN/
fi

# inserting subjects masked brains
# make T1w, T2w directories, copy ${Subject}_TXw_???_average_brain.nii.gz in as TXw_brain.nii.gz
mkdir -p ${StudyFolder}/${Subject}/T1w 
if [ $numT1s -ge 1 ]; then 
	cp "$WD"/${Subject}_T1w_MPR_average_brain.nii.gz ${StudyFolder}/${Subject}/T1w/T1w_brain.nii.gz 
fi
mkdir -p ${StudyFolder}/${Subject}/T2w
if [ $numT2s -ge 1 ]; then 
	cp "$WD"/${Subject}_T2w_SPC_average_brain.nii.gz ${StudyFolder}/${Subject}/T2w/T2w_brain.nii.gz 
fi
cp "$WD"/${Subject}_aseg.nii.gz ${StudyFolder}/${Subject}/T1w/aseg.nii.gz
cp
