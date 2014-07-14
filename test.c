#include <stdio.h>
#include <arpa/inet.h>
#define _BSD_SOURCE
#include <endian.h>

// Data format of the AARTFAAC Uniboard output packets.
typedef struct                                                                     
{ unsigned long long rsp_reserved_1:59;
  unsigned int rsp_rsp_clock:1;
  unsigned int rsp_sdo_mode:2;
  unsigned int rsp_lane_id:2;
  unsigned int rsp_station_id:16;
  unsigned int nof_words_per_block:16; // 8sbbands X 96 dipoles=768 (4B = 1 word)  
  unsigned int nof_blocks_per_packet:16;// 2                                       
  unsigned long long rsp_bsn:50;        // Two timeslices share the same BSN     
  unsigned int rsp_sync:1;
  unsigned int rsp_reserved_0:13;
}__attribute ((__packed__)) UniHdrType ;                                                  
typedef struct
{ unsigned long long field1;
  unsigned short field2;
  unsigned short field3;
  unsigned short field4;
  unsigned long long field5;
  /*
  unsigned short field5;
  unsigned short field6;
  unsigned short field7;
  unsigned short field8;
  */
}__attribute ((__packed__)) UniFieldType;

typedef union
{ UniHdrType hdr;
  UniFieldType f;
} HdrField;

int main()
{ FILE *fout = fopen ("test.out", "wb");
  HdrField f1, f2;;
  UniHdrType *hdr = (UniHdrType*) (&f1.hdr);
  UniHdrType *hdr2 = (UniHdrType*) (&f2.hdr);

  // hdr.rsp_reserved_1 = 0x123412341234123;
  hdr->rsp_reserved_1 = 0x123456789abcdef;
  hdr->rsp_rsp_clock = 0;
  hdr->rsp_sdo_mode = 0;
  hdr->rsp_lane_id = 0;
  hdr->rsp_station_id = 0x5678;
  hdr->nof_words_per_block = 0x99aa; // 0x9abc;
  hdr->nof_blocks_per_packet = 0xbbcc; // 0xdef1;
  hdr->rsp_sync = 0;
  hdr->rsp_reserved_0 = 0;
  // Original data, appears in hexdump as 0x
  //                        4000
  // 0000010 1d95 2ea6 ffb7                      
  // with 1D95 being the 2-bit right shifted version of the LSBs 0x7655.
  // Note that the LS nibble of 0x7655 is 0x5, and its ls 2 bits (01) create the 
  // 4000 in the upper address.
  // hdr->rsp_bsn = (0x0fedcba987655 >> 0);

  // Sample  50bit timestamp
  hdr->rsp_bsn = 0x0f60629575D9D;

  f2.f.field1 = htobe64 (f1.f.field1); 
  f2.f.field2 = htobe16 (f1.f.field2);
  f2.f.field3 = htobe16 (f1.f.field3);
  f2.f.field4 = htobe16 (f1.f.field4);
  f2.f.field5 = htobe64 (f1.f.field5); 
/*
  f2.f.field5 = htobe16 (f1.f.field5); 
  f2.f.field6 = htobe16 (f1.f.field6); 
  f2.f.field7 = htobe16 (f1.f.field7); 
  f2.f.field8 = htobe16 (f1.f.field8); 
*/
  fprintf (stderr, "field5: 0x%LX, hton: 0x%LX\n", f1.f.field5, f2.f.field5);
  fwrite (hdr2, 1, sizeof (UniHdrType), fout);

  fclose (fout);
}
