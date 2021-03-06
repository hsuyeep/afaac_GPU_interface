#!/usr/bin/python
# Script to generate uncalibrated images from a live (RT) GPU visibility stream.
# pep/29Oct14
# Added ability to display casacore images as generated by aartfaac-imaging-pipeline using aplpy
# pep/13Jan15

import sys;
import socket;
import optparse;
import time, datetime;
import ctypes;
try:
	import numpy;
	numpyFound = 1;
except ImportError:
	numpyFound = 0;

import math;
try:
	import scipy.io as sio;
	scipyFound = 1;
except ImportError:
	scipyFound = 0;

import os;
import struct;
try:
	import matplotlib.pylab as plt;
	import matplotlib.animation as animation;
	matplotFound = 1;
except ImportError:
	matplotFound = 0;

try:
	import ephem; 
	ephemFound = 1;
except:
	ephemFound = 0;

try:
	import pyrap.images as msim;
	pyrapFound = 1;
except:
	pyrapFound = 0;


#class msImgHandler:
#	'Class to handle images in casacore MeasurementSet format, as generated by the AARTFAAC imaging pipeline. Uses pyrap to access the MS, stores fits object in memory for display with aplpy. Note that multiple images are stored, upto the internally defined limit MAXMS. This allows operating on the images as a timeseries.'
#
#	# Public variables
#	# TODO
#	maxms = 100; # Adjust according to memory usage
#
#	# fnames : list of filenames
#	# def __init__ (self, fnames):
#
#	def openFiles (fnames):
#		assert (len (fnames) >= maxms);
#		return 1;			
#
#
#	def readMS:
#		return 1;

class subbandHandler:
	'Class representing data from a single subband of visibilities, as generated by the GPU correlator'
	
	# Public variables, shared between all class instances.
	Sb2Port = {'sb0':55560, 'sb1':5556};
	Nsec2Rd = 10000; # -1 indicates read infinitely
	Nelem  = 288;       
	Nbline= Nelem*(Nelem+1)/2; 
	Nchan = 63;
	Npol = 4;
	NRec2Buf = 2; # Number of records in local buffer.
	Hdrsize = 512;
	Recsize = Hdrsize + Nbline*Nchan*Npol*2*4; # 4 is for sizeof (float), 2 is for complex float.

	# Private variables
	# Create an array for every timeslice from all subbands
	_tobs = numpy.zeros (NRec2Buf, 'd'); # Time of obs, as double
	_vis = numpy.zeros ([Nbline, Nchan, Npol, 2], 'f');
	_vis_int = numpy.zeros ([Nbline, Npol, 2], 'f');
	_acm = numpy.zeros ([Npol, Nelem*Nelem], dtype=complex);
	_acm_resh = numpy.zeros ([Npol, Nelem, Nelem], dtype=complex);
	_sel = numpy.nonzero(numpy.triu(numpy.ones([Nelem,Nelem])).flatten(1) == 1);
	_streamtype = 'file'; # Default

	""" desc. is a string descriptor of the source of data
		file:filename  = If gpu output is dumped to disk
		tcp:port       = if gpu output is streamed over network
	"""
	def __init__ (self, desc, sbnum, fobs):
		self._streamtype = desc.split(':')[0];
		self._sbnum = sbnum;
		self._fobs = fobs; 

		if self._streamtype == 'file':
			print '--> Operating on file ', desc.split(':')[1];
			try:
				self._fid = open (desc.split(':')[1], "rb");	
			except IOError:
				print 'File ', desc.split(':')[1], ' does not exist. Quitting.';
				
		elif self._streamtype == 'tcp':
			print '--> Operating on TCP socket.';
			self._fid = socket.socket (socket.AF_INET, socket.SOCK_STREAM);
			self._fid.bind( ('', self.Sb2Port[sbnum]) );
			print '--> Binding on port ', self.Sb2Port[sbnum], ' for subband ', sbnum;
			self._fid.listen(1); # Blocking wait
			print '--> Found remote sender';
			self._clientconn,self._clientaddr = self._fid.accept ();
			print '--> Conn', self._clientconn, ' Addr: ', self._clientaddr; 
		else:
			print '### Unknown descriptor type ', self._streamtype, ' Quitting!';
			sys.exit();


	def __del__(self):
		print '<-- Clearing memory';
		if self._streamtype == 'file':
			self._fid.close();
		elif self._streamtype == 'tcp':
			self._clientconn.close();


	""" Read a single record from a binary dump of GPU correlations, 
		either from file or tcp"""
	def readRec (self): # Can include number of records to read here TODO
		if self._streamtype == 'file':
			rec = self._fid.read (self.Recsize);
			if not rec: 
				print 'EOF reached. Last few records may be discarded.\n';
		 		Doneread = 1;

		elif self._streamtype == 'tcp':	
			bytes_recv = 0;
			self._chunks = [];
			ind = 0;
			while bytes_recv < self.Recsize:
				chunk = self._clientconn.recv (min ((self.Recsize - bytes_recv), 20480));
				# if chunk == b'':
				# 	raise RuntimeError ("Socket connection broken");
				self._chunks.append(chunk);
				bytes_recv = bytes_recv + len (chunk);
				ind = ind + 1;

			rec = ''.join(self._chunks);
		else:
			print 'Unknown streamtype: ', self_streamtype;
			
			# TOTO RAise an exception here.
		
		(magic, pad0, self._tobs, endTime) = struct.unpack ("<IIdd", rec[0:24]);
		print 'Start: %.2f, End: %.2f' % (self._tobs, endTime);
		self._vis = numpy.reshape (numpy.asarray (struct.unpack ("ff"*self.Nbline*self.Nchan*self.Npol, rec[512:])),[self.Nbline, self.Nchan, self.Npol, 2]);

		# Integrating over all channels in a subband;
		self._vis_int = numpy.mean (self._vis, axis=1);
		# self._vis_int = self._vis[:,32,:,:];

		# NOTE: Required to set acm to zero due to accumulation on _acm_resh,
		# which is a view (referenced object).
		self._acm[:,:]= 0;
		for ind in range (0, self.Npol):
			self._acm [ind,self._sel] = self._vis_int[:,ind,0] + 1j*self._vis_int[:,ind,1];

		# Make ACM hermitian symmetric
		self._acm_resh = numpy.reshape (self._acm, [self.Npol, self.Nelem, self.Nelem]);
		for ind in range (0, self.Npol):
			self._acm_resh [ind,:,:] = self._acm_resh[ind,:,:] + self._acm_resh[ind,:,:].conj().transpose();
	
		return self._acm_resh, self._tobs, self._fobs;

class imager:
	'Class representing imaged data from a single subband of visibilities, all pols as generated by the GPU correlator'
	# Public variables, shared between all class instances;
	C = 2.9979245e8; # m/s

	def __init__ (self, npix=512, mode='dft', fobs=60000000, sbnum='sb0', pol='xx'):
		self._npix = npix;
		self._pol = pol;
		self._Npol = 1; # NOTE: Hardcoded!
		self._skymap = numpy.asmatrix(numpy.zeros([self._npix, self._npix], 'f'));
		self._tobs = -1; 
		self._fobs = fobs;
		self._mode = mode;
		self._sbnum = sbnum;
		self._meta = ctypes.create_string_buffer(subbandHandler.Hdrsize); # 512Byte file header.
		print '--> Creating Imager in %s mode with npix %d for %s pol at %f Hz.' % (self._mode, self._npix, self._pol, self._fobs);

		# Load antenna positions
		mat_contents = sio.loadmat ('poslocal_outer.mat');
		self._poslocal = numpy.asmatrix (mat_contents['poslocal']);

		if self._mode == 'fft':
			# Generate uv coordinates in local horizon coord. system, needed for
			# imaging.
			u1, v1 = numpy.meshgrid (numpy.asarray(self._poslocal[:,0]), numpy.asarray(self._poslocal[:,1]));
			v2, u2 = numpy.meshgrid (numpy.asarray(self._poslocal[:,1]), numpy.asarray(self._poslocal[:,0]));
			self._uloc = (u1 - u2).flatten(1);
			self._vloc = (v1 - v2).flatten(1);

			self._duv = 2.5;		# In units of meters, default, reassigned from freq. of obs. to
									# image just the full Fov (-1<l<1)
			self._Nuv = int(self._npix)/100 * 100; # size of gridded visibility matrix without padding.
			self._dl = (self.C/(self._fobs * self._npix* self._duv)); # dimensionless, in dir. cos. units
			self._lmax = self._dl * self._npix/ 2;
			self._gridvis = numpy.zeros ([self._npix, self._npix], dtype=complex);
			self._l = numpy.linspace (-self._lmax, self._lmax, self._npix);
			self._m = numpy.linspace (-self._lmax, self._lmax, self._npix);


		elif self._mode == 'dft':
			self._l = numpy.asmatrix (numpy.linspace(-1, 1, self._npix));
			self._dl = 2.0/self._npix;
			self._m = self._l;

			# Create imaging weights for DFT imaging
		  	wavelength = self.C / fobs;
			k = 2 * math.pi / wavelength;
			self._wx = numpy.exp(-1j * k * self._poslocal[:,0] * self._l);
			self._wy = numpy.exp(-1j * k * self._poslocal[:,1] * self._l);

	def createImage (self, acm, tobs, fobs):
		self._tobs = tobs;
		if self._mode.lower() == 'dft':
			self.createImageDFT (acm[0,:,:], tobs, fobs);
		else:
			self.createImageFFT (acm[0,:,:], tobs, fobs);

	""" DFT based imager.
		Arge: acm  = 4xNelemxNelem complex matrix
			  tobs = time of observation in unix time
	"""
	def createImageDFT (self, acm, tobs, fobs):
		self._tobs = tobs;
		self._fobs = fobs;
		# acm[0][:][:] = acm[0][:][:]+acm[0][:][:].conj().transpose();
		self._skymap[:,:] = 0;
		for lidx in range (0, self._npix):
			for midx in range (0, self._npix):
				weight = numpy.multiply(self._wx[:, lidx],self._wy[:, midx]);
				self._skymap[lidx, midx] = (weight.conj().transpose() * acm[0][:][:] * weight).real;

		return self._skymap;


	def gridVis (self, acm):
	
		# For zero padding to desired (u,v)-size
		N1 = numpy.floor((self._npix - self._Nuv) / 2);
		self._gridvis[:,:] = 0;
			
		for idx in range (0, len(self._uloc)):
			ampl = abs(acm[idx]);
			if ampl == 0:
				phasor = 0;
			else:
				phasor = acm[idx] / ampl;
			uidx = self._uloc[idx] / self._duv + self._Nuv/2;
			uidxl = math.floor(uidx);
			uidxh = math.ceil(uidx);
			dul = abs(uidx - uidxl);
			duh = abs(uidx - uidxh);
			sul = duh * ampl;
			suh = dul * ampl;
			
			vidx = self._vloc[idx] / self._duv + self._Nuv / 2;
			vidxl = math.floor(vidx);
			vidxh = math.ceil(vidx);
			dvl = abs(vidx - vidxl);
			dvh = abs(vidx - vidxh);
			sull = dvh * sul;
			sulh = dvl * sul;
			suhl = dvh * suh;
			suhh = dvl * suh;
			
			self._gridvis[N1+uidxl, vidxl+N1] = self._gridvis[N1+uidxl, vidxl+N1] + sull * phasor;
			self._gridvis[N1+uidxl, vidxh+N1] = self._gridvis[N1+uidxl, vidxh+N1] + sulh * phasor;
			self._gridvis[N1+uidxh, vidxl+N1] = self._gridvis[N1+uidxh, vidxl+N1] + suhl * phasor;
			self._gridvis[N1+uidxh, vidxh+N1] = self._gridvis[N1+uidxh, vidxh+N1] + suhh * phasor;
		    
	def createImageFFT (self, acm, tobs, fobs):
		# Grid visibilities;
		self.gridVis (acm.flatten(1));

		# compute image
		self._skymap[:,:] = numpy.fft.fftshift(numpy.fft.fft2(self._gridvis));
		return self._skymap;

	""" Function reads a file containing images written by writeImgToFile and 
		generates a GIF out of them.
	"""
	def convertImgToGIF (self, fid):
		return None; # TODO.

	def writeMetaToFile(self, fid):
		struct.pack_into ('<3s3sffff', self._meta, 0, self._mode, self._sbnum, float(self._npix), float(self._duv), float(self._dl), float(self._Npol));
		numpy.array(self._meta).tofile(fid,sep="");		

	def readMetaFromFile(self, fid):
		rec = fid.read (subbandHandler.Hdrsize);
		self._mode, self._sbnum, self._npix, self._duv, self._dl, self._Npol = struct.unpack_from('<3s3sffff',rec);
		print '<-- Image Meta Information: '
		print '<--   Mode: %s, sb: %s, npix: %f, dl: %f, Npol: %f' % (self._mode, self._sbnum, self._npix, self._dl, self._Npol);

	def writeImgToFile (self, fid):
		print 'Write: ', self._tobs, 'fobs: ', self._fobs;
		numpy.array(numpy.float32 (self._tobs)).tofile(fid,sep="");
		numpy.array(numpy.float32 (self._fobs)).tofile(fid,sep="");
		# Readers can get shape information from the meta data block.
		skymap1 = numpy.array(numpy.float32(abs(self._skymap.flatten(1))));   # skymap is a matrix type otherwise
		skymap1.tofile(fid,sep="");# Written as float32

	def readImgFromFile (self, fid):
		# import pdb; pdb.set_trace();
		t = numpy.fromfile (fid, dtype='float32',count=2);		
		print 'tobs: %f, fobs: %f'% (t[0], t[1]);
		img = numpy.fromfile (fid, dtype='float32',count=int(self._Npol*self._npix*self._npix));
		return t[0], t[1], img;
		

class pltImage:
	'Class representing a plot device on which images are shown'

	def __init__ (self, im, location, fprefix='./',  wrpng=1, pltmoon=1):
		self._wrpng = wrpng;
		self._im = im;
		self._nof_im = len(self._im); # Total number of images to display.
		self._fprefix = fprefix;
		self._pltmoon = pltmoon;
		self._loc = location;

		# Available locations
		if self._loc.lower() == 'lofar':
			self._obssite = ephem.Observer();
			self._obssite.pressure = 0; # To prevent refraction corrections.
			self._obssite.lon, self._obssite.lat = '6.869837540','52.915122495'; # CS002 on LOFAR
		elif self._loc.lower() == 'dwingeloo':
			self._obssite = ephem.Observer();
			self._obssite.pressure = 0; # To prevent refraction corrections.
			self._obssite.lon, self._obssite.lat = '6.396297','52.812204'; # Dwingeloo telescope
		else:
			print 'Unknown observatory site!'

		if self._pltmoon == 1:
			self._moon = ephem.Moon();
			self._casa = ephem.readdb('Cas-A,f|J, 23:23:26.0, 58:48:00,99.00,2000');

		if matplotFound ==0 & ephemFound == 0:
			print 'Matplotlib or pyephem not found! PNG Images written to disk.'
			self._wrpng = 1;
		else:
			self._imgplt = plt.imshow (abs(self._im[0]._skymap[:,:]), extent = [self._im[0]._l[-1], self._im[0]._l[0], self._im[0]._m[-1], self._im[0]._m[0]]);
			plt.grid;
			plt.colorbar();
			# plt.show();

	def showImg (self):
		if self._pltmoon == 1:
			# Convert UTC unix time to datetime
			self._obssite.date = datetime.datetime.fromtimestamp(self._im[0]._tobs); 

			# Compute azi/alt
			self._moon.compute(self._obssite);
			self._casa.compute(self._obssite);


			if self._moon.alt < 0:
				print 'Moon below horizon at time ', self._obssite.date;
			else:
				# Compute l,m of moon's position, in units of array indices

				moon_l = -(numpy.cos(self._moon.alt) * numpy.sin(self._moon.az));
				moon_m =  (numpy.cos(self._moon.alt) * numpy.cos(self._moon.az)); 
				print 'moon l/m: %f, %f' % (moon_l, moon_m);
				# moon_l = moon_l/self._im[0]._dl + self._im[0]._npix/2;
				# moon_m = moon_m/self._im[0]._dl + self._im[0]._npix/2;
				# print 'Moon: RA/dec = %f/%f, alt/az = %f/%f, lind/mind = %f/%f, dl=%f'% (self._moon.ra, self._moon.dec, self._moon.alt, self._moon.az, moon_l, moon_m, self._im._dl);

			if self._casa.alt < 0:
				print 'CasA below horizon at time ', self._obssite.date;
			else:
				casa_l = -(numpy.cos(self._casa.alt) * numpy.sin(self._casa.az));
				casa_m =  (numpy.cos(self._casa.alt) * numpy.cos(self._casa.az)); 
				print 'CasA l/m: %f, %f' % (casa_l, casa_m);
				# casa_l = casa_l/self._im[0]._dl + self._im[0]._npix/2;
				# casa_m = casa_m/self._im[0]._dl + self._im[0]._npix/2;
				# print 'CasA: RA/dec = %f/%f, alt/az = %f/%f, lind/mind = %f/%f, dl=%f'% (self._casa.ra, self._casa.dec, self._casa.alt, self._casa.az, casa_l, casa_m, self._im._dl);

		self._imgplt.set_data (abs(self._im[0]._skymap[:,:]));

		plt.title ('%s - %f' % (self._im[0]._pol, self._im[0]._tobs));
		# if self._moon.alt > 0:
			# self._im[0]._skymap[moon_m-1:moon_m+1, moon_l-1:moon_l+1] = 5e10;	
			# plt.annotate ('*',xy=(-moon_l,-moon_m),color='yellow');
		# plt.annotate ('*',xy=(-casa_m,casa_l),color='white');
		plt.draw();
		plt.pause(0.001);
		if self._wrpng == 1:
			plt.savefig ('%s/%.0f_XX.png' % (self._fprefix,self._im[0]._tobs));
	
	
if __name__ == '__main__':
	if numpyFound == 0 | scipyFound == 0:
		print '### Numpy and/or scipy not found; unable to proceed.';
		sys.exit(-1);
	o = optparse.OptionParser()
	o.set_usage('vismon.py [options]')
	o.set_description(__doc__)

	o.add_option('-i', '--in', dest='fin', 
    	help='Specify the source of visibilities to image. Prefix with file: if reading from file, or tcp: if reading from network.');

	o.add_option('-o', '--out', dest='fout', default='./',
		help='Specify the prefix of output files.  If it exists, generated images will be added to the map file.  Othewise, the file will be created.');

	o.add_option('-m', '--mode', dest='mode', default='fft', 
		help='Mode of imaging: dft or fft');

	o.add_option('-n', '--npix', type='int', dest='npix', default=512,
		help='Number of pixels in output image');

	o.add_option('-s', '--sbnum', dest='sbnum', default='sb0',
		help='Subband number being handled');

	o.add_option('-l', '--loc', dest='loc', default='lofar',
		help='Location of observatory');

	o.add_option('-p', '--pols', dest='pols', default='xx,xy,yx,yy',
		help='Polarizations to image.');

	o.add_option('-f', '--freq', dest='freq', default=60000000,
		help='Center frequency of the subband to be imaged.');

	opts, args = o.parse_args(sys.argv[1:])

	sb = subbandHandler (opts.fin, opts.sbnum, int(opts.freq));
	pols = ['xx', 'xy', 'yx', 'yy'];
	im = [];
	for pol in range (0,4):
		im.append (imager (opts.npix, opts.mode, int(opts.freq), opts.sbnum, pols[pol]));

	irec = 0;

	# First record reading
	acm, tobs, fobs = sb.readRec();
	for pol in range (0,3):
		im[pol].createImage (acm, tobs, fobs);

	pltwin = pltImage (im, opts.loc, opts.fout, pltmoon=1);
	"""
	# Generate output file name based on first timeinstant
	print '--> Writing with prefix ', opts.fout;
	fname = '%s/%.0f_XX.img' % (opts.fout, tobs);
	print 'Filename:', fname;
	fid = open (fname, "wb");
	im.writeMetaToFile (fid); # Write out the meta information.
	im.writeImgToFile (fid);
	"""

	while irec < subbandHandler.Nsec2Rd:
		acm, tobs, fobs = sb.readRec();
		for pol in range (0,3):
			im[pol].createImage (acm, tobs, fobs);
		pltwin.showImg();
		# im.writeImgToFile (fid);
		irec = irec + 1;
