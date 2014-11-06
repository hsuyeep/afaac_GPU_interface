""" Script to display images as recorded by vismon.py
    pep/31Oct14
"""
import numpy as n;
import matplotlib.pylab as plt;
import sys;
import vismon;

if __name__ == "__main__":
	rec = 0;
	npix = 500; 
	im = vismon.imager (npix, 'dft', 60000000);
	fid = open (sys.argv[1], 'r');
	tobs, fobs, img = im.readImgFromFile (fid);		
	print 'Rec: %d, Time: %.0f, Freq: %.0f' % (rec, tobs, fobs);
	img.shape  = (npix, npix);
	imgplt = plt.imshow (img);
	plt.colorbar();
	plt.pause(0.1);
	
	while True:
		tobs, fobs, img = im.readImgFromFile (fid);		
		print 'Rec: %d, Time: %.0f, Freq: %.0f' % (rec, tobs, fobs);
		img.shape = (npix, npix);
		imgplt.set_data (img);
		plt.draw();
		plt.title ('XX - %f' % tobs);
		# plt.clf();
		rec = rec + 1;
