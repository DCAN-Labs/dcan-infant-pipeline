#!/bin/bash
#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # PreFreeSurferPipeline.sh
#
# ## Copyright Notice
#
# Copyright (C) 2013-2014 The Human Connectome Project
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Matthew F. Glasser, Department of Anatomy and Neurobiology, Washington University in St. Louis
# * Mark Jenkinson, FMRIB Centre, Oxford University
# * Timothy B. Brown, Neuroinformatics Research Group, Washington University in St. Louis
# * Modifications to support General Electric Gradient Echo field maps for readout distortion correction
#   are based on example code provided by Gaurav Patel, Columbia University
#
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENSE.md) file
#
# ## Description
#
# This script, PreFreeSurferPipeline.sh, is the first of 3 sub-parts of the
# Structural Preprocessing phase of the [HCP][HCP] Minimal Preprocessing Pipelines.
#
# See [Glasser et al. 2013][GlasserEtAl].
#
# This script implements the PreFreeSurfer Pipeline referred to in that publication.
#
# The primary purposes of the PreFreeSurfer Pipeline are:
#
# 1. To average any image repeats (i.e. multiple T1w or T2w images available)
# 2. To create a native, undistorted structural volume space for the
#      images in this native space will be distortion corrected
#      for gradient and b0 distortions and rigidly aligned to the axes
#      of the MNI space. "Native, undistorted structural volume space"
#      is sometimes shortened to the "subject's native space" or simply
#      "native space".
# 3. To provide an initial robust brain extraction
# 4. To align the T1w and T2w structural images (register them to the native space)
# 5. To perform bias field correction
# 6. To register the subject's native space to the MNI space
#
# ## Prerequisites:
#
# ### Installed Software
#
# * [FSL][FSL] - FMRIB's Software Library (version 5.0.6)
#
# ### Environment Variables
#
# * HCPPIPEDIR
#
#   The "home" directory for the version of the HCP Pipeline Tools product
#   being used. E.g. /nrgpackages/tools.release/hcp-pipeline-tools-V3.0
#
# * HCPPIPEDIR_PreFS
#
#   Location of PreFreeSurfer sub-scripts that are used to carry out some of
#   steps of the PreFreeSurfer pipeline
#
# * HCPPIPEDIR_Global
#
#   Location of shared sub-scripts that are used to carry out some of the
#   steps of the PreFreeSurfer pipeline and are also used to carry out
#   some steps of other pipelines.
#
# * FSLDIR
#
#   Home directory for [FSL][FSL] the FMRIB Software Library from Oxford
#   University
#
# ### Image Files
#
# At least one T1 weighted image and one T2 weighted image are required
# for this script to work.
#
# ### Output Directories
#
# Command line arguments are used to specify the path (--path) of derivative
# files.  All outputs are generated within the tree rooted at ${DerivRoot}.
# The main output directories are:
#
# * The T1wFolder: ${DerivRoot}/T1w
# * The T2wFolder: ${DerivRoot}/T2w
# * The AtlasSpaceFolder: ${DerivRoot}/MNINonLinear
#
# All outputs are generated in directories at or below these three main
# output directories.  The full list of output directories is:
#
# * ${T1wFolder}/T1w${i}_GradientDistortionUnwarp
# * ${T1wFolder}/AverageT1wImages
# * ${T1wFolder}/ACPCAlignment
# * ${T1wFolder}/BrainExtraction_FNIRTbased
# * ${T1wFolder}/xfms - transformation matrices and warp fields
#
# * ${T2wFolder}/T2w${i}_GradientDistortionUnwarp
# * ${T2wFolder}/AverageT1wImages
# * ${T2wFolder}/ACPCAlignment
# * ${T2wFolder}/BrainExtraction_FNIRTbased
# * ${T2wFolder}/xfms - transformation matrices and warp fields
#
# * ${T2wFolder}/T2wToT1wDistortionCorrectAndReg
# * ${T1wFolder}/BiasFieldCorrection_sqrtT1wXT1w
#
# * ${AtlasSpaceFolder}
# * ${AtlasSpaceFolder}/xfms
#
# Note that no assumptions are made about the input paths with respect to the
# output directories. All specification of input files is done via command
# line arguments specified when this script is invoked.
#
# Also note that the following output directories are created:
#
# * T1wFolder, which is created by concatenating the following option
#   values: --path / --t1
# * T2wFolder, which is created by concatenating the following option
#   values: --path / --t2
#
# These two output directories must be different. Otherwise, various output
# files with standard names contained in such subdirectories, e.g.
# full2std.mat, would overwrite each other).  If this script is modified,
# then those two output directories must be kept distinct.
#
# ### Output Files
#
# * T1wFolder Contents: TODO
# * T2wFolder Contents: TODO
# * AtlasSpaceFolder Contents: TODO
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
# [GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
# [FSL]: http://fsl.fmrib.ox.ac.uk
#
#~ND~END~

# ------------------------------------------------------------------------------
#  Code Start
# ------------------------------------------------------------------------------

# Setup this script such that if any command exits with a non-zero value, the
# script itself exits and does not attempt any further processing.
#set -e

# -----------------------------------------------------------------------------------
#  Constants for specification of Averaging and Readout Distortion Correction Method
# -----------------------------------------------------------------------------------

NONE_METHOD_OPT="NONE"
FIELDMAP_METHOD_OPT="FIELDMAP"
SIEMENS_METHOD_OPT="SiemensFieldMap"
SPIN_ECHO_METHOD_OPT="TOPUP"
GENERAL_ELECTRIC_METHOD_OPT="GeneralElectricFieldMap"

# ------------------------------------------------------------------------------
#  Load Function Libraries
# ------------------------------------------------------------------------------

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------

show_usage() {
    cat <<EOF
PreFreeSurferPipeline.sh
Usage: PreeFreeSurferPipeline.sh [options]
  --path=<path>        Path to derivative-files folder (required) for all outputs.
  --t1=<T1w images>    An @ symbol separated list of full paths to T1-weighted
                       (T1w) structural images for the subject (required)
  --t2=<T2w images>    An @ symbol separated list of full paths to T2-weighted
                       (T2w) structural images for the subject (required)
  --t1template=<file path>          MNI T1w template
  --t1templatebrain=<file path>     Brain extracted MNI T1wTemplate
  --t1template2mm=<file path>       MNI 2mm T1wTemplate
  --t2template=<file path>          MNI T2w template
  --t2templatebrain=<file path>     Brain extracted MNI T2wTemplate
  --t2template2mm=<file path>       MNI 2mm T2wTemplate
  --templatemask=<file path>        Brain mask MNI Template
  --template2mmmask=<file path>     Brain mask MNI 2mm Template
  --brainsize=<size value>          Brain size estimate in mm, 120 for infant humans
  --fnirtconfig=<file path>         FNIRT 2mm T1w Configuration file
  --fmapmag=<file path>             Siemens Gradient Echo Fieldmap magnitude file
  --fmapphase=<file path>           Siemens Gradient Echo Fieldmap phase file
  --fmapgeneralelectric=<file path> General Electric Gradient Echo Field Map file
                                    Two volumes in one file
                                    1. field map in deg
                                    2. magnitude
  --echodiff=<delta TE>             Delta TE in ms for field map or "NONE" if
                                    not used
  --SEPhaseNeg={<file path>, NONE}  For spin echo field map, path to volume with
                                    a negative phase encoding direction (LR in
                                    HCP data), set to "NONE" if not using Spin
                                    Echo Field Maps
  --SEPhasePos={<file path>, NONE}  For spin echo field map, path to volume with
                                    a positive phase encoding direction (RL in
                                    HCP data), set to "NONE" if not using Spin
                                    Echo Field Maps
  --echospacing=<dwell time>        Echo Spacing or Dwelltime of Spin Echo Field
                                    Map or "NONE" if not used
  --seunwarpdir={x, y, NONE}        Phase encoding direction of the spin echo
                                    field map. (Only applies when using a spin echo
                                    field map.)
  --t1samplespacing=<seconds>       T1 image sample spacing, "NONE" if not used
  --t2samplespacing=<seconds>       T2 image sample spacing, "NONE" if not used
  --unwarpdir={x, y, z}             Readout direction of the T1w and T2w images
                                    (Used with either a gradient echo field map
                                     or a spin echo field map)
  --gdcoeffs=<file path>            File containing gradient distortion
                                    coefficients, Set to "NONE" to turn off
  --avgrdcmethod=<avgrdcmethod>     Averaging and readout distortion correction
                                    method. See below for supported values.
      "${NONE_METHOD_OPT}"
         average any repeats with no readout distortion correction
      "${FIELDMAP_METHOD_OPT}"
         equivalent to "${SIEMENS_METHOD_OPT}" (see below)
         SiemensFieldMap is preferred. This option value is maintained for
         backward compatibility.
      "${SPIN_ECHO_METHOD_OPT}"
         average any repeats and use Spin Echo Field Maps for readout
         distortion correction
      "${GENERAL_ELECTRIC_METHOD_OPT}"
         average any repeats and use General Electric specific Gradient
         Echo Field Maps for readout distortion correction
      "${SIEMENS_METHOD_OPT}"
         average any repeats and use Siemens specific Gradient Echo
         Field Maps for readout distortion correction
  --topupconfig=<file path>      Configuration file for topup or "NONE" if not
                                 used
  --bfsigma=<value>              Bias Field Smoothing Sigma (optional)
EOF
    exit 1
}

# Supply a file's path. Optionally, supply the line number.
assert_file_exists() {
    if [ -e ${1} ] ; then
        : # all is well
    else
        # Assertion failed.
        log_Msg "Error. File does not exist: ${1}"
        if [ -n "${2}" ] ; then
            log_Msg "$0, line $2"
        fi
        exit 1
    fi
}

# ------------------------------------------------------------------------------
#  Establish tool name for logging
# ------------------------------------------------------------------------------
log_SetToolName "PreFreeSurferPipeline.sh"

# ------------------------------------------------------------------------------
#  Parse Command Line Options
# ------------------------------------------------------------------------------

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
    show_usage
fi

log_Msg "Platform Information Follows: "
uname -a

log_Msg "Parsing Command Line Options"

DerivRoot=`opts_GetOpt1 "--path" $@`
T1wInputImages=`opts_GetOpt1 "--t1" $@`
T2wInputImages=`opts_GetOpt1 "--t2" $@`
T1wTemplate=`opts_GetOpt1 "--t1template" $@`
T1wTemplateBrain=`opts_GetOpt1 "--t1templatebrain" $@`
T1wTemplate2mm=`opts_GetOpt1 "--t1template2mm" $@`
T2wTemplate=`opts_GetOpt1 "--t2template" $@`
T2wTemplateBrain=`opts_GetOpt1 "--t2templatebrain" $@`
T2wTemplate2mm=`opts_GetOpt1 "--t2template2mm" $@`
TemplateMask=`opts_GetOpt1 "--templatemask" $@`
Template2mmMask=`opts_GetOpt1 "--template2mmmask" $@`
BrainSize=`opts_GetOpt1 "--brainsize" $@`
FNIRTConfig=`opts_GetOpt1 "--fnirtconfig" $@`
MagnitudeInputName=`opts_GetOpt1 "--fmapmag" $@`
PhaseInputName=`opts_GetOpt1 "--fmapphase" $@`
GEB0InputName=`opts_GetOpt1 "--fmapgeneralelectric" $@`
TE=`opts_GetOpt1 "--echodiff" $@`
SpinEchoPhaseEncodeNegative=`opts_GetOpt1 "--SEPhaseNeg" $@`
SpinEchoPhaseEncodePositive=`opts_GetOpt1 "--SEPhasePos" $@`
DwellTime=`opts_GetOpt1 "--echospacing" $@`
SEUnwarpDir=`opts_GetOpt1 "--seunwarpdir" $@`
T1wSampleSpacing=`opts_GetOpt1 "--t1samplespacing" $@`
T2wSampleSpacing=`opts_GetOpt1 "--t2samplespacing" $@`
UnwarpDir=`opts_GetOpt1 "--unwarpdir" $@`
GradientDistortionCoeffs=`opts_GetOpt1 "--gdcoeffs" $@`
AvgrdcSTRING=`opts_GetOpt1 "--avgrdcmethod" $@`
TopupConfig=`opts_GetOpt1 "--topupconfig" $@`
BiasFieldSmoothingSigma=`opts_GetOpt1 "--bfsigma" $@`
T1wNormalized=`opts_GetOpt1 "--t1n" $@`
MultiTemplateDir=`opts_GetOpt1 "--multitemplatedir" $@`
MultiMaskingDir=`opts_GetOpt1 "--multimaskingdir" $@`
TemplateList=`opts_GetOpt1 "--templatelist" $@`
T1wStudyTemplate=`opts_GetOpt1 "--t1studytemplate" $@`
T1wStudyTemplateBrain=`opts_GetOpt1 "--t1studytemplatebrain" $@`
T2wStudyTemplate=`opts_GetOpt1 "--t2studytemplate" $@`
T2wStudyTemplateBrain=`opts_GetOpt1 "--t2studytemplatebrain" $@`
ASegDir=`opts_GetOpt1 "--asegdir" $@`
AtroposMaskMethod=`opts_GetOpt1 "--atroposmaskmethod" $@`
AtroposLabelMin=`opts_GetOpt1 "--atroposlabelmin" $@`
AtroposLabelMax=`opts_GetOpt1 "--atroposlabelmax" $@`
JLFMethod=`opts_GetOpt1 "--jlfmethod" $@`
T1BrainMask=`opts_GetOpt1 "--t1brainmask" $@`

if [ -n "${T1BrainMask}" ] && [[ "${T1BrainMask^^}" == "NONE" ]] ; then
    unset T1BrainMask
elif [ -n "${T1BrainMask}" ] ; then
    log_Msg User supplied T1BrainMask is ${T1BrainMask}.
    assert_file_exists ${T1BrainMask} ${LINENO}
fi

#NOTE: currently is only used in gradient distortion correction of spin echo fieldmaps to topup
#not currently in usage, either, because of this very limited use
UseJacobian=`opts_GetOpt1 "--usejacobian" $@`

# Use --printcom=echo for just printing everything and not actually
# running the commands (the default is to actually run the commands)
RUN=`opts_GetOpt1 "--printcom" $@`

# Convert UseJacobian value to all lowercase (to allow the user the flexibility to use True, true, TRUE, False, False, false, etc.)
UseJacobian="$(echo ${UseJacobian} | tr '[:upper:]' '[:lower:]')"
UseJacobian=`opts_DefaultOpt $UseJacobian "true"`

# useT2 flag added for excluding or include T2w image in processing AP 20162111
# Any line that requires the T2 should be encapsulated in an if-then statement and skipped if useT2=false
useT2=`opts_GetOpt1 "--useT2" $@`

# Cropping: If processing images that don't have neck and shoulders, specify --crop=false.
crop=`opts_GetOpt1 "--crop" $@`

# The default alignment script does cropping of neck, shoulders. Choose the
# correct script. (Both scripts have same args, outputs.)
acpc_align_script_T2=${HCPPIPEDIR_PreFS}/ACPCAlignment_with_crop.sh
acpc_align_script_T1=${HCPPIPEDIR_PreFS}/ACPCAlignment_with_crop_T1.sh

if [ -n "${crop}" ] && [[ "${crop^^}" == "FALSE" ]] ; then
    acpc_align_script_T2=${HCPPIPEDIR_PreFS}/ACPCAlignment_no_crop.sh
    acpc_align_script_T1=${HCPPIPEDIR_PreFS}/ACPCAlignment_no_crop_T1.sh
fi

    

# ------------------------------------------------------------------------------
#  Show Command Line Options
# ------------------------------------------------------------------------------

log_Msg "Finished Parsing Command Line Options"
log_Msg "DerivRoot: ${DerivRoot}"
log_Msg "T1wInputImages: ${T1wInputImages}"
log_Msg "T2wInputImages: ${T2wInputImages}"
log_Msg "T1wTemplate: ${T1wTemplate}"
log_Msg "T1wTemplateBrain: ${T1wTemplateBrain}"
log_Msg "T1wTemplate2mm: ${T1wTemplate2mm}"
log_Msg "T2wTemplate: ${T2wTemplate}"
log_Msg "T2wTemplateBrain: ${T2wTemplateBrain}"
log_Msg "T2wTemplate2mm: ${T2wTemplate2mm}"
log_Msg "TemplateMask: ${TemplateMask}"
log_Msg "Template2mmMask: ${Template2mmMask}"
log_Msg "BrainSize: ${BrainSize}"
log_Msg "FNIRTConfig: ${FNIRTConfig}"
log_Msg "MagnitudeInputName: ${MagnitudeInputName}"
log_Msg "PhaseInputName: ${PhaseInputName}"
log_Msg "GEB0InputName: ${GEB0InputName}"
log_Msg "TE: ${TE}"
log_Msg "SpinEchoPhaseEncodeNegative: ${SpinEchoPhaseEncodeNegative}"
log_Msg "SpinEchoPhaseEncodePositive: ${SpinEchoPhaseEncodePositive}"
log_Msg "DwellTime: ${DwellTime}"
log_Msg "SEUnwarpDir: ${SEUnwarpDir}"
log_Msg "T1wSampleSpacing: ${T1wSampleSpacing}"
log_Msg "T2wSampleSpacing: ${T2wSampleSpacing}"
log_Msg "UnwarpDir: ${UnwarpDir}"
log_Msg "GradientDistortionCoeffs: ${GradientDistortionCoeffs}"
log_Msg "AvgrdcSTRING: ${AvgrdcSTRING}"
log_Msg "TopupConfig: ${TopupConfig}"
log_Msg "BiasFieldSmoothingSigma: ${BiasFieldSmoothingSigma}"
log_Msg "UseJacobian: ${UseJacobian}"
log_Msg "useT2: ${useT2}"
log_Msg "t1n: ${T1wNormalized}"
log_Msg "asegdir: ${ASegDir}"
log_Msg "crop: ${crop}"

# ------------------------------------------------------------------------------
#  Show Environment Variables
# ------------------------------------------------------------------------------

log_Msg "FSLDIR: ${FSLDIR}"
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"
log_Msg "HCPPIPEDIR_Global: ${HCPPIPEDIR_Global}"
log_Msg "HCPPIPEDIR_PreFS: ${HCPPIPEDIR_PreFS}"

# To avoid 5000+ lines of parsing parameters, moving -x here. KJS 5/10/19.
set -x

# Naming Conventions
T1wImage="T1w"
T1wFolder="T1w" #Location of T1w images
if $useT2; then
    T2wImage="T2w"
    T2wFolder="T2w" #Location of T2w images
fi

if [ ! ${T1wNormalized} = "NONE" ]; then
    T1wNImage="T1wN"
fi
log_Msg "T1wNImage: ${T1wNImage}"

# study template defaults to NONE
if [ -z "${T1wStudyTemplate}" ]; then
    T1wStudyTemplate="NONE"
    T1wStudyTemplateBrain="NONE"
fi
if [ -z "${T2wStudyTemplate}" ]; then
    # T2wStudyTemplate is required.
    log_Error_Abort "T2wStudyTemplate is a required argument and was not specified."
fi


AtlasSpaceFolder="MNINonLinear"

# Build Pathssubmit_HcpPre
T1wFolder=${DerivRoot}/${T1wFolder}
if $useT2; then
    T2wFolder=${DerivRoot}/${T2wFolder}
fi
AtlasSpaceFolder=${DerivRoot}/${AtlasSpaceFolder}

log_Msg "T1wFolder: ${T1wFolder}"
if $useT2; then
    log_Msg "T2wFolder: ${T2wFolder}"
fi
log_Msg "AtlasSpaceFolder: $AtlasSpaceFolder"

# Unpack List of Images
T1wInputImages=`echo ${T1wInputImages} | sed 's/@/ /g'`
if $useT2; then
    T2wInputImages=`echo ${T2wInputImages} | sed 's/@/ /g'`
fi

if [ ! -e ${T1wFolder}/xfms ] ; then
    log_Msg "mkdir -p ${T1wFolder}/xfms/"
    mkdir -p ${T1wFolder}/xfms/
fi

if $useT2; then
    if [ ! -e ${T2wFolder}/xfms ] ; then
        log_Msg "mkdir -p ${T2wFolder}/xfms/"
        mkdir -p ${T2wFolder}/xfms/
    fi
fi

if [ ! -e ${AtlasSpaceFolder}/xfms ] ; then
    log_Msg "mkdir -p ${AtlasSpaceFolder}/xfms/"
    mkdir -p ${AtlasSpaceFolder}/xfms/
fi

log_Msg "POSIXLY_CORRECT="${POSIXLY_CORRECT}

# Function to do classic JLF (using T1w)
# This is all of the processing that was at lines 784-813 in last version of PreFreeSurfer.
run_JLF_orig(){

    log_Msg "Performing T1w Joint Label Fusion method"

    # Added stage to get cortex/subcortical labels from multitemplate approach
    mkdir -p ${T1wFolder}/TemplateLabelFusion

    # for now, use basic wrapper for joint label fusion
    MultiTemplateT1wHead=T1w.nii.gz
    MultiTemplateSeg=Segmentation.nii.gz
    Council=($(ls "$MultiMaskingDir"))  # we have to make sure only subdirectories are inside...
    cmd="${HCPPIPEDIR_PreFS}/JLF_T1w_classic.sh --working-dir=${T1wFolder}/TemplateLabelFusion \
                    --target=$T1wFolder/${T1wImage}_acpc_dc_restore.nii.gz \
                    --refdir=${MultiMaskingDir} --output=${T1wFolder}/aseg_acpc_mask.nii.gz --ncores=${OMP_NUM_THREADS:-1}"
    for ((i=0; i<${#Council[@]}; i++)); do
            cmd=${cmd}" -g ${Council[$i]}/$MultiTemplateT1wHead -l ${Council[$i]}/$MultiTemplateSeg"
    done
    echo $cmd
    $cmd

    # run JLF using Zollei's brain atlases @TODO make these arguments cleaner later...
    mkdir -p ${T1wFolder}/TemplateLabelFusion2

    MultiTemplateT1wBrain=T1w_brain.nii.gz
    Council=($(ls "$MultiTemplateDir"))  # we have to make sure only subdirectories are inside...
    cmd="${HCPPIPEDIR_PreFS}/JLF_T1w_classic.sh --working-dir=${T1wFolder}/TemplateLabelFusion2 -x \
                    --target=$T1wFolder/${T1wImage}_acpc_dc_restore_brain.nii.gz \
                    --refdir=${MultiTemplateDir} --output=${T1wFolder}/aseg_acpc.nii.gz --ncores=${OMP_NUM_THREADS:-1}"
    for ((i=0; i<${#Council[@]}; i++)); do
            cmd=${cmd}" -g ${Council[$i]}/$MultiTemplateT1wBrain -l ${Council[$i]}/$MultiTemplateSeg"
    done
    echo $cmd
    $cmd

    fslmaths ${T1wFolder}/aseg_acpc.nii.gz -mas ${T1wFolder}/aseg_acpc_mask.nii.gz ${T1wFolder}/aseg_acpc.nii.gz
}

# Function to do JLF using T1w and DHCP atlas T1ws
run_JLF_T1W(){
    log_Msg "Performing T1w Joint Label Fusion method"
    cmd=$( which python3 ) ${HCPPIPEDIR_PreFS}/JLF.py --Txw_image=1 --target=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain.nii.gz --atlas-dir=${MultiTemplateDir} --output-dir=${T1wFolder} --njobs=${OMP_NUM_THREADS:-1}
    echo $cmd
    $cmd

    if [ -e ${T1wFolder}/aseg_acpc.nii.gz ] ; then
        echo SUCCESS: ${T1wFolder}/aseg_acpc.nii.gz was created.
    else
        echo ERROR: No ${T1wFolder}/aseg_acpc.nii.gz was created.
    fi
}

# Function to do new JLF (using T2w)
# Note: no aseg_acpc_mask.nii.gz is generated (or used) in this method.
run_JLF_T2W(){
    log_Msg "Performing T2w Joint Label Fusion method"
    cmd=$( which python3 ) ${HCPPIPEDIR_PreFS}/JLF.py --Txw_image=2 --target=${T1wFolder}/${T2wImage}_acpc_dc_restore_brain.nii.gz --atlas-dir=${MultiTemplateDir} --output-dir=${T1wFolder} --njobs=${OMP_NUM_THREADS:-1}
    echo $cmd
    $cmd

    if [ -e ${T1wFolder}/aseg_acpc.nii.gz ] ; then
        echo SUCCESS: ${T1wFolder}/aseg_acpc.nii.gz was created.
    else
        echo ERROR: No ${T1wFolder}/aseg_acpc.nii.gz was created.
    fi
}

# ------------------------------------------------------------------------------
#  Do primary work
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
#  Loop over the processing for T1w and T2w (just with different names).
#  For each modality, perform
#  - Gradient Nonlinearity Correction (Unless no gradient distortion
#    coefficients are available)
#  - Average same modality images (if more than one is available)
#  - Rigidly align images to 0.7mm MNI Template to create native volume space
#  - Perform Brain Extraction(FNIRT-based Masking)
# ------------------------------------------------------------------------------

if $useT2; then Modalities="T1w T2w"; else Modalities="T1w"; fi

for TXw in ${Modalities} ; do
    log_Msg "Processing Modality: " ${TXw}

    # set up appropriate input variables
    if [ ${TXw} = T1w ] ; then
        TXwInputImages="${T1wInputImages}"
        TXwFolder=${T1wFolder}
        TXwImage=${T1wImage}
        TXwTemplate=${T1wTemplate}
        TXwTemplateBrain=${T1wTemplateBrain}
        TXwTemplate2mm=${T1wTemplate2mm}
    else
        TXwInputImages="${T2wInputImages}"
        TXwFolder=${T2wFolder}
        TXwImage=${T2wImage}
        TXwTemplate=${T2wTemplate}
        TXwTemplateBrain=${T2wTemplateBrain}
        TXwTemplate2mm=${T2wTemplate2mm}
    fi
    OutputTXwImageSTRING=""

    #done need to put in when block out code up until a script i want

    #:<<'END'
    # Perform ANTs Denoising on base images
    i=1
    for Image in ${TXwInputImages} ; do
        #@WARNING we don't use gdc nonlinearity correction, but old naming scheme is kept here. This should be changed later.
        ${RUN} ${FSLDIR}/bin/fslreorient2std $Image ${TXwFolder}/${TXwImage}${i}_gdc
        #  Running ANTS denoising on images
        ${RUN} ${ANTSPATH}${ANTSPATH:+/}DenoiseImage -d 3 -n Rician --input-image ${TXwFolder}/${TXwImage}${i}_gdc.nii.gz --output ${TXwFolder}/${TXwImage}${i}_dn.nii.gz
        OutputTXwImageSTRING="${OutputTXwImageSTRING}${TXwFolder}/${TXwImage}${i}_dn "
        i=$(($i+1))
    done

    # Average Like (Same Modality) Scans

    if [ `echo ${TXwInputImages} | wc -w` -gt 1 ] ; then
        log_Msg "Averaging ${TXw} Images"
        log_Msg "mkdir -p ${TXwFolder}/Average${TXw}Images"
        mkdir -p ${TXwFolder}/Average${TXw}Images
        log_Msg "PERFORMING SIMPLE AVERAGING"
        ${RUN} ${HCPPIPEDIR_PreFS}/AnatomicalAverage.sh -o ${TXwFolder}/${TXwImage} -s ${TXwTemplate} -m ${TemplateMask} -n -w ${TXwFolder}/Average${TXw}Images --noclean -v -b $BrainSize $OutputTXwImageSTRING
    else
        log_Msg "Not Averaging ${TXw} Images"
        log_Msg "ONLY ONE AVERAGE FOUND: COPYING"
        ${RUN} ${FSLDIR}/bin/imcp $OutputTXwImageSTRING ${TXwFolder}/${TXwImage}
    fi

    # Run ANTs Bias Field Correction on average modality
    # Reduce computation time by resampling with shrink factor 2. Output both
    # corrected version (to TXw) and optional bias field (to TXwN4BiasField).
    immv "${TXwFolder}/${TXwImage}" "${TXwFolder}/${TXwImage}_pre_n4bias"
    ${ANTSPATH}${ANTSPATH:+/}N4BiasFieldCorrection -d 3 \
        --input-image "${TXwFolder}/${TXwImage}_pre_n4bias.nii.gz" \
        --shrink-factor 2 \
        --output ["${TXwFolder}/${TXwImage}.nii.gz","${TXwFolder}/${TXwImage}N4BiasField.nii.gz"]

done # End of looping over modalities (T1w and T2w)

# ACPC align T2w image to NIH pediatric Template to create native volume space
log_Msg "Aligning ${TXw} image to Baby ${TXw}Template to create native volume space"
log_Msg "mkdir -p ${TXwFolder}/ACPCAlignment"

# Bransize for robustfov is size of brain in z-dimension (using 120mm).
mkdir -p ${T2wFolder}/ACPCAlignment
${RUN} ${acpc_align_script_T2} \
    --workingdir=${T2wFolder}/ACPCAlignment \
    --in=${T2wFolder}/${T2wImage} \
    --ref=${T2wTemplate} \
    --out=${T2wFolder}/${T2wImage}_acpc \
    --omat=${T2wFolder}/xfms/acpc.mat \
    --brainsize=${BrainSize}

mkdir -p ${T1wFolder}/ACPCAlignment
${RUN} ${acpc_align_script_T1} \
    --workingdir=${T1wFolder}/ACPCAlignment \
    --in=${T1wFolder}/${T1wImage} \
    --ref=${T1wTemplate} \
    --out=${T1wFolder}/${T1wImage}_acpc \
    --omat=${T1wFolder}/xfms/acpc.mat \
    --brainsize=${BrainSize} \
    --ref_t2=${T2wFolder}/${T2wImage}_acpc

if [ -n "${T1BrainMask}" ] ; then
    # The user has supplied a T1 brain mask. Extract the T1w brain, then use
    # the T1w mask to make the T2w mask.

    # Copy the user-supplied mask to ${T1wFolder}/${T1wImage}_brain_mask.
    imcp ${T1BrainMask} ${T1wFolder}/${T1wImage}_brain_mask
    
    # The T1w head was ACPC aligned in the loop above. Use the resulting
    # acpc.mat to align the mask.
    ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${T1wFolder}/${T1wImage}_brain_mask -r ${T1wTemplateBrain} --premat=${T1wFolder}/xfms/acpc.mat -o ${T1wFolder}/${T1wImage}_acpc_brain_mask

    # Use the ACPC aligned T1w brain mask to extract the T1w brain.
    ${FSLDIR}/bin/fslmaths ${T1wFolder}/${T1wImage}_acpc -mas ${T1wFolder}/${T1wImage}_acpc_brain_mask ${T1wFolder}/${T1wImage}_acpc_brain

    # Align the T1w to the T2w to get the matrix that will be needed to make
    # the T2w mask from the T1w mask.
    ${FSLDIR}/bin/flirt -in ${T1wFolder}/${T1wImage}_acpc -ref ${T2wFolder}/${T2wImage}_acpc -cost mutualinfo \
        -searchrx -15 15 -searchry -15 15 -searchrz -15 15 -dof 6 \
        -omat ${T1wFolder}/xfms/tmpT1w2T2w.mat

    ${FSLDIR}/bin/flirt -in ${T1wFolder}/${T1wImage}_acpc_brain_mask -interp nearestneighbour -ref ${T2wFolder}/${T2wImage}_acpc \
        -applyxfm -init ${T1wFolder}/xfms/tmpT1w2T2w.mat -out ${T2wFolder}/${T2wImage}_acpc_brain_mask

    # Use the T2w brain mask to extract the T2w brain.
    ${FSLDIR}/bin/fslmaths ${T2wFolder}/${T2wImage}_acpc -mas ${T2wFolder}/${T2wImage}_acpc_brain_mask ${T2wFolder}/${T2wImage}_acpc_brain

else
    # No mask was supplied. Extract the T2 brain and make the T2w
    # mask via ANTs-based brain extraction, then use the T2w mask
    # to make the T1w mask.

    # Brain Extraction(ANTs-based Masking)
    log_Msg "Performing Brain Extraction using ANTs-based Masking"
    log_Msg "mkdir -p ${T2wFolder}/BrainExtraction_ANTsbased"
    mkdir -p ${T2wFolder}/BrainExtraction_ANTsbased

    T2wTemplate=${T2wStudyTemplate}
    Save=$TemplateMask
    TemplateMask=${T2wStudyTemplateBrain}

    log_Msg "Now using templates:"
    log_Msg "    T2wTemplate: ${T2wTemplate}"
    log_Msg "    T2wTemplateBrain: ${T2wTemplateBrain}"
    log_Msg "    TemplateMask: ${TemplateMask}"

    # Extract brain with nonlinear registration from template.
    ${RUN} ${HCPPIPEDIR_PreFS}/BrainExtraction_ANTsbased.sh \
        --workingdir=${T2wFolder}/BrainExtraction_ANTsbased \
        --in=${T2wFolder}/${T2wImage}_acpc \
        --ref=${T2wTemplate} \
        --refmask=${TemplateMask} \
        --ref2mm=${T2wTemplate2mm} \
        --ref2mmmask=${Template2mmMask} \
        --outbrain=${T2wFolder}/${T2wImage}_acpc_brain \
        --outbrainmask=${T2wFolder}/${T2wImage}_acpc_brain_mask

    if [ -n "${Save}" ]; then TemplateMask=$Save; fi

    # initial T2w to T1w brain masking step (second in restore stage for dc corrected t2 brain mask)
    ${FSLDIR}/bin/flirt -in ${T2wFolder}/${T2wImage}_acpc -ref ${T1wFolder}/${T1wImage}_acpc -cost mutualinfo -searchrx -15 15 -searchry -15 15 -searchrz -15 15 -dof 6 -omat ${T2wFolder}/xfms/tmpT2w2T1w.mat
    ${FSLDIR}/bin/flirt -in ${T2wFolder}/${T2wImage}_acpc_brain_mask -interp nearestneighbour -ref ${T1wFolder}/${T1wImage}_acpc -applyxfm -init ${T2wFolder}/xfms/tmpT2w2T1w.mat -out ${T1wFolder}/${T1wImage}_acpc_brain_mask

    # Use the T1w brain mask to extract the T1w brain.
    ${FSLDIR}/bin/fslmaths ${T1wFolder}/${T1wImage}_acpc -mas ${T1wFolder}/${T1wImage}_acpc_brain_mask ${T1wFolder}/${T1wImage}_acpc_brain

fi

# Whether or not the user supplied a brain mask, make sure we have the
# following files:
#    ${T1wFolder}/${T1wImage}_acpc_brain
#    ${T1wFolder}/${T1wImage}_acpc_brain_mask
#    ${T2wFolder}/${T2wImage}_acpc_brain
#    ${T2wFolder}/${T2wImage}_acpc_brain_mask
#    ${T1wFolder}/xfms/acpc.mat
for FILE in ${T1wFolder}/${T1wImage}_acpc_brain.nii.gz ${T1wFolder}/${T1wImage}_acpc_brain_mask.nii.gz ${T2wFolder}/${T2wImage}_acpc_brain.nii.gz ${T2wFolder}/${T2wImage}_acpc_brain_mask.nii.gz ${T1wFolder}/xfms/acpc.mat ; do
    assert_file_exists ${FILE} ${LINENO}
done


# ------------------------------------------------------------------------------
#  T2w to T1w Registration and Optional Readout Distortion Correction
# ------------------------------------------------------------------------------

case $AvgrdcSTRING in

    ${FIELDMAP_METHOD_OPT} | ${SPIN_ECHO_METHOD_OPT} | ${GENERAL_ELECTRIC_METHOD_OPT} | ${SIEMENS_METHOD_OPT})
        if ${useT2}; then TXwFolder=${T2wFolder}; else TXwFolder=${T1wFolder}; fi
        log_Msg "Performing ${AvgrdcSTRING} Readout Distortion Correction"
        wdir=${TXwFolder}/T2wToT1wDistortionCorrectAndReg
        if [ -d ${wdir} ] ; then
            # DO NOT change the following line to "rm -r ${wdir}" because the
            # chances of something going wrong with that are much higher, and
            # rm -r always needs to be treated with the utmost caution
            rm -r ${TXwFolder}/T2wToT1wDistortionCorrectAndReg
        fi

        log_Msg "mkdir -p ${wdir}"
        mkdir -p ${wdir}

        ${RUN} ${HCPPIPEDIR_PreFS}/T2wToT1wDistortionCorrectAndReg.sh \
            --workingdir=${wdir} \
            --t1=${T1wFolder}/${T1wImage}_acpc \
            --t1brain=${T1wFolder}/${T1wImage}_acpc_brain \
            --t2=${T2wFolder}/${T2wImage}_acpc \
            --t2brain=${T2wFolder}/${T2wImage}_acpc_brain \
            --fmapmag=${MagnitudeInputName} \
            --fmapphase=${PhaseInputName} \
            --fmapgeneralelectric=${GEB0InputName} \
            --echodiff=${TE} \
            --SEPhaseNeg=${SpinEchoPhaseEncodeNegative} \
            --SEPhasePos=${SpinEchoPhaseEncodePositive} \
            --echospacing=${DwellTime} \
            --seunwarpdir=${SEUnwarpDir} \
            --t1sampspacing=${T1wSampleSpacing} \
            --t2sampspacing=${T2wSampleSpacing} \
            --unwarpdir=${UnwarpDir} \
            --ot1=${T1wFolder}/${T1wImage}_acpc_dc \
            --ot1brain=${T1wFolder}/${T1wImage}_acpc_dc_brain \
            --ot1warp=${T1wFolder}/xfms/${T1wImage}_dc \
            --ot2=${T1wFolder}/${T2wImage}_acpc_dc \
            --ot2warp=${T1wFolder}/xfms/${T2wImage}_reg_dc \
            --method=${AvgrdcSTRING} \
            --topupconfig=${TopupConfig} \
            --gdcoeffs=${GradientDistortionCoeffs} \
            --usejacobian=${UseJacobian} \
            --useT2=${useT2}

        ;;

    *)

        log_Msg "NOT PERFORMING READOUT DISTORTION CORRECTION"
        if ${useT2}; then
            wdir=${T2wFolder}/T2wToT1wReg
            if [ -e ${wdir} ] ; then
                # DO NOT change the following line to "rm -r ${wdir}" because the
                # chances of something going wrong with that are much higher, and
                # rm -r always needs to be treated with the utmost caution
                rm -r ${T2wFolder}/T2wToT1wReg
            fi

            log_Msg "mkdir -p ${wdir}"
            mkdir -p ${wdir}

            ${RUN} ${HCPPIPEDIR_PreFS}/T2wToT1wReg.sh \
                ${wdir} \
                ${T1wFolder}/${T1wImage}_acpc \
                ${T1wFolder}/${T1wImage}_acpc_brain \
                ${T2wFolder}/${T2wImage}_acpc \
                ${T2wFolder}/${T2wImage}_acpc_brain \
                ${T1wFolder}/${T1wImage}_acpc_dc \
                ${T1wFolder}/${T1wImage}_acpc_dc_brain \
                ${T1wFolder}/xfms/${T1wImage}_dc \
                ${T1wFolder}/${T2wImage}_acpc_dc \
                ${T1wFolder}/xfms/${T2wImage}_reg_dc
        else
            log_Msg "Skipping T2wToT1wReg.sh - Copying T1w_acpc to T1w_acpc_dc"
            imcp ${T1wFolder}/${T1wImage}_acpc ${T1wFolder}/${T1wImage}_acpc_dc
            imcp ${T1wFolder}/${T1wImage}_acpc_brain ${T1wFolder}/${T1wImage}_acpc_dc_brain
        fi

esac

:<<'END'
#  T2w masking is working much better...
if ${useT2}; then
    for ext in _acpc _acpc_dc; do
        fslmaths ${T1wFolder}/${T1wImage}${ext} -mas ${T1wFolder}/${T2wImage}_acpc_dc_brain ${T1wFolder}/${T1wImage}${ext}_brain
    done
fi
taking out, if want to test, use ${T2wImage}_acpc_brain
END


# ------------------------------------------------------------------------------
#  Bias Field Correction: Calculate bias field using square root of the product
#  of T1w and T2w iamges.
# ------------------------------------------------------------------------------

#@DECISION this stage is possibly unecessary in babies, need to test results with/out
log_Msg "Performing Bias Field Correction"
if $useT2; then
    if [ ! -z ${BiasFieldSmoothingSigma} ] ; then
        BiasFieldSmoothingSigma="--bfsigma=${BiasFieldSmoothingSigma}"
    fi

    log_Msg "mkdir -p ${T1wFolder}/BiasFieldCorrection_sqrtT1wXT1w"
    mkdir -p ${T1wFolder}/BiasFieldCorrection_sqrtT1wXT1w

    ${RUN} ${HCPPIPEDIR_PreFS}/BiasFieldCorrection_sqrtT1wXT1w.sh \
        --workingdir=${T1wFolder}/BiasFieldCorrection_sqrtT1wXT1w \
        --T1im=${T1wFolder}/${T1wImage}_acpc_dc \
        --T1brain=${T1wFolder}/${T1wImage}_acpc_dc_brain \
        --T2im=${T1wFolder}/${T2wImage}_acpc_dc \
        --obias=${T1wFolder}/BiasField_acpc_dc \
        --oT1im=${T1wFolder}/${T1wImage}_acpc_dc_restore \
        --oT1brain=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain \
        --oT2im=${T1wFolder}/${T2wImage}_acpc_dc_restore \
        --oT2brain=${T1wFolder}/${T2wImage}_acpc_dc_restore_brain \
        ${BiasFieldSmoothingSigma}
else
    log_Msg "useT2=false: Running FAST to do BiasFieldCorrection. Note:${T1wImage}_acpc_dc_restore is brain extracted"
    fast -b -B -o ${T1wFolder}/T1w_fast -t 1 ${T1wFolder}/T1w_acpc_dc_brain.nii.gz
    imcp ${T1wFolder}/T1w_fast_bias ${T1wFolder}/BiasField_acpc_dc
    imcp ${T1wFolder}/T1w_fast_restore ${T1wFolder}/${T1wImage}_acpc_dc_restore_brain
    #imcp ${T1wFolder}/T1w_fast_restore ${T1wFolder}/${T1wImage}_acpc_dc_restore #FAST does not output a non-brain extracted image, so use the brain extracted as the full image AP 20162111
    fslmaths ${T1wFolder}/T1w_acpc_dc -div ${T1wFolder}/BiasField_acpc_dc ${T1wFolder}/T1w_acpc_dc_restore  # apply bias field to head
fi

# With or without T2, When we get here, we must have the 2 files:
# ${T1wFolder}/${T1wImage}_acpc_dc_restore.nii. and
# ${T1wFolder}/${T1wImage}_acpc_dc_restore_brain.nii.
# If not, there has been an error. Die NOW, so we don't have to debug later.
if ! [ -e ${T1wFolder}/${T1wImage}_acpc_dc_restore.nii.gz ] && ! [ -e ${T1wFolder}/${T1wImage}_acpc_dc_restore.nii ] ; then
    log_Error_Abort "After BiasFieldCorrection, ${T1wFolder}/${T1wImage}_acpc_dc_restore does not exist."
elif ! [ -e ${T1wFolder}/${T1wImage}_acpc_dc_restore_brain.nii.gz ] && ! [ -e ${T1wFolder}/${T1wImage}_acpc_dc_restore_brain.nii ] ; then
    log_Error_Abort "After BiasFieldCorrection, ${T1wFolder}/${T1wImage}_acpc_dc_restore_brain does not exist."
fi

fslmaths ${T1wFolder}/${T2wImage}_acpc_dc_restore_brain -bin ${T1wFolder}/${T2wImage}_acpc_dc_restore_brain_mask

# If Atropos parameters are not specified, do this the way we've done it in the past.
if [ -z "${AtroposLabelMin}" ] ; then AtroposLabelMin=4; fi
if [ -z "${AtroposLabelMax}" ] ; then AtroposLabelMax=5; fi


# ANTs Atropos - refine mask step.
# There are currently 3 options for atropos_refine_mask.py:
# 1. Run and use its mask to refine the input mask.
# 2. Run and use its mask to replace the input mask.
# 3. Skip it.
# Default is to refine the input mask.

maskflag=""
if [ -z "${AtroposMaskMethod}" ] ; then
    AtroposMaskMethod="REFINE"
elif [[ "CREATE" == "${AtroposMaskMethod}" ]] ; then
    maskflag="--replacemask"
fi

if [[ "NONE" != "${AtroposMaskMethod}" ]] ; then
    mkdir -p ${T1wFolder}/Atropos
    ${RUN} ${HCPPIPEDIR_PreFS}/atropos_refine_mask.py \
        --wd=${T1wFolder}/Atropos \
        --t1w=${T1wFolder}/${T1wImage}_acpc_dc_restore.nii.gz \
        --t2w=${T1wFolder}/${T2wImage}_acpc_dc_restore.nii.gz \
        --mask=${T1wFolder}/${T2wImage}_acpc_dc_restore_brain_mask.nii.gz \
        --omask=${T1wFolder}/${T1wImage}_acpc_brain_mask.nii.gz \
        --ot1w=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain.nii.gz \
        --ot2w=${T1wFolder}/${T2wImage}_acpc_dc_restore_brain.nii.gz \
        --thr=${AtroposLabelMin} \
        --uthr=${AtroposLabelMax} \
        ${maskflag}
fi

# ------------------------------------------------------------------------------
#  Atlas Registration to MNI152: FLIRT + FNIRT
#  Also applies registration to T1w and T2w images
# ------------------------------------------------------------------------------

log_Msg "Performing Atlas Registration to MNI152"

${RUN} ${HCPPIPEDIR_PreFS}/FakeAtlasRegistration.sh \
    --workingdir=${AtlasSpaceFolder} \
    --t1=${T1wFolder}/${T1wImage}_acpc_dc \
    --t1rest=${T1wFolder}/${T1wImage}_acpc_dc_restore \
    --t1restbrain=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain \
    --t1brainmask=${T1wFolder}/${T1wImage}_acpc_brain_mask \
    --t2=${T1wFolder}/${T2wImage}_acpc_dc \
    --t2rest=${T1wFolder}/${T2wImage}_acpc_dc_restore \
    --t2restbrain=${T1wFolder}/${T2wImage}_acpc_dc_restore_brain \
    --ref=${T1wTemplate} \
    --refbrain=${T1wTemplateBrain} \
    --refmask=${TemplateMask} \
    --ref2mm=${T1wTemplate2mm} \
    --ref2mmmask=${Template2mmMask} \
    --owarp=${AtlasSpaceFolder}/xfms/acpc_dc2standard.nii.gz \
    --oinvwarp=${AtlasSpaceFolder}/xfms/standard2acpc_dc.nii.gz \
    --ot1=${AtlasSpaceFolder}/${T1wImage} \
    --ot1rest=${AtlasSpaceFolder}/${T1wImage}_restore \
    --ot1restbrain=${AtlasSpaceFolder}/${T1wImage}_restore_brain \
    --ot2=${AtlasSpaceFolder}/${T2wImage} \
    --ot2rest=${AtlasSpaceFolder}/${T2wImage}_restore \
    --ot2restbrain=${AtlasSpaceFolder}/${T2wImage}_restore_brain \
    --fnirtconfig=${FNIRTConfig} \
    --useT2=${useT2}

# Call JLF.
# If T2W JLFMethod was requested and all other conditions are right, use it.
# Default is the T1W method.
assert_file_exists ${T1wFolder}/${T1wImage}_acpc_dc_restore_brain.nii.gz ${LINENO}

if [ -z "${JLFMethod}" ] ; then
    JLFMethod="T1W"
fi
if [[ "T2W" == "${JLFMethod}" ]] && $useT2 ; then
    run_JLF_T2W
elif [[ "T1W_ORIG" == "${JLFMethod}" ]] ; then
    run_JLF_orig
else
    # Default:
    run_JLF_T1W
fi

if ! [ -z "${ASegDir}" ] ; then
    if [ -d ${ASegDir} ] && [ -e ${ASegDir}/aseg_acpc.nii.gz ] ; then
        # We also have a supplied aseg file for this subject.
        echo Using supplied aseg file: ${ASegDir}/aseg_acpc.nii.gz
        # Rename (but keep) the one we just generated....
        mv ${T1wFolder}/aseg_acpc.nii.gz ${T1wFolder}/aseg_acpc_dcan-derived.nii.gz
        # Copy the one that was supplied; it will be used from here on....
        scp -p ${ASegDir}/aseg_acpc.nii.gz ${T1wFolder}/aseg_acpc.nii.gz
    else
        echo Using aseg file generated with JLF.
    fi
fi

log_Msg "Completed"
