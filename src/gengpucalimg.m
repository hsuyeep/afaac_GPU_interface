% Script to calibrate GPU correlator output available as .mat files (output of gpu2mat.py)
% Calibrate using pelican_sunAteamsub, and subsequently imaged.
% pep/12Nov14
% Arguments:
%  fname : .mat filename generated from gpu2mat.py, corresponding to a siRAteam ngle subband.
%  fobs  : Center frequency of the subband


% function gencalimg (fname, fobs, flagant)
function [tobs, map] = gengpucalimg (fobs)
 	load '/dop312_0/prasad/LBA_OUTER_09Nov14/08Nov14_231707_1415488620-1415488650.mat'
	filename = '08Nov14_231707_1415488620.gif';
	% load '/dop312_0/prasad/LBA_OUTER_09Nov14/08Nov14_231707_1415488651-1415488680.mat'
	% filename = '08Nov14_231707_1415488651.gif';
	load 'srclist3CR.mat'
	poslocal = load ('poslocal_outer.mat', 'poslocal');
	posITRF = load ('poslocal_outer.mat', 'posITRF');
	poslocal = poslocal.poslocal;
	posITRF = posITRF.posITRF;
	normal  = [0.598753, 0.072099, 0.797682].';
	uloc = meshgrid (poslocal(:,1)) - meshgrid (poslocal (:,1)).';
    vloc = meshgrid (poslocal(:,2)) - meshgrid (poslocal (:,2)).';


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

	rec = 0;
	clear pelican_sunAteamsub;
	for ind = 1:size (acm_t,1)
		fprintf (2, '--> Processing rec: %d, time: %.2f\n', rec, tobs_mjd(ind));
		tobs = tobs_mjd(ind);

		acm = conj(squeeze(acm_t(ind,:,:,1)));
		[uvflag, flagant] = flagdeadcorr (acm, tobs, fobs, visamphithresh, visamplothresh);
		fprintf (1, '<-- Flagant: %s', num2str(flagant)); 
		goodants = setdiff ([1:288], flagant);
		[uloc_flag, vloc_flag] = gen_flagged_uvloc (uloc, vloc, flagant);

		sol = pelican_sunAteamsub (acm, tobs,fobs, uvflag, flagant, 0, 1, [], [], 'poslocal_outer.mat');		
		clear pelican_sunAteamsub;

		[radecmap, map(ind, :, :), calvis, l, m] = ... 
            fft_imager_sjw_radec (sol.calvis(:), uloc_flag(:), vloc_flag(:), ... 
                                    gparm, [], [], tobs, fobs, 0);

		% map(ind,:,:) = acm2skyimage (sol.calvis,  poslocal(goodants, 1), poslocal(goodants, 2), fobs, l, l);
		imagesc (l,l,squeeze(real(map(ind,:,:))));
		set (gca, 'XDir', 'Reverse');
		set (gca, 'YDir', 'Normal');
		set (gca, 'FontSize', 14);
		colorbar;
		caxis ([0 6]);
		title (sprintf ('%s UTC, GPU Correlator', datestr(mjdsec2datenum(tobs))), 'FontSize', 14);
		overplotcat (tobs, srclist3CR, 50, gcf, 1);
		ylabel('South $\leftarrow$ m $\rightarrow$ North', 'interpreter', 'latex', 'FontSize', 13);
        xlabel('East $\leftarrow$ l $\rightarrow$ West', 'interpreter', 'latex', 'FontSize', 13);

    	drawnow;
    	frame = getframe(1);
    	im = frame2im(frame);
    	[imind,cm] = rgb2ind(im,256);
    	if rec == 0;
        	imwrite(imind,cm,filename,'gif', 'Loopcount',inf);
    	else
        	imwrite(imind,cm,filename,'gif','WriteMode','append');
    	end
		rec = rec + 1;

		
	end;
