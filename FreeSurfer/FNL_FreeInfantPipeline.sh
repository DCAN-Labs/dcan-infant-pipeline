#!/bin/bash

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions

log_SetToolName "FNL_FreeInfantPipeline.sh"

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
    show_usage
fi

log_Msg "Parsing Command Line Options"

# Input Variables
SubjectID=`opts_GetOpt1 "--subject" $@` # FreeSurfer Subject ID Name
SubjectDIR=`opts_GetOpt1 "--subjectDIR" $@` # Location to Put FreeSurfer Subject's Folder
T1wImage=`opts_GetOpt1 "--t1" $@` # T1w FreeSurfer Input (Full Resolution)
T1wImageBrain=`opts_GetOpt1 "--t1brain" $@`
T2wImage=`opts_GetOpt1 "--t2" $@` # T2w FreeSurfer Input (Full Resolution)
recon_all_seed=`opts_GetOpt1 "--seed" $@`
Aseg=`opts_GetOpt1 "--aseg" $@`
GCA=`opts_GetOpt1 "--gca" $@`
useT2=`opts_GetOpt1 "--useT2" $@`
MaxThickness=`opts_GetOpt1 "--maxThickness" $@` # Max threshold for thickness measurements (default = 5mm)
NormMethod=`opts_GetOpt1 "--normalizationMethod" $@`
SmoothingIterations=`opts_GetOpt1 "--smoothingIterations" $@`

T1wImageFile=`remove_ext $T1wImage`
T1wImageBrainFile=`remove_ext $T1wImageBrain`
AsegFile=`remove_ext $Aseg`
Modalities=T1w

if [ -z  "${NormMethod}" ] ; then
    # Default is to use the adult grey matter intensity profile.
    NormMethod="ADULT_GM_IP"
fi

if [[ "${NormMethod^^}" != "NONE" ]] ; then
    Modalities="T1w T1wN"
fi

if [ -z "${MaxThickness}" ] ; then
    MaxThickness=5     # FreeSurfer default is 5 mm
fi
MAXTHICKNESS="-max ${MaxThickness}"

if [ -z "${SmoothingIterations}" ] ; then
    # mris_smooth default is 10 iterations
    log_Msg "No smoothing iterations were provided. Using default of 10."
    SmoothingIterations=10
fi

######## FNL CODE #######
echo "`basename $0` $@"
echo "START: `basename $0`"

set -x

export SUBJECTS_DIR=$SubjectDIR
# remove old runs
cd $SubjectDIR

# SUBJECTS_DIR is the location to put FreeSurfer subject's folder.
# And, it is actually the path to T1w files.
# FreeSurfer creates 2 directories w/in T1w for its files:
#       <subject id> and <subject id>N.
if [ -e "${SUBJECTS_DIR}"/$SubjectID ]; then
    rm -rf "${SUBJECTS_DIR}"/$SubjectID
fi
if [ -e "${SUBJECTS_DIR}"/${SubjectID}N ]; then
    rm -rf "${SUBJECTS_DIR}"/${SubjectID}N
fi
mksubjdirs $SubjectID

# convert files to freesurfer standard
Mean=`fslstats $T1wImageBrain -M`

# Hypernormalization was being done at the very end of PreFreeSurfer. Moved to beginning of
# FreeSurfer so that users can do extra processing between the 2 steps.
# Currently has 3 methods: ADULT_GM_IP (default), ROI_IPS (prior method), or NONE.
if [[ "${NormMethod^^}" == "NONE" ]] ; then
    echo Skipping hyper-normalization step per request.
else
    ${HCPPIPEDIR_FS}/hypernormalize.sh ${SUBJECTS_DIR} ${NormMethod}
    T1wNImage=${SUBJECTS_DIR}/T1wN_acpc.nii.gz
    T1wNImageBrain=${SUBJECTS_DIR}/T1wN_acpc_brain.nii.gz
    echo T1wNImage=$T1wNImage
    echo T1wNImageBrain=$T1wNImageBrain
    T1wNImageFile=`remove_ext $T1wNImage`
    T1wNImageBrainFile=`remove_ext $T1wNImageBrain`
fi

#@TODO test isoxfm for this data.  Will it work without being 1mm isotropic?
if ! ${CrudeHistogramMatching:-true}; then
    flirt -interp spline -in "$T1wImage"  -ref "$T1wImage" -applyisoxfm 1 -out "$T1wImageFile"_1mm.nii.gz
else
    cp "$T1wImage" "$T1wImageFile"_1mm.nii.gz
    echo "1mm files are misnamed!" > "${SUBJECTS_DIR}"/README.txt
fi

applywarp --rel --interp=spline -i "$T1wImage" -r "$T1wImageFile"_1mm.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1wImageFile"_1mm.nii.gz
applywarp --rel --interp=nn -i "$T1wImageBrain" -r "$T1wImageFile"_1mm.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1wImageBrainFile"_1mm.nii.gz
fslmaths "$T1wImageFile"_1mm.nii.gz -div $Mean -mul 150 -abs "$T1wImageFile"_1mm.nii.gz
fslmaths "$T1wImageBrainFile"_1mm.nii.gz -thr 0 "$T1wImageBrainFile"_1mm.nii.gz # ensure no negative values in input image
applywarp --rel --interp=nn -i "$AsegFile".nii.gz -r "$T1wImageFile"_1mm.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$AsegFile"_1mm.nii.gz
# convert Norm files if in use
if [[ "${NormMethod^^}" != "NONE" ]] ; then
    applywarp --rel --interp=spline -i "$T1wNImage" -r "$T1wImageFile"_1mm.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1wNImageFile"_1mm.nii.gz
    applywarp --rel --interp=nn -i "$T1wNImageBrain" -r "$T1wImageFile"_1mm.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1wNImageBrainFile"_1mm.nii.gz
    fslmaths "$T1wNImageBrainFile"_1mm.nii.gz -thr 0 "$T1wNImageBrainFile"_1mm.nii.gz # ensure no negative values in input image
fi

for Modality in $Modalities; do

if [ $Modality = T1w ]; then
    TXwImageBrainFile="$T1wImageBrainFile"
    tmpID=$SubjectID
elif [ $Modality = T1wN ]; then
    TXwImageBrainFile="$T1wNImageBrainFile"
    tmpID=${SubjectID}N
    mksubjdirs $tmpID
fi

mri_convert --conform -ns 1 "$TXwImageBrainFile"_1mm.nii.gz "$tmpID"/mri/001.mgz
mri_convert --conform -ns 1 "$AsegFile"_1mm.nii.gz "$tmpID"/mri/aseg.mgz

cp "$tmpID"/mri/001.mgz "$tmpID"/mri/rawavg.mgz
cp "$tmpID"/mri/rawavg.mgz "$tmpID"/mri/orig.mgz

pushd ${tmpID}/mri > /dev/null
mkdir tmp.mri_nu_correct.mni.16177
mri_convert orig.mgz ./tmp.mri_nu_correct.mni.16177/nu0.mnc -odt float
nu_correct -clobber ./tmp.mri_nu_correct.mni.16177/nu0.mnc ./tmp.mri_nu_correct.mni.16177/nu1.mnc -tmpdir ./tmp.mri_nu_correct.mni.16177/0/ -iterations 1000 -distance 50
mri_convert ./tmp.mri_nu_correct.mni.16177/nu1.mnc orig_nu.mgz --like orig.mgz
cp orig_nu.mgz nu.mgz
cp nu.mgz brainmask.mgz
mri_normalize -aseg aseg.mgz -brainmask brainmask.mgz nu.mgz T1.mgz
if [ -e T1.mgz ] ; then
    cp T1.mgz brainmask.mgz
else
    log_Error_Abort "After mri_normalize, ${tmpID}/mri/T1.mgz does not exist."
fi
mri_convert --conform -ns 1 brainmask.mgz brain.mgz
mri_mask -T 5 brain.mgz brainmask.mgz brain.finalsurfs.mgz

mri_em_register -uns 3 -mask brainmask.mgz nu.mgz $GCA transforms/talairach.lta

mri_ca_normalize -mask brainmask.mgz nu.mgz $GCA transforms/talairach.lta norm.mgz
popd >/dev/null
done

if ${CrudeHistogramMatching:-true}; then
    cp -T -n ${SubjectID}N/mri/brain.finalsurfs.mgz ${SubjectID}/mri/brain.AN.mgz
fi

fslmaths "$AsegFile"_1mm.nii.gz -thr 41 -uthr 41 -bin rwm_1mm.nii.gz
fslmaths "$AsegFile"_1mm.nii.gz -thr 2 -uthr 2 -bin lwm_1mm.nii.gz
#@TODO evaluate if this is best, in babies, this is not the average white matter intensity:
fslmaths rwm_1mm.nii.gz -add lwm_1mm.nii.gz -mul 110 wm.nii.gz
mri_convert --conform -ns 1 wm.nii.gz wm.seg.mgz

pushd "$SubjectID"/mri >/dev/null
mv "$SubjectDIR"/wm.seg.mgz ./
mri_edit_wm_with_aseg -keep-in wm.seg.mgz brain.mgz aseg.mgz wm.asegedit.mgz
mri_pretess wm.asegedit.mgz wm norm.mgz wm.mgz
mri_fill -a ../scripts/ponscc.cut.log -xform transforms/talairach.lta -segmentation aseg.mgz wm.mgz filled.mgz
cp aseg.mgz aseg.presurf.mgz
popd > /dev/null

# create initial white matter surface
if ${CrudeHistogramMatching:-true}; then
    echo "BEGIN: recon-all-to-pial for T1w"
    recon-all -subjid ${SubjectID} -tessellate -smooth1 -inflate1 -qsphere -fix
    echo "Using Adult-Normalized brain to make white matter surface"
    cp ${SubjectID}N/mri/brain.finalsurfs.mgz ${SubjectID}/mri/brain.AN.mgz
    mris_make_surfaces ${MAXTHICKNESS} -whiteonly -noaparc -mgz -T1 brain.AN ${SubjectID} lh
    mris_make_surfaces ${MAXTHICKNESS} -whiteonly -noaparc -mgz -T1 brain.AN ${SubjectID} rh
    # Do our own smoothing before the next recon-all so that we can choose the number of iterations.
    surf_files=${SUBJECTS_DIR}/${SubjectID}/surf
    mris_smooth -n ${SmoothingIterations} -nw ${surf_files}/lh.white.preaparc ${surf_files}/lh.smoothwm
    mris_smooth -n ${SmoothingIterations} -nw ${surf_files}/rh.white.preaparc ${surf_files}/rh.smoothwm
    recon-all -subjid ${SubjectID} -inflate2 -sphere -surfreg -jacobian_white -avgcurv -cortparc
    cp "${SUBJECTS_DIR}"/"$SubjectID"/mri/aseg.mgz "${SUBJECTS_DIR}"/"$SubjectID"/mri/wmparc.mgz
    echo "END: recon-all-to-pial for T1w"

    echo "Using Adult-Normalized brain to make pial surface"
    for hemi in l r; do
        # use Pial from Adult-Normalized surface as a prior.
        cp -T -n ${SubjectID}/surf/"${hemi}"h.white ${SubjectID}/surf/"${hemi}"h.white.noAN
        mris_make_surfaces ${MAXTHICKNESS} -white NOWRITE -mgz -T1 brain.AN "$SubjectID" ${hemi}h
        #mris_make_surfaces -nowhite -orig_pial pial -mgz -T1 brain.finalsurfs $Subject ${hemi}h
    done
    echo "Beginning final recon-all stages"
    recon-all -subjid $SubjectID -surfvolume -pctsurfcon \
        -parcstats -cortparc2 -parcstats2 -cortribbon -segstats -aparc2aseg -wmparc -balabels
    echo "End: final recon-all"

else
    echo "running standard recon-all"
    recon-all -subjid ${SubjectID} -tessellate -smooth1 -inflate1 -qsphere -fix -white -smooth2 -inflate2
    recon-all -autorecon3 -subjid $SubjectID
fi
pushd ${SubjectID}/surf > /dev/null
# Data already in 1mm isotropic, copying white matter
cp lh.white lh.white.deformed
cp rh.white rh.white.deformed
popd > /dev/null
pushd ${SubjectID}/mri > /dev/null
    if [ ! -e transforms/eye.dat ]; then
        mkdir -p transforms
        echo "$SubjectID" > transforms/eye.dat
        echo "1" >> transforms/eye.dat
        echo "1" >> transforms/eye.dat
        echo "1" >> transforms/eye.dat
        echo "1 0 0 0" >> transforms/eye.dat
        echo "0 1 0 0" >> transforms/eye.dat
        echo "0 0 1 0" >> transforms/eye.dat
        echo "0 0 0 1" >> transforms/eye.dat
        echo "round" >> transforms/eye.dat
    fi
    # faking refined transformation for T2wtoT1w.mat
    flirt -in $T1wImage -ref $T1wImage -applyisoxfm 1 -omat transforms/T2wtoT1w.mat #@TODO investigate how this looks downstream
popd > /dev/null
fslmaths "$T1wImage" -abs -add 1 "${SUBJECTS_DIR}/$SubjectID/mri/T1w_hires.nii.gz"

echo "End FNL_FreeInfantPipeline.sh - aka FreeSurfer script."

