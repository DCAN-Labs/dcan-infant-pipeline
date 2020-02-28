#!/bin/bash
set -e
script_name="SubcorticalAlign_MNI_Affine.sh"
echo "${script_name}: START"

AtlasSpaceFolder="$1"
echo "${script_name}: AtlasSpaceFolder: ${AtlasSpaceFolder}"

ROIFolder="$2"
echo "${script_name}: ROIFolder: ${ROIFolder}"

FinalfMRIResolution="$3"
echo "${script_name}: FinalfMRIResolution: ${FinalfMRIResolution}"

ResultsFolder="$4"
echo "${script_name}: ResultsFolder: ${ResultsFolder}"

NameOffMRI="$5"
echo "${script_name}: NameOffMRI: ${NameOffMRI}"

SmoothingFWHM="$6"
echo "${script_name}: SmoothingFWHM: ${SmoothingFWHM}"

BrainOrdinatesResolution="$7"
echo "${script_name}: BrainOrdinatesResolution: ${BrainOrdinatesResolution}"

VolumefMRI="${ResultsFolder}/${NameOffMRI}"
echo "${script_name}: VolumefMRI: ${VolumefMRI}"

Sigma=`echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`
echo "${script_name}: Sigma: ${Sigma}"

#NOTE: wmparc has dashes in structure names, which -cifti-create-* won't accept
#ROIs files have acceptable structure names

#deal with fsl_sub being silly when we want to use numeric equality on decimals
unset POSIXLY_CORRECT

############# INJECTING BABY -> MNI AFFINE TRANSFORM ###############
flirt -in "$VolumefMRI".nii.gz -ref "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz -applyxfm -init "$HCPPIPEDIR_Templates"/InfMNI_2AdultMNI_Step2.mat -out "$VolumefMRI"_2MNI.nii.gz

# Testing this out.
${CARET7DIR}/wb_command -volume-affine-resample "$ROIFolder"/ROIs."$BrainOrdinatesResolution".nii.gz "$HCPPIPEDIR_Templates"/InfMNI_2AdultMNI_Step2.mat "$VolumefMRI"_2MNI.nii.gz ENCLOSING_VOXEL "$ResultsFolder"/ROIs."$BrainOrdinatesResolution".nii.gz -flirt "$ROIFolder"/ROIs."$BrainOrdinatesResolution".nii.gz "$VolumefMRI"_2MNI.nii.gz
####################################################################


## For babies, we have to use volume-parcel-resampling-generic, otherwise this will not map well.  We will have to redo with current HCP pipeline if/when we have our own volume space.
if [ 1 -eq `echo "$BrainOrdinatesResolution == $FinalfMRIResolution" | bc -l` ] ; then
  ########## EDIT VolumefMRI input ##############
  ${CARET7DIR}/wb_command -volume-parcel-resampling "$VolumefMRI"_2MNI.nii.gz "$ROIFolder"/ROIs."$BrainOrdinatesResolution".nii.gz "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz $Sigma "$VolumefMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz -fix-zeros
else
  applywarp --interp=nn -i "$AtlasSpaceFolder"/wmparc.nii.gz -r "$VolumefMRI"_2MNI.nii.gz -o "$ResultsFolder"/wmparc."$FinalfMRIResolution".nii.gz

  ##### INJECTING BABY -> MNI AFFINE TRANSFORM ######
  flirt -in "$AtlasSpaceFolder"/ROIs/wmparc."$FinalfMRIResolution".nii.gz -ref "$VolumefMRI"_2MNI.nii.gz -interp nearestneighbour -applyxfm -init "$HCPPIPEDIR_Templates"/InfMNI_2AdultMNI_Step2.mat -out "$AtlasSpaceFolder"/ROIs/wmparc."$FinalfMRIResolution".nii.gz
  ###################################################

  ${CARET7DIR}/wb_command -volume-label-import "$ResultsFolder"/wmparc."$FinalfMRIResolution".nii.gz ${HCPPIPEDIR_Config}/FreeSurferSubcorticalLabelTableLut.txt "$ResultsFolder"/ROIs."$FinalfMRIResolution".nii.gz -discard-others
  ${CARET7DIR}/wb_command -volume-parcel-resampling-generic "$VolumefMRI"_2MNI.nii.gz "$ResultsFolder"/ROIs."$FinalfMRIResolution".nii.gz "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz $Sigma "$VolumefMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz -fix-zeros
  rm "$ResultsFolder"/wmparc."$FinalfMRIResolution".nii.gz
fi

echo "${script_name}: END"

