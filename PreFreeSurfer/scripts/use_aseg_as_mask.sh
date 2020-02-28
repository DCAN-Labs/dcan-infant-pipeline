##ADDITIONAL MASKING STEP - USE ASEG AS A MASK FOR ELABE - EMMA 11.21

fslmaths ${T1wFolder}/aseg_acpc.nii.gz -fillh -dilM -dilM -ero -ero ${T1wFolder}/aseg_refined_brainmask.nii.gz

fslmaths ${TXwFolder}/${TXwImage}_acpc_brain.nii.gz -mas ${T1wFolder}/aseg_refined_brainmask.nii.gz ${TXwFolder}/${TXwImage}_acpc_brain.nii.gz #does not work for T1, works for T2

fslmaths ${TXwFolder}/${TXwImage}_acpc_brain_mask.nii.gz -mas ${T1wFolder}/aseg_refined_brainmask.nii.gz ${TXwFolder}/${TXwImage}_acpc_brain_mask.nii.gz #does not work for T1, works for T2,

fslmaths ${T1wFolder}/${T1wImage}_acpc_dc_brain.nii.gz -mas ${T1wFolder}/aseg_refined_brainmask.nii.gz ${T1wFolder}/${T1wImage}_acpc_dc_brain.nii.gz #works

fslmaths ${T1wFolder}/${T2wImage}_acpc_dc_restore_brain_mask.nii.gz -mas ${T1wFolder}/aseg_refined_brainmask.nii.gz ${T1wFolder}/${T2wImage}_acpc_dc_restore_brain_mask.nii.gz #works

fslmaths ${T1wFolder}/${T1wImage}_acpc_dc_restore_brain.nii.gz -mas ${T1wFolder}/aseg_refined_brainmask.nii.gz ${T1wFolder}/${T1wImage}_acpc_dc_restore_brain.nii.gz #doesn't work

fslmaths ${T1wFolder}/${T2wImage}_acpc_dc_restore_brain.nii.gz -mas ${T1wFolder}/aseg_refined_brainmask.nii.gz ${T1wFolder}/${T2wImage}_acpc_dc_restore_brain.nii.gz #doesn't work


