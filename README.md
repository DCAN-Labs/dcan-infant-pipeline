# The DCAN Labs Infant Processing Pipeline

*See full description of pipeline on the [DCAN Labs readthedocs](https://dcanlab.readthedocs.io/en/stable/) under [Infant Pipeline Documentation](https://dcanlab.readthedocs.io/en/stable/manualpro/infant/pipeline/)*

This fMRI minimal preprocessing pipeline is based on Washington University's HCP
Pipeline. Many changes were made to accomodate the differences in the
developing brain of infants. Notably:

- Skull Stripping:
-- This pipeline utilizes ANTs SyN registration.
-- This pipeline requires a T2w for skull stripping because the intensity of the
CSF is better detected in T2w images.
- Segmentation: The infant pipeline utilizes ANTs JointFusion. This can be
  perfomed using either the T1w image or the T2w image, depending on the
quality. (Default is to use T1w.)
- Surface Reconstruction: These steps in FreeSurfer have been modified:
    * No hires.
    * The aseg is generated from JLF.
    * Adjust class means of tissue to fit T1w contrasts.

fMRI -> anatomical registration - no boundary based registration, use T2w to
align.

Running PreFreeSurfer, FreeSurfer, and PostFreeSurfer stages will preprocess
anatomical images. Following those with fMRIVolume and fMRISurface will
preprocess functional images.

It is recommended to use the infant-abcd-bids-pipeline BIDS App (whose docker
image is available on DockerHub) to run the pipeline as it simplifies the
interface by providing defaults for most options.

The application can also run dcan-bold-preprocessing, executive summary, custom
clean, and file-mapper. The stages are optional and can be controlled through
that application's interface. Running the dcan-bold-preprocessing stage performs
analysis and creates time series. The executive summary stage creates an HTML
page (whose content will vary depending on the pipeline stages run) to show the
primary outputs from the pipeline. Providing a Custom Clean json (via the
option) will result in the pipeline running a custom-clean stage to remove many
intermediate files generated during the processing. Providing a File Mapper json
will cause pipeline to use file-mapper, in copy mode, to create BIDS
derivatives.

If you still want to run these scripts without the application, the
Examples/Scripts directory contains the basic individual building blocks of the
pipeline (and some extra).

## Please cite these papers for use of this pipeline:

Autio, Joonas A, Glasser, Matthew F, Ose, Takayuki, Donahue, Chad J, Bastiani, Matteo, Ohno, Masahiro, Kawabata, Yoshihiko, Urushibata, Yuta, Murata, Katsutoshi, Nishigori, Kantaro, Yamaguchi, Masataka, Hori, Yuki, Yoshida, Atsushi, Go, Yasuhiro, Coalson, Timothy S, Jbabdi, Saad, Sotiropoulos, Stamatios N, Smith, Stephen, Van Essen, David C, Hayashi, Takuya. (2019). Towards HCP-Style Macaque Connectomes: 24-Channel 3T Multi-Array Coil, MRI Sequences and Preprocessing. BioRxiv, 602979. https://doi.org/10.1101/602979

Donahue, Chad J, Sotiropoulos, Stamatios N, Jbabdi, Saad, Hernandez-Fernandez, Moises, Behrens, Timothy E, Dyrby, Tim B, Coalson, Timothy, Kennedy, Henry, Knoblauch, Kenneth, Van Essen, David C, Glasser, Matthew F. (2016). Using Diffusion Tractography to Predict Cortical Connection Strength and Distance: A Quantitative Comparison with Tracers in the Monkey. The Journal of Neuroscience, 36(25), 6758 LP – 6770. https://doi.org/10.1523/JNEUROSCI.0493-16.2016

Glasser, Matthew F, Sotiropoulos, Stamatios N, Wilson, J Anthony, Coalson, Timothy S, Fischl, Bruce, Andersson, Jesper L, Xu, Junqian, Jbabdi, Saad, Webster, Matthew, Polimeni, Jonathan R, Van Essen, David C, Jenkinson, Mark. (2013). The minimal preprocessing pipelines for the Human Connectome Project. NeuroImage, 80, 105–124. https://doi.org/10.1016/j.neuroimage.2013.04.127

## Links
[ANTs](http://stnava.github.io/ANTs)

[DiffeomorphicRegistration](https://www.ncbi.nlm.nih.gov/pubmed/17659998)

[JointLabelFusion](http://www.ncbi.nlm.nih.gov/pubmed/22732662)

[HCP](http://www.humanconnectome.org)

[HCPGit](https://github.com/Washington-University/Pipelines)

[GlasserEtAl](http://www.ncbi.nlm.nih.gov/pubmed/23668970)

