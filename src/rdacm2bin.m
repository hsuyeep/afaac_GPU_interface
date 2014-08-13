% Script to read the output of wracm2bin.c. 
% Operates on the GPU correlator output format as specified in Visibilities.h
% of Romeins GPU correlator (Triple-A) code.
% pep/02Jun14
function acc = rdacm2bin (fname)
	dat = load (fname);
	tim = dat(:,1); % Timestamps of every ACM
	acc = dat (:,2:end); % Split time
	acm = complex (acc(:,1:2:end), acc(:,2:2:end));
	clear acc;
	acc = zeros (30, 288, 288);
	tmp = triu(ones (288));
	for ind = 1:30
		acc(ind,:,:) = tmp;
		acc(ind,acc(ind,:,:)==1) =acm(ind,:);
		acc(ind,:,:) = squeeze(acc(ind,:,:)) + squeeze(acc(ind,:,:))' - diag(diag(squeeze(acc(ind,:,:))));
		% acc(ind,acc(ind,:,:)==0) = acm(ind,:)';
	end;
	

