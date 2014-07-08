/* Program to convert raw RSP board data recorded onto CEP nodes 
 * (see Afaac_cep/udp-copy-8bit.c) into the format accepted by the GPU correlator.
 * This allows prerecorded data to be correlated with both the PC and the GPU
 * correlator.
 *   Program generates a single station output, which is available in the output
 *   of 4 RSP boards.
 * pep/07Jul14
 */


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

// Data format of the AARTFAAC Uniboard output packets.
typedef struct                                                                     
{ unsigned long long rsp_reserved_1:59;
  unsigned int rsp_rsp_clock:1;
  unsigned int rsp_sdo_mode:2;
  unsigned int rsp_lane_id:2;
  unsigned int rsp_station_id:16;
  unsigned int nof_words_per_block:16; // 8sbbands X 96 dipoles=768 (4B = 1 word)  
  unsigned int nof_blocks_per_packet:16;// 2                                       
  unsigned int rsp_sync:1;
  unsigned int rsp_reserved_0:13;
  unsigned long long rsp_bsn:50;        // Two timeslices share the same BSN       
}__attribute ((__packed__)) UniHdrType ;                                                  
                                                                                   
#define NRUNISUBBANDS 8                                                            
#define NRUNIDIPOLES 96                                                               
/* Uniboard data format:
 UDPhdr->userhdr(22B)->
 |d0_sb0_t0_p0_[r,i]...d95_sb0_t0_p1_[r,i]|... //subband 0
 |d0_sb7_t0_p1_[r,i]...d95_sb7_t0_p1_[r,i]|... // ts0

 |d0_sb0_t1_p0_[r,i]...d95_sb0_t1_p1_[r,i]|...
 |d0_sb7_t1_p0_[r,i]...d95_sb7_t1_p1_[r,i]|    // ts1
 d = dipole 0-95, p = pol 0 or 1 of an antenna, sb = subband, t = time sample,
 [r,i] = real/imag.
 1 UDP packet = 2 timeslices, 8 subbands, 96 dipoles.
*/
typedef struct                                                                     
{ short data [NRUNISUBBANDS*NRUNIDIPOLES*2];    
} UniBlkType;                                                                      
                                                                                   
typedef struct                                                                     
{ UniHdrType hdr;
  UniBlkType blk[2]; // Two timeslices
} UniUDPPktType;

#define DEBUG 0

int main (int argc, char *argv[])
{ FILE *frsp[4] = {NULL,};
  FILE *funi = NULL;
  RSPPktType rsppkt[4];
  UniUDPPktType unipkt;
  UniBlkType *blk = NULL;
  int i = 0, j = 0, rd = 0;
  unsigned int pktno = 0, max = 0;
  unsigned int prevseq[4] = {0,};

  int ts=0, sb=0, rsp=0, dip=0; 

  if (argc != 6)
  { fprintf (stderr, "Usage: %s rsp0 rsp1 rsp2 rsp3 unifile\n", argv[0]); 
	return -1;
  }

  fprintf (stderr, "Opening files...\n");
  for (i=0; i<4; i++)
  { if ((frsp[i] = fopen (argv[i+1], "rb")) < 0)
	{ perror ("feof"); return -1;}
  }

  if ((funi=fopen (argv[5], "wb")) < 0)
  { fprintf (stderr, "Error in opening output file.\n"); }
 
  while (1)
  { max = 0;
    for (i=0; i<4; i++)
    { if ((rd=fread ((unsigned char*)(rsppkt+i), 1, sizeof (RSPPktType), 
		   frsp[i])) != sizeof (RSPPktType))
      {fprintf(stderr, "Error in packet rd %d from RSP board %d.\n", pktno, i);}

  	  if (max < rsppkt[i].hdr.timestamp) max = rsppkt[i].hdr.timestamp;
    }
    
    // Align packets on timestamp + BSN number, so to absolute time.
    for (i=0; i<4; i++)
    { while (rsppkt[i].hdr.timestamp != max)
      { if ((rd=fread ((unsigned char*)(rsppkt+i), 1, sizeof (RSPPktType), 
			 frsp[i])) != sizeof (RSPPktType))
        { fprintf(stderr, "Error in packet rd %d from RSP board %d.\n", 
				  pktno, i);
        }
      }
    }

    fprintf (stderr, "Pkt %d: %d/%d  %d/%d  %d/%d  %d/%d\n", pktno,
		 rsppkt[0].hdr.timestamp, rsppkt[0].hdr.blockSequenceNumber-prevseq[0],
		 rsppkt[1].hdr.timestamp, rsppkt[1].hdr.blockSequenceNumber-prevseq[1],
		 rsppkt[2].hdr.timestamp, rsppkt[2].hdr.blockSequenceNumber-prevseq[2],
		 rsppkt[3].hdr.timestamp, rsppkt[3].hdr.blockSequenceNumber-prevseq[3]);

    prevseq[0] =  rsppkt[0].hdr.blockSequenceNumber;
    prevseq[1] =  rsppkt[1].hdr.blockSequenceNumber;
    prevseq[2] =  rsppkt[2].hdr.blockSequenceNumber;
    prevseq[3] =  rsppkt[3].hdr.blockSequenceNumber;


    // Reformat the packet contents into Uniboard output type.
    unipkt.hdr.nof_words_per_block = 768;
    unipkt.hdr.nof_blocks_per_packet = 2;
    // Note that only the BSN of the first timeslice(of the two in a 
	// UniUDPPktType) is planted into the UniUDPPktType hdr.
    unipkt.hdr.rsp_bsn = rsppkt[0].hdr.blockSequenceNumber;
  
    for (ts=0; ts<16; ts++)
    { blk = &unipkt.blk[ts%2];
      for (sb=0; sb<8; sb++)
      { short *sbdata = blk->data + sb*(NRUNIDIPOLES*2);
        for (rsp=0; rsp<4; rsp++)
    	  { for (dip=0; dip<12; dip++)
          { 
  #if DEBUG
              fprintf (stderr, "DEB: ts=%d, sb=%d,rsp=%d, dip=%d\n", ts, sb, rsp, dip);
  #endif 
  		  if (sb == 0)
            { // Re, pol 0
			  sbdata[rsp*24 + 4*dip  ] = rsppkt[rsp].data[2*dip  ][ts][0][0];
			  // Im, pol 0
              sbdata[rsp*24 + 4*dip+1] = rsppkt[rsp].data[2*dip  ][ts][0][1];
			  // Re, pol 1
              sbdata[rsp*24 + 4*dip+2] = rsppkt[rsp].data[2*dip+1][ts][0][0];
			  // Im, pol 1
              sbdata[rsp*24 + 4*dip+3] = rsppkt[rsp].data[2*dip+1][ts][0][1];
            }
  
            else if (sb == 1)
            { // Re, pol 0
			  sbdata[rsp*24 + 4*dip  ] = rsppkt[rsp].data[2*dip  ][ts][1][0];
			  // Im, pol 0
              sbdata[rsp*24 + 4*dip+1] = rsppkt[rsp].data[2*dip  ][ts][1][1];
			  // Re, pol 1
              sbdata[rsp*24 + 4*dip+2] = rsppkt[rsp].data[2*dip+1][ts][1][0];
			  // Im, pol 1
              sbdata[rsp*24 + 4*dip+3] = rsppkt[rsp].data[2*dip+1][ts][1][1];
            }
  
  		  else 
            { sbdata[rsp*24 + 4*dip  ] = 0;
              sbdata[rsp*24 + 4*dip+1] = 0;
              sbdata[rsp*24 + 4*dip+2] = 0;
              sbdata[rsp*24 + 4*dip+3] = 0;
            }
          }
        }
      }
  
      if ((ts%2) == 1)
  	  { // Dispatch UniPktType, first derive BSN relative to that of the first 
        // timeslice within the rsppacket. Arbit. choose RSP0 for ref.
        unipkt.hdr.rsp_bsn = (rsppkt[0].hdr.timestamp * (200000000/512) + 1)/2 + 
							  rsppkt[0].hdr.blockSequenceNumber + ts;
  	    fwrite ((unsigned char*)(&unipkt), 1, sizeof (UniUDPPktType), funi);
  	  }
    } 
    if (feof (frsp[0]) != 0) break;
	pktno++;
  }


  for (i=0; i<4; i++) if (frsp[i]) fclose (frsp[i]);
  fclose (funi);

  return 0;
}
