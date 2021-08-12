#!/bin/bash
set -e

#notes for running ROI splitting
#    Preconditions:
#        ROIFolder must have:
#            Atlas_ROIs.2.nii.gz -- one per subject; generated in PostFreeSurfer
#            ROIs.2.nii.gz       -- one per subject; generated in PostFreeSurfer (FreeSurfer2CaretConvertAndRegisterNonlinear.sh)
#
#    Files generated during alignment:
#        NOTE: These will be the same for each run for the same subject.
#        However, if we create in same folder, the runs will overwrite each
#        other. Possible to have first one write the file and put a lock on
#        while writing, and get all complicated, OR, just create in a working
#        directory for each run. Simpler is better.
#            labelfile.txt
#            sub_allroi.nii.gz
#            atl_allroi.nii.gz
#            sub_ROI*.nii.gz
#            atl_ROI*.nii.gz
#            sub2atl_ROI*
#            sub2atl_vol_${ROInum}
#
#    Files generated during recombination:
#        ResultsFolder
#            ${NameOffMRI}_AtlasSubcortical_s${SmoothingFWHM}.nii.gz
#

#declaring neccessary variables
ROIFolder=${1}
ResultsFolder=${2}
NameOffMRI=${3}
SmoothingFWHM=${4}
GrayordinatesResolution=${5}
TR=${6}

VolumefMRI="${ResultsFolder}/${NameOffMRI}"
Sigma=`echo "${SmoothingFWHM} / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`

# Cleanup old data.
WD=${ROIFolder}/${NameOffMRI}_working_directory
if [ -d ${WD} ] ; then
    rm -rf ${WD}
fi
mkdir -p ${WD}

script=$(basename $0)
echo "START ${script}"
echo "ROIFolder: ${ROIFolder}"
echo "ResultsFolder: ${ResultsFolder}"
echo "NameOffMRI: ${NameOffMRI}"
echo "VolumefMRI: ${VolumefMRI}"
echo "SmoothingFWHM: ${SmoothingFWHM}"
echo "Sigma: ${Sigma}"
echo "Working Directory: ${WD}"

#generate altas-roi space fMRI cifti for subcortical data
flirt -in ${VolumefMRI}.nii.gz -ref ${ROIFolder}/Atlas_ROIs.${GrayordinatesResolution}.nii.gz -applyxfm -init $HCPPIPEDIR_Templates/InfMNI_2AdultMNI_Step2.mat -out ${VolumefMRI}_2MNI.nii.gz
${CARET7DIR}/wb_command -volume-affine-resample ${ROIFolder}/ROIs.${GrayordinatesResolution}.nii.gz $HCPPIPEDIR_Templates/InfMNI_2AdultMNI_Step2.mat ${VolumefMRI}_2MNI.nii.gz ENCLOSING_VOXEL ${ResultsFolder}/ROIs.${GrayordinatesResolution}.nii.gz -flirt ${ROIFolder}/ROIs.${GrayordinatesResolution}.nii.gz ${VolumefMRI}_2MNI.nii.gz
${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${WD}/${NameOffMRI}_temp_orig_atlas.dtseries.nii -volume ${VolumefMRI}_2MNI.nii.gz ${ROIFolder}/Atlas_ROIs.${GrayordinatesResolution}.nii.gz

#splitting atlas and subject volume label files into individual ROI files for registration
pushd ${WD}
${CARET7DIR}/wb_command -volume-all-labels-to-rois ${ROIFolder}/ROIs.${GrayordinatesResolution}.nii.gz 1 ${WD}/sub_allroi.nii.gz
fslsplit ${WD}/sub_allroi.nii.gz sub_ROI -t
${CARET7DIR}/wb_command -volume-all-labels-to-rois ${ROIFolder}/Atlas_ROIs.${GrayordinatesResolution}.nii.gz 1 ${WD}/atl_allroi.nii.gz
fslsplit ${WD}/atl_allroi.nii.gz atl_ROI -t

#exporting table to generate independent label files
${CARET7DIR}/wb_command -volume-label-export-table ${ROIFolder}/Atlas_ROIs.${GrayordinatesResolution}.nii.gz 1 ${WD}/labelfile.txt

#initialize workbench command for creating dense time series.
#DTSCommand="${CARET7DIR}/wb_command -cifti-create-dense-from-template ${WD}/${NameOffMRI}_temp_orig_atlas.dtseries.nii ${WD}/${NameOffMRI}_temp_atlas.dtseries.nii -series ${TR} 0.0 "
#initialize command to make sub2atl_label_ROI.2.nii.gz
Sub2AtlCmd=""

#loop to register each ROI independently, and perform subcoritcal mapping (see fMRISurface/scripts/SubcorticalAlign_MNI_Affine.sh for more details)
label_count=0
for file in $( ls sub_ROI*.nii.gz ); do # next ROI file
    ROIname=${file/sub_/}
    ROInum=${ROIname/.nii.gz/}
    (( label_count += 1 ))

    #perform linear mapping from subject to atlas ROI
    flirt -in ${WD}/sub_${ROIname} -ref ${WD}/atl_${ROIname} -searchrx -20 20 -searchry -20 20 -searchrz -20 20 -o sub2atl_${ROIname} -interp nearestneighbour -omat ${WD}/sub2atl_${ROInum}.mat

    flirt -in ${VolumefMRI} -ref ${WD}/atl_${ROIname} -applyxfm -init ${WD}/sub2atl_${ROInum}.mat -o sub2atl_vol_${ROIname} -interp spline

    #masking BOLD volumetric data to ROI only
    fslmaths sub2atl_vol_${ROIname} -mas sub2atl_${ROIname} sub2atl_vol_masked_${ROIname}

    #extract information from label file (values on even numbered line preceded by label on odd)
    (( label_line = label_count * 2 ))
    roi_value=$( cat ${WD}/labelfile.txt | head -n ${label_line} | tail -n 1 | awk '{ print $1 }' )
    (( label_line = label_line - 1 ))
    roi_name=$( cat ${WD}/labelfile.txt | head -n ${label_line} | tail -n 1 | awk '{ print $1 }' )

    #multiply ROI volume by value -- needed for creating a volume label file
    fslmaths ${WD}/sub2atl_${ROIname} -mul $roi_value ${WD}/sub2atl_label_${ROIname}
    fslmaths ${WD}/atl_${ROIname} -mul $roi_value ${WD}/atl_label_${ROIname}

    #use wb_command to create the volume label file, needed for creating the individual dtseries
    ${CARET7DIR}/wb_command -volume-label-import ${WD}/sub2atl_label_${ROIname} ${WD}/labelfile.txt sub2atl_vol_label_${ROIname} -drop-unused-labels
    ${CARET7DIR}/wb_command -volume-label-import ${WD}/atl_label_${ROIname} ${WD}/labelfile.txt atl_vol_label_${ROIname} -drop-unused-labels

    #create the individual dtseries
    ${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${WD}/${NameOffMRI}_temp_subject_${ROInum}.dtseries.nii -volume sub2atl_vol_masked_${ROIname} ${WD}/sub2atl_vol_label_${ROIname}
    # Maybe here, too.

    #create the cifti label file from the volume label file (why?????)
    #${CARET7DIR}/wb_command -cifti-create-label ${WD}/sub_${NameOffMRI}_temp_template_${ROInum}.dlabel.nii -volume ${WD}/sub2atl_vol_label_${ROIname} ${WD}/sub2atl_vol_label_${ROIname}
    ${CARET7DIR}/wb_command -cifti-create-label ${WD}/atl_${NameOffMRI}_temp_template_${ROInum}.dlabel.nii -volume ${WD}/atl_vol_label_${ROIname} ${WD}/atl_vol_label_${ROIname}

    #dilate the timeseries
    ${CARET7DIR}/wb_command -cifti-dilate ${WD}/${NameOffMRI}_temp_subject_${ROInum}.dtseries.nii COLUMN 0 10 ${WD}/${NameOffMRI}_temp_subject_${ROInum}_dilate.dtseries.nii

    #perform resampling - resample into Atlas space, not subject space.
    ${CARET7DIR}/wb_command -cifti-resample ${WD}/${NameOffMRI}_temp_subject_${ROInum}_dilate.dtseries.nii COLUMN ${WD}/atl_${NameOffMRI}_temp_template_${ROInum}.dlabel.nii COLUMN ADAP_BARY_AREA CUBIC ${WD}/${NameOffMRI}_temp_atlas_${ROInum}.dtseries.nii -volume-predilate 10

    #perform smoothing
    ${CARET7DIR}/wb_command -cifti-smoothing ${WD}/${NameOffMRI}_temp_atlas_${ROInum}.dtseries.nii 0 ${Sigma} COLUMN ${WD}/${NameOffMRI}_temp_subject_dilate_resample_smooth_${ROInum}.dtseries.nii -fix-zeros-volume

    #split back into a volumetric timeseries file
    ${CARET7DIR}/wb_command -cifti-separate ${WD}/${NameOffMRI}_temp_subject_dilate_resample_smooth_${ROInum}.dtseries.nii COLUMN -volume-all ${ResultsFolder}/${NameOffMRI}_${ROInum}.nii.gz

    #add timeseries input to new dtseries file
    if (( $label_count == 1 )); then
        ${CARET7DIR}/wb_command -cifti-create-dense-from-template ${WD}/${NameOffMRI}_temp_orig_atlas.dtseries.nii ${WD}/${NameOffMRI}_temp_atlas.dtseries.nii -series ${TR} 0.0 -volume ${roi_name} ${ResultsFolder}/${NameOffMRI}_${ROInum}.nii.gz
    else
        ${CARET7DIR}/wb_command -cifti-replace-structure ${WD}/${NameOffMRI}_temp_atlas.dtseries.nii COLUMN -volume ${roi_name} ${ResultsFolder}/${NameOffMRI}_${ROInum}.nii.gz
    fi

    #add input to fslmaths command to grow iteratively
    #DTSCommand="${DTSCommand} -volume ${roi_name} ${ResultsFolder}/${NameOffMRI}_${ROInum}.nii.gz"
    Sub2AtlCmd="${Sub2AtlCmd}-add ${WD}/sub2atl_label_${ROIname} "
done

# Replace first "-add" with "fslmaths" in Sub2AtlCmd.
Sub2AtlCmd="${Sub2AtlCmd/-add/fslmaths}"

set -x

# Combine all of the volumes of all of the ROIs into one temporary file.
#${DTSCommand}
# Combine all of the sub2atl_label files into one.
${Sub2AtlCmd} ${ROIFolder}/sub2atl_ROI.${GrayordinatesResolution}.nii.gz

# Convert the cifti into a volume file the output volume.
${CARET7DIR}/wb_command -cifti-separate ${WD}/${NameOffMRI}_temp_atlas.dtseries.nii COLUMN -volume-all ${VolumefMRI}_AtlasSubcortical_s${SmoothingFWHM}.nii.gz

# Remove temporary files.
popd
rm -rf ${WD}

echo File ${VolumefMRI}_AtlasSubcortical_s${SmoothingFWHM}.nii.gz was written.
echo "END $script"


