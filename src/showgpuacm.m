% Script to generate covariance matrices from the output of gpu2mat.py.
% Shows the phases of all 4 crosshands pols, and the amplitude from XX.
% Done to mimmic the output of gpucorrelator test script with WGs.
% pep/14Oct14

% Input :
%  acm : real matrix containing visibilities
%        (time, bline(=41616), chan(=63), pol(=4), re/im(=2))
%  tobs: Time in UTC sec.
% t_pause: Time to pause between plots.

function [acc_t] = showgpuacm(acm, tobs, chan, t_pause)
	if (isempty(t_pause)) t_pause=0.1; end;
	tmp = triu(ones (288));
	% tobs is in unix time seconds.
	mjddateref = datenum (1858,11,17,00,00,00); % Start of MJD
	unixtime  = datenum (1970, 01, 01, 00, 00, 00);
	tobs1 = (unixtime + tobs/86400. - mjddateref)*86400;
	acc_t = zeros (size (acm, 1), 288, 288, length (chan));
	absfig = figure;
	phfig = figure;
	set (absfig, 'Position', [0, 10, 600 700]);
	set (phfig, 'Position', [650, 10, 600 700]);
	polname = {'YY', 'XY', 'YX', 'YY'};

	% NOTE: Time axis controlled by tobs! 
	for ind = 1:size (tobs, 1) % Time axis.
	    % for ch = 1:size (acm, 3) % Channel axis.
	    for ch = 1:length (chan) % Channel axis.
			for pol = 1:size (acm, 4) % Pol. axis.
				acc = squeeze (complex (acm(ind,:,chan(ch),pol,1), acm(ind,:,chan(ch),pol,2))); % XX pol only, single chan.
				tmp1 = tmp;
				tmp1 (tmp(:) == 1) = acc;
				% tmp1 = tmp1 + tmp1' - diag(diag(tmp1));
				acc_t (ind, :, :, ch) = tmp1;
	
				figure (absfig);
				subplot (2,2,pol);
				imagesc (abs(tmp1)); 
				% imagesc (20*log10(abs(tmp1))); 
				title (sprintf ('abs: %s, %.2f, ch %d', char(polname{pol}), tobs1(ind), chan(ch)));
				colorbar;
	

                figure (phfig);
				subplot (2,2,pol);
				imagesc (angle(tmp1));
				title (sprintf ('phase: %s, %.2f, ch %d', char(polname{pol}), tobs1(ind), chan(ch)));
				colorbar;
				drawnow ();
				pause (t_pause);
			end;
		end;
	end;
