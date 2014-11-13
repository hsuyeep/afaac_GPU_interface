% Apply the station calibration table on the uncalibrated GPU correlator 
% output. Useful in case the AARTFAAC calibration is unable to find the 
% optimal solution on completely uncalibrated visibilities.
% pep/23Oct14
% Arguments:
%  sbnum : Subband number for which to extract calibration solutions.

function [cal_x, cal_y] = readafaaccaltab(sbnum)
	addpath ~/WORK/AARTFAAC/Afaac_matlab_calib/;

	calmat_x = zeros (288, 512);
	calmat_y = zeros (288, 512);
	% fprintf (2, '### NOTE: Currently only LBA_OUTER tables are available!\n');

	calfiles = {'CS002_CalTable_mode2.dat', 'CS003_CalTable_mode2.dat', 'CS004_CalTable_mode2.dat', 'CS005_CalTable_mode2.dat', 'CS006_CalTable_mode2.dat', 'CS007_CalTable_mode2.dat'}; 

	for ind = 1:6
		start_ind = (ind-1)*48 + 1;
		[calmat_x(start_ind:start_ind+47, :), calmat_y(start_ind:start_ind+47,:), hdr] = readCalTable (calfiles{ind});
	end;
	cal_x = calmat_x (:,sbnum);
	cal_y = calmat_y (:,sbnum);
