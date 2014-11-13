% Script to generate an image from uncalibrated GPU correlated visibilities.
% Allows specifying stations to include (i.e, subarrays can be used).
% Operates on the output of gpu2mat.py.
%  Arguments:
% 	acm   : The covariance matrix loaded from the output of gpu2mat.py. 
%   tobs  : Time of observation in unixtime (generated by gpu2mat.py)
% 	chan  : A selection of channels, which are averaged before imaging.
% flagant : Antennas to flag before forming the image.
%  calx/y : Calibration complex vectors, output of readafaaccaltab()
%     img : Bool turning imaging on or off.
% Incoming ACM dimensions: [time][bline][chan][pol][re/im]
% Results:
%  acm_t : Reshaped complex acm with calibration vector applied.
%		   [time][nant][nant][chan][pol]
%  tobs_mjdsec: Observation time in MJDsec.
%  fobs  : Assumed frequency of obs. (fixed at 60 MHz)
%  map   : DFT images: [time][l][m][pol]

% pep/22Oct14

function [acm_t, tobs_mjdsec, fobs, map, l] = gengpuimg(acm, tobs, fobs, chan, flagant, calx, caly, img, deb)
	addpath ~/WORK/AARTFAAC/Afaac_matlab_calib/

	nrec = size (acm, 1);
	nchan = size (acm,3);
	npol = size (acm,4);
	fprintf (2, '--> Found %d timeslices: %.2f-%.2f, %d chan, %d pol.\n', length(tobs), tobs(1), tobs(end), nchan, npol);

	if (isempty(chan))
		chan = [1:63];
	end;
    
	if (isempty (fobs))
		fobs = 60000000; % Arbit value, not available from text file
	end;
	t1 = triu(ones (288));
	% tobs is in unix time seconds.
	mjddateref = datenum (1858,11,17,00,00,00); % Start of MJD
	unixtime  = datenum (1970, 01, 01, 00, 00, 00);
	tobs_mjdsec = (unixtime + tobs/86400. - mjddateref)*86400;

	if (deb > 0)
		fdeb = figure;
		% Randomly choose a visibility, extract from all available chans.
		% 288*48*2 + 48*4 + 30*2 = 30th visibility in the CS003xCS005 block
		vis_ch = acm (1, 27900, chan, 1, 1) + i*acm (1, 27900, chan, 1, 2);
		subplot (211);
		plot (chan, 10*log10(abs(vis_ch)));
		xlabel ('Chan'); ylabel ('Vis. mag (dB)');
		title ('Visibility mag. across channels');
		subplot (212);
		plot (chan, angle(vis_ch), '-o');
		xlabel ('Chan'); ylabel ('Vis. phase (rad)');
		title ('Visibility phase across channels');
	end;

	% Flagging and calibration related.
	goodant = setdiff ([1:288], flagant);
	if (~isempty (calx))
		fprintf (1, '--> Applying X calibration...\n');
		calmat_x = calx(goodant)*calx(goodant)';
	end;
	if (~isempty (caly))
		fprintf (1, '--> Applying Y calibration...\n');
		calmat_y = caly(goodant)*caly(goodant)';
	end;

    % Average over the channel range selected 
    acm = squeeze(mean (acm (:,:,chan,:,:), 3));
	acm_t = zeros (nrec, length(goodant), length(goodant), npol);
	tmp = zeros (length(goodant));
	tmp1 = zeros (288,288);
	for tind = 1:nrec
		for pind = 1:npol
			tmp1 (t1==1) = complex (acm (tind, :, pind, 1), acm(tind,:,pind,2));
			tmp = tmp1 (goodant, goodant);
			tmp = tmp + tmp';
			% tmp = tmp - diag(diag(tmp));

			% Apply calibration vector, if available
			if (~isempty(calx))
				tmp = tmp .* calmat_x;
			end;

			acm_t (tind, :,:, pind) = tmp;
		end;
	end;

	l = [-1:0.01:1];
	if img == 1
		% Imaging part
		load ('poslocal_outer.mat', 'poslocal');
		% map = zeros (nrec, length(l), length(l), npol);
		map = zeros (nrec, 512, 512, npol);

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
	
		tind = 1;
		for tind = 1:nrec
			fprintf (1, '--> Imaging timeslice %d...\n', tind);
			% pind = 1;
			for pind = 1:npol
				% Slow DFT imaging;
				% map(tind,:,:,pind) = acm2skyimage (squeeze(acm_t(tind, :,:, pind)), poslocal(goodant,1), poslocal(goodant,2), fobs, l, l);
	
	    		[map(tind, :, :, pind), calmap, calvis, l, m] = ... 
					fft_imager_sjw_radec (acm_t(tind, :, :, pind), uloc_flag(:), vloc_flag(:), ... 
										gparm, [], [], tobs_mjdsec(tind), fobs, 0);
				if (deb > 0)
					figure(fdeb);
					subplot(2,2,pind);
					% imagesc (l,l,10*log10(abs(map))); colorbar;
					imagesc (l,l,abs(map(tind,:,:,pind))); colorbar;
					cmd = sprintf ('date -d @%f +%%d%%b%%g', tobs);
					[~, r1] = system (cmd);
					cmd = sprintf ('date -d @%f +%%H%%M%%S', tobs);
					[~, r2] = system (cmd);
					tstamp = strcat (r1,'\_', r2);
					title (sprintf ('[%d:%d] ch. avg, uncalib map from station %s: %s', chan(1), chan(end), num2str(stat),tstamp));
				end;
			end;
		end;
	else
		map = [];
	end;
