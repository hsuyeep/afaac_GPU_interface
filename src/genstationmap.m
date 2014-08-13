% Script to generate uncalibrated images from each station of AARTFAAC
function [map] = genstationmap (acc, station, poslocal, l, freq)
	m = l;
	indbeg = (station-1)*48 + 1;
	indend = (station*48);
	map = acm2skyimage (acc(indbeg:indend,indbeg:indend), poslocal(indbeg:indend,1), poslocal(indbeg:indend,2), freq, l, m);

