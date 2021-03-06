#!/bin/bash
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), FreeSurfer (version 5.3.0-HCP)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR

########################################## PIPELINE OVERVIEW ##########################################

#TODO

########################################## OUTPUT DIRECTORIES ##########################################

#TODO

# --------------------------------------------------------------------------------
#  Load Function Libraries
# --------------------------------------------------------------------------------

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions

########################################## SUPPORT FUNCTIONS ##########################################

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

show_usage() {
    echo "Usage information To Be Written"
    exit 1
}

# --------------------------------------------------------------------------------
#   Establish tool name for logging
# --------------------------------------------------------------------------------
log_SetToolName "FreeSurferPipeline.sh"

################################################## OPTION PARSING #####################################################

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
    show_usage
fi

log_Msg "Parsing Command Line Options"

# Input Variables
SubjectID=`opts_GetOpt1 "--subject" $@` #FreeSurfer Subject ID Name
SubjectDIR=`opts_GetOpt1 "--subjectDIR" $@` #Location to Put FreeSurfer Subject's Folder
T1wImage=`opts_GetOpt1 "--t1" $@` #T1w FreeSurfer Input (Full Resolution)
T1wImageBrain=`opts_GetOpt1 "--t1brain" $@`
T2wImage=`opts_GetOpt1 "--t2" $@` #T2w FreeSurfer Input (Full Resolution)
recon_all_seed=`opts_GetOpt1 "--seed" $@`
Aseg=`opts_GetOpt1 "--aseg" $@` #DS 20170419
GCA=`opts_GetOpt1 "--gca" $@`
useT2=`opts_GetOpt1 "--useT2" $@` #AP 20162111

# ------------------------------------------------------------------------------
#  Show Command Line Options
# ------------------------------------------------------------------------------

log_Msg "Finished Parsing Command Line Options"
log_Msg "SubjectID: ${SubjectID}"
log_Msg "SubjectDIR: ${SubjectDIR}"
log_Msg "T1wImage: ${T1wImage}"
log_Msg "T1wImageBrain: ${T1wImageBrain}"
log_Msg "T2wImage: ${T2wImage}"
log_Msg "recon_all_seed: ${recon_all_seed}"
log_Msg "useT2: ${useT2}"

# figure out whether to include a random seed generator seed in all the recon-all command lines
seed_cmd_appendix=""
if [ -z "${recon_all_seed}" ] ; then
	seed_cmd_appendix=""
else
	seed_cmd_appendix="-norandomness -rng-seed ${recon_all_seed}"
fi
log_Msg "seed_cmd_appendix: ${seed_cmd_appendix}"

# ------------------------------------------------------------------------------
#  Show Environment Variables
# ------------------------------------------------------------------------------

log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"
log_Msg "HCPPIPEDIR_FS: ${HCPPIPEDIR_FS}"

# ------------------------------------------------------------------------------
#  Identify Tools
# ------------------------------------------------------------------------------

which_flirt=`which flirt`
flirt_version=`flirt -version`
log_Msg "which flirt: ${which_flirt}"
log_Msg "flirt -version: ${flirt_version}"

which_applywarp=`which applywarp`
log_Msg "which applywarp: ${which_applywarp}"

which_fslstats=`which fslstats`
log_Msg "which fslstats: ${which_fslstats}"

which_fslmaths=`which fslmaths`
log_Msg "which fslmaths: ${which_fslmaths}"

which_recon_all=`which recon-all`
recon_all_version=`recon-all --version`
log_Msg "which recon-all: ${which_recon_all}"
log_Msg "recon-all --version: ${recon_all_version}"

which_mri_convert=`which mri_convert`
log_Msg "which mri_convert: ${which_mri_convert}"

which_mri_em_register=`which mri_em_register`
mri_em_register_version=`mri_em_register --version`
log_Msg "which mri_em_register: ${which_mri_em_register}"
log_Msg "mri_em_register --version: ${mri_em_register_version}"

which_mri_watershed=`which mri_watershed`
mri_watershed_version=`mri_watershed --version`
log_Msg "which mri_watershed: ${which_mri_watershed}"
log_Msg "mri_watershed --version: ${mri_watershed_version}"

# Start work

T1wImageFile=`remove_ext $T1wImage`;
T1wImageBrainFile=`remove_ext $T1wImageBrain`;
AsegFile=`remove_ext $Aseg`;

PipelineScripts=${HCPPIPEDIR_FS}


if [ -e "$SubjectDIR"/"$SubjectID"/scripts/IsRunning.lh+rh ] ; then
  rm "$SubjectDIR"/"$SubjectID"/scripts/IsRunning.lh+rh
fi

mkdir -p "$SubjectDIR"/"$SubjectID"/mri
echo "*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#TEST*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*"
#Make Spline Interpolated Downsample to 1mm
log_Msg "Make Spline Interpolated Downsample to 1mm"
Mean=`fslstats $T1wImageBrain -M`
flirt -interp spline -in "$T1wImage" -ref "$T1wImage" -applyisoxfm 1 -out "$T1wImageFile"_1mm.nii.gz
applywarp --rel --interp=spline -i "$T1wImage" -r "$T1wImageFile"_1mm.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1wImageFile"_1mm.nii.gz
applywarp --rel --interp=nn -i "$T1wImageBrain" -r "$T1wImageFile"_1mm.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1wImageBrainFile"_1mm.nii.gz
fslmaths "$T1wImageFile"_1mm.nii.gz -div $Mean -mul 150 -abs "$T1wImageFile"_1mm.nii.gz
fslmaths "$T1wImageFile"_1mm.nii.gz -mas "$T1wImageBrainFile"_1mm.nii.gz "$T1wImageBrainFile"_1mm.nii.gz
mri_convert "$T1wImageBrainFile"_1mm.nii.gz "$SubjectDIR"/"$SubjectID"/mri/orig.mgz --conform

#Initial Recon-all Steps
log_Msg "Initial Recon-all Steps"

# Call recon-all with flags that are part of "-autorecon1", with the exception of -skullstrip.
# -skullstrip of FreeSurfer not reliable for Phase II data because of poor FreeSurfer mri_em_register registrations with Skull on,
# so run registration with PreFreeSurfer masked data and then generate brain mask as usual.
#recon-all -i "$T1wImageFile"_1mm.nii.gz -subjid $SubjectID -sd $SubjectDIR -motioncor ${seed_cmd_appendix}
echo "*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#TEST 2*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*"
pushd "$SubjectDIR"/"$SubjectID"/mri
mkdir -p "$SubjectDIR"/"$SubjectID"/mri/tmp.mri_nu_correct.mni.16177
mri_convert orig.mgz ./tmp.mri_nu_correct.mni.16177/nu0.mnc -odt float
nu_correct -clobber ./tmp.mri_nu_correct.mni.16177/nu0.mnc ./tmp.mri_nu_correct.mni.16177/nu1.mnc -tmpdir ./tmp.mri_nu_correct.mni.16177/0/ -iterations 1000 -distance 50
mri_convert ./tmp.mri_nu_correct.mni.16177/nu1.mnc orig_nu.mgz --like orig.mgz
cp orig_nu.mgz nu.mgz
cp nu.mgz brainmask.mgz
popd
mkdir -p "$SubjectDIR"/"$SubjectID"/mri/transforms
# Generate brain mask
#mri_convert "$T1wImageBrainFile"_1mm.nii.gz "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz --conform
echo "*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#TEST 3*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*"
mri_em_register -uns 3 -mask "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz "$SubjectDIR"/"$SubjectID"/mri/nu.mgz "$FREESURFER_HOME"/average/RB_all_2008-03-26.gca "$SubjectDIR"/"$SubjectID"/mri/transforms/talairach.lta
# skipping watershed - no proper .gca, poor talairach.lta for infants.
#mri_watershed -T1 -brain_atlas $FREESURFER_HOME/average/RB_all_withskull_2008-03-26.gca "$SubjectDIR"/"$SubjectID"/mri/transforms/talairach_with_skull.lta "$SubjectDIR"/"$SubjectID"/mri/T1.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.auto.mgz
#cp "$SubjectDIR"/"$SubjectID"/mri/brainmask.auto.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz

# Both the SGE and PBS cluster schedulers use the environment variable NSLOTS to indicate the number of cores
# a job will use.  If this environment variable is set, we will use it to determine the number of cores to
# tell recon-all to use.


if [[ -z ${NSLOTS} ]]
then
    num_cores=8
else
    num_cores="${NSLOTS}"
fi
num_cores=1 ##### Set by Anders 20162211
# Call recon-all to run most obrain.mgzf the "-autorecon2" stages, but turning off smooth2, inflate2, curvstats, and segstats stages

# recon-all -subjid $SubjectID -sd $SubjectDIR -gcareg -canorm -careg  -careginv -rmneck -skull-lta -openmp ${num_cores} ${seed_cmd_appendix}

############################################# INFANT PROTOCOL ############################################
# utilize aseg_acpc.nii.gz, convert to aseg.mgz
log_Msg "Pre-aseg images: `ls ${SubjectDIR}/${SubjectID}/mri`" 
pushd ${SubjectDIR}/${SubjectID}/mri
mri_convert --conform -ns 1 ${SubjectDIR}/../masks/aseg_acpc_1mm.nii.gz ${SubjectDIR}/${SubjectID}/mri/aseg.mgz # ${AsegFile}_1mm.nii.gz to aseg_acpc_1mm.nii.gz 7/31/17 -Dakota
echo "*#*#*#*#*#*#*#*#*#*#*#*#*TEST 4*#*#*#*#*#*#*#*#*#*#*#*#*#*#*"
mri_ca_normalize -c ctrl_pts.mgz -mask brainmask.mgz nu.mgz $FREESURFER_HOME/average/RB_all_2008-03-26.gca transforms/talairach.lta norm.mgz
mri_normalize -aseg aseg.mgz -mask brainmask.mgz norm.mgz brain.mgz
mri_mask -T 5 brain.mgz brainmask.mgz brain.finalsurfs.mgz
popd

pushd ${SubjectDIR}/../masks
fslmaths ${SubjectDIR}/../masks/aseg_acpc_1mm.nii.gz -thr 41 -uthr 41 -bin blah41.nii.gz # ${AsegFile}_1mm.nii.gz to aseg_acpc_1mm.nii.gz 7/31/17 -Dakota
fslmaths ${SubjectDIR}/../masks/aseg_acpc_1mm.nii.gz -thr 2 -uthr 2 -bin blah2.nii.gz # ${AsegFile}_1mm.nii.gz to aseg_acpc_1mm.nii.gz 7/31/17 -Dakota
fslmaths blah41.nii.gz -add blah2.nii.gz wm_init.nii.gz
#rm blah*brain.mgz
fslmaths wm_init.nii.gz -mul 110 wm.nii.gz #is this best?
mri_convert --conform -ns 1 wm.nii.gz wm.seg.mgz
cp wm.seg.mgz ${SubjectDIR}/${SubjectID}/mri/wm.seg.mgz
popd

mkdir -p "$SubjectDIR"/"$SubjectID"/scripts
pushd ${SubjectDIR}/${SubjectID}/mri
mri_convert -odt uchar -ns 1 brain.mgz brain.mgz
mri_edit_wm_with_aseg -keep-in wm.seg.mgz brain.mgz aseg.mgz wm.asegedit.mgz
mri_pretess wm.asegedit.mgz wm norm.mgz wm.mgz
mri_fill -a ../scripts/ponscc.cut.log -xform transforms/talairach.lta -segmentation aseg.mgz wm.mgz filled.mgz
popd
recon-all -subjid $SubjectID -sd $SubjectDIR -tessellate -smooth1 -inflate1 -qsphere -fix -white -openmp ${num_cores} ${seed_cmd_appendix}
###########################################################################################################

#Highres white stuff and Fine Tune T2w to T1w Reg
log_Msg "High resolution white matter and fine tune T2w to T1w registration"
"$PipelineScripts"/FreeSurferHiresWhite.sh "$SubjectID" "$SubjectDIR" "$T1wImage" "$T2wImage" "$useT2"

#Intermediate Recon-all Steps
log_Msg "Intermediate Recon-all Steps"
recon-all -subjid $SubjectID -sd $SubjectDIR -smooth2 -inflate2 -curvstats -sphere -surfreg -jacobian_white -avgcurv -cortparc ${seed_cmd_appendix}

if $useT2; then
#Highres pial stuff (this module adjusts the pial surface based on the the T2w image)
log_Msg "High Resolution pial surface"
"$PipelineScripts"/FreeSurferHiresPial.sh "$SubjectID" "$SubjectDIR" "$T1wImage" "$T2wImage"
fi

#Final Recon-all Steps
log_Msg "Final Recon-all Steps"
recon-all -subjid $SubjectID -sd $SubjectDIR -surfvolume -parcstats -cortparc2 -parcstats2 -cortparc3 -parcstats3 -cortribbon -segstats -aparc2aseg -wmparc -balabels -label-exvivo-ec ${seed_cmd_appendix}

log_Msg "Completed"
