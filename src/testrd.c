#include <stdio.h>

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

int main()
{ FILE *fout = fopen ("test.out", "rb");
  UniHdrType hdr;
  fread (&hdr, 1, sizeof (UniHdrType), fout);
  // hdr.rsp_reserved_1 = 0x123412341234123;
  printf ("0x%LX\n", hdr.rsp_reserved_1);
  printf ("0x%x\n", hdr.rsp_rsp_clock);
  printf ("0x%x\n", hdr.rsp_sdo_mode);
  printf ("0x%x\n", hdr.rsp_lane_id);
  printf ("0x%x\n", hdr.rsp_station_id);
  printf ("0x%x\n", hdr.nof_words_per_block);
  printf ("0x%x\n", hdr.nof_blocks_per_packet);
  printf ("0x%x\n", hdr.rsp_sync);
  printf ("0x%LX\n", hdr.rsp_reserved_0);
  // Original data, appears in hexdump as 0x
  //                        4000
  // 0000010 1d95 2ea6 ffb7                      
  // with 1D95 being the 2-bit right shifted version of the LSBs 0x7655.
  // Note that the LS nibble of 0x7655 is 0x5, and its ls 2 bits (01) create the 
  // 4000 in the upper address.
  printf ("0x%LX\n", hdr.rsp_bsn);
  // hdr.rsp_bsn = 0x0f60629575D9D;


  fclose (fout);
}
