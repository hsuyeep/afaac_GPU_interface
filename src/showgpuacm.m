function [acc_t] = showgpuacm(acm, tobs, t_pause)
	if (isempty(t_pause)) t_pause=0.1; end;
	tmp = triu(ones (288));
	% tobs is in unix time seconds.
	mjddateref = datenum (1858,11,17,00,00,00); % Start of MJD
	unixtime  = datenum (1970, 01, 01, 00, 00, 00);
	tobs1 = (unixtime + tobs/86400. - mjddateref)*86400;
	acc_t = zeros (size (acm, 1), 288, 288, size (acm, 3));
	for ch = 1:size (acm, 3)
		for ind = 1:size (acm, 1) % Time axis.
			acc = squeeze (complex (acm(ind,:,ch,4,1), acm(ind,:,ch,4,2))); % XX pol only, single chan.
			tmp1 = tmp;
			tmp1 (tmp(:) == 1) = acc;
			tmp1 = tmp1 + tmp1' - diag(diag(tmp1));
			acc_t (ind, :, :, ch) = tmp1;
			imagesc (20*log10(abs(tmp1)));
			title (sprintf ('Time: %.2f, channel %d', tobs1(ind), ch));
			colorbar;
			drawnow ();
			% pause (t_pause);
		end;
	end;
