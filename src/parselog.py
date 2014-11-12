#!/usr/bin/python
# Simple script to parse the correlator logfile

import sys
import re
import datetime


from matplotlib import lines
import matplotlib.pyplot as plt
import numpy as np

NUM_STATIONS = 6

if __name__ == "__main__":
    flagged = re.compile ('\[(\d+)s, (\d+)\], stats (\d+)-(\d+); flagged: ([-+]?(\d+(\.\d*)?))% \((\d+)\)');

    maxsize = 1000000
    times = np.zeros(maxsize, dtype=np.uint32)
    stations = np.zeros((NUM_STATIONS, maxsize), dtype=np.float16)

    i = 0
    with open(sys.argv[1]) as f:
        for l in f:
            if 'stat' in l:
                m = flagged.match(l)

                if not m:
                    continue

                time = np.uint32(m.group(1))
                station = int(m.group(3)) / 48
                flag = np.float16(m.group(5))
                assert(station >= 0 and station <= 5)
                assert(flag >= 0 and flag <= 100)

                if times[i] == 0:
                    times[i] = time
                stations[station][i] = flag
                
                if station == 5:
                    i += 1
                else:
                    assert(times[i] == time)

            if i >= maxsize:
                break
                

    points = 1280

    fig = plt.figure(frameon = False)
    fig.set_size_inches(points/96.0, 500/96.0)

    points = min(points, i)
    l = i - (i % points)
    r = l / points
    T = times[0:l]
    I = T.argsort()
    T = T[I].reshape(points, r).mean(axis=1, dtype=np.float64)
    for s in range(NUM_STATIONS):
        S = stations[s][0:l]
        S = S[I].reshape(points, r).mean(axis=1, dtype=np.float64)
        plt.plot(T, S, label=('CS00%i' % (s+2)))
    plt.xlabel('unix time')
    plt.ylabel('% flagged')
    plt.ylim([-1, 101])
    plt.suptitle('GPU Correlator flagging')
    plt.legend()
    plt.savefig("flagged.png", dpi=96)
