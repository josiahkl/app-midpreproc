#! /bin/bash
# This is the base preprocessing script to preprocess fmri data

############## User Params #############

sub='NDARINVB72KCUK5'
fname='abcdmid'

cp $sub'_t1.nii' anat.nii
cp $sub'_midfmri.nii' $fname'.nii' 

### rename anatomical scan ###
3dcopy anat.nii.gz anat

#tlrc
@auto_tlrc -warp_orig_vol -suffix NONE -base '~/fmri/abcdmid/masks/TT_N27+tlrc' -input anat+orig.

### convert the files to AFNI, cut off leadin/leadout ###
3dTcat -overwrite -prefix "$fname"_epi "$fname"'.nii[6..$]'

### refitting + slice time correction ###
3drefit -TR 2.0 "$fname"_epi+orig.

3dTshift -slice 0 -tpattern altplus -overwrite -prefix "$fname" "$fname"_epi+orig.

### correct for motion ###
3dvolreg -Fourier -twopass -overwrite -prefix "$fname"_m -base 3 -dfile 3dmotion"$fname".1D "$fname"+orig

#### censor motion ####
# 1d_tool.py -overwrite -infile  '3dmotion'"$fname"".1D[1..6]" -set_nruns 1 \
#	                        -show_censor_count \
#	                        -censor_motion .25 "$fname" \
#	                        -censor_prev_TR

#### smooth spatially ####
3dmerge -overwrite -prefix "$fname"_mb -1blur_fwhm 4 -doall "$fname"_m+orig

#### normalize (calculate pct signal change / average) and filter ###
3dTstat -overwrite -prefix "$fname"_ave "$fname"'_mb+orig[0..$]'
3drefit -abuc "$fname"_ave+orig
3dcalc -datum float -a "$fname"'_mb+orig[0..$]' -b "$fname"_ave+orig -expr "((a-b)/b)*100" -overwrite -prefix "$fname"_mbn

#filter slow drift > 90 s
3dFourier  -prefix "$fname"_mbnf -highpass .011 "$fname"_mbn+orig

#### set the epi parent to the auto-warped anat ####
3drefit -apar anat+orig "$fname"_mbnf+orig

end
