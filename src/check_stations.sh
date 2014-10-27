#!/bin/bash
declare -A port2station=( ["53268"]="CS002" ["53276"]="CS003" ["53284"]="CS004" ["53292"]="CS005" ["53300"]="CS006" ["53308"]="CS007" );
# for port in 53268 53276 53284 53292 53300 53308; do
for port in ${!port2station[@]}; do
	# printf "\n\n--> Checking port $port, station ${port2station["$port"]}\n"
	printf "\n\n--> Checking port $port, station ${port2station[$port]}.\n"
	sudo timeout 2 tcpdump -vvxSnelfi eth2 -c 1 -s 100 udp port $port
	# sudo  tcpdump -vvxSnelfi eth2 -c 1 -s 100 udp port $port & sleep 10s && pkill -HUP -f tcpdump 
	
done;
