/* Program to read the file based output of the GPU correlator
 * pep/07Aug14
 */

#include <stdio.h>
#include <complex.h>
#include <stdint.h>
#include <errno.h>
#include <stdlib.h>
#include <complex.h>

#define NR_BLINES 41616
#define NR_CHANS 63
#define NR_POL 4

typedef struct 
{ uint32_t magic;
  uint32_t pad0;
  double   startTime, endTime;
  char     pad1[512 - 24];
} HdrType;

typedef struct 
{ HdrType hdr; 
  // float dat[2*NR_BLINES*NR_CHANS*NR_POL];   
  float complex dat[NR_BLINES][NR_CHANS][NR_POL];   
} VisType;

int main (int argc, char *argv[])
{ FILE *fin = NULL;

  VisType *vis;

  if ((vis=(VisType*)malloc (sizeof (VisType))) < 0)
  { perror ("malloc:"); return -1;} 

  int i=0, rd=0, blind=0, chansel=0;
 
  if (argc < 2)
  { fprintf (stderr, "Usage: %s filename.vis\n", argv[0]); return -1; }

  fprintf (stderr, "--> Reading from file %s.\n", argv[1]);
  if ((fin = fopen (argv[1], "rb")) == NULL)
  { fprintf (stderr, "%s: Unable to open file %s.\n", argv[0], argv[1]); 
    return -1;
  }

  for (i=0; i<1; i++)
  { if ((rd=fread (vis, 1, sizeof (VisType), fin)) < sizeof (VisType))
    { fprintf (stderr, "Error in reading packet!\n"); }

    fprintf (stderr, "Magic: 0x%x. t_start: %f, t_end:%f \n", vis->hdr.magic,
			 vis->hdr.startTime, vis->hdr.endTime);

	/* Write out a single chan,single pol. ACM.
 	 * chansel. selects the channel to write out.
	 * vis->dat[blines][chans][pols];
 	 */
    fprintf (stdout, "%f ", vis->hdr.startTime);
/*
	for (blind=0; blind<NR_BLINES; blind++)
	// { float *bline = vis->dat + blind*2*NR_POL*NR_CHANS + chansel*2*NR_POL;
	{ float *bline = vis->dat + blind*2*NR_POL + chansel*2*NR_POL*NR_BLINES;
	  fprintf (stdout, "%.4f %.4f ", bline[0], bline[1]); // Re comes first.
	}
	fprintf (stdout, "\n");
*/

	for (blind=0; blind<NR_BLINES; blind++)
	{ 
	  // fprintf (stdout, "%.4f %.4f ", vis->dat[2*blind], vis->dat[2*blind+1]); // Re comes first.
	  fprintf (stdout, "%.4f %.4f ", crealf(vis->dat[blind][31][0]), cimagf(vis->dat[blind][31][0])); // Re comes first.
	}
	fprintf (stdout, "\n");
  }
  return 0;
	
}