/* Copyright 2008, John W. Romein, Stichting ASTRON
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */
/* Program modified to accomodate the URI-uniboard data format and selection of dipoles
 * and subbands within the packet. Please see showunbhdr.c for the uniboard hdr format
 * and decodepkt.c for a comparison with the python decoding of the data.
 * pep/13Aug15
 */


#define  _GNU_SOURCE
#include "common.h"

#include <sched.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/if_ether.h>
#include <linux/if_packet.h>
#include <linux/filter.h>
#include <netdb.h>
#include <netinet/in.h>
#include <assert.h>
#include <poll.h>
#include <pthread.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <arpa/inet.h>

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
                                                                                   
#define NR_UNI_SUBBAND 8                                                            
#define NR_UNI_DIPOLE 96                                                               
#define NR_TSLICE_PKT 2                                                               
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
{ short data [NR_UNI_SUBBAND*NR_UNI_DIPOLE*2];  // For complex input   
} UniBlkType;                                                                      
                                                                                   
typedef struct                                                                     
{ UniHdrType hdr;
  UniBlkType blk[NR_TSLICE_PKT]; // Two timeslices
} UniUDPPktType;

/* Output packet */
typedef struct                                                                     
{ short data [3*6*2];  // For complex output, 3 subbands, 6 dipoles, short complex
} UniOutBlkType;                                                                      

typedef struct
{ UniHdrType hdr;
  UniOutBlkType blk[NR_TSLICE_PKT]; // Two timeslices
} OutPktType;
  
enum proto input_proto, output_proto;
char	   source[64], destination[64];

int	   sk_in, sk_out;
unsigned   nr_packets = 0, nr_bytes = 0;


void *log_thread(void *arg)
{
  while (1) {
    sleep(1);

    if (nr_packets > 0) {
      if (input_proto == UDP || input_proto == Eth)
	fprintf(stderr, "copied %u bytes (= %u packets) from %s to %s\n", nr_bytes, nr_packets, source, destination);
      else
	fprintf(stderr, "copied %u bytes from %s to %s\n", nr_bytes, source, destination);

      nr_packets = nr_bytes = 0;
    }
  }

  return 0;
}


void init(int argc, char **argv)
{
  int arg;

  for (arg = 1; arg < argc && argv[arg][0] == '-' && argv[arg][1] != '\0'; arg ++)
    switch (argv[arg][1]) {
      case 'r': set_real_time_priority();
		break;
    }

  if (arg + 2 != argc) {
    fprintf(stderr, "Usage: \"%s [-r] src-addr dest-addr\", where -r sets RT priority and addr is [tcp:|udp:]ip-addr:port or [file:]filename\n", argv[0]);
    exit(1);
  }

  sk_in  = create_fd(argv[arg], 0, &input_proto, source, sizeof source);
  sk_out = create_fd(argv[arg + 1], 1, &output_proto, destination, sizeof destination);

  setlinebuf(stdout);
  if_BGP_set_default_affinity();
}


int main(int argc, char **argv)
{
  time_t   previous_time = 0, current_time;
  unsigned i;
  char	   buffer[1024 * 1024] __attribute__ ((aligned(16)));
  int      read_size, write_size;
  int dip_sel[] = {0,1,47,48,94,95}; // three dual-pol antennas, should be roughly equidistant.
  int dip_sel_size = 6;
  int sb_sel[] = {0,1,2};
  int sb_sel_size = 3;
  int re_ind = 0, im_ind = 0;
  int t,sb,re,im,dip;

  UniUDPPktType in_packet;
  OutPktType out_packet;

  unsigned int bad = 0;
  init(argc, argv);

#if defined USE_RING_BUFFER
  if (input_proto == Eth) {
    unsigned offset = 0;
    while (1) {
      void *frame = ((char *) ring_buffer + offset * 8192);
      struct tpacket_hdr *hdr = frame;

#if 1
      if (hdr->tp_status == TP_STATUS_KERNEL) {
	struct pollfd pfd;

	pfd.fd = sk_in;
	pfd.revents = 0;
	pfd.events = POLLIN|POLLERR;

	if (poll(&pfd, 1, -1) < 0)
	  perror("poll");
      }
#else
      while (* (volatile long *) &hdr->tp_status == TP_STATUS_KERNEL)
	;
#endif

      assert((hdr->tp_status & 1) == TP_STATUS_USER); // FIXME

      unsigned char *mac = (char *) frame + hdr->tp_mac;
      unsigned char *data = (char *) frame + hdr->tp_net;

      if (write(sk_out, data, hdr->tp_snaplen) < hdr->tp_snaplen) {
	perror("write");
	sleep(1);
      } else {
	nr_bytes += hdr->tp_snaplen;
      }

      ++ nr_packets;

      if ((current_time = time(0)) != previous_time) {
	previous_time = current_time;

	fprintf(stderr, "ok: copied %u bytes (= %u packets) from %s to %s\n", nr_bytes, nr_packets, source, destination);
	nr_packets = nr_bytes = 0;
      }

      hdr->tp_status = TP_STATUS_KERNEL;

      if (++ offset == 1024)
	offset = 0;
    }
  }
#endif
  pthread_t thread;

  if (pthread_create(&thread, 0, log_thread, 0) != 0) {
    perror("pthread_create");
    exit(1);
  }

  // size_t max_size = output_proto == UDP ? 8960 : 1024 * 1024;
  size_t max_size = output_proto == UDP ? sizeof (UniUDPPktType): 1024 * 1024;

  UniUDPPktType *inpkt = (UniUDPPktType*) buffer;
  OutPktType outpkt;
  short *inpayload  = (short*)(inpkt->blk);
  short *outpayload = (short*)(&outpkt.blk);
  int outcnt = 0;

  while ((read_size = read(sk_in, buffer, max_size)) != 0) 
  { if (read_size < 0) 
    { perror("read");
      sleep(1);
    } 
    else 
    { memcpy (&outpkt.hdr, &inpkt->hdr, sizeof (UniHdrType));
      outcnt = 0;
	  for (t=0; t<NR_TSLICE_PKT; t++)
	  {   for (sb=0; sb<sb_sel_size; sb++)
	      {   for (dip=0; dip<dip_sel_size; dip++)
	          {   re_ind = t*1536 + (sb_sel[sb]*96*2) + dip_sel[dip]*2; 
	              im_ind = re_ind + 1;
	              re = inpayload[re_ind]; 
	              im = inpayload[im_ind]; 
                  outpayload[outcnt]   = re;
                  outpayload[outcnt+1] = im;
                  outcnt+=2;
	              // fprintf(stderr, "SDO timesample: %d, sb: %d, dip: %02d, re/im: %7d / %7d.\n",t,sb,dip,re,im);
	          }
	      }
	  }
      write_size = 0;
      while (write_size < sizeof (outpkt)) 
      { if ((write_size = write(sk_out, &outpkt, sizeof (outpkt))) < 0) 
        { perror("write");
          sleep(1);
        } 
        else 
        { read_size -= write_size;
          nr_bytes  += write_size;
        }
      }
      ++ nr_packets;
    }
 }

  return 0;
}
