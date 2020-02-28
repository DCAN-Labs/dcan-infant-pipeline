#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), HCP-gradunwarp (version 1.0.2)
#  environment: as in SetUpHCPPipeline.sh  (or individually: FSLDIR, HCPPIPEDIR_Global, HCPPIPEDIR_Bin and PATH for gradient_unwarp.py)
## Created by Emma Schifsky 12/19

################################################ SUPPORT FUNCTIONS ##################################################

# --------------------------------------------------------------------------------
#  Load Function Libraries
# --------------------------------------------------------------------------------

source $HCPPIPEDIR_Global/log.shlib # Logging related functions

Usage() {
  echo "`basename $0`: Script for using ANTS to do distortion correction for EPI (scout) via T2"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working directory>]"
  echo "            --scoutin=<scout input image: should be corrected for gradient non-linear distortions>"
  echo "            [--owarp=<output warpfield image: scout to distortion corrected SE EPI>]"
  echo "            [--ojacobian=<output Jacobian image>]"
  echo "            --usejacobian=<\"true\" or \"false\">"
  echo " "
  echo "   Note: the input T2 should be the ???raw T2"
}

# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
	if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
	    echo $fn | sed "s/^${sopt}=//"
	    return 0
	fi
    done
}

defaultopt() {
    echo $1
}

# --------------------------------------------------------------------------------
#  Establish tool name for logging
# --------------------------------------------------------------------------------

log_SetToolName "T2DistortionCorrection.sh"

################################################### OUTPUT FILES #####################################################

# Output images (in $WD): 
#          BothPhases      (input to topup - combines both pe direction data, plus masking)
#          SBRef2PhaseOne_gdc.mat SBRef2PhaseOne_gdc   (linear registration result)
#          PhaseOne_gdc  PhaseTwo_gdc
#          PhaseOne_gdc_dc  PhaseOne_gdc_dc_jac  PhaseTwo_gdc_dc  PhaseTwo_gdc_dc_jac
#          SBRef_dc   SBRef_dc_jac
#          WarpField  Jacobian
# Output images (not in $WD): 
#          ${DistortionCorrectionWarpFieldOutput}  ${JacobianOutput}

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
#if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
#if [ $# -lt 7 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
ScoutInputName=`getopt1 "--scoutin" $@`  # "$2"
T2wPrepImage=`getopt1 "--t2in" $@`  # "$2"
DistortionCorrectionWarpFieldOutput=`getopt1 "--owarp" $@`  # "$7"
JacobianOutput=`getopt1 "--ojacobian" $@`  # "$8"
UseJacobian=`getopt1 "--usejacobian" $@`

GlobalScripts=${HCPPIPEDIR_Global}

T2wScoutImage=${WD}/T2w_2_Scout

if [[ -n $HCPPIPEDEBUG ]]
then
    set -x
fi

#sanity check the jacobian option
if [[ "$UseJacobian" != "true" && "$UseJacobian" != "false" ]]
then
    log_Msg "the --usejacobian option must be 'true' or 'false'"
    exit 1
fi


# default parameters #Breaks when --owarp becomes optional
#DistortionCorrectionWarpFieldOutput=`$FSLDIR/bin/remove_ext $DistortionCorrectionWarpFieldOutput`
#WD=`defaultopt $WD ${DistortionCorrectionWarpFieldOutput}.wdir`

log_Msg "START: EPI distortion correction via T2"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt


########################################## DO WORK ########################################## 

#Linearly transform T2w to Scout

${FSLDIR}${FSLDIR:+/}bin/flirt -interp spline -dof 6 -in ${T2wPrepImage}.nii.gz -ref ${ScoutInputName}.nii.gz -out ${T2wScoutImage}.nii.gz

##do we care about the lessened resolution?? next test would be, opposite w omat, apply omat to use later, then use ScoutT2IMage for antsRegistrationSyn.sh below

# Nonlinearly transform Scout_gdc to T2w

echo "ANTS EPI (Scout_gdc) Registration to T2 (unprocessed)"
echo " "

echo ${ANTSPATH}${ANTSPATH:+/}antsRegistrationSyN.sh -d 3 -f ${T2wScoutImage}.nii.gz -m ${ScoutInputName}.nii.gz -o ${WD}/Scout_to_T2w_

${ANTSPATH}${ANTSPATH:+/}antsRegistrationSyN.sh -d 3 -f ${T2wScoutImage}.nii.gz -m ${ScoutInputName}.nii.gz -o ${WD}/Scout_to_T2w_ 

echo " antsApplyTransform"
echo " "
# combine all the affine and non-linear warps in the order: W2, A2, W1, A1
${ANTSPATH}${ANTSPATH:+/}antsApplyTransforms -d 3 -i ${ScoutInputName}.nii.gz -r ${T2wScoutImage}.nii.gz -t ${WD}/Scout_to_T2w_1Warp.nii.gz ${WD}/Scout_to_T2w_0GenericAffine.mat -o [${WD}/ANTs_CombinedWarp.nii.gz,1]

#got rid of -t, ANTS reads right to left

${FSLDIR}${FSLDIR:+/}bin/imcp ${WD}/Scout_to_T2w_1Warp.nii.gz ${WD}/SBRef.nii.gz

#Conversion of ANTs to FSL format
echo " ANTs to FSL warp conversion"
echo " "

# split 3 component vectors
${C3DPATH}${C3DPATH:+/}c4d -mcs ${WD}/ANTs_CombinedWarp.nii.gz -oo ${WD}/e1.nii.gz ${WD}/e2.nii.gz ${WD}/e3.nii.gz

# reverse y_hat
${FSLDIR}${FSLDIR:+/}bin/fslmaths ${WD}/e2.nii.gz -mul -1 ${WD}/e-2.nii.gz

# merge to get FSL format warps
# later on clean up the eX.nii.gz
${FSLDIR}${FSLDIR:+/}bin/fslmerge -t ${WD}/WarpField.nii.gz ${WD}/e1.nii.gz ${WD}/e-2.nii.gz ${WD}/e3.nii.gz

##put convertwarp command using linear omat and warpfield to overwrite warpfield

# create Jacobian determinant
${ANTSPATH}${ANTSPATH:+/}CreateJacobianDeterminantImage 3 ${WD}/ANTs_CombinedWarp.nii.gz ${WD}/Jacobian.nii.gz [doLogJacobian=0] [useGeometric=0]

# Scout - warp and Jacobian modulate to get distortion corrected output
${FSLDIR}${FSLDIR:+/}bin/applywarp --rel --interp=spline -i ${WD}/SBRef.nii.gz -r ${WD}/SBRef.nii.gz -w ${WD}/WarpField.nii.gz -o ${WD}/SBRef_dc.nii.gz
${FSLDIR}${FSLDIR:+/}bin/fslmaths ${WD}/SBRef_dc.nii.gz -mul ${WD}/Jacobian.nii.gz ${WD}/SBRef_dc_jac.nii.gz


# copy images to specified outputs
if [ ! -z ${DistortionCorrectionWarpFieldOutput} ] ; then
  ${FSLDIR}/bin/imcp ${WD}/WarpField.nii.gz ${DistortionCorrectionWarpFieldOutput}.nii.gz
fi
if [ ! -z ${JacobianOutput} ] ; then
  ${FSLDIR}/bin/imcp ${WD}/Jacobian.nii.gz ${JacobianOutput}.nii.gz
fi

echo " "
echo " END: T2 Distortion Correction"
echo " END: `date`" >> $WD/log.txt
