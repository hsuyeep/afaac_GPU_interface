function genmapgif (img, filename)
figure(1)
for ind = 1:size (img, 1)
      imagesc (10*log10(squeeze(abs(img(ind, :,:))))); colorbar;
      drawnow;
      frame = getframe(1);
      im = frame2im(frame);
      [imind,cm] = rgb2ind(im,256);
      if ind == 1;
          imwrite(imind,cm,filename,'gif', 'Loopcount',inf);
      else
          imwrite(imind,cm,filename,'gif','WriteMode','append');
      end
end
