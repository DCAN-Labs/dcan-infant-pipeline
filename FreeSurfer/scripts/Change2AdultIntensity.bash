#! /bin/bash

#This script changes the intensity profile (i.e. histogram) of the base image to match the adult freesurfer atlas. The original script adjusted the intensity profiles of each ROI (GM. WM, CSF) separately and re-assembled the parts. In contrast, this script adjusts the entire base image such that the intensity profile of gray matter (GM) in the target roughly matches the intensity profile of gray matter in the reference. Then the white matter (WM) is shifted to the target image to match the histogram of white matter in the reference. If you run this script on native or baby space images then need to bring into Tal space before Freesurfer.

base_image=$1
# EXAMPLE T1w_acpc_dc_restore - do not need to include file extensions

adult_image=$2 #adult freesurfer atlas
# EXAMPLE means_RB_all

#Changing intensities of infant WM,GM and CSF to match adult freesurfer template
fslmaths ${base_image} -sub `fslstats ${base_image}_GM -M` -div `fslstats ${base_image}_GM -S` -mul `fslstats ${adult_image}_GM -S` -add `fslstats ${adult_image}_GM -M` ${base_image}_GMshifted
fslmaths ${base_image} -sub `fslstats ${base_image}_WM -M` -div `fslstats ${base_image}_WM -S` -mul `fslstats ${adult_image}_WM -S` -add `fslstats ${adult_image}_WM -M` -mas ${base_image}_WM  ${base_image}_WM_AdultInt

#Replace WM in GM_shifted with shifted WM

#inverted binarized WM
fslmaths ${base_image}_WM_AdultInt -binv ${base_image}_WM_AdultInt_binv 
#multiply binv WM by GMshifted to "delete" WM
fslmaths ${base_image}_WM_AdultInt_binv -mul ${base_image}_GMshifted ${base_image}_GMshifted_zeroWM 
#add back WM mask to GMshifted w/ deleted WM
fslmaths ${base_image}_GMshifted_zeroWM -add ${base_image}_WM_AdultInt ${base_image}_AdultInt 

#threshold to get rid of negative values
fslmaths ${base_image}_AdultInt -thr 0  ${base_image}_AdultInt_thr

