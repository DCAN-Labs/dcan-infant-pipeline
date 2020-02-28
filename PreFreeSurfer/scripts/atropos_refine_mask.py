#!/usr/bin/env python
import argparse
import os
import subprocess


def _cli():
    parser = generate_parser()

    args = parser.parse_args()

    kwargs = _args2spec(args)

    return interface(**kwargs)


def _args2spec(args):
    return vars(args)


def generate_parser(parser=None):
    if not parser:
        parser = argparse.ArgumentParser('atropos_refine_mask',
                              description="""refines a mask by using ANTs
                                          Atropos and taking the intersect
                                          of result and input mask.""")
    parser.add_argument('--wd', required=True,
                        help='working directory')
    parser.add_argument('--t1w', required=True,
                        help='input T1-weighted nifti path.')
    parser.add_argument('--t2w', required=True,
                        help='input T2-weighted nifti path.')
    parser.add_argument('--ot1w', required=True,
                        help='output T1-weighted brain (optional)')
    parser.add_argument('--ot2w', required=True,
                        help='output T2-weighted brain (optional)')
    parser.add_argument('--mask', required=True,
                        help='input brain mask or aseg nifti path.')
    parser.add_argument('--omask', required=True,
                        help='output refined brain mask or aseg.')
    parser.add_argument('--thr', required=False, default=4,
                        help='lower limit for lables.')
    parser.add_argument('--uthr', required=False, default=5,
                        help='upper limit for lables.')
    parser.add_argument('--replacemask', dest='replacemask', action='store_true',
                        help='replace input mask with mask generated here.')

    return parser


def interface(**kwargs):
    step_files = {}
    step_files['fg'] = '{wd}/foreground.nii.gz'.format(**kwargs)
    step_files['lab'] = '{wd}/atropos_labels.nii.gz'.format(**kwargs)
    step_files['amask'] = '{wd}/atropos_mask.nii.gz'.format(**kwargs)
    kwargs.update(step_files)
    print(kwargs)

    fg_cmd = '{ANTSPATH}/ThresholdImage 3 {t2w} {fg} Otsu 2'
    dil_cmd = '{FSLDIR}/bin/fslmaths {fg} -dilM -dilM -bin {fg}'
    atropos_cmd = '{ANTSPATH}/Atropos -a {t2w} -a {t1w} -m -x {fg} -i Otsu[5] -m -k Gaussian -o {lab}'

    # image math operations
    cls_cmd = '{FSLDIR}/bin/fslmaths {lab} -thr {thr} -uthr {uthr} -bin -fillh {amask}'
    lgcomp_cmd = '{ANTSPATH}/ImageMath 3 {amask} GetLargestComponent {amask}'
    fill_cmd = '{FSLDIR}/bin/fslmaths {amask} -dilM -dilM -ero -ero {amask}'

    # image math operations to fully fill the mask made by atropos
    # Dilate mask using kernel size 6
    dil2_cmd = '{FSLDIR}/bin/fslmaths {amask} -kernel box 6 -dilM {amask}'
    # Fill holes
    fillh_cmd = '{FSLDIR}/bin/fslmaths {amask} -fillh {amask}'
    # Erode the mask again using kernel size 6
    ero_cmd = '{FSLDIR}/bin/fslmaths {amask} -kernel box 6 -ero {amask}'


    # apply masks
    replacemask='{replacemask}'.format(**kwargs)
    if replacemask:
        # When kids are a little bit older, the mask made by atropos is really
        # preferred over a refinement of the mask that we started with.
        mask_cmd = 'imcp {amask} {omask}'
    else:
        mask_cmd = '{FSLDIR}/bin/fslmaths {mask} -mas {amask} {omask}'

    t1mask_cmd = '{FSLDIR}/bin/fslmaths {t1w} -mas {omask} {ot1w}'
    t2mask_cmd = '{FSLDIR}/bin/fslmaths {t2w} -mas {omask} {ot2w}'

    cmd_list = [fg_cmd, dil_cmd, atropos_cmd, cls_cmd, lgcomp_cmd, fill_cmd, dil2_cmd, fillh_cmd, ero_cmd, mask_cmd,
                t1mask_cmd, t2mask_cmd]
    kwargs.update(os.environ)
    for cmd in cmd_list:
        cmd = cmd.format(**kwargs)
        print(cmd)
        subprocess.call(cmd, shell=True)


if __name__ == '__main__':
    _cli()

