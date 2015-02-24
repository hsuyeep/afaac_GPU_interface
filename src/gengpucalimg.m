% Script to calibrate GPU correlator output available as .mat files (output of gpu2mat.py)
% Calibrate using pelican_sunAteamsub, and subsequently imaged.
% pep/12Nov14
% Arguments:
%  fname : .mat filename generated from gpu2mat.py, corresponding to a single subband.
%  fobs  : Center frequency of the subband
%  togif : Bool representing writing output to a .gif image
%  calall: Variable to decide if all timeslices will be calibrated
%  separately (-1), or only the first 'calall' recs are to be used to
%  create an average calib. solution.


% function gencalimg (fname, fobs, flagant)
function [tobs, map] = gengpucalimg (fname, fobs, togif, calall)
	addpath ~/WORK/AARTFAAC/Afaac_matlab_calib/
	fprintf (2, 'Working on file %s\n', fname);
 	load (fname); 
	if (togif == 1)
		giffilename = strcat (fname, '.gif');
		fprintf (2, '--> Writing calibrated images to %s.\n', giffilename);
	end;
	load 'srclist3CR.mat'
	poslocal = load ('poslocal_outer.mat', 'poslocal');
	posITRF = load ('poslocal_outer.mat', 'posITRF');
	poslocal = poslocal.poslocal;
	posITRF = posITRF.posITRF;
	normal  = [0.598753, 0.072099, 0.797682].';
	uloc = meshgrid (poslocal(:,1)) - meshgrid (poslocal (:,1)).';
    vloc = meshgrid (poslocal(:,2)) - meshgrid (poslocal (:,2)).';
    antmask = zeros (288);
    


	% Gridding parameters
	gparm.type = 'pillbox';
    gparm.lim = 0;
    gparm.duv = 0.5;
    gparm.Nuv = 500;
    gparm.uvpad = 512;
    gparm.fft = 1;



	if (isempty (fobs))
		fobs = 60000000;
	end;
	visamphithresh= 1.5;% Reject visibilities with median >visampthresh*median.
    visamplothresh= 0.5;% Reject visibilities with median >visampthresh*median.

 	[acm_t, tobs_mjd, fobs, map, l] = gengpuimg (acm, tobs, fobs, [1:63], [], [], [], 0, 0);
% 
% 	% uncalimg = figure;
% 	imagesc (l,l,squeeze(real(map)));
% 	set (gca, 'XDir', 'Reverse');
% 	set (gca, 'YDir', 'Normal');
% 	set (gca, 'FontSize', 14);
% 	colorbar;
% 	caxis ([0 6]);
% 	title (sprintf ('Uncalibrated imag: %s UTC, GPU Correlator', datestr(mjdsec2datenum(tobs_mjd))), 'FontSize', 14);

	rec = 0;
	calimg = figure;
	clear pelican_sunAteamsub;
	for ind = 1:size (acm_t,1)-1
		fprintf (2, '--> Processing rec: %d, time: %.2f\n', rec, tobs_mjd(ind));
		tobs = tobs_mjd(ind);

		acm_i = conj(squeeze(acm_t(ind,:,:,1)));
		[uvflag, flagant] = flagdeadcorr (acm_i, tobs, fobs, visamphithresh, visamplothresh);
		fprintf (1, '<-- Flagant: %s', num2str(flagant)); 
		goodants = setdiff ([1:288], flagant);
		[uloc_flag, vloc_flag] = gen_flagged_uvloc (uloc, vloc, flagant);
        
        
        if (calall < 0 || ind < calall)
		   sol = pelican_sunAteamsub (acm_i, tobs,fobs, uvflag, flagant, 0, 1, [], [], 'poslocal_outer.mat');		
		   clear pelican_sunAteamsub;
%           [radecmap, map(ind, :, :), calvis, l, m] = ...
%             fft_imager_sjw_radec (acm_i(:), uloc(:), vloc(:), ... 
%                                     gparm, [], [], tobs, fobs, 0);
           [radecmap, map(ind, :, :), calvis, l, m] = ...
            fft_imager_sjw_radec (sol.calvis(:), uloc_flag(:), vloc_flag(:), ... 
                                   gparm, [], [], tobs, fobs, 0);
        else
            fprintf (2, 'Applying prev. calibration sol.');
            
            
            srcposhat = [cos(sol.phisrc_wsf) .* cos(sol.thsrc_wsf),...
                         sin(sol.phisrc_wsf) .* cos(sol.thsrc_wsf),...
                         sin(sol.thsrc_wsf)];
            A = exp(-(2 * pi * 1i * fobs / 299792458) * ... 
                    (posITRF * srcposhat.'));            
            RAteam = A * diag(sol.sigmas) * A';

                     
            for ind = 1:length(sol.flagant)
                antmask(sol.flagant(ind),:) = 1; antmask(:,sol.flagant(ind)) = 1;
            end;
            sigman = zeros (288);
            sigman(antmask == 0) = sol.sigman;
            acm_i = acm_i./ sqrt (diag(acm_i) * diag(acm_i).');
            % acc = sol.gainsol'*sol.gainsol.*((acm_i) - sigman) - RAteam;
            acc = sol.gainsol'*sol.gainsol.*((acm_i) - sigman);
            rem_ants = 288 - length (sol.flagant);
            acc = reshape (acc(antmask ~= 1), [rem_ants, rem_ants]);
            
%            [radecmap, map(ind, :, :), calvis, l, m] = ... 
%             fft_imager_sjw_radec (acm_i(:), uloc(:), vloc(:), ...
%                                    gparm, [], [], tobs, fobs, 0);
            [radecmap, map(ind, :, :), calvis, l, m] = ... 
            fft_imager_sjw_radec (acc(:), uloc_flag(:), vloc_flag(:), ... 
                                   gparm, [], [], tobs, fobs, 0);
            % pause (1);
        end;    
		

		% map(ind,:,:) = acm2skyimage (sol.calvis,  poslocal(goodants, 1), poslocal(goodants, 2), fobs, l, l);
		imagesc (l,l,squeeze(real(map(ind,:,:))));
		set (gca, 'XDir', 'Reverse');
		set (gca, 'YDir', 'Normal');
		set (gca, 'FontSize', 14);
		colorbar;
		% caxis ([0 8]);
		title (sprintf ('%s UTC, GPU Correlator', datestr(mjdsec2datenum(tobs))), 'FontSize', 14);
		overplotcat (tobs, srclist3CR, 50, gcf, 1);
		ylabel('South $\leftarrow$ m $\rightarrow$ North', 'interpreter', 'latex', 'FontSize', 13);
        xlabel('East $\leftarrow$ l $\rightarrow$ West', 'interpreter', 'latex', 'FontSize', 13);

    	drawnow;
		if (togif == 1)
    		frame = getframe(calimg);
    		im = frame2im(frame);
	    	[imind,cm] = rgb2ind(im,256);
	    	if rec == 0;
	        	imwrite(imind,cm,giffilename,'gif', 'Loopcount',inf);
	    	else
	        	imwrite(imind,cm,giffilename,'gif','WriteMode','append');
	    	end
		end;
		rec = rec + 1;
	end;
