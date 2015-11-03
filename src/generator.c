/* Script to simulate the output of the unb AARTFAAC SDO interface.
 * The output mimmics the waveform generator output of the tests, as
 * documented in ASTRON_RP_1462_AARTFAAC_Subband_Data_Offload_System.pdf
 * Peeyush, 02Nov15
 */
#define  _BSD_SOURCE

#include "common.h"

#include <assert.h>
#include <byteswap.h>
#include <math.h>
#include <omp.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>
#include <arpa/inet.h>

#define MAX_SOCKETS	64


double   SampleRate    = 195312.5; // Assumes 200 MHz sampling clock, 1024pt PFB
unsigned Subbands      = 61;
unsigned Samples2Frame = 16;
unsigned Dipoles2Frame = 96;
unsigned BitsPerSample = 16;
double BeginTime = 0;

//enum header_format header_format = SECONDS_PLUS_FRACTION;
enum header_format header_format = CONSECUTIVE_64_BIT;

char	 packet[MAX_SOCKETS][9000];
unsigned message_size;
int	 sockets[MAX_SOCKETS];
unsigned nr_sockets	   = 0;
unsigned packets_sent[MAX_SOCKETS], skipped[MAX_SOCKETS], errors[MAX_SOCKETS];
char     names[MAX_SOCKETS][64];


#if 0
// Format of header struct used by John Romein in his correlator code.
typedef struct 
{
  uint64_t rsp_lane_id : 2;
  uint64_t rsp_sdo_mode : 2;
  uint64_t rsp_rsp_clock : 1;
  uint64_t rsp_reserved_1 : 59;

  uint16_t rsp_station_id;
  uint16_t nof_words_per_block;
  uint16_t nof_blocks_per_packet;

  uint64_t rsp_bsn /*: 50;
  uint64_t rsp_reserved_0 : 13;
  uint64_t rsp_sync : 1*/;

  //uint8_t  pad[8];
  //uint64_t block_seqno;
}__attribute ((__packed__)) UniHdrType ;                                                  
#endif

// Data format of the AARTFAAC Uniboard output packets.
// NOTE: Each field needs to be converted to network order (big endian)
// while the bsn field needs a bswap_64!
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

void *log_thread(void *arg)
{
  while (1) {
    sleep(1);

    for (unsigned socket_nr = 0; socket_nr < nr_sockets; socket_nr ++) {
      if (packets_sent[socket_nr] > 0 || errors[socket_nr] > 0)  
      { fprintf(stderr, "sent %u packets to %s, skipped = %u, errors = %u\n", 
         packets_sent[socket_nr], names[socket_nr], skipped[socket_nr], errors[socket_nr]);
	packets_sent[socket_nr] = errors[socket_nr] = 0; // ignore race
      }

      skipped[socket_nr] = 0;
    }
  }

  return 0;
}


void send_packet(unsigned socket_nr, unsigned long long packet_time)
{ unsigned long long recov_time = 0;
  UniHdrType *hdr = (UniHdrType*) packet[socket_nr];

  switch (header_format) {
    case SECONDS_PLUS_FRACTION: {
	unsigned clock_speed = 1024 * SampleRate;
	unsigned seconds  = 1024 * packet_time / clock_speed;
	unsigned fraction = 1024 * packet_time % clock_speed / 1024;

#if defined __BIG_ENDIAN__
	* (int *) (packet[socket_nr] +  8) = __bswap_32(seconds);
	* (int *) (packet[socket_nr] + 12) = __bswap_32(fraction);
#else
	* (int *) (packet[socket_nr] +  8) = seconds;
	* (int *) (packet[socket_nr] + 12) = fraction;
#endif
      }

      break;

      case CONSECUTIVE_64_BIT: {
	hdr->rsp_station_id = htons(socket_nr+2); // CS002 is always 2.
	hdr->nof_words_per_block = htons(Dipoles2Frame*Subbands);
	hdr->nof_blocks_per_packet = htons(Samples2Frame);

#if defined __BIG_ENDIAN__
	* (unsigned long long *) (packet[socket_nr] + 14) = packet_time;
#else
	* (unsigned long long *) (packet[socket_nr] + 14) = __bswap_64(packet_time);
#endif
      }
  }

  ++ packets_sent[socket_nr];

#if 1
  recov_time = __bswap_64(*((unsigned long long*)(packet[socket_nr]+14)));
  // fprintf (stderr, "--> Socket no: %d, time: %llu, %f\n", socket_nr, recov_time, recov_time/SampleRate);
  for (unsigned bytes_written = 0; bytes_written < message_size;) {
    ssize_t retval = write(sockets[socket_nr], &packet[socket_nr] + bytes_written, message_size - bytes_written);

    if (retval < 0) {
      ++ errors[socket_nr];
      perror("write");
      sleep(1);
      break;
    } else {
      bytes_written += retval;
    }
  }
#endif
}


void parse_args(int argc, char **argv)
{
  if (argc == 1) {
    fprintf(stderr, "usage: %s [-u unixtimestamp -f frequency (default 195312.5)] [-s Subbands (default 61)] [-t times_per_frame (default 16)] [-d Samples2Frame (default 1)] [udp:ip:port | tcp:ip:port | file:name | null: | - ] ... \n", argv[0]);
    exit(1);
  }

  int arg;

  for (arg = 1; arg < argc && argv[arg][0] == '-'; arg ++)
    switch (argv[arg][1]) {
      case 'a': set_affinity(argument(&arg, argv));
		break;

      case 'b': BitsPerSample = atoi(argument(&arg, argv));
		break;

      case 'f': SampleRate = atof(argument(&arg, argv));
		break;

      case 'h': header_format = (enum header_format) atoi(argument(&arg, argv));
		break;

      case 'r': set_real_time_priority();
		break;

      case 's': Subbands = atoi(argument(&arg, argv));
		break;

      case 't': Samples2Frame = atoi(argument(&arg, argv));
		break;
      case 'd': Samples2Frame = atoi (argument(&arg, argv));

      case 'u': BeginTime = atoi (argument(&arg, argv));

      default : fprintf(stderr, "unrecognized option '%c'\n", argv[arg][1]);
		exit(1);
    }

  if (arg == argc)
    exit(0);

  enum proto proto;

  for (nr_sockets = 0; arg != argc && nr_sockets < MAX_SOCKETS; arg ++, nr_sockets ++)
  { fprintf (stderr, "<-- Associating file %s with socket number %d.\n", argv[arg], nr_sockets);
    sockets[nr_sockets] = create_fd(argv[arg], 1, &proto, names[nr_sockets], sizeof names[nr_sockets]);
  }

  if (arg != argc)
    fprintf(stderr, "Warning: too many sockets specified\n");
}


void fill_packet(unsigned socket_nr, unsigned long long packet_time)
{ int dipstride = 2*2; // 2*2 = Re/im, 2 bytes each (16bit mode)
                       // Move by this count in bytes to go from one dip to another. 
                       //
  // Bytes to move from one subband to another consecutive one.
  int sbstride  = dipstride * Dipoles2Frame;  
  // Bytes to move from one timeslice to another consecutive one.
  int tstride   =  sbstride * Subbands; 

  float ph_inc = 2*M_PI/288, amp_inc = 1./288, re, im;

  for (int t = 0; t<Samples2Frame; t++)
  { unsigned char *tslice = packet[socket_nr] + 22 + t*tstride; // 22B SDO header

    for (int sb = 0; sb < 8; sb++)
    { unsigned short *sbslice = (unsigned short*) (tslice + sb*sbstride);

      for (int dip=0; dip<Dipoles2Frame/2; dip++)
      { // Address of this station within all 6.
        int global_dip = socket_nr * Dipoles2Frame/2 + dip; 

	// Fill in the X-dipoles
        re = amp_inc * global_dip * cos ( global_dip * ph_inc);
        im = amp_inc * global_dip * sin ( global_dip * ph_inc);
        sbslice [4*dip    ] = (short) (floor (re*32767));
        sbslice [4*dip + 1] = (short) (floor (im*32767));

	// Fill in the Y-dipoles
        re = amp_inc * global_dip * cos ( global_dip * 2 * ph_inc);
        im = amp_inc * global_dip * sin ( global_dip * 2 * ph_inc);
        sbslice [4*dip + 2] = (short) (floor (re*32767));
        sbslice [4*dip + 3] = (short) (floor (im*32767));
        // fprintf (stderr, "val : %6.4f %6.4f %6.4f   %5d %5d\n", re, im, atan2(im, re), sbslice[2*dip], sbslice[2*dip+1]);
      }
    }
  }
}

int main(int argc, char **argv)
{
  if_BGP_set_default_affinity();
  parse_args(argc, argv);
  message_size = (header_format == 0 ? 16 : 22) + Samples2Frame*Dipoles2Frame * Subbands * BitsPerSample / 8 * 2;
  fprintf (stderr, "<-- Message size: %d Bytes\n", message_size);

  pthread_t thread;

  if (pthread_create(&thread, 0, log_thread, 0) != 0) {
    perror("pthread_create");
    exit(1);
  }

  struct timeval now;
/*
  if (BeginTime != 0)
  { now.tv_sec = BeginTime;
    now.tv_usec = (BeginTime - floor (BeginTime))*1e6;
  }
  else 
*/
    gettimeofday(&now, 0);
  fprintf (stderr, "<-- Setting Starting timestamp to %f\n", now.tv_sec+now.tv_usec/1e6);

#pragma omp parallel num_threads(nr_sockets)
  {
    unsigned long long packet_time = (now.tv_sec + now.tv_usec / 1e6) * SampleRate;
    unsigned long long end_packet_time = (now.tv_sec + 2 + now.tv_usec / 1e6) * SampleRate;
    unsigned socket_nr = omp_get_thread_num();
    fprintf (stderr, "<-- Thread %d, start time :%ld\n", socket_nr, packet_time);
    while (packet_time < end_packet_time) {
      packet_time += Samples2Frame;

#if 0
      gettimeofday(&now, 0);
      unsigned long long now_us = 1000000ULL * now.tv_sec + now.tv_usec;
      unsigned long long pkt_us = 1000000ULL * (packet_time / SampleRate);

      long long wait_us = pkt_us - now_us;

      if (wait_us > 10)
	usleep(wait_us);
      else if (pkt_us + 100000 < now_us) {
	unsigned skip = (unsigned long long) (-wait_us * 1e-6 * SampleRate) / Samples2Frame;
	skipped[socket_nr] += skip;
	packet_time += skip * Samples2Frame; // skip packets; keep modulo(Samples2Frame)
      }
#endif

#if 1
      fill_packet(socket_nr, packet_time);
#endif

      send_packet(socket_nr, packet_time);
    }
   #pragma omp barrier 
  }

  return 0;
}
