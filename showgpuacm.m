function showgpuacm(acm, tobs, t_pause)
	if (isempty(t_pause)) t_pause=0.1; end;
	tmp = triu(ones (288));
	% tobs is in unix time seconds.
	mjddateref = datenum (1858,11,17,00,00,00); % Start of MJD
	unixtime  = datenum (1970, 01, 01, 00, 00, 00);
	tobs1 = (unixtime + tobs/86400. - mjddateref)*86400;

	for ch = 1:size (acm, 3)
		for ind = 1:size (acm, 1) % Time axis.
			acc = squeeze (complex (acm(ind,:,ch,1,1), acm(ind,:,ch,1,2))); % XX pol only, single chan.
			acc_t = tmp;
			acc_t(tmp(:) == 1) = acc;
			acc_t = acc_t - diag(diag(acc_t));
			imagesc (20*log10(abs(acc_t)));
			title (sprintf ('Time: %.2f, channel %d', tobs_1(ind), ch));
			colorbar;
			drawnow ();
			% pause (t_pause);
		end;
	end;
