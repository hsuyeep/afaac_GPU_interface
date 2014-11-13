% Script to apply interstation delays as a phase ramp on correlated 
% visibilities across a subband.
% pep/23Oct14
% Arguments: 
%  fobs: Observation frequency in Hz.
%  fixed_del : Inter station delays wrt. common reference within Superterp.

function [acc, phasor] = applystationdelays (acm, fobs, pos, flagant)
	% In CS00[2-7] order.
	fixed_del = [ones(1,48)*8.339918e-06, ones(1,48)*6.936566e-06, ones(1,48)*7.905512e-06, ones(1,48)*8.556805e-06, ones(1,48)*7.905282e-06, ones(1,48)*7.928823e-06]; % In secs.

	goodant = setdiff ([1:288], flagant);

	% ((295.5 + subband) * 195312.5));
	if pos == 1
		[phix, phiy] = meshgrid (2 * pi * fobs * fixed_del(goodant));
	else
		[phix, phiy] = meshgrid (-2 * pi * fobs * fixed_del(goodant));
	end;

	phasor = exp(1i*(phix - phiy));
	acc = acm .* phasor;
