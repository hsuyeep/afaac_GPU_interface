""" Script to display images as recorded by vismon.py
    pep/31Oct14
"""
import numpy as n;
import matplotlib.pylab as plt;
import sys;
import signal;
import vismon;

def sighdlr (signal, frame):
	print 'Keyboard interrupt! aborting...'
	sys.exit(0);

if __name__ == "__main__":
	rec = 0;
	fid = open (sys.argv[1], 'r');
	im = vismon.imager ();
	im.readMetaFromFile (fid);
	tobs, fobs, img = im.readImgFromFile (fid);		
	print 'Rec: %04d, Time: %.0f, Freq: %.0f' % (rec, tobs, fobs);
	img.shape  = (im._npix, im._npix);
	imgplt = plt.imshow (abs(img));
	plt.colorbar();
	
	signal.signal(signal.SIGINT, sighdlr);

	while True:
		tobs, fobs, img = im.readImgFromFile (fid);		
		print 'Rec: %d, Time: %.0f, Freq: %.0f' % (rec, tobs, fobs);
		img.shape = (im._npix, im._npix);
		imgplt.set_data (abs(img));
		plt.draw();
		plt.title ('XX - %f' % tobs);
		plt.pause(0.01);
		# plt.clf();
		rec = rec + 1;
