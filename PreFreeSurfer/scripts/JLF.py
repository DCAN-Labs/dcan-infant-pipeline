#! /usr/bin/env python3
# standard lib

'''

Joint label fusion works by first non-linearly registering a list of atlas brains that have segmentations to a subject T1w or T2w as specified.
The transform is then applied to the atlas segmentations, which all "vote" on the intensity value of each matching voxel of the subject brain,
resulting in a final subject brain segmentation.

Note: I broke the rules of nipype! At the end of the function that does the actual work, I removed the directory of > 200 files left by the
      processing. According to Luci, 'remove_unnecessary_outputs' is set to true by default*, but that was not cleaning up the files. The
      reason you want to know this is, the directory removed is the workflow, so, if you try to plug this file into a nipypes project and
      the next stop in the workflow expects output from this one I don't think that's going to work. To fix that, see the end of the
      register function after the comment "Cleanup working directory".  -- KJS 20191126.

      *(see https://nipype.readthedocs.io/en/0.11.0/users/config_file.html)
'''

import argparse
import os
import shutil

# external libs
import nipype.pipeline.engine as pe
from nipype.interfaces import ants, utility


def main():
    parser = generate_parser()
    args = parser.parse_args()

    Txw_image = args.Txw_image
    subject_image = args.subject_image
    jlf_folder = args.joint_fusion_folder
    output_dir = args.output_dir
    njobs = args.njobs

    print('Args to JLF_T2w.py: %s' % args )

    atlas_images = []
    atlas_segmentations = []

    for root, directories, files in os.walk(jlf_folder):
        if Txw_image == 1:
            for file in files:
                if 'T1w_brain.nii.gz' in file:
                    atlas_images.append(os.path.join(root, file))

        else:
            for file in files:
                if 'T2w_brain.nii.gz' in file:
                    atlas_images.append(os.path.join(root, file))

    for root, directories, files in os.walk(jlf_folder):
        for file in files:
            if 'Segmentation.nii.gz' in file:
                atlas_segmentations.append(os.path.join(root, file))

    atlas_images = sorted(atlas_images)
    atlas_segmentations = sorted(atlas_segmentations)

    warped_dir = output_dir

    register(warped_dir, subject_image, atlas_images, atlas_segmentations, n_jobs=njobs)


def generate_parser():
    parser = argparse.ArgumentParser(description='Nipype ANTS jont label fusion script')
    parser.add_argument('--Txw_image', dest='Txw_image', type=int, help='specify numbers 1 or 2 if you want to use T1w or T2w for segmentation')
    parser.add_argument('--target', dest='subject_image', help='subject T2w')
    parser.add_argument('--atlas-dir', dest='joint_fusion_folder', help='path to joint label fusion atlas directory')
    parser.add_argument('--output-dir',dest='output_dir', help='path to output for jlf')
    parser.add_argument('--njobs', default=1, type=int, help='number of cpus to utilize')
    return parser


def register(warped_dir, subject_T2w, atlas_images, atlas_segmentations, n_jobs):
    sub_Tw2_list = []
    sub_Tw2_list.append(subject_T2w)

    input_spec = pe.Node(
        utility.IdentityInterface(
            fields=['subject_image', 'sub_image_list', 'atlas_image', 'atlas_segmentation']),
        iterables=[('atlas_image', atlas_images), ('atlas_segmentation', atlas_segmentations)],
        synchronize=True,
        name='input_spec'
    )
    # set input_spec
    input_spec.inputs.subject_image = subject_T2w
    input_spec.inputs.sub_image_list = sub_Tw2_list  # need to do this bc JLF requires target image to be a list

    '''
    CC[x, x, 1, 8]: [fixed, moving, weight, radius]
    -t SyN[0.25]: Syn transform with a gradient step of 0.25
    -r Gauss[3, 0]: sigma 0
    -I 30x50x20
    use - Histogram - Matching
    number - of - affine - iterations 10000x10000x10000x10000: 4 level image pyramid with 10000 iterations at each level
    MI - option 32x16000: 32 bins, 16000 samples
    '''

    reg = pe.Node(
        ants.Registration(
            dimension=3,
            output_transform_prefix="output_",
            collapse_output_transforms = False,
            # interpolation='BSpline',
            transforms=['Affine', 'SyN'],
            transform_parameters=[(2.0,), (0.25,)],  # default values syn
            shrink_factors=[[8, 4, 2, 1], [4, 2, 1]],
            smoothing_sigmas=[[3, 2, 1, 0], [2, 1, 0]],  # None for Syn?
            sigma_units=['vox'] * 2,
            sampling_percentage=[0.05, None],  # just use default?
            sampling_strategy=['Random', 'None'],
            number_of_iterations=[[10000, 10000, 10000, 10000], [30, 50, 20]],
            metric=['MI', 'CC'],
            metric_weight=[1, 1],
            radius_or_number_of_bins=[(32), (8)],
            # winsorize_lower_quantile=0.05,
            # winsorize_upper_quantile=0.95,
            verbose=True,
            use_histogram_matching=[True, True]
        ),
        name='calc_registration')

    applytransforms_atlas = pe.Node(
        ants.ApplyTransforms(
            interpolation='BSpline',
            dimension=3,
        ),
        name='apply_warpfield_atlas')

    applytransforms_segs = pe.Node(
        ants.ApplyTransforms(
            interpolation='NearestNeighbor',
            dimension=3
        ),
        name='apply_warpfield_segs')

    jointlabelfusion = pe.JoinNode(
        ants.AntsJointFusion(
            dimension=3,
            alpha=0.1,
            beta=2.0,
            patch_radius=[2, 2, 2],
            search_radius=[3, 3, 3],
            out_label_fusion='aseg_acpc.nii.gz',
        ),
        joinsource='input_spec',
        joinfield=['atlas_image', 'atlas_segmentation_image'],
        name='joint_label_fusion'
    )

    wf = pe.Workflow(name='wf', base_dir=warped_dir)

    wf.connect(input_spec, 'subject_image', reg, 'fixed_image')
    wf.connect(input_spec, 'atlas_image', reg, 'moving_image')

    wf.connect(reg, 'forward_transforms', applytransforms_atlas, 'transforms')
    wf.connect(input_spec, 'atlas_image', applytransforms_atlas, 'input_image')
    wf.connect(input_spec, 'subject_image', applytransforms_atlas, 'reference_image')

    wf.connect(reg, 'forward_transforms', applytransforms_segs, 'transforms')
    wf.connect(input_spec, 'atlas_segmentation', applytransforms_segs, 'input_image')
    wf.connect(input_spec, 'subject_image', applytransforms_segs, 'reference_image')

    wf.connect(input_spec, 'sub_image_list', jointlabelfusion, 'target_image')
    wf.connect(applytransforms_atlas, 'output_image', jointlabelfusion, 'atlas_image')
    wf.connect(applytransforms_segs, 'output_image', jointlabelfusion, 'atlas_segmentation_image')

    wf.config['execution']['parameterize_dirs'] = False

    wf.write_graph()
    output = wf.run(plugin='MultiProc', plugin_args={'n_procs': n_jobs})

    shutil.move(os.path.join(warped_dir, 'wf', 'joint_label_fusion', 'aseg_acpc.nii.gz'), os.path.join(warped_dir, 'aseg_acpc.nii.gz'))

    # Cleanup working directory.
    shutil.rmtree(os.path.join(warped_dir, 'wf'))

if __name__ == '__main__':
    main()
