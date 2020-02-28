#! /bin/bash

# This script adjusts the intensity profiles of each ROI (GM, WM, CSF) separately and re-assembles the parts.
# If you run this script on native or baby space images then need to bring into Tal space before Freesurfer.

base_image=$1   # EXAMPLE T1w_acpc_dc_restore - do not include file extensions
adult_image=$2  # THIS IS ADULT FREESURFER ATLAS-GET INTENSITIES FROM HERE; EXAMPLE means_RB_all

# Change intensities of infant WM,GM and CSF to match adult freesurfer template.
fslmaths ${base_image}_WM -sub `fslstats ${base_image}_WM -M` -div `fslstats ${base_image}_WM -S` -mul `fslstats ${adult_image}_WM -S` -add `fslstats ${adult_image}_WM -M` -mas ${base_image}_WM  ${base_image}_WM_AdultInt
fslmaths ${base_image}_GM -sub `fslstats ${base_image}_GM -M` -div `fslstats ${base_image}_GM -S` -mul `fslstats ${adult_image}_GM -S` -add `fslstats ${adult_image}_GM -M` -mas ${base_image}_GM  ${base_image}_GM_AdultInt
fslmaths ${base_image}_CSF -sub `fslstats ${base_image}_CSF -M` -div `fslstats ${base_image}_CSF -S` -mul `fslstats ${adult_image}_CSF -S` -add `fslstats ${adult_image}_CSF -M` -mas ${base_image}_CSF  ${base_image}_CSF_AdultInt

# Put baby image back together.
fslmaths ${base_image}_WM_AdultInt -add ${base_image}_GM_AdultInt -add ${base_image}_CSF_AdultInt ${base_image}_AdultInt

# Use "threshold" to get rid of negative values
fslmaths ${base_image}_AdultInt -thr 0  ${base_image}_AdultInt_thr


