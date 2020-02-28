#!/bin/bash
# args
if [ $# -lt 3 ]; then
	echo -e "Usage: `basename $0` <WORKING DIRECTORY> <T1w_Image> <ASEG> [OUTPUT]"
	exit 1
fi
SOURCE_DIR=$(readlink -f ${BASH_SOURCE%/*})
WD="$1" # working directory
T1w="$2" # T1w
ASEG="$3"
OUTPUT="$4"
cd "$WD"
${SOURCE_DIR}/make_WMGMCSF_masks.sh "$T1w" "$ASEG"
${SOURCE_DIR}/Change2AdultIntensity.bash $(remove_ext "$T1w") $(remove_ext "$ASEG") ${HCPPIPEDIR_Templates}/means_RB_all
cp $(remove_ext "$T1w")_AdultInt.nii.gz "$OUTPUT"
