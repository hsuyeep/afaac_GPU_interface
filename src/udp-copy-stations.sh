#!/bin/bash
stat=2;
# for port in 53276 53284 53292 53300 53308; do
for port in 53276 53292 53300 53308; do
	echo "Recording from port $port"
	timeout 8 udp-copy 0:$port `date -u +%d%b%g_%H%M%S`_$port.bin &
done;
