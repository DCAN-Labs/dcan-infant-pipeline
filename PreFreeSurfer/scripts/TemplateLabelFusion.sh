#!/bin/bash
set -e
# This script applies ANTs Joint Label Fusion to generate subject labels
#  ANTs:
#  Paper:

# Requirements for this script
#  installed versions of: ANTs (version 2.2.0)
#  environment: ANTSPATH (optional)

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Tool for non-linearly registering T1w and T2w to MNI space (T1w and T2w must already be registered together)"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working dir>]"
  echo "                --t1=<t1w image>"
  echo "                --t1rest=<bias corrected t1w image>"
  echo "                --t1restbrain=<bias corrected, brain extracted t1w image>"
  echo "                --t2=<t2w image>"
  echo "                --t2rest=<bias corrected t2w image>"
  echo "                --t2restbrain=<bias corrected, brain extracted t2w image>"
  echo "                --multitemplatedir=<base directory of templates>"
  echo "                --templatelist=<list of template folders in multitemplatedir to use>"
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
if [ $# -lt 5 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`
T1wImage=`getopt1 "--t1" $@`
T1wRestore=`getopt1 "--t1rest" $@`
T1wRestoreBrain=`getopt1 "--t1restbrain" $@`
T2wImage=`getopt1 "--t2" $@`
T2wRestore=`getopt1 "--t2rest" $@`
T2wRestoreBrain=`getopt1 "--t2restbrain" $@`
ReferenceDirectory=`getopt1 "--multitemplatedir" $@`
TemplateList=`getopt1 "--templatelist" $@`
RunOpt=`getopt1 "--runopt" $@`

# default parameters
WD=`defaultopt $WD .`
# default templatelist to all templates in the reference directory
if [ -z "${TemplateList:+x}" ]; then
    echo "Using all atlases in $ReferenceDirectory"
    TemplateList=($(cd "$ReferenceDirectory" && ls -d */))  # each reference should have its own subdirectory
fi

declare -a SegmentationList
for ((i=0; i<${#TemplateList[@]}; i++)); do
    # each folder should contain a label file named with "seg" or "label", and a matching anatomical without.
    # later we may introduce a dual modality option.
    SegmentationList[$i]=$(ls -d ${TemplateList[$i]} | egrep 'seg|label' | egrep '.nii.gz')
    TemplateList[$i]=$(ls -d ${TemplateList[$i]} | egrep -v 'seg|label' | egrep '.nii.gz')
done

echo "Running ANTs Joint Label Fusion"
echo "Base Directory: $ReferenceDirectory"
echo "Atlases: ${TemplateList[@]}"
echo "Labels: ${SegmentationList[@]}"

numTemplates=${#TemplateList[@]}
if [ ${numTemplates:-X} != ${#SegmentationList[@]} ]; then
    echo "Inconsistent number of templates and labels, exiting..."
    exit 1
fi

# template command for registration of atlases
XFMCMD=${ANTSPATH}${ANTSPATH:+/}antsRegistration -d 3 \
        --output \<output\> \
        --interpolation BSpline \
        --transform Affine["0.1"] \
        --metric MI[$T1wRestore,\<moving\>,1,32] \
        --convergence 100x100x100x100 \
        --shrink-factors 8x4x2x1 \
        --smoothing-sigmas 3x2x1x0 \
        --transform SyN[0.1,3,0] \
        --metric CC[$T1wRestore,\<moving\>,1,4] \
        --convergence 100x70x50x20 \
        --shrink-factors 8x4x2x1 \
        --smoothing-sigmas 3x2x1x0 \
        --verbose

LABELCMD=${ANTSPATH}${ANTSPATH:+/}antsApplyTransforms -d 3 \
        --output \<output\> \
        --input \<moving\> \
        --reference $T1wRestore \
        --interpolation NearestNeighbor \
        --transform \<nonlinear\> \
        --transform \<affine\>



# execute jobs based on parallelism options
if [ SLURM = $RunOpt ]; then
SLURMOPTS="sbatch --mem-per-cpu 8G --time 12:00:00 --ntasks $numTemplates --output $WD/log.txt --error $WD/err.txt --"
echo '#!/bin/bash' > jlf.sh
for ((i=0; i<${#TemplateList[@]}; i++)); do
    CMD1=$(echo "$XFMCMD" | sed "|\<output\>|$WD/atlas|" | sed
            "|\<moving\>|$ReferenceDirectory/$TemplateList[$i]|")
    CMD2=$(echo "$LABELCMD" | sed "|\<output\>|$WD/label${i}.nii.gz|" | sed
            "|\<moving\>|$ReferenceDirectory/$SegmentationList[$i]|"
    echo $SUBMITOPTS $CMD '&' >> jlf.sh
done
echo 'wait' >> jlf.sh
sbatch $SLURMOPTS jlf_registration.sh

# serial option
elif [ SERIAL = $RunOpt ]; then
for ((i=0; i<${#TemplateList[@]}; i++)); do
    CMD=$(echo "$BASECMD" | sed "|\<output\>|$WD/atlas|" | sed "|\<fixed\>|$T1wRestore|" | sed
            "|\<moving\>|$ReferenceDirectory/$TemplateList[$i]|")
    $CMD
done

fi
