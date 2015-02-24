#!/usr/bin/python
# Script to extract out a segment of a gpu correlated visibility dataset.
# pep/i23Feb15

import sys;
import socket;
import optparse;
import time, datetime;
import struct;
import optparse;


if __name__ == '__main__':
	o = optparse.OptionParser();
	o.set_usage('splitgpuvis.py [options]')
	o.set_description(__doc__)

	o.add_option('-i', '--in', dest='fin', help='Specify the source of visibilities to split.'); 

	o.add_option('-o', '--out', dest='fout', default='./',
		help='Specify the directory containing the output file.');  

	o.add_option('-r', '--range', dest='trange', 
		help='timerange to extract, as start:end in ctime units.');

	opts, args = o.parse_args(sys.argv[1:])
	print opts.fin, opts.fout, opts.trange;
	
	tstart = int(opts.trange.split(':')[0]);
	tend   = int(opts.trange.split(':')[1]);
	fid = open (opts.fin, "rb");	
	foutname = '%s/%d-%d' % (opts.fout, tstart, tend);
	print '<-- Creating output file ', foutname;
	fout = open (foutname, "wb");

	Nelem  = 288;       
	Nbline= Nelem*(Nelem+1)/2; 
	Nchan = 63;
	Npol = 4;
	NRec2Buf = 2; # Number of records in local buffer.
	Hdrsize = 512;
	Recsize = Hdrsize + Nbline*Nchan*Npol*2*4; # 4 is for sizeof (float), 2 is for complex float.

	
	rec = fid.read (Recsize);
	(magic, pad0, tfirst, endTime) = struct.unpack ("<IIdd", rec[0:24]);
	fid.seek (-Recsize, 2);

	rec = fid.read (Recsize);
	(magic, pad0, tlast, endTime) = struct.unpack ("<IIdd", rec[0:24]);
	
	print 'Timerange : %f - %f' % (tfirst, tlast);
	assert (tstart < tlast);
	assert (tend > tfirst);
	recs2skip = int(tstart - tfirst);
	fid.seek (recs2skip*Recsize, 0);

	rec = fid.read (Recsize);
	(magic, pad0, tcurr, endTime) = struct.unpack ("<IIdd", rec[0:24]);

	while (tcurr < tend):
		bytearr = bytearray (rec);
		fout.write (bytearr);
		rec = fid.read (Recsize);
		(magic, pad0, tcurr, endTime) = struct.unpack ("<IIdd", rec[0:24]);
		print tcurr;
		
	
