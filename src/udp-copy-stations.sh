#!/bin/bash
stat=2;

declare -A port2station=( ["53268"]="CS002" ["53276"]="CS003" ["53284"]="CS004" ["53292"]="CS005" ["53300"]="CS006" ["53308"]="CS007" );

# Check what ports currently have data on them
for port in ${!port2station[@]}; do
	# printf "\n\n--> Checking port $port, station ${port2station["$port"]}\n"
	printf "\n\n--> Checking port $port, station ${port2station[$port]}.\n"
	sudo timeout 2 tcpdump -vvxSnelfi eth2 -c 1 -s 100 udp port $port
done;

echo "Start recording..."
for port in ${!port2station[@]}; do
	echo "Recording from port $port, station ${port2station["$port"]}.\n"
	# timeout 8 udp-copy 0:$port `date -u +%d%b%g_%H%M%S`_${port2station["$port"]}_$port.bin &
	timeout 8 udp-copy 0:$port `date -u +%d%b%g_%H%M%S`_$port.bin &
done;
