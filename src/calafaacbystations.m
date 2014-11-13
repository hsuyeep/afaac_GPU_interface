% Script to calibration aartfaac staions by adding them one by one.
% pep/12Nov14

close all;
clear all;

% This dataset was recorded in the night (so no Sun), and has minimum dipoles missing.
load '/dop312_0/prasad/LBA_OUTER_09Nov14/08Nov14_231707_1415488630-1415488639.mat'
load 'srclist3CR.mat'
poslocal = load ('poslocal_outer.mat', 'poslocal');
posITRF = load ('poslocal_outer.mat', 'posITRF');
poslocal = poslocal.poslocal;
posITRF = posITRF.posITRF;
normal  = [0.598753, 0.072099, 0.797682].';
srcsel =  [324, 283, 88, 179, 0];
flagant = [ 140,  149,  199,  260]; % For timeslice 3.
goodants = setdiff ([1:288], flagant);
l = [-1:0.01:1];

% Generates uncalibrated ACMs averaged over 63 channels. We choose timeslice 3 which has least missing dipoles. 
[acm_t, tobs_mjd, fobs, map, l] = gengpuimg (acm, tobs, 60000000, [1:63], [], [], [], 0, 0);

acm = conj (squeeze(acm_t(3,:,:,1)));

% Calibrate individual stations
st = 1;
calx = zeros (1,288);
sigmax = zeros (6,5);
map_uncal = zeros (6,length(l), length(l));
map_cal = zeros (6,length(l), length(l));
f1 = figure;
st = 1;
for ind = 1:48:288
	uvflag = zeros (48);
	st_fl = find (ismember ([ind:ind+47], flagant));
	st_goodant = setdiff ([ind:ind+47], st_fl+ind-1);
	uvflag (st_fl, :) = 1;
	uvflag (:, st_fl) = 1;
	rem_ants = length (st_goodant);
	acm_stat = acm (ind:ind+47, ind:ind+47);

	acm_tmp = reshape (acm_stat(uvflag == 0), [rem_ants, rem_ants]);
	diagent = find (eye(48) == 1);
	uvflag(diagent) = 1;

	[calx(st_goodant), sigmax(st,:), sigmanx] = statcal (acm_tmp, tobs_mjd(1)/86400.+2400000.5, fobs, posITRF(st_goodant,:), srcsel, normal, 4, 30, uvflag(st_goodant-ind+1, st_goodant-ind+1));
	

	calmat = calx (ind:ind+47)' * calx(ind:ind+47);
	acc = acm_stat .* calmat;
	
	map_uncal(st,:,:) = acm2skyimage (acm_stat,  poslocal(ind:ind+47, 1), poslocal(ind:ind+47, 2), fobs, l, l);
	map_cal(st,:,:) = acm2skyimage (acc,  poslocal(ind:ind+47, 1), poslocal(ind:ind+47, 2), fobs, l, l);

	% Display
	subplot (2,2,1);
	imagesc (abs(squeeze(map_uncal(st,:,:))));
	title (sprintf ('Uncalibrated CS%d', st+1));

	subplot (2,2,2);
	imagesc (abs(squeeze(map_cal(st,:,:))));
	title (sprintf ('Calibrated CS%d', st+1));
	
	subplot (2,2,3);
	imagesc (10*log10(abs(acm_stat)));
	title (sprintf ('Uncalibrated ACM CS%d', st+1));

	subplot (2,2,4);
	imagesc (uvflag);
	title (sprintf ('Flags CS%d', st+1));


	st = st + 1;
end;

% Now try to calibrate all 6 stations of aartfaac
uvflag = zeros (288);
fl = find (ismember ([1:288], flagant));
goodant = setdiff ([1:288], flagant);
uvflag (fl, :) = 1;
uvflag (:,fl) = 1;
rem_ants = length (goodant);

acm_tmp = reshape (acm(uvflag == 0), [rem_ants, rem_ants]);
diagent = find (eye(288) == 1);
uvflag(diagent) = 1;

calx_afacc = zeros (1,288);
[calx_afaac(goodant),  sigmax_afaac, sigmanx_afaac] = statcal (acm_tmp, tobs_mjd(1)/86400.+2400000.5, fobs, posITRF(goodant,:), srcsel, normal, 4, 30, uvflag(goodant, goodant));

calmat = calx_afaac' * calx_afaac;
acc = acm .* calmat;

	map_afaac_uncal = acm2skyimage (acm,  poslocal(:,1), poslocal(:, 2), fobs, l, l);
	map_afaac_cal = acm2skyimage (acc,  poslocal(:, 1), poslocal(:, 2), fobs, l, l);

figure;
subplot (2,2,1);
imagesc (abs(map_afaac_uncal));
title ('Uncalibrated map');
subplot (2,2,2);
imagesc (abs(map_afaac_cal));
title ('Calibrated map');
subplot (2,2,3);
imagesc (10*log10(abs(acm)));
title ('Uncalibrated ACM');
subplot (2,2,4);
imagesc (uvflag);
title ('Flags');

