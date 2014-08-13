
#include <stdio.h>
#include <errno.h>
#include <stdint.h>
#include <complex.h>

// Data format of the RSP board output packets.
#define NRRSPSUBBANDS 2  // NOTE: Only valid for 24Hr. observations!
#define NRRSPTIMES 16    // 2 subbands, 8bit complex, 2 pol.
#define NRRSPPOL 2
  
typedef struct 
{
  struct {
    uint8_t  version;
    uint8_t  sourceInfo;
    uint16_t configuration;
    uint16_t station;
    uint8_t  nrBeamlets;
    uint8_t  nrBlocks;
    uint32_t timestamp;
    uint32_t blockSequenceNumber;
  } hdr;
  // char       data[NRRSPSUBBANDS * NRRSPTIMES * NRRSPPOL * 2];
  char       data[24][16][2][2];
}__attribute((__packed__)) RSPPktType;
// RSP board data format: 
// 2 pols of 12 dipoles (=24), 16 timesamples, 2 subbands, re/im.

int Done = 0;
int main (int argc, char *argv[])
{ FILE *frsp = NULL;
  RSPPktType rsppkt;
  int i = 0, j = 0, rd = 0;
  unsigned int pktno = 0, max = 0;
  unsigned int prevseq[4] = {0,};

  int ts=0, sb=0, rsp=0, dip=0; 

  if ((frsp=fopen (argv[1], "rb")) < 0)
  { fprintf (stderr, "Error in opening input file.\n"); return -1;}

  while (Done == 0)
  { if ((rd=fread ((unsigned char*)(&rsppkt), 1, sizeof (RSPPktType), 
		   frsp)) != sizeof (RSPPktType))
    { fprintf(stderr, "Error in packet rd %d from RSP board %d.\n", pktno, i);
	  if (feof (frsp)) Done = 1;	
    }

    fprintf (stderr, "0x%0x 0x%0x\n", 
			 rsppkt.hdr.timestamp, rsppkt.hdr.blockSequenceNumber);
  }

  if (frsp) fclose (frsp);
  return 0;
}
