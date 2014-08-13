% Script to create station images as a gif.
function genstationgif (img, filename, poslocal, l, freq, nrecs)
figure(1)
for ind = 1:nrecs
	for stat = 1:6
		map = genstationmap (squeeze(img(ind, :,:)), stat, poslocal, l, freq);
		subplot (2,3,stat);
    	imagesc (10*log10(squeeze(abs(map)))); colorbar;
		title (sprintf ('CS00%d: T:%d', stat+1, ind));
	end;
    drawnow;
    frame = getframe(1);
    im = frame2im(frame);
    [imind,cm] = rgb2ind(im,256);
    if ind == 1;
        imwrite(imind,cm,filename,'gif', 'Loopcount',inf);
    else
        imwrite(imind,cm,filename,'gif','WriteMode','append');
    end
	fprintf (1, 'Time ind: %d\n', ind);
	clf;
end
