#! /bin/bash

#base image and baby seg need to be in same space, but doesn't matter for adult seg. If you run this script on native or baby space images then need to bring into Tal space before Freesurfer

base_image=$1 
# EXAMPLE BUSS_2002_T2_in_T2 

baby_seg=$2 
# EXAMPLE BUSS_2002_3label_seg_brain_in_T2_Reo.nii 

adult_image=$3 
# THIS IS ADULT FREESURFER ATLAS-GET INTENSITIES FROM HERE /group_shares/FAIR_INFANT/Projects/UCIrvine/Projects/Segmentations/means_RB_all

#Splitting baby seg up into WM,GM and CSF
#fslmaths ${baby_seg} -thr 1 -uthr 1 -bin -mul ${base_image} ${base_image}_WM
#fslmaths ${baby_seg} -thr 2 -uthr 2 -bin -mul ${base_image} ${base_image}_GM
#fslmaths ${baby_seg} -thr 3 -uthr 3 -bin -mul ${base_image} ${base_image}_CSF

#Changing intensities of infant WM,GM and CSF to match adult freesurfer template
fslmaths ${base_image}_WM -sub `fslstats ${base_image}_WM -M` -div `fslstats ${base_image}_WM -S` -mul `fslstats ${adult_image}_WM -S` -add `fslstats ${adult_image}_WM -M` -mas ${base_image}_WM  ${base_image}_WM_AdultInt
fslmaths ${base_image}_GM -sub `fslstats ${base_image}_GM -M` -div `fslstats ${base_image}_GM -S` -mul `fslstats ${adult_image}_GM -S` -add `fslstats ${adult_image}_GM -M` -mas ${base_image}_GM  ${base_image}_GM_AdultInt
fslmaths ${base_image}_CSF -sub `fslstats ${base_image}_CSF -M` -div `fslstats ${base_image}_CSF -S` -mul `fslstats ${adult_image}_CSF -S` -add `fslstats ${adult_image}_CSF -M` -mas ${base_image}_CSF  ${base_image}_CSF_AdultInt

#putting baby image backtogether
fslmaths ${base_image}_WM_AdultInt -add ${base_image}_GM_AdultInt -add ${base_image}_CSF_AdultInt ${base_image}_AdultInt 

#threshold to get rid of negative values
fslmaths ${base_image}_AdultInt -thr 0  ${base_image}_AdultInt_thr

