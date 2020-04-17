#!/bin/bash
#PBS -l nodes=1:ppn=1,vmem=8gb
#PBS -l walltime=1:00:00
#PBS -N MID_Task_Preprocessin

set -e
set -x

# This is the base preprocessing script to preprocess fmri data

############## Load File names and Params from JSON #############
export fmri=`jq -r '.fmri' config.json`
export anat=`jq -r '.anat' config.json`
export afnidir=`$SERVICE_DIR/jq -r '.afnidir' config.json`

# User selected parameters
export TEMPLATE=`jq -r '.template' config.json`
export lead_in_out=`jq -r '.lead_in_out' config.json`
export TR=`jq -r '.tr' config.json`
export SLICE_timing=`jq -r '.slice_timing' config.json`
export MC_startframe=`jq -r '.motion_comp_startframe' config.json`
export MC_method=`jq -r '.motion_comp_method' config.json`
export MC_method_npass=`jq -r '.motion_comp_npass' config.json`
export MC_remove_frames=`jq -r '.motion_comp_remove_frames' config.json`
export spatial_smoothing=`jq -r '.spatial_smoothing' config.json`

### rename anatomical scan ###
mkdir ./anat
3dcopy anat.nii.gz ./anat/anat

#tlrc
@auto_tlrc -warp_orig_vol -suffix NONE -base 'afnidir/PATH/{$TEMPLATE}' -input anat+orig.

### convert the files to AFNI, cut off leadin/leadout ###
3dTcat -overwrite -prefix fmri_epi fmri.nii.gz[$lead_in_out{1}..$lead_in_out{2}]

### refitting + slice time correction ###
3drefit -TR $TR fmri_epi+orig.

3dTshift -slice $SLICE_timing -tpattern altplus -overwrite -prefix fmri fmri_epi+orig.

### correct for motion ###
3dvolreg \
         -$Fourier \
         -$twopass \
         -overwrite \
         -prefix fmri_motion_comp \ 
         -base $MC_startframe \
         -dfile motioncompestimates.1D fmri+orig

### Indeally here we should change motioncompestimates.1D to => motioncompestimates.JSON/.tsv

#### censor motion ####
1d_tool.py -overwrite -infile  motioncompestimates.1D[1..6] \
                          -set_nruns 1 \
	                        -show_censor_count \
	                        -censor_motion $MC_remove_frames fmri_motion_comp \
	                        -censor_prev_TR

#### smooth spatially ####
3dmerge -overwrite -prefix fmri_mc_smooth -1blur_fwhm $spatial_smoothing -doall ****FIX FIX"$fname"_m+orig***

FIX all below

#### normalize (calculate pct signal change / average) and filter ###
3dTstat -overwrite -prefix "$fname"_ave "$fname"'_mb+orig[0..$]'
3drefit -abuc "$fname"_ave+orig
3dcalc -datum float -a "$fname"'_mb+orig[0..$]' -b "$fname"_ave+orig -expr "((a-b)/b)*100" -overwrite -prefix "$fname"_mbn

#filter slow drift > 90 s
3dFourier  -prefix "$fname"_mbnf -highpass .011 "$fname"_mbn+orig

#### set the epi parent to the auto-warped anat ####
3drefit -apar anat+orig "$fname"_mbnf+orig

end
