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
	addpath ~/WORK/Matlab/ofek_matlab/fun/ephem/

	fprintf (2, 'Working on file %s\n', fname);
 	load (fname); 
	if (togif == 1)
		uncalgiffilename = strcat (fname, '_uncal.gif');
		calateamgiffilename = strcat (fname, '_calateam.gif');
		calgiffilename = strcat (fname, '_cal.gif');
		fprintf (2, '--> Writing calibrated images to %s.\n', calgiffilename);
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

	
	% Obtain moon position for this timeinstant and plot
	tobs_jd = tobs_mjd/86400. + 2400000.5;
	Moonpos = get_moon (tobs_jd, [6.869837540, 52.915122495]);
	[Moon_l, Moon_m] = radectolm (Moonpos.RA, Moonpos.Dec, tobs_jd, 6.869837540, 52.915122495, 0);

% 	% uncalimg = figure;
% 	imagesc (l,l,squeeze(real(map)));
% 	set (gca, 'XDir', 'Reverse');
% 	set (gca, 'YDir', 'Normal');
% 	set (gca, 'FontSize', 14);
% 	colorbar;
% 	caxis ([0 6]);
% 	title (sprintf ('Uncalibrated imag: %s UTC, GPU Correlator', datestr(mjdsec2datenum(tobs_mjd))), 'FontSize', 14);

	rec = 0;
	calimg      = figure ('Position', [0 100 800 400]);
    calimgAteam = figure ('Position', [200 100 800 400]);
    uncalimg    = figure ('Position', [400 100 800 400]);
	clear pelican_sunAteamsub;
    pol = 1; % XX
    
    % Flag antennas based on first timeslice, then don't flag at all.
    acm_i = conj(squeeze(acm_t(1,:,:,pol)));		
    [uvflag, flagant] = flagdeadcorr (acm_i, tobs_mjd(1), fobs, visamphithresh, visamplothresh);
	fprintf (1, '<-- Flagant: %s', num2str(flagant)); 
	goodants = setdiff ([1:288], flagant);
    [uloc_flag, vloc_flag] = gen_flagged_uvloc (uloc, vloc, flagant);
	
    for ant = 1:length(flagant)
                antmask(flagant(ant),:) = 1; antmask(:,flagant(ant)) = 1;
    end;
  
    for ind = 1:size (acm_t,1)-1
		fprintf (2, '--> Processing rec: %d, time: %.2f\n', rec, tobs_mjd(ind));
		tobs = tobs_mjd(ind);

        moon_l = Moon_l(ind); moon_m = Moon_m(ind);
		acm_i = conj(squeeze(acm_t(ind,:,:,pol)));
        
        if (calall < 0 || ind < calall)
		   sol = pelican_sunAteamsub (acm_i, tobs,fobs, uvflag, flagant, 0, 1, [], [], 'poslocal_outer.mat');		
		   clear pelican_sunAteamsub;
           
           
           acm_i = acm_i./ sqrt (diag(acm_i) * diag(acm_i).');
           
           figure (uncalimg);
           subplot (121);
          [radecmap, uncalmap(ind, :, :), calvis, l, m] = ...
            fft_imager_sjw_radec (acm_i(:), uloc(:), vloc(:), ... 
                                    gparm, [], [], tobs, fobs, 0);

           plotimg (l,l,squeeze(uncalmap(ind,:,:)), tobs, 'Uncalib. map', srclist3CR, moon_l,moon_m);
           
           % imagesc (l,l,real(squeeze(uncalmap(ind,:,:))));
           acc_ateam = sol.gainsol'*sol.gainsol.*(acm_i);
           
           figure (calimgAteam);
           subplot (121);
           [radecmap, calateammap(ind, :, :), calvis, l, m] = ...
            fft_imager_sjw_radec (acc_ateam(:), uloc (:), vloc(:), ... 
                                   gparm, [], [], tobs, fobs, 0);
           plotimg (l,l,squeeze(calateammap(ind,:,:)), tobs, 'Cal. map + Ateam', srclist3CR, moon_l,moon_m);
           
           % imagesc (l,l,real(squeeze(calateammap(ind,:,:))));
            
           figure (calimg);
           subplot (121);
           [radecmap, map(ind, :, :), calvis, l, m] = ...
            fft_imager_sjw_radec (sol.calvis(:), uloc_flag(:), vloc_flag(:), ... 
                                   gparm, [], [], tobs, fobs, 0);
           
            plotimg (l,l,squeeze(map(ind,:,:)), tobs,' Cal. map',  srclist3CR, moon_l,moon_m);
           
            % imagesc (l,l,real(squeeze(map(ind,:,:))));
         else
            fprintf (2, 'Applying prev. calibration sol.');
            
            
            srcposhat = [cos(sol.phisrc_wsf) .* cos(sol.thsrc_wsf),...
                         sin(sol.phisrc_wsf) .* cos(sol.thsrc_wsf),...
                         sin(sol.thsrc_wsf)];
            A = exp(-(2 * pi * 1i * fobs / 299792458) * ... 
                    (posITRF * srcposhat.'));            
            RAteam = A * diag(sol.sigmas) * A';

                     
            
            sigman = zeros (288);
            sigman(antmask == 0) = sol.sigman;
            
            % Plot uncalibrated image on untouched vis.
            figure (uncalimg);
            clf;
            subplot (121);
            [radecmap, uncalmap(ind, :, :), calvis, l, m] = ... 
            fft_imager_sjw_radec (acm_i(:), uloc(:), vloc(:), ...
                                   gparm, [], [], tobs, fobs, 0);
            plotimg (l,l,squeeze(uncalmap(ind,:,:)), tobs, 'Uncal. map', srclist3CR, moon_l,moon_m);
            subplot (122);
            % plotimg (l,l,squeeze(uncalmap(ind,:,:)) - squeeze(uncalmap(ind-1,:,:)), tobs, 'Diff', srclist3CR, moon_l,moon_m);
            plotimg (l,l,squeeze(uncalmap(ind,:,:)) - squeeze(uncalmap(ind-1,:,:)), tobs, 'Diff', srclist3CR, moon_l,moon_m);
           
            acm_i = acm_i./ sqrt (diag(acm_i) * diag(acm_i).');
            rem_ants = 288 - length (sol.flagant);
            
            % Generate plot with one time determined gain solutions. 
            acc = sol.gainsol'*sol.gainsol.*((acm_i) - sigman) - RAteam;
            acc_ateam = sol.gainsol'*sol.gainsol.*((acm_i));
            acc_ateam = reshape (acc_ateam(antmask ~= 1), [rem_ants, rem_ants]);
            
            
            acm_i = reshape (acm_i(antmask ~= 1), [rem_ants, rem_ants]);
            acc = reshape (acc(antmask ~= 1), [rem_ants, rem_ants]);
            
            fprintf (2, 'Norm raw: %f, calateam: %f cal: %f',norm(acm_i), norm(acc_ateam), norm(acc));
           figure (calimgAteam);
           clf;
           subplot (121);
           [radecmap, calateammap(ind, :, :), calvis, l, m] = ... 
            fft_imager_sjw_radec (acc_ateam(:), uloc_flag(:), vloc_flag(:), ... 
                                    gparm, [], [], tobs, fobs, 0);
            plotimg (l,l,squeeze(calateammap(ind,:,:)), tobs, 'Cal. img + Ateam', srclist3CR, moon_l,moon_m);
            subplot (122);
            % plotimg (l,l,squeeze(calateammap(ind,:,:)) - squeeze(calateammap(ind-1,:,:)), tobs, 'Diff', srclist3CR, moon_l,moon_m);
            plotimg (l,l,squeeze(calateammap(ind,:,:)) - squeeze(calateammap(2,:,:)), tobs, 'Diff', srclist3CR, moon_l,moon_m);
            
           figure (calimg);
           clf;
           subplot(121);
           [radecmap, map(ind, :, :), calvis, l, m] = ... 
            fft_imager_sjw_radec (acc(:), uloc_flag(:), vloc_flag(:), ... 
                                    gparm, [], [], tobs, fobs, 0);
            plotimg (l,l,squeeze(map(ind,:,:)), tobs, 'Cal img', srclist3CR, moon_l,moon_m);
            subplot (122);
            % plotimg (l,l,squeeze(map(ind,:,:)) - squeeze(map(ind-1,:,:)), tobs, 'Diff', srclist3CR, moon_l,moon_m);
            plotimg (l,l,squeeze(map(ind,:,:)) - squeeze(map(2,:,:)), tobs, 'Diff', srclist3CR, moon_l,moon_m);
            
            % pause (1);
        end;    
		
    	drawnow;
		if (togif == 1)
    		frame = getframe(calimg);
    		im = frame2im(frame);
	    	[imind,cm] = rgb2ind(im,256);
	    	if rec == 0;
	        	imwrite(imind,cm,calgiffilename,'gif', 'Loopcount',inf);
	    	else
	        	imwrite(imind,cm,calgiffilename,'gif','WriteMode','append');
	    	end

    		frame = getframe(calimgAteam);
    		im = frame2im(frame);
	    	[imind,cm] = rgb2ind(im,256);
	    	if rec == 0;
	        	imwrite(imind,cm,calateamgiffilename,'gif', 'Loopcount',inf);
	    	else
	        	imwrite(imind,cm,calateamgiffilename,'gif','WriteMode','append');
	    	end

    		frame = getframe(uncalimg);
    		im = frame2im(frame);
	    	[imind,cm] = rgb2ind(im,256);
	    	if rec == 0;
	        	imwrite(imind,cm,uncalgiffilename,'gif', 'Loopcount',inf);
	    	else
	        	imwrite(imind,cm,uncalgiffilename,'gif','WriteMode','append');
	    	end
		end;
		rec = rec + 1;
        % pause;
	end;
    
    function plotimg (l,m,img, tobs, tit, srclist3CR, moon_l,moon_m)
        
        imagesc (l,l,real(img));
        set (gca, 'XDir', 'Reverse');
		set (gca, 'YDir', 'Normal');
		set (gca, 'FontSize', 14);
		colorbar;
		% caxis ([0 8]);
		title (sprintf ('%s, %s UTC', tit, datestr(mjdsec2datenum(tobs))), 'FontSize', 14);
		overplotcat (tobs, srclist3CR, 50, gcf, 1);

		% Overplot the location of the Moon
	    text ('Color' , [1 1 0], 'Position', [moon_l, moon_m], ... 
			  'String', 'Moon');
		
		ylabel('South $\leftarrow$ m $\rightarrow$ North', 'interpreter', 'latex', 'FontSize', 13);
        xlabel('East $\leftarrow$ l $\rightarrow$ West', 'interpreter', 'latex', 'FontSize', 13);
        
