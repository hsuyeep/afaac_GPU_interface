% Script to compare acc and images generated from CPU and GPU correlators
% pep/18Aug14

%%%%%%% Single channel response.
% GPU correlator output with no delay compensation
 [acc_1ch_nodel, tobs, fobs, map_1ch_nodel, goodant] = gengpusubarrayimage ('../Data/08Aug14_142716_nodel.dat', 31:32, [1 3 5], 1);

% GPU correlator output with positive delay compensation.
 [acc_1ch_pdel, tobs, fobs, map_1ch_pdel, goodant] = gengpusubarrayimage ('../Data/08Aug14_142716_posdel.dat', 31:32, [1 3 5], 1);

% GPU correlator output with negative delay compensation
 [acc_1ch_ndel, tobs, fobs, map_1ch_ndel, goodant] = gengpusubarrayimage ('../Data/08Aug14_142716_negdel.dat', 31:32, [1 3 5], 1);
%%%%%%%%%%%%%%%%%%%%%% Analysis %%%%%%%%%%%%%%%%
% Phase difference between acc with no delay and positive delay 
figure;
imagesc (angle (acc_1ch_nodel(goodant, goodant)) - angle (acc_1ch_pdel(goodant, goodant))); colorbar;
title ('Phase diff: No delay comp - pos. delay comp, 1ch/1sec avg, uncalib, CS003,5,7');

% Phase difference between acc with positive and negative delay compensation.
figure;
imagesc (angle (acc_1ch_pdel(goodant, goodant)) - angle (acc_1ch_ndel(goodant, goodant))); colorbar;
title ('Phase diff: pos. delay comp - neg. delay comp, 1ch/1sec avg, uncalib, CS003,5,7');

% Image difference between nodelay and pos. delay
figure;
imagesc (map_1ch_nodel - map_1ch_pdel); colorbar;
title ('Image diff: no delay comp - pos. delay comp, 1ch/1sec avg, uncalib, CS003,5,7, gpucorr');

figure;
imagesc (map_1ch_nodel - map_1ch_ndel); colorbar;
title ('Image diff: no delay comp - neg. delay comp, 1ch/1sec avg, uncalib, CS003,5,7, gpucorr');



%%%%%% 30 Chan. response.
% GPU correlator output with no delay compensation
 [acc_30ch_nodel, tobs, fobs, map_nodel, goodant] = gengpusubarrayimage ('../Data/08Aug14_142716_nodel.dat', 20:50, [1 3 5], 1);

% GPU correlator output with positive delay compensation.
 [acc_30ch_pdel, tobs, fobs, map_pdel, goodant] = gengpusubarrayimage ('../Data/08Aug14_142716_posdel.dat', 20:50, [1 3 5], 1);

% GPU correlator output with negative delay compensation
 [acc_30ch_ndel, tobs, fobs, map_ndel, goodant] = gengpusubarrayimage ('../Data/08Aug14_142716_negdel.dat', 20:50, [1 3 5], 1);

%%%%%%%%%%%%%%%%%%%%%% Analysis %%%%%%%%%%%%%%%%
% Phase difference between acc with no delay and positive delay 
figure;
imagesc (angle (acc_30ch_nodel(goodant, goodant)) - angle (acc_30ch_pdel(goodant, goodant))); colorbar;
title ('Phase diff: No delay comp - pos. delay comp, 30ch/1sec avg, uncalib, CS003,5,7');

% Phase difference between acc with positive and negative delay compensation.
figure;
imagesc (angle (acc_30ch_pdel(goodant, goodant)) - angle (acc_30ch_ndel(goodant, goodant))); colorbar;
title ('Phase diff: pos. delay comp - neg. delay comp, 30ch/1sec avg, uncalib, CS003,5,7');

% Image difference between nodelay and pos. delay
figure;
imagesc (map_30ch_nodel - map_30ch_pdel);
title ('Image diff: no delay comp - pos. delay comp, 30ch/1sec avg, uncalib, CS003,5,7, gpucorr');

figure;
imagesc (map_30ch_nodel - map_30ch_ndel);
title ('Image diff: no delay comp - neg. delay comp, 30ch/1sec avg, uncalib, CS003,5,7, gpucorr');


%%%%%%%%%%% CPU correlated output products.
%%%%%%%%%%%
fname = '../Data/SB002_LBA_OUTER_8b2sbr04_64ch_0006-0007_3khz.bin'; % Archive data with proper delay compensation
stat = [1 3 5];
fid = fopen (fname, 'rb');
[acc_cpu_1ch, tobs_cpu, fobs_cpu] = readms2float (fid, -1, -1, 288);
[acc_cpu_1ch, tobs_cpu, fobs_cpu] = readms2float (fid, -1, -1, 288);
[acc_cpu_1ch, tobs_cpu, fobs_cpu] = readms2float (fid, -1, -1, 288);
load ('poslocal_outer.mat', 'poslocal');
l = [-1:0.01:1];
map_cpu_1ch = acm2skyimage (acc_cpu_1ch(goodant,goodant), poslocal(goodant,1), poslocal(goodant,2), fobs_cpu, l, l);
imagesc (l,l,abs(map_cpu_1ch)); colorbar;
title (sprintf ('1ch. avg, uncalib map from station %s: %s', num2str(stat),datestr(mjdsec2datenum(tobs_cpu))));
fclose (fid);

fname = '../Data/SB002_LBA_OUTER_8b2sbr04_nodelay_3khz.bin'; % Archive data with no delay compensation
stat = [1 3 5];
fid = fopen (fname, 'rb');
[acc_cpu_1ch_nodel, tobs_cpu, fobs_cpu] = readms2float (fid, -1, -1, 288);
[acc_cpu_1ch_nodel, tobs_cpu, fobs_cpu] = readms2float (fid, -1, -1, 288);
[acc_cpu_1ch_nodel, tobs_cpu, fobs_cpu] = readms2float (fid, -1, -1, 288);
load ('poslocal_outer.mat', 'poslocal');
l = [-1:0.01:1];
map_cpu_1ch_nodel = acm2skyimage (acc_cpu_1ch_nodel(goodant,goodant), poslocal(goodant,1), poslocal(goodant,2), fobs_cpu, l, l);
imagesc (l,l,abs(map_cpu_1ch_nodel)); colorbar;
title (sprintf ('1ch. avg, uncalib map, no delay comp. from station %s: %s', num2str(stat),datestr(mjdsec2datenum(tobs_cpu))));
fclose (fid);


