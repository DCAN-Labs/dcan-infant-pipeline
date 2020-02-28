#!/bin/bash
set -e
# This script is a modification of "AtlasRegistrationToMNI152_FLIRTandFNIRT.sh" from the HCP pipeline to run using ANTs
#  HCP:
#  ANTs:

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), ANTs (version 2.2.0)
#  environment: FSLDIR

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Tool for non-linearly registering T1w and T2w to MNI space (T1w and T2w must already be registered together)"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working dir>]"
  echo "                --t1=<t1w image>"
  echo "                --t1rest=<bias corrected t1w image>"
  echo "                --t1restbrain=<bias corrected, brain extracted t1w image>"
  echo "                --t2=<t2w image>"
  echo "	 	--t2rest=<bias corrected t2w image>"
  echo "                --t2restbrain=<bias corrected, brain extracted t2w image>"
  echo "                --ref=<reference image>"
  echo "                --refbrain=<reference brain image>"
  echo "                --refmask=<reference brain mask>"
  echo "                [--ref2mm=<reference 2mm image>]"
  echo "                [--ref2mmmask=<reference 2mm brain mask>]"
  echo "                --owarp=<output warp>"
  echo "                --oinvwarp=<output inverse warp>"
  echo "                --ot1=<output t1w to MNI>"
  echo "                --ot1rest=<output bias corrected t1w to MNI>"
  echo "                --ot1restbrain=<output bias corrected, brain extracted t1w to MNI>"
  echo "                --ot2=<output t2w to MNI>"
  echo "		--ot2rest=<output bias corrected t2w to MNI>"
  echo "                --ot2restbrain=<output bias corrected, brain extracted t2w to MNI>"
  echo "                [--fnirtconfig=<FNIRT configuration file>]"
  echo "                --useT2=<false in T2w image is unavailable, default is true>"
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

################################################### OUTPUT FILES #####################################################

# Outputs (in $WD):  @TODO
# Outputs (not in $WD): ${OutputTransform} ${OutputInvTransform}
#                       ${OutputT1wImage} ${OutputT1wImageRestore}
#                       ${OutputT1wImageRestoreBrain}
#                       ${OutputT2wImage}  ${OutputT2wImageRestore}
#                       ${OutputT2wImageRestoreBrain}

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 13 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
T1wImage=`getopt1 "--t1" $@`  # "$2"
T1wRestore=`getopt1 "--t1rest" $@`  # "$3"
T1wRestoreBrain=`getopt1 "--t1restbrain" $@`  # "$4"
T1wBrainMask=`getopt1 "--t1brainmask" $@`
T2wImage=`getopt1 "--t2" $@`  # "$5"
T2wRestore=`getopt1 "--t2rest" $@`  # "$6"
T2wRestoreBrain=`getopt1 "--t2restbrain" $@`  # "$7"
Reference=`getopt1 "--ref" $@`  # "$8"
ReferenceBrain=`getopt1 "--refbrain" $@`  # "$9"
ReferenceMask=`getopt1 "--refmask" $@`  # "${10}"
Reference2mm=`getopt1 "--ref2mm" $@`  # "${11}"
Reference2mmMask=`getopt1 "--ref2mmmask" $@`  # "${12}"
OutputTransform=`getopt1 "--owarp" $@`  # "${13}"
OutputInvTransform=`getopt1 "--oinvwarp" $@`  # "${14}"
OutputT1wImage=`getopt1 "--ot1" $@`  # "${15}"
OutputT1wImageRestore=`getopt1 "--ot1rest" $@`  # "${16}"
OutputT1wImageRestoreBrain=`getopt1 "--ot1restbrain" $@`  # "${17}"
OutputT2wImage=`getopt1 "--ot2" $@`  # "${18}"
OutputT2wImageRestore=`getopt1 "--ot2rest" $@`  # "${19}"
OutputT2wImageRestoreBrain=`getopt1 "--ot2restbrain" $@`  # "${20}"
useT2=`getopt1 "--useT2" $@` # "${22}"

# default parameters
WD=`defaultopt $WD .`
Reference2mm=`defaultopt $Reference2mm ${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz`
Reference2mmMask=`defaultopt $Reference2mmMask ${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz`


T1wRestoreBasename=`remove_ext $T1wRestore`;
T1wRestore=${T1wRestoreBasename}.nii.gz
T1wRestoreBasename=`basename $T1wRestoreBasename`;
T1wRestoreBrainBasename=`remove_ext $T1wRestoreBrain`;
T1wRestoreBrain=${T1wRestoreBrainBasename}.nii.gz
T1wRestoreBrainBasename=`basename $T1wRestoreBrainBasename`;
T1wBrainMaskBasename=`remove_ext $T1wBrainMask`;
T1wBrainMask=${T1wBrainMaskBasename}.nii.gz

echo " "
echo " START: AtlasRegistration to MNI152"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/xfms/log.txt
echo "PWD = `pwd`" >> $WD/xfms/log.txt
echo "date: `date`" >> $WD/xfms/log.txt
echo " " >> $WD/xfms/log.txt

########################################## DO WORK ##########################################

# Linear then non-linear registration to atlas space, use brain masks for linear transformation
${ANTSPATH}${ANTSPATH:+/}antsRegistration -d 3 \
        --output "$WD"/xfms/antsreg \
        --interpolation BSpline \
	--transform Rigid["0.1"] \
	--metric CC["$Reference","$T1wRestore",1,5] \
	--convergence 1000x500x250 \
	--shrink-factors 4x2x1 \
	--smoothing-sigmas 2x1x0 \
	--masks ["$ReferenceMask","$T1wBrainMask"] \
        --transform Affine["0.1"] \
        --metric CC["$Reference","$T1wRestore",1,5] \
        --convergence 1000x500x250x100 \
        --shrink-factors 8x4x2x1 \
        --smoothing-sigmas 3x2x1x0 \
        --masks ["$ReferenceMask","$T1wBrainMask"] \
        --transform SyN[0.1,3,0] \
        --metric CC["$Reference","$T1wRestore",1,4] \
        --convergence 100x70x50x20 \
        --shrink-factors 8x4x2x1 \
        --smoothing-sigmas 3x2x1x0 \
        --masks ["$ReferenceMask",ignore]  # use fixed space mask only for nonlinear registration

# Concatenate ANTs transformations
${ANTSPATH}${ANTSPATH:+/}antsApplyTransforms -d 3 \
        --reference-image "$Reference" \
        --input "$T1wRestore" \
        --transform "$WD"/xfms/antsreg1Warp.nii.gz "$WD"/xfms/antsreg0GenericAffine.mat \
        --output ["$WD"/xfms/antsacpc2standard.nii.gz,1]

${ANTSPATH}${ANTSPATH:+/}antsApplyTransforms -d 3 \
        --reference-image "$T1wRestore" \
        --input "$Reference" \
        --transform ["$WD"/xfms/antsreg0GenericAffine.mat,1] "$WD"/xfms/antsreg1InverseWarp.nii.gz \
        --output ["$WD"/xfms/antsstandard2acpc.nii.gz,1]

# Compute Jacobian of basis vector mapping between subject and atlas spaces
${ANTSPATH}${ANTSPATH:+/}CreateJacobianDeterminantImage 3 "$WD"/xfms/antsstandard2acpc.nii.gz "$WD"/xfms/NonlinearRegJacobians.nii.gz [doLogJacobian=0] [useGeometric=0]

# Convert ANTs warpfields to fsl format
${C3DPATH}${C3DPATH:+/}c4d -mcs "$WD"/xfms/antsacpc2standard.nii.gz -oo "$WD"/e{1..3}.nii.gz  # split dim5 into basis vectors
${FSLDIR}/bin/fslmaths "$WD"/e2.nii.gz -mul -1 "$WD"/e2.nii.gz  # negate yhat vector
${FSLDIR}/bin/fslmerge -t ${OutputTransform} "$WD"/e{1..3}.nii.gz  # merge into dim4 (this may only work because the warp is from and to MNI space)
rm "$WD"/e{1..3}.nii.gz

${C3DPATH}${C3DPATH:+/}c4d -mcs "$WD"/xfms/antsstandard2acpc.nii.gz -oo "$WD"/e{1..3}.nii.gz
${FSLDIR}/bin/fslmaths "$WD"/e2.nii.gz -mul -1 "$WD"/e2.nii.gz
${FSLDIR}/bin/fslmerge -t ${OutputInvTransform} "$WD"/e{1..3}.nii.gz
rm "$WD"/e{1..3}.nii.gz

# Continue as normal, warps are now in fsl format
# T1w set of warped outputs (brain/whole-head + restored/orig)
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T1wImage} -r ${Reference} -w ${OutputTransform} -o ${OutputT1wImage}
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T1wRestore} -r ${Reference} -w ${OutputTransform} -o ${OutputT1wImageRestore}
${FSLDIR}/bin/applywarp --rel --interp=nn -i ${T1wRestoreBrain} -r ${Reference} -w ${OutputTransform} -o ${OutputT1wImageRestoreBrain}
${FSLDIR}/bin/fslmaths ${OutputT1wImageRestore} -mas ${OutputT1wImageRestoreBrain} ${OutputT1wImageRestoreBrain}

if ${useT2:-true}; then
# T2w set of warped outputs (brain/whole-head + restored/orig)
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T2wImage} -r ${Reference} -w ${OutputTransform} -o ${OutputT2wImage}
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T2wRestore} -r ${Reference} -w ${OutputTransform} -o ${OutputT2wImageRestore}
${FSLDIR}/bin/applywarp --rel --interp=nn -i ${T2wRestoreBrain} -r ${Reference} -w ${OutputTransform} -o ${OutputT2wImageRestoreBrain}
${FSLDIR}/bin/fslmaths ${OutputT2wImageRestore} -mas ${OutputT2wImageRestoreBrain} ${OutputT2wImageRestoreBrain}
fi

echo " "
echo " END: AtlasRegistration"
echo " END: `date`" >> $WD/xfms/log.txt

########################################## QA STUFF ##########################################

if [ -e $WD/xfms/qa.txt ] ; then rm -f $WD/xfms/qa.txt ; fi
echo "cd `pwd`" >> $WD/xfms/qa.txt
echo "# Check quality of alignment with MNI image" >> $WD/xfms/qa.txt
echo "fslview ${Reference} ${OutputT1wImageRestore}" >> $WD/xfms/qa.txt
if $useT2; then echo "fslview ${Reference} ${OutputT2wImageRestore}" >> $WD/xfms/qa.txt; fi

##############################################################################################
