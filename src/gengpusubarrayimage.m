% Script to generate an image from GPU correlated visibilities.
% Allows specifying stations to include
% fname is the ascii file containing the output of rdgpuvis.c
% stat numbering starts at 0;
% chan is a selection of channels on which to operate
% Note: text file format: time chan 2*41616 numbers. 
% Currently assumes only a single timeslice

function [acc, tobs, fobs, map, goodant] = gengpusubarrayimage(fname, chan, stat, deb)
	dat = load (fname);
    fprintf (2, 'Loaded file %s.\n', fname);
	tobs = dat (1,1);
    
	fobs = 60000000; % Arbit value, not available from text file

	acc = triu(ones (288));
    
	if (deb > 0)
		figure;
		% Randomly choose a visibility, extract from all available chans.
		vis_ch = dat (chan, 13321) + i*dat(chan,13322); 
		subplot (211);
		plot (chan, 10*log10(abs(vis_ch)));
		xlabel ('Chan'); ylabel ('Vis. mag (dB)');
		title ('Visibility mag. across channels');
		subplot (212);
		plot (chan, angle(vis_ch), '-o');
		xlabel ('Chan'); ylabel ('Vis. phase (rad)');
		title ('Visibility phase across channels');
	end;

    % Average over the channel range selected 
    if (length (chan) > 1)
      dat_ave = mean (dat(chan,:));
    else
      dat_ave = dat;
    end;
	acm = dat_ave (3:2:end) + i*dat_ave(4:2:end);
	acc (acc(:) == 1) = acm;
	acc = acc + acc';
    acc = acc - diag(diag(acc));

	load ('poslocal_outer.mat', 'poslocal');
	goodant = [];
	for ind = 1:length (stat)
		st_ind = stat(ind)*48+1;
		goodant = [goodant [st_ind:st_ind+47]];
	end;

	l = [-1:0.01:1];
	map = acm2skyimage (acc(goodant,goodant), poslocal(goodant,1), poslocal(goodant,2), fobs, l, l);
	if (deb > 0)
		figure;
		% imagesc (l,l,10*log10(abs(map))); colorbar;
		imagesc (l,l,abs(map)); colorbar;
		cmd = sprintf ('date -d @%f +%%d%%b%%g', tobs);
		[~, r1] = system (cmd);
		cmd = sprintf ('date -d @%f +%%H%%M%%S', tobs);
		[~, r2] = system (cmd);
		tstamp = strcat (r1,'\_', r2);
		title (sprintf ('[%d:%d] ch. avg, uncalib map from station %s: %s', chan(1), chan(end), num2str(stat),tstamp));
	end;
