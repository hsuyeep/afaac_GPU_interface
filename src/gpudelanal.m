% Script to analyze the inter station delay compensation as applied by the GPU
% correlator. This data was recorded on 14Oct14 during waveform generator 
% tests with Daniel, in LBA_OUTER mode. The raw data are available in 
% fs5:/var/scratch2/romein/AARTFAAC-RealData-14-10-14-13:45:28.
% Raw data has been checked and found to have NO missing data.

fprintf (2, '### NOTE: Subband currently hardcoded to 295!');
[cal_x, cal_y] = readafaaccaltab (295); 
load 'srclist3CR.mat';

% Raw data correlated with delay compensation turned off.
flagant = [65:80, 137, 199];
load 'sb0_14Oct14_134528_lba_outer_nodel.vis_1413294328-1413294330.mat'
[acm_0c0d0f, tobs_mjd, fobs, map_0c0d0f, l] = gengpuimg (acm, tobs, 60000000, [1:63], [], [], [], 1, 0);
[acm_1c0d0f, tobs_mjd, fobs, map_1c0d0f, l] = gengpuimg (acm, tobs, 60000000, [1:63], [], cal_x, cal_y, 1, 0);
[acm_1c0d1f, tobs_mjd, fobs, map_1c0d1f, l] = gengpuimg (acm, tobs, 60000000, [1:63], flagant, cal_x, cal_y, 1, 0);


overplt = 0;

% Apply delays and image
[acm_1cppd1f, phasor] =  applystationdelays (squeeze(acm_1c0d1f(1,:,:,1)), fobs, 1, flagant); % Pos del
[acm_1cpnd1f, phasor] =  applystationdelays (squeeze(acm_1c0d1f(1,:,:,1)), fobs, 0, flagant); % Neg del
load ('poslocal_outer.mat', 'poslocal');
% map = zeros (nrec, length(l), length(l), npol);
uloc = meshgrid (poslocal(:,1)) - ... 
		meshgrid (poslocal (:,1)).';
vloc = meshgrid (poslocal(:,2)) - ... 
		meshgrid (poslocal (:,2)).';
[uloc_flag, vloc_flag] = gen_flagged_uvloc (uloc, vloc, flagant); 

gparm.type = 'pillbox';
gparm.lim = 0;
gparm.duv = 0.5; 
gparm.Nuv = 500;
gparm.uvpad = 512; 
gparm.fft = 1;
[map_nodel, calmap, calvis, l, m] = ... 
    fft_imager_sjw_radec (squeeze(acm_1c0d1f(1,:,:,1)), uloc_flag(:), vloc_flag(:), ... 
						gparm, [], [], tobs_mjd(1), fobs, 0);
[map_posdel, calmap, calvis, l, m] = ... 
    fft_imager_sjw_radec (acm_1cppd1f, uloc_flag(:), vloc_flag(:), ... 
						gparm, [], [], tobs_mjd(1), fobs, 0);
[map_negdel, calmap, calvis, l, m] = ... 
    fft_imager_sjw_radec (acm_1cpnd1f, uloc_flag(:), vloc_flag(:), ... 
						gparm, [], [], tobs_mjd(1), fobs, 0);
figure;
subplot (131);
imagesc (-l, -l, abs(map_nodel)); colorbar;
title ('Station calib, flag, nodelay');
if overplt == 1
	overplotcat(tobs_mjd(1), srclist3CR, 500, gcf, 1); 
end;

subplot (132);
imagesc (-l, -l, abs(map_posdel)); colorbar;
title ('Station calib, flag, with pos delay');
if overplt == 1
	overplotcat(tobs_mjd(1), srclist3CR, 500, gcf, 1); 
end;

subplot (133);
imagesc (-l, -l, abs(map_negdel)); colorbar;
title ('Station calib, flag, with neg delay');
if overplt == 1
	overplotcat(tobs_mjd(1), srclist3CR, 500, gcf, 1); 
end;



clear acm, tobs;

% Plot related.
figure;
subplot (231);
imagesc (10*log10(abs(squeeze(acm_0c0d0f(1,:,:,1))))); colorbar;
title (sprintf ('0c 0d 0f: %s', datestr(mjdsec2datenum(tobs_mjd(1)))));

subplot (234);
imagesc (-l, -l, abs(squeeze(map_0c0d0f(1,:,:,1)))); colorbar;
if overplt == 1
	overplotcat(tobs_mjd(1), srclist3CR, 500, gcf, 1); 
end;

subplot (232);
imagesc (10*log10(abs(squeeze(acm_1c0d0f(1,:,:,1))))); colorbar;
title (sprintf ('1c 0d 0f: %s', datestr(mjdsec2datenum(tobs_mjd(1)))));

subplot (235);
imagesc (-l, -l, abs(squeeze(map_1c0d0f(1,:,:,1)))); colorbar;
if overplt == 1
	overplotcat(tobs_mjd(1), srclist3CR, 500, gcf, 1); 
end;

subplot (233);
imagesc (10*log10(abs(squeeze(acm_1c0d1f(1,:,:,1))))); colorbar;
title (sprintf ('1c 0d 1f: %s', datestr(mjdsec2datenum(tobs_mjd(1)))));

subplot (236);
imagesc (-l, -l, abs(squeeze(map_1c0d1f(1,:,:,1)))); colorbar;
if overplt == 1
	overplotcat(tobs_mjd(1), srclist3CR, 500, gcf, 1); 
end;

% Raw data correlated with delay compensation turned ON.
load 'sb0_14Oct14_134528_lba_outer_del.vis_1413294328-1413294330.mat'
[acm_0c1d0f, tobs_mjd, fobs, map_0c1d0f, l] = gengpuimg (acm, tobs, 60000000, [1:63], [], [], [], 1, 0);
[acm_1c1d0f, tobs_mjd, fobs, map_1c1d0f, l] = gengpuimg (acm, tobs, 60000000, [1:63], [], cal_x, cal_y, 1, 0);
[acm_1c1d1f, tobs_mjd, fobs, map_1c1d1f, l] = gengpuimg (acm, tobs, 60000000, [1:63], flagant, cal_x, cal_y, 1, 0);

% Plot related.
figure;
subplot (231);
imagesc (10*log10(abs(squeeze(acm_0c1d0f(1,:,:,1))))); colorbar;
title (sprintf ('0c 1d 0f: %s', datestr(mjdsec2datenum(tobs_mjd(1)))));

subplot (234);
imagesc (-l, -l, abs(squeeze(map_0c1d0f(1,:,:,1)))); colorbar;
if overplt == 1
	overplotcat(tobs_mjd(1), srclist3CR, 500, gcf, 1); 
end;

subplot (232);
imagesc (10*log10(abs(squeeze(acm_1c1d0f(1,:,:,1))))); colorbar;
title (sprintf ('1c 1d 0f: %s', datestr(mjdsec2datenum(tobs_mjd(1)))));

subplot (235);
imagesc (-l, -l, abs(squeeze(map_1c1d0f(1,:,:,1)))); colorbar;
if overplt == 1
	overplotcat(tobs_mjd(1), srclist3CR, 500, gcf, 1); 
end;

subplot (233);
imagesc (10*log10(abs(squeeze(acm_1c1d1f(1,:,:,1))))); colorbar;
title (sprintf ('1c 1d 1f: %s', datestr(mjdsec2datenum(tobs_mjd(1)))));

subplot (236);
imagesc (-l, -l, abs(squeeze(map_1c1d1f(1,:,:,1)))); colorbar;
if overplt == 1
	overplotcat(tobs_mjd(1), srclist3CR, 500, gcf, 1); 
end;

% Raw data correlated with negative delay compensation turned ON.
load 'sb0_14Oct14_134528_lba_outer_negdel.vis_1413294328-1413294330.mat'
[acm_0cn1d0f, tobs_mjd, fobs, map_0cn1d0f, l] = gengpuimg (acm, tobs, 60000000, [1:63], [], [], [], 1, 0);
[acm_1cn1d0f, tobs_mjd, fobs, map_1cn1d0f, l] = gengpuimg (acm, tobs, 60000000, [1:63], [], cal_x, cal_y, 1, 0);
[acm_1cn1d1f, tobs_mjd, fobs, map_1cn1d1f, l] = gengpuimg (acm, tobs, 60000000, [1:63], flagant, cal_x, cal_y, 1, 0);

% Plot related.
figure;
subplot (231);
imagesc (10*log10(abs(squeeze(acm_0cn1d0f(1,:,:,1))))); colorbar;
title (sprintf ('0c n1d 0f: %s', datestr(mjdsec2datenum(tobs_mjd(1)))));

subplot (234);
imagesc (-l, -l, abs(squeeze(map_0cn1d0f(1,:,:,1)))); colorbar;
if overplt == 1
	overplotcat(tobs_mjd(1), srclist3CR, 500, gcf, 1); 
end;

subplot (232);
imagesc (10*log10(abs(squeeze(acm_1cn1d0f(1,:,:,1))))); colorbar;
title (sprintf ('1c n1d 0f: %s', datestr(mjdsec2datenum(tobs_mjd(1)))));

subplot (235);
imagesc (-l, -l, abs(squeeze(map_1cn1d0f(1,:,:,1)))); colorbar;
if overplt == 1
	overplotcat(tobs_mjd(1), srclist3CR, 500, gcf, 1); 
end;

subplot (233);
imagesc (10*log10(abs(squeeze(acm_1cn1d1f(1,:,:,1))))); colorbar;
title (sprintf ('1c n1d 1f: %s', datestr(mjdsec2datenum(tobs_mjd(1)))));

subplot (236);
imagesc (-l, -l, abs(squeeze(map_1cn1d1f(1,:,:,1)))); colorbar;
if overplt == 1
	overplotcat(tobs_mjd(1), srclist3CR, 500, gcf, 1); 
end;
