# The DCAN Labs Infant Processing Pipeline
This fMRI minimal preprocessing pipeline is based on Washington University's HCP Pipeline. Many changes were made to accomodate the start differences in the developing brain of infants. Notably:

- Skull Stripping: utilizes ANTs SyN registration.
- Segmentation: utilizes ANTs JointFusion.
- Surface Reconstruction: modified steps in FreeSurfer:
    * No hires.
    * The aseg is generated from JLF.
    * Adjust class means of tissue to fit T1w contrasts.

fMRI -> anatomical registration - no boundary based registration, use T2w to align.

Running PreFreeSurfer, FreeSurfer, and PostFreeSurfer stages will preprocess anatomical images. Following those with fMRIVolume and fMRISurface will complete the pipeline by preprocessing functional images. Knowing the inputs to each script can be difficult to keep track of and will not be documented here.

It is recommended to use the infant-abcd-bids-pipeline BIDS App (whose docker images is available on DockerHub) to run the pipeline as it simplifies the interface by providing defaults for most options. The application can also run dcan-bold-preprocessing, executive summary, and custom clean. The stages are optional and can be controlled through that application's interface.


Please cite these papers for use of this pipeline:

Autio, Joonas A, Glasser, Matthew F, Ose, Takayuki, Donahue, Chad J, Bastiani, Matteo, Ohno, Masahiro, Kawabata, Yoshihiko, Urushibata, Yuta, Murata, Katsutoshi, Nishigori, Kantaro, Yamaguchi, Masataka, Hori, Yuki, Yoshida, Atsushi, Go, Yasuhiro, Coalson, Timothy S, Jbabdi, Saad, Sotiropoulos, Stamatios N, Smith, Stephen, Van Essen, David C, Hayashi, Takuya. (2019). Towards HCP-Style Macaque Connectomes: 24-Channel 3T Multi-Array Coil, MRI Sequences and Preprocessing. BioRxiv, 602979. https://doi.org/10.1101/602979

Donahue, Chad J, Sotiropoulos, Stamatios N, Jbabdi, Saad, Hernandez-Fernandez, Moises, Behrens, Timothy E, Dyrby, Tim B, Coalson, Timothy, Kennedy, Henry, Knoblauch, Kenneth, Van Essen, David C, Glasser, Matthew F. (2016). Using Diffusion Tractography to Predict Cortical Connection Strength and Distance: A Quantitative Comparison with Tracers in the Monkey. The Journal of Neuroscience, 36(25), 6758 LP – 6770. https://doi.org/10.1523/JNEUROSCI.0493-16.2016

Glasser, Matthew F, Sotiropoulos, Stamatios N, Wilson, J Anthony, Coalson, Timothy S, Fischl, Bruce, Andersson, Jesper L, Xu, Junqian, Jbabdi, Saad, Webster, Matthew, Polimeni, Jonathan R, Van Essen, David C, Jenkinson, Mark. (2013). The minimal preprocessing pipelines for the Human Connectome Project. NeuroImage, 80, 105–124. https://doi.org/10.1016/j.neuroimage.2013.04.127

[ANTs](http://stnava.github.io/ANTs)
[DiffeomorphicRegistration](https://www.ncbi.nlm.nih.gov/pubmed/17659998)
[JointLabelFusion](http://www.ncbi.nlm.nih.gov/pubmed/22732662)

[HCP](http://www.humanconnectome.org)
[HCPGit](https://github.com/Washington-University/Pipelines)
[GlasserEtAl](http://www.ncbi.nlm.nih.gov/pubmed/23668970)

