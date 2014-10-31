""" Script to display images as recorded by vismon.py
    pep/31Oct14
"""
import numpy as n;
import matplotlib.pylab as plt;
import vismon;

if __name__ == "__main__":
	rec = 0;
	with open (sys.argv[1], 'r') as f:
		tobs, fobs, img = vismon.imager.readImgFromFile (f);		
		print 'Rec: %d, Time: %.0f, Freq: %.0f' % (rec, tobs, fobs);
		img.shape = (500, 500);
		imgplt = plt.imshow (skymap);
		plt.colorbar();
		imgplt.set_data (skymap);
		plt.draw();
		plt.title ('XX - %f' % tobs);
		rec = rec + 1;
