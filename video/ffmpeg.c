#include <bits/floatn.h>
#ifdef __HAVE_FLOAT128
#undef __HAVE_FLOAT128
#undef __HAVE_DISTINCT_FLOAT128
#define __HAVE_FLOAT128 0
#define __HAVE_DISTINCT_FLOAT128 0
#endif
#include <math.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
