/* Program to generate a total power per polarization based on data dumped
 * to disk
*/

#define  _GNU_SOURCE
// #include "common.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdint.h>
#include <complex.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <math.h>

typedef  struct {
      uint32_t magic;
      uint32_t pad0;
      double   startTime, endTime;
      char     pad1[512 - 24];
    }HdrType;

unsigned nr_baselines = 288 * 289 / 2;
unsigned nr_channels = 63;
unsigned nr_polarizations = 4;
unsigned baseline = 0;
unsigned channel = 0;
//unsigned time = 0;
unsigned polarization = 0;

int main(int argc, char *argv[])
{
  const size_t header_size = 512;
  // FILE *fid = fopen (argv[1],  "rb");
  int fd = -1;
  float pol_pwr = 0;
  unsigned long long fsize = 0;

  fd = open (argv[1], O_RDONLY);
  HdrType *hdr = NULL;

  struct stat sb;
  if (fstat(fd, &sb) < 0) {
    perror("fstat");
    exit(1);
  }

  size_t block_size = header_size + sizeof(complex float) * nr_baselines * nr_channels * nr_polarizations;
  fprintf (stderr, "Filesize: %d, Blocksize: %lld bytes, Nblks: %d\n", 
		   (unsigned long long)sb.st_size, block_size, floor ((unsigned long long)sb.st_size/block_size));
  unsigned time = 0;
  for (time = 0; time * block_size < sb.st_size; time ++) 
  { complex float *block = mmap(0, block_size, PROT_READ, MAP_SHARED, fd, time * block_size);
    if (block == MAP_FAILED) 
    {
      perror("mmap");
      exit(1);
    }
	
    hdr = (HdrType*) block;
	// fprintf (stderr, "Time start:%.3f, end: %.3f\n", hdr->startTime, hdr->endTime);
	fprintf (stderr, "%.3f ", hdr->startTime);


	for (polarization = 0; polarization<nr_polarizations; polarization++)
    { pol_pwr = 0;
	  for (baseline=0; baseline<nr_baselines; baseline++)
        for (channel = 0; channel < nr_channels; channel ++) 
	    {
          complex float *ptr = &block[header_size / sizeof(complex float) + 
				baseline * nr_channels * nr_polarizations + 
				channel * nr_polarizations + polarization];
		  pol_pwr += cabs(ptr[0]);
        }
       printf("%f ", pol_pwr);
    }
	printf ("\n");

    if (munmap(block, block_size) != 0) {
      perror("munmap");
      exit(1);
    }
  }

  return 0;
}
