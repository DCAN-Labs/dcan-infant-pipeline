#!/bin/bash

WD="$1"
Subject="$2"
StudyAtlasHead="$3"
StudyAtlasBrain="$4"
StudyAtlasAseg="$5"

pushd $WD
T1wImage=${Subject}_T1w_MPR_average
T2wImage=${Subject}_T2w_SPC_average #added T2 7/14/17 -Dakota

#Added ANTS & c3d_affine_tool path 6/29/17 - Dakota
if [ ! $(command -v ANTS) ] || [ ! $(command -v c3d_affine_tool) ] && [ -z $ANTSPATH ]; then
	echo -e "ANTS or c3d_affine_tool path not found!"
	exit 1
fi

#using flirt because ANTS takes forever on this stage for some reason
flirt -v -in ${T1wImage} -ref ${StudyAtlasHead} -out ${T1wImage}_rot2atl -omat ${T1wImage}_rot2atl.mat -interp spline

## warping atlas to subject T1 to get brain mask
fslmaths ${StudyAtlasBrain} -bin StudyAtlasMask
${ANTSPATH}${ANTSPATH:+/}ANTS 3 -m  CC[${T1wImage}_rot2atl.nii.gz,${StudyAtlasHead},1,5] -t SyN[0.25] -r Gauss[3,0] -o atl2T1 -i 60x50x20 --use-Histogram-Matching  --number-of-affine-iterations 10000x10000x10000x10000x10000 --MI-option 32x16000
#apply warp
${ANTSPATH}${ANTSPATH:+/}antsApplyTransforms -d 3 -i StudyAtlasMask.nii.gz -t atl2T1Warp.nii.gz atl2T1Affine.txt -r ${T1wImage}_rot2atl.nii.gz -o ${T1wImage}_rot2atl_mask.nii.gz
## NOTE: antsApplyTransforms is deprecated in ANTS 2.0 and might not be available; if so, use WarpImageMultiTransform instead
#back it into native space; threshold it; apply it
convert_xfm -omat ${T1wImage}_rot2native.mat -inverse ${T1wImage}_rot2atl.mat; flirt -in ${T1wImage}_rot2atl_mask -ref ${T1wImage} -o ${T1wImage}_mask -applyxfm -init ${T1wImage}_rot2native.mat
fslmaths ${T1wImage}_mask -thr .5 -bin ${T1wImage}_mask
fslmaths ${T1wImage} -mas ${T1wImage}_mask ${T1wImage}_brain
#create T2 brain
flirt -dof 6 -cost mutualinfo -in ${T1wImage} -ref ${T2wImage} -omat t1wtot2w.mat
flirt -in ${T1wImage}_mask -interp nearestneighbour -ref ${T2wImage} -o ${T2wImage}_mask -applyxfm -init t1wtot2w.mat
fslmaths ${T2wImage} -mas ${T2wImage}_mask ${T2wImage}_brain

## flirt
flirt -v -dof 6 -searchrx -180 180 -searchry -180 180 -searchrz -180 180 -in ${T1wImage}_brain -ref ${StudyAtlasBrain} -o ${T1wImage}_brain_rot2atl -omat ${T1wImage}_roTt2atl.mat
flirt -in ${T1wImage} -ref ${StudyAtlasHead} -o ${T1wImage}_rot2atl -applyxfm -init ${T1wImage}_rot2atl.mat -interp spline

#get warp from atlas brain to subject brain in atlas space
${ANTSPATH}${ANTSPATH:+/}ANTS 3 -m  CC[${T1wImage}_brain_rot2atl.nii.gz,${StudyAtlasBrain},1,5] -t SyN[0.25] -r Gauss[3,0] -o atl2T1rot -i 50x60x30 --use-Histogram-Matching  --number-of-affine-iterations 10000x10000x10000x10000x10000 --MI-option 32x16000
#apply warp atlas -> T1wImage_rot2atl
${ANTSPATH}${ANTSPATH:+/}antsApplyTransforms -d 3 -i ${StudyAtlasBrain} -t atl2T1rotWarp.nii.gz atl2T1rotAffine.txt -r ${T1wImage}_rot2atl.nii.gz -o atl2T1rot_deforemdImage.nii.gz

#atlas segmentations -warp-> T1wImage_rot2atl -affine-> T1wImage_native
${ANTSPATH}${ANTSPATH:+/}antsApplyTransforms -d 3 -i ${StudyAtlasAseg} -t atl2T1rotWarp.nii.gz atl2T1rotAffine.txt -r ${T1wImage}_rot2atl.nii.gz -o ${Subject}_aseg_rot2atl.nii.gz -n MultiLabel[0.38,4] #11-30-16 BR added multilabel parameters
convert_xfm -omat ${T1wImage}_rot2native.mat -inverse ${T1wImage}_rot2atl.mat
${C3DPATH}${C3DPATH:+/}c3d_affine_tool -ref ${T1wImage}_brain.nii.gz -src ${StudyAtlasBrain} ${T1wImage}_rot2native.mat -fsl2ras -oitk ${T1wImage}_rot2native.txt
${ANTSPATH}${ANTSPATH:+/}antsApplyTransforms -d 3 -i ${Subject}_aseg_rot2atl.nii.gz -t ${T1wImage}_rot2native.txt -r ${T1wImage}.nii.gz -o ${Subject}_aseg_double_resample.nii.gz -n NearestNeighbor #11-30-16 BR switched from multilabel to NearestNeighbor
## NOTE: antsApplyTransforms is deprecated in ANTS 2.0 and might not be available; if so, use WarpImageMultiTransform instead
${ANTSPATH}${ANTSPATH:+/}antsApplyTransforms -d 3 -i ${StudyAtlasAseg} -t ${T1wImage}_rot2native.txt atl2T1rotWarp.nii.gz atl2T1rotAffine.txt -r ${T1wImage}_brain.nii.gz -o ${Subject}_aseg.nii.gz -n MultiLabel[0.38,4] #2-13-17 Darrick- added onestep resample

