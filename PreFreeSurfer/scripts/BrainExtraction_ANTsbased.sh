#!/bin/bash
set -e
# This script is a modification of "BrainExtraction_FNIRTbased.sh" from the HCP pipeline to run using ANTs
#  HCP:
#  ANTs:

Usage() {
  echo "`basename $0`: Tool for performing brain extraction using non-linear (ANTs) results"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working dir>] --in=<input image> [--ref=<reference highres image>] [--refmask=<reference brain mask>] [--ref2mm=<reference image 2mm>] [--ref2mmmask=<reference brain mask 2mm>] --outbrain=<output brain extracted image> --outbrainmask=<output brain mask>]"
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

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
Input=`getopt1 "--in" $@`  # "$2"
Reference=`getopt1 "--ref" $@` # "$3"
ReferenceMask=`getopt1 "--refmask" $@` # "$4"
Reference2mm=`getopt1 "--ref2mm" $@` # "$5"
Reference2mmMask=`getopt1 "--ref2mmmask" $@` # "$6"
OutputBrainExtractedImage=`getopt1 "--outbrain" $@` # "$7"
OutputBrainMask=`getopt1 "--outbrainmask" $@` # "$8"

# default parameters
WD=`defaultopt $WD .`
Reference=`defaultopt $Reference ${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm.nii.gz`
ReferenceMask=`defaultopt $ReferenceMask ${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain_mask.nii.gz`  # dilate to be conservative with final brain mask
Reference2mm=`defaultopt $Reference2mm ${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz`
Reference2mmMask=`defaultopt $Reference2mmMask ${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz`  # dilate to be conservative with final brain mask

BaseName=`${FSLDIR}/bin/remove_ext $Input`;
Input="${BaseName}.nii.gz"
BaseName=`basename $BaseName`;


echo " "
echo " START: BrainExtraction_ANTs"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ##########################################

${ANTSPATH}${ANTSPATH:+/}ANTS 3 -m CC["$Input","$Reference",1,5] -t SyN[0.25] -r Gauss[3,0] -o "$WD"/antsreg -i 60x50x20 --use-Histogram-Matching  --number-of-affine-iterations 10000x10000x10000x10000x10000 --MI-option 32x16000

# apply transformation to template mask
${ANTSPATH}${ANTSPATH:+/}antsApplyTransforms -d 3 \
        --output "$WD"/brainmask.nii.gz \
        --reference-image "$Input" \
        --transform "$WD"/antsregWarp.nii.gz "$WD"/antsregAffine.txt \
        --input "$ReferenceMask"


${FSLDIR}/bin/fslmaths "$Input" -mas "$WD"/brainmask.nii.gz "$OutputBrainExtractedImage"
${FSLDIR}/bin/fslmaths "$OutputBrainExtractedImage" -bin "$OutputBrainMask"


echo " "
echo " END: BrainExtraction_ANTs"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ##########################################

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check that the following brain mask does not exclude any brain tissue (and is reasonably good at not including non-brain tissue outside of the immediately surrounding CSF)" >> $WD/qa.txt
echo "fslview $Input $OutputBrainMask -l Red -t 0.5" >> $WD/qa.txt
echo "# Optional debugging: linear and non-linear registration result" >> $WD/qa.txt
echo "fslview $Reference2mm $WD/${BaseName}_to_MNI_roughlin.nii.gz" >> $WD/qa.txt
echo "fslview $Reference $WD/${BaseName}_to_MNI_nonlin.nii.gz" >> $WD/qa.txt

##############################################################################################

