local ffi = require("ffi")

local header = [[
enum AVMediaType {
AVMEDIA_TYPE_UNKNOWN = -1,
AVMEDIA_TYPE_VIDEO,
AVMEDIA_TYPE_AUDIO,
AVMEDIA_TYPE_DATA,
AVMEDIA_TYPE_SUBTITLE,
AVMEDIA_TYPE_ATTACHMENT,
AVMEDIA_TYPE_NB
};

enum AVPixelFormat {
AV_PIX_FMT_NONE = -1,
AV_PIX_FMT_YUV420P,
AV_PIX_FMT_YUYV422,
AV_PIX_FMT_RGB24,
AV_PIX_FMT_BGR24,
AV_PIX_FMT_YUV422P,
AV_PIX_FMT_YUV444P,
AV_PIX_FMT_YUV410P,
AV_PIX_FMT_YUV411P,
AV_PIX_FMT_GRAY8,
AV_PIX_FMT_MONOWHITE,
AV_PIX_FMT_MONOBLACK,
AV_PIX_FMT_PAL8,
AV_PIX_FMT_YUVJ420P,
AV_PIX_FMT_YUVJ422P,
AV_PIX_FMT_YUVJ444P,
AV_PIX_FMT_UYVY422,
AV_PIX_FMT_UYYVYY411,
AV_PIX_FMT_BGR8,
AV_PIX_FMT_BGR4,
AV_PIX_FMT_BGR4_BYTE,
AV_PIX_FMT_RGB8,
AV_PIX_FMT_RGB4,
AV_PIX_FMT_RGB4_BYTE,
AV_PIX_FMT_NV12,
AV_PIX_FMT_NV21,
AV_PIX_FMT_ARGB,
AV_PIX_FMT_RGBA,
AV_PIX_FMT_ABGR,
AV_PIX_FMT_BGRA,
AV_PIX_FMT_GRAY16BE,
AV_PIX_FMT_GRAY16LE,
AV_PIX_FMT_YUV440P,
AV_PIX_FMT_YUVJ440P,
AV_PIX_FMT_YUVA420P,
AV_PIX_FMT_RGB48BE,
AV_PIX_FMT_RGB48LE,
AV_PIX_FMT_RGB565BE,
AV_PIX_FMT_RGB565LE,
AV_PIX_FMT_RGB555BE,
AV_PIX_FMT_RGB555LE,
AV_PIX_FMT_BGR565BE,
AV_PIX_FMT_BGR565LE,
AV_PIX_FMT_BGR555BE,
AV_PIX_FMT_BGR555LE,
AV_PIX_FMT_VAAPI_MOCO,
AV_PIX_FMT_VAAPI_IDCT,
AV_PIX_FMT_VAAPI_VLD,
AV_PIX_FMT_VAAPI = AV_PIX_FMT_VAAPI_VLD,
AV_PIX_FMT_YUV420P16LE,
AV_PIX_FMT_YUV420P16BE,
AV_PIX_FMT_YUV422P16LE,
AV_PIX_FMT_YUV422P16BE,
AV_PIX_FMT_YUV444P16LE,
AV_PIX_FMT_YUV444P16BE,
AV_PIX_FMT_DXVA2_VLD,
AV_PIX_FMT_RGB444LE,
AV_PIX_FMT_RGB444BE,
AV_PIX_FMT_BGR444LE,
AV_PIX_FMT_BGR444BE,
AV_PIX_FMT_YA8,
AV_PIX_FMT_Y400A = AV_PIX_FMT_YA8,
AV_PIX_FMT_GRAY8A= AV_PIX_FMT_YA8,
AV_PIX_FMT_BGR48BE,
AV_PIX_FMT_BGR48LE,
AV_PIX_FMT_YUV420P9BE,
AV_PIX_FMT_YUV420P9LE,
AV_PIX_FMT_YUV420P10BE,
AV_PIX_FMT_YUV420P10LE,
AV_PIX_FMT_YUV422P10BE,
AV_PIX_FMT_YUV422P10LE,
AV_PIX_FMT_YUV444P9BE,
AV_PIX_FMT_YUV444P9LE,
AV_PIX_FMT_YUV444P10BE,
AV_PIX_FMT_YUV444P10LE,
AV_PIX_FMT_YUV422P9BE,
AV_PIX_FMT_YUV422P9LE,
AV_PIX_FMT_GBRP,
AV_PIX_FMT_GBR24P = AV_PIX_FMT_GBRP,
AV_PIX_FMT_GBRP9BE,
AV_PIX_FMT_GBRP9LE,
AV_PIX_FMT_GBRP10BE,
AV_PIX_FMT_GBRP10LE,
AV_PIX_FMT_GBRP16BE,
AV_PIX_FMT_GBRP16LE,
AV_PIX_FMT_YUVA422P,
AV_PIX_FMT_YUVA444P,
AV_PIX_FMT_YUVA420P9BE,
AV_PIX_FMT_YUVA420P9LE,
AV_PIX_FMT_YUVA422P9BE,
AV_PIX_FMT_YUVA422P9LE,
AV_PIX_FMT_YUVA444P9BE,
AV_PIX_FMT_YUVA444P9LE,
AV_PIX_FMT_YUVA420P10BE,
AV_PIX_FMT_YUVA420P10LE,
AV_PIX_FMT_YUVA422P10BE,
AV_PIX_FMT_YUVA422P10LE,
AV_PIX_FMT_YUVA444P10BE,
AV_PIX_FMT_YUVA444P10LE,
AV_PIX_FMT_YUVA420P16BE,
AV_PIX_FMT_YUVA420P16LE,
AV_PIX_FMT_YUVA422P16BE,
AV_PIX_FMT_YUVA422P16LE,
AV_PIX_FMT_YUVA444P16BE,
AV_PIX_FMT_YUVA444P16LE,
AV_PIX_FMT_VDPAU,
AV_PIX_FMT_XYZ12LE,
AV_PIX_FMT_XYZ12BE,
AV_PIX_FMT_NV16,
AV_PIX_FMT_NV20LE,
AV_PIX_FMT_NV20BE,
AV_PIX_FMT_RGBA64BE,
AV_PIX_FMT_RGBA64LE,
AV_PIX_FMT_BGRA64BE,
AV_PIX_FMT_BGRA64LE,
AV_PIX_FMT_YVYU422,
AV_PIX_FMT_YA16BE,
AV_PIX_FMT_YA16LE,
AV_PIX_FMT_GBRAP,
AV_PIX_FMT_GBRAP16BE,
AV_PIX_FMT_GBRAP16LE,
AV_PIX_FMT_QSV,
AV_PIX_FMT_MMAL,
AV_PIX_FMT_D3D11VA_VLD,
AV_PIX_FMT_CUDA,
AV_PIX_FMT_0RGB,
AV_PIX_FMT_RGB0,
AV_PIX_FMT_0BGR,
AV_PIX_FMT_BGR0,
AV_PIX_FMT_YUV420P12BE,
AV_PIX_FMT_YUV420P12LE,
AV_PIX_FMT_YUV420P14BE,
AV_PIX_FMT_YUV420P14LE,
AV_PIX_FMT_YUV422P12BE,
AV_PIX_FMT_YUV422P12LE,
AV_PIX_FMT_YUV422P14BE,
AV_PIX_FMT_YUV422P14LE,
AV_PIX_FMT_YUV444P12BE,
AV_PIX_FMT_YUV444P12LE,
AV_PIX_FMT_YUV444P14BE,
AV_PIX_FMT_YUV444P14LE,
AV_PIX_FMT_GBRP12BE,
AV_PIX_FMT_GBRP12LE,
AV_PIX_FMT_GBRP14BE,
AV_PIX_FMT_GBRP14LE,
AV_PIX_FMT_YUVJ411P,
AV_PIX_FMT_BAYER_BGGR8,
AV_PIX_FMT_BAYER_RGGB8,
AV_PIX_FMT_BAYER_GBRG8,
AV_PIX_FMT_BAYER_GRBG8,
AV_PIX_FMT_BAYER_BGGR16LE,
AV_PIX_FMT_BAYER_BGGR16BE,
AV_PIX_FMT_BAYER_RGGB16LE,
AV_PIX_FMT_BAYER_RGGB16BE,
AV_PIX_FMT_BAYER_GBRG16LE,
AV_PIX_FMT_BAYER_GBRG16BE,
AV_PIX_FMT_BAYER_GRBG16LE,
AV_PIX_FMT_BAYER_GRBG16BE,
AV_PIX_FMT_XVMC,
AV_PIX_FMT_YUV440P10LE,
AV_PIX_FMT_YUV440P10BE,
AV_PIX_FMT_YUV440P12LE,
AV_PIX_FMT_YUV440P12BE,
AV_PIX_FMT_AYUV64LE,
AV_PIX_FMT_AYUV64BE,
AV_PIX_FMT_VIDEOTOOLBOX,
AV_PIX_FMT_P010LE,
AV_PIX_FMT_P010BE,
AV_PIX_FMT_GBRAP12BE,
AV_PIX_FMT_GBRAP12LE,
AV_PIX_FMT_GBRAP10BE,
AV_PIX_FMT_GBRAP10LE,
AV_PIX_FMT_MEDIACODEC,
AV_PIX_FMT_GRAY12BE,
AV_PIX_FMT_GRAY12LE,
AV_PIX_FMT_GRAY10BE,
AV_PIX_FMT_GRAY10LE,
AV_PIX_FMT_P016LE,
AV_PIX_FMT_P016BE,
AV_PIX_FMT_D3D11,
AV_PIX_FMT_GRAY9BE,
AV_PIX_FMT_GRAY9LE,
AV_PIX_FMT_GBRPF32BE,
AV_PIX_FMT_GBRPF32LE,
AV_PIX_FMT_GBRAPF32BE,
AV_PIX_FMT_GBRAPF32LE,
AV_PIX_FMT_DRM_PRIME,
AV_PIX_FMT_OPENCL,
AV_PIX_FMT_GRAY14BE,
AV_PIX_FMT_GRAY14LE,
AV_PIX_FMT_GRAYF32BE,
AV_PIX_FMT_GRAYF32LE,
AV_PIX_FMT_NB
};

typedef enum {
AV_CLASS_CATEGORY_NA = 0,
AV_CLASS_CATEGORY_INPUT,
AV_CLASS_CATEGORY_OUTPUT,
AV_CLASS_CATEGORY_MUXER,
AV_CLASS_CATEGORY_DEMUXER,
AV_CLASS_CATEGORY_ENCODER,
AV_CLASS_CATEGORY_DECODER,
AV_CLASS_CATEGORY_FILTER,
AV_CLASS_CATEGORY_BITSTREAM_FILTER,
AV_CLASS_CATEGORY_SWSCALER,
AV_CLASS_CATEGORY_SWRESAMPLER,
AV_CLASS_CATEGORY_DEVICE_VIDEO_OUTPUT = 40,
AV_CLASS_CATEGORY_DEVICE_VIDEO_INPUT,
AV_CLASS_CATEGORY_DEVICE_AUDIO_OUTPUT,
AV_CLASS_CATEGORY_DEVICE_AUDIO_INPUT,
AV_CLASS_CATEGORY_DEVICE_OUTPUT,
AV_CLASS_CATEGORY_DEVICE_INPUT,
AV_CLASS_CATEGORY_NB
} AVClassCategory;

enum AVFrameSideDataType {
AV_FRAME_DATA_PANSCAN,
AV_FRAME_DATA_A53_CC,
AV_FRAME_DATA_STEREO3D,
AV_FRAME_DATA_MATRIXENCODING,
AV_FRAME_DATA_DOWNMIX_INFO,
AV_FRAME_DATA_REPLAYGAIN,
AV_FRAME_DATA_DISPLAYMATRIX,
AV_FRAME_DATA_AFD,
AV_FRAME_DATA_MOTION_VECTORS,
AV_FRAME_DATA_SKIP_SAMPLES,
AV_FRAME_DATA_AUDIO_SERVICE_TYPE,
AV_FRAME_DATA_MASTERING_DISPLAY_METADATA,
AV_FRAME_DATA_GOP_TIMECODE,
AV_FRAME_DATA_SPHERICAL,
AV_FRAME_DATA_CONTENT_LIGHT_LEVEL,
AV_FRAME_DATA_ICC_PROFILE,
AV_FRAME_DATA_QP_TABLE_PROPERTIES,
AV_FRAME_DATA_QP_TABLE_DATA,
AV_FRAME_DATA_S12M_TIMECODE,
};

enum AVPictureType {
AV_PICTURE_TYPE_NONE = 0,
AV_PICTURE_TYPE_I,
AV_PICTURE_TYPE_P,
AV_PICTURE_TYPE_B,
AV_PICTURE_TYPE_S,
AV_PICTURE_TYPE_SI,
AV_PICTURE_TYPE_SP,
AV_PICTURE_TYPE_BI,
};

enum AVColorRange {
AVCOL_RANGE_UNSPECIFIED = 0,
AVCOL_RANGE_MPEG = 1,
AVCOL_RANGE_JPEG = 2,
AVCOL_RANGE_NB
};

enum AVColorPrimaries {
AVCOL_PRI_RESERVED0 = 0,
AVCOL_PRI_BT709 = 1,
AVCOL_PRI_UNSPECIFIED = 2,
AVCOL_PRI_RESERVED = 3,
AVCOL_PRI_BT470M = 4,
AVCOL_PRI_BT470BG = 5,
AVCOL_PRI_SMPTE170M = 6,
AVCOL_PRI_SMPTE240M = 7,
AVCOL_PRI_FILM = 8,
AVCOL_PRI_BT2020 = 9,
AVCOL_PRI_SMPTE428 = 10,
AVCOL_PRI_SMPTEST428_1 = AVCOL_PRI_SMPTE428,
AVCOL_PRI_SMPTE431 = 11,
AVCOL_PRI_SMPTE432 = 12,
AVCOL_PRI_JEDEC_P22 = 22,
AVCOL_PRI_NB
};

enum AVColorTransferCharacteristic {
AVCOL_TRC_RESERVED0 = 0,
AVCOL_TRC_BT709 = 1,
AVCOL_TRC_UNSPECIFIED = 2,
AVCOL_TRC_RESERVED = 3,
AVCOL_TRC_GAMMA22 = 4,
AVCOL_TRC_GAMMA28 = 5,
AVCOL_TRC_SMPTE170M = 6,
AVCOL_TRC_SMPTE240M = 7,
AVCOL_TRC_LINEAR = 8,
AVCOL_TRC_LOG = 9,
AVCOL_TRC_LOG_SQRT = 10,
AVCOL_TRC_IEC61966_2_4 = 11,
AVCOL_TRC_BT1361_ECG = 12,
AVCOL_TRC_IEC61966_2_1 = 13,
AVCOL_TRC_BT2020_10 = 14,
AVCOL_TRC_BT2020_12 = 15,
AVCOL_TRC_SMPTE2084 = 16,
AVCOL_TRC_SMPTEST2084 = AVCOL_TRC_SMPTE2084,
AVCOL_TRC_SMPTE428 = 17,
AVCOL_TRC_SMPTEST428_1 = AVCOL_TRC_SMPTE428,
AVCOL_TRC_ARIB_STD_B67 = 18,
AVCOL_TRC_NB
};

enum AVColorSpace {
AVCOL_SPC_RGB = 0,
AVCOL_SPC_BT709 = 1,
AVCOL_SPC_UNSPECIFIED = 2,
AVCOL_SPC_RESERVED = 3,
AVCOL_SPC_FCC = 4,
AVCOL_SPC_BT470BG = 5,
AVCOL_SPC_SMPTE170M = 6,
AVCOL_SPC_SMPTE240M = 7,
AVCOL_SPC_YCGCO = 8,
AVCOL_SPC_YCOCG = AVCOL_SPC_YCGCO,
AVCOL_SPC_BT2020_NCL = 9,
AVCOL_SPC_BT2020_CL = 10,
AVCOL_SPC_SMPTE2085 = 11,
AVCOL_SPC_CHROMA_DERIVED_NCL = 12,
AVCOL_SPC_CHROMA_DERIVED_CL = 13,
AVCOL_SPC_ICTCP = 14,
AVCOL_SPC_NB
};

enum AVChromaLocation {
AVCHROMA_LOC_UNSPECIFIED = 0,
AVCHROMA_LOC_LEFT = 1,
AVCHROMA_LOC_CENTER = 2,
AVCHROMA_LOC_TOPLEFT = 3,
AVCHROMA_LOC_TOP = 4,
AVCHROMA_LOC_BOTTOMLEFT = 5,
AVCHROMA_LOC_BOTTOM = 6,
AVCHROMA_LOC_NB
};

enum AVCodecID {
AV_CODEC_ID_NONE,
AV_CODEC_ID_MPEG1VIDEO,
AV_CODEC_ID_MPEG2VIDEO,
AV_CODEC_ID_H261,
AV_CODEC_ID_H263,
AV_CODEC_ID_RV10,
AV_CODEC_ID_RV20,
AV_CODEC_ID_MJPEG,
AV_CODEC_ID_MJPEGB,
AV_CODEC_ID_LJPEG,
AV_CODEC_ID_SP5X,
AV_CODEC_ID_JPEGLS,
AV_CODEC_ID_MPEG4,
AV_CODEC_ID_RAWVIDEO,
AV_CODEC_ID_MSMPEG4V1,
AV_CODEC_ID_MSMPEG4V2,
AV_CODEC_ID_MSMPEG4V3,
AV_CODEC_ID_WMV1,
AV_CODEC_ID_WMV2,
AV_CODEC_ID_H263P,
AV_CODEC_ID_H263I,
AV_CODEC_ID_FLV1,
AV_CODEC_ID_SVQ1,
AV_CODEC_ID_SVQ3,
AV_CODEC_ID_DVVIDEO,
AV_CODEC_ID_HUFFYUV,
AV_CODEC_ID_CYUV,
AV_CODEC_ID_H264,
AV_CODEC_ID_INDEO3,
AV_CODEC_ID_VP3,
AV_CODEC_ID_THEORA,
AV_CODEC_ID_ASV1,
AV_CODEC_ID_ASV2,
AV_CODEC_ID_FFV1,
AV_CODEC_ID_4XM,
AV_CODEC_ID_VCR1,
AV_CODEC_ID_CLJR,
AV_CODEC_ID_MDEC,
AV_CODEC_ID_ROQ,
AV_CODEC_ID_INTERPLAY_VIDEO,
AV_CODEC_ID_XAN_WC3,
AV_CODEC_ID_XAN_WC4,
AV_CODEC_ID_RPZA,
AV_CODEC_ID_CINEPAK,
AV_CODEC_ID_WS_VQA,
AV_CODEC_ID_MSRLE,
AV_CODEC_ID_MSVIDEO1,
AV_CODEC_ID_IDCIN,
AV_CODEC_ID_8BPS,
AV_CODEC_ID_SMC,
AV_CODEC_ID_FLIC,
AV_CODEC_ID_TRUEMOTION1,
AV_CODEC_ID_VMDVIDEO,
AV_CODEC_ID_MSZH,
AV_CODEC_ID_ZLIB,
AV_CODEC_ID_QTRLE,
AV_CODEC_ID_TSCC,
AV_CODEC_ID_ULTI,
AV_CODEC_ID_QDRAW,
AV_CODEC_ID_VIXL,
AV_CODEC_ID_QPEG,
AV_CODEC_ID_PNG,
AV_CODEC_ID_PPM,
AV_CODEC_ID_PBM,
AV_CODEC_ID_PGM,
AV_CODEC_ID_PGMYUV,
AV_CODEC_ID_PAM,
AV_CODEC_ID_FFVHUFF,
AV_CODEC_ID_RV30,
AV_CODEC_ID_RV40,
AV_CODEC_ID_VC1,
AV_CODEC_ID_WMV3,
AV_CODEC_ID_LOCO,
AV_CODEC_ID_WNV1,
AV_CODEC_ID_AASC,
AV_CODEC_ID_INDEO2,
AV_CODEC_ID_FRAPS,
AV_CODEC_ID_TRUEMOTION2,
AV_CODEC_ID_BMP,
AV_CODEC_ID_CSCD,
AV_CODEC_ID_MMVIDEO,
AV_CODEC_ID_ZMBV,
AV_CODEC_ID_AVS,
AV_CODEC_ID_SMACKVIDEO,
AV_CODEC_ID_NUV,
AV_CODEC_ID_KMVC,
AV_CODEC_ID_FLASHSV,
AV_CODEC_ID_CAVS,
AV_CODEC_ID_JPEG2000,
AV_CODEC_ID_VMNC,
AV_CODEC_ID_VP5,
AV_CODEC_ID_VP6,
AV_CODEC_ID_VP6F,
AV_CODEC_ID_TARGA,
AV_CODEC_ID_DSICINVIDEO,
AV_CODEC_ID_TIERTEXSEQVIDEO,
AV_CODEC_ID_TIFF,
AV_CODEC_ID_GIF,
AV_CODEC_ID_DXA,
AV_CODEC_ID_DNXHD,
AV_CODEC_ID_THP,
AV_CODEC_ID_SGI,
AV_CODEC_ID_C93,
AV_CODEC_ID_BETHSOFTVID,
AV_CODEC_ID_PTX,
AV_CODEC_ID_TXD,
AV_CODEC_ID_VP6A,
AV_CODEC_ID_AMV,
AV_CODEC_ID_VB,
AV_CODEC_ID_PCX,
AV_CODEC_ID_SUNRAST,
AV_CODEC_ID_INDEO4,
AV_CODEC_ID_INDEO5,
AV_CODEC_ID_MIMIC,
AV_CODEC_ID_RL2,
AV_CODEC_ID_ESCAPE124,
AV_CODEC_ID_DIRAC,
AV_CODEC_ID_BFI,
AV_CODEC_ID_CMV,
AV_CODEC_ID_MOTIONPIXELS,
AV_CODEC_ID_TGV,
AV_CODEC_ID_TGQ,
AV_CODEC_ID_TQI,
AV_CODEC_ID_AURA,
AV_CODEC_ID_AURA2,
AV_CODEC_ID_V210X,
AV_CODEC_ID_TMV,
AV_CODEC_ID_V210,
AV_CODEC_ID_DPX,
AV_CODEC_ID_MAD,
AV_CODEC_ID_FRWU,
AV_CODEC_ID_FLASHSV2,
AV_CODEC_ID_CDGRAPHICS,
AV_CODEC_ID_R210,
AV_CODEC_ID_ANM,
AV_CODEC_ID_BINKVIDEO,
AV_CODEC_ID_IFF_ILBM,
AV_CODEC_ID_KGV1,
AV_CODEC_ID_YOP,
AV_CODEC_ID_VP8,
AV_CODEC_ID_PICTOR,
AV_CODEC_ID_ANSI,
AV_CODEC_ID_A64_MULTI,
AV_CODEC_ID_A64_MULTI5,
AV_CODEC_ID_R10K,
AV_CODEC_ID_MXPEG,
AV_CODEC_ID_LAGARITH,
AV_CODEC_ID_PRORES,
AV_CODEC_ID_JV,
AV_CODEC_ID_DFA,
AV_CODEC_ID_WMV3IMAGE,
AV_CODEC_ID_VC1IMAGE,
AV_CODEC_ID_UTVIDEO,
AV_CODEC_ID_BMV_VIDEO,
AV_CODEC_ID_VBLE,
AV_CODEC_ID_DXTORY,
AV_CODEC_ID_V410,
AV_CODEC_ID_XWD,
AV_CODEC_ID_CDXL,
AV_CODEC_ID_XBM,
AV_CODEC_ID_ZEROCODEC,
AV_CODEC_ID_MSS1,
AV_CODEC_ID_MSA1,
AV_CODEC_ID_TSCC2,
AV_CODEC_ID_MTS2,
AV_CODEC_ID_CLLC,
AV_CODEC_ID_MSS2,
AV_CODEC_ID_VP9,
AV_CODEC_ID_AIC,
AV_CODEC_ID_ESCAPE130,
AV_CODEC_ID_G2M,
AV_CODEC_ID_WEBP,
AV_CODEC_ID_HNM4_VIDEO,
AV_CODEC_ID_HEVC,
AV_CODEC_ID_FIC,
AV_CODEC_ID_ALIAS_PIX,
AV_CODEC_ID_BRENDER_PIX,
AV_CODEC_ID_PAF_VIDEO,
AV_CODEC_ID_EXR,
AV_CODEC_ID_VP7,
AV_CODEC_ID_SANM,
AV_CODEC_ID_SGIRLE,
AV_CODEC_ID_MVC1,
AV_CODEC_ID_MVC2,
AV_CODEC_ID_HQX,
AV_CODEC_ID_TDSC,
AV_CODEC_ID_HQ_HQA,
AV_CODEC_ID_HAP,
AV_CODEC_ID_DDS,
AV_CODEC_ID_DXV,
AV_CODEC_ID_SCREENPRESSO,
AV_CODEC_ID_RSCC,
AV_CODEC_ID_AVS2,
AV_CODEC_ID_Y41P = 0x8000,
AV_CODEC_ID_AVRP,
AV_CODEC_ID_012V,
AV_CODEC_ID_AVUI,
AV_CODEC_ID_AYUV,
AV_CODEC_ID_TARGA_Y216,
AV_CODEC_ID_V308,
AV_CODEC_ID_V408,
AV_CODEC_ID_YUV4,
AV_CODEC_ID_AVRN,
AV_CODEC_ID_CPIA,
AV_CODEC_ID_XFACE,
AV_CODEC_ID_SNOW,
AV_CODEC_ID_SMVJPEG,
AV_CODEC_ID_APNG,
AV_CODEC_ID_DAALA,
AV_CODEC_ID_CFHD,
AV_CODEC_ID_TRUEMOTION2RT,
AV_CODEC_ID_M101,
AV_CODEC_ID_MAGICYUV,
AV_CODEC_ID_SHEERVIDEO,
AV_CODEC_ID_YLC,
AV_CODEC_ID_PSD,
AV_CODEC_ID_PIXLET,
AV_CODEC_ID_SPEEDHQ,
AV_CODEC_ID_FMVC,
AV_CODEC_ID_SCPR,
AV_CODEC_ID_CLEARVIDEO,
AV_CODEC_ID_XPM,
AV_CODEC_ID_AV1,
AV_CODEC_ID_BITPACKED,
AV_CODEC_ID_MSCC,
AV_CODEC_ID_SRGC,
AV_CODEC_ID_SVG,
AV_CODEC_ID_GDV,
AV_CODEC_ID_FITS,
AV_CODEC_ID_IMM4,
AV_CODEC_ID_PROSUMER,
AV_CODEC_ID_MWSC,
AV_CODEC_ID_WCMV,
AV_CODEC_ID_RASC,
AV_CODEC_ID_FIRST_AUDIO = 0x10000,
AV_CODEC_ID_PCM_S16LE = 0x10000,
AV_CODEC_ID_PCM_S16BE,
AV_CODEC_ID_PCM_U16LE,
AV_CODEC_ID_PCM_U16BE,
AV_CODEC_ID_PCM_S8,
AV_CODEC_ID_PCM_U8,
AV_CODEC_ID_PCM_MULAW,
AV_CODEC_ID_PCM_ALAW,
AV_CODEC_ID_PCM_S32LE,
AV_CODEC_ID_PCM_S32BE,
AV_CODEC_ID_PCM_U32LE,
AV_CODEC_ID_PCM_U32BE,
AV_CODEC_ID_PCM_S24LE,
AV_CODEC_ID_PCM_S24BE,
AV_CODEC_ID_PCM_U24LE,
AV_CODEC_ID_PCM_U24BE,
AV_CODEC_ID_PCM_S24DAUD,
AV_CODEC_ID_PCM_ZORK,
AV_CODEC_ID_PCM_S16LE_PLANAR,
AV_CODEC_ID_PCM_DVD,
AV_CODEC_ID_PCM_F32BE,
AV_CODEC_ID_PCM_F32LE,
AV_CODEC_ID_PCM_F64BE,
AV_CODEC_ID_PCM_F64LE,
AV_CODEC_ID_PCM_BLURAY,
AV_CODEC_ID_PCM_LXF,
AV_CODEC_ID_S302M,
AV_CODEC_ID_PCM_S8_PLANAR,
AV_CODEC_ID_PCM_S24LE_PLANAR,
AV_CODEC_ID_PCM_S32LE_PLANAR,
AV_CODEC_ID_PCM_S16BE_PLANAR,
AV_CODEC_ID_PCM_S64LE = 0x10800,
AV_CODEC_ID_PCM_S64BE,
AV_CODEC_ID_PCM_F16LE,
AV_CODEC_ID_PCM_F24LE,
AV_CODEC_ID_PCM_VIDC,
AV_CODEC_ID_ADPCM_IMA_QT = 0x11000,
AV_CODEC_ID_ADPCM_IMA_WAV,
AV_CODEC_ID_ADPCM_IMA_DK3,
AV_CODEC_ID_ADPCM_IMA_DK4,
AV_CODEC_ID_ADPCM_IMA_WS,
AV_CODEC_ID_ADPCM_IMA_SMJPEG,
AV_CODEC_ID_ADPCM_MS,
AV_CODEC_ID_ADPCM_4XM,
AV_CODEC_ID_ADPCM_XA,
AV_CODEC_ID_ADPCM_ADX,
AV_CODEC_ID_ADPCM_EA,
AV_CODEC_ID_ADPCM_G726,
AV_CODEC_ID_ADPCM_CT,
AV_CODEC_ID_ADPCM_SWF,
AV_CODEC_ID_ADPCM_YAMAHA,
AV_CODEC_ID_ADPCM_SBPRO_4,
AV_CODEC_ID_ADPCM_SBPRO_3,
AV_CODEC_ID_ADPCM_SBPRO_2,
AV_CODEC_ID_ADPCM_THP,
AV_CODEC_ID_ADPCM_IMA_AMV,
AV_CODEC_ID_ADPCM_EA_R1,
AV_CODEC_ID_ADPCM_EA_R3,
AV_CODEC_ID_ADPCM_EA_R2,
AV_CODEC_ID_ADPCM_IMA_EA_SEAD,
AV_CODEC_ID_ADPCM_IMA_EA_EACS,
AV_CODEC_ID_ADPCM_EA_XAS,
AV_CODEC_ID_ADPCM_EA_MAXIS_XA,
AV_CODEC_ID_ADPCM_IMA_ISS,
AV_CODEC_ID_ADPCM_G722,
AV_CODEC_ID_ADPCM_IMA_APC,
AV_CODEC_ID_ADPCM_VIMA,
AV_CODEC_ID_ADPCM_AFC = 0x11800,
AV_CODEC_ID_ADPCM_IMA_OKI,
AV_CODEC_ID_ADPCM_DTK,
AV_CODEC_ID_ADPCM_IMA_RAD,
AV_CODEC_ID_ADPCM_G726LE,
AV_CODEC_ID_ADPCM_THP_LE,
AV_CODEC_ID_ADPCM_PSX,
AV_CODEC_ID_ADPCM_AICA,
AV_CODEC_ID_ADPCM_IMA_DAT4,
AV_CODEC_ID_ADPCM_MTAF,
AV_CODEC_ID_AMR_NB = 0x12000,
AV_CODEC_ID_AMR_WB,
AV_CODEC_ID_RA_144 = 0x13000,
AV_CODEC_ID_RA_288,
AV_CODEC_ID_ROQ_DPCM = 0x14000,
AV_CODEC_ID_INTERPLAY_DPCM,
AV_CODEC_ID_XAN_DPCM,
AV_CODEC_ID_SOL_DPCM,
AV_CODEC_ID_SDX2_DPCM = 0x14800,
AV_CODEC_ID_GREMLIN_DPCM,
AV_CODEC_ID_MP2 = 0x15000,
AV_CODEC_ID_MP3,
AV_CODEC_ID_AAC,
AV_CODEC_ID_AC3,
AV_CODEC_ID_DTS,
AV_CODEC_ID_VORBIS,
AV_CODEC_ID_DVAUDIO,
AV_CODEC_ID_WMAV1,
AV_CODEC_ID_WMAV2,
AV_CODEC_ID_MACE3,
AV_CODEC_ID_MACE6,
AV_CODEC_ID_VMDAUDIO,
AV_CODEC_ID_FLAC,
AV_CODEC_ID_MP3ADU,
AV_CODEC_ID_MP3ON4,
AV_CODEC_ID_SHORTEN,
AV_CODEC_ID_ALAC,
AV_CODEC_ID_WESTWOOD_SND1,
AV_CODEC_ID_GSM,
AV_CODEC_ID_QDM2,
AV_CODEC_ID_COOK,
AV_CODEC_ID_TRUESPEECH,
AV_CODEC_ID_TTA,
AV_CODEC_ID_SMACKAUDIO,
AV_CODEC_ID_QCELP,
AV_CODEC_ID_WAVPACK,
AV_CODEC_ID_DSICINAUDIO,
AV_CODEC_ID_IMC,
AV_CODEC_ID_MUSEPACK7,
AV_CODEC_ID_MLP,
AV_CODEC_ID_GSM_MS,
AV_CODEC_ID_ATRAC3,
AV_CODEC_ID_APE,
AV_CODEC_ID_NELLYMOSER,
AV_CODEC_ID_MUSEPACK8,
AV_CODEC_ID_SPEEX,
AV_CODEC_ID_WMAVOICE,
AV_CODEC_ID_WMAPRO,
AV_CODEC_ID_WMALOSSLESS,
AV_CODEC_ID_ATRAC3P,
AV_CODEC_ID_EAC3,
AV_CODEC_ID_SIPR,
AV_CODEC_ID_MP1,
AV_CODEC_ID_TWINVQ,
AV_CODEC_ID_TRUEHD,
AV_CODEC_ID_MP4ALS,
AV_CODEC_ID_ATRAC1,
AV_CODEC_ID_BINKAUDIO_RDFT,
AV_CODEC_ID_BINKAUDIO_DCT,
AV_CODEC_ID_AAC_LATM,
AV_CODEC_ID_QDMC,
AV_CODEC_ID_CELT,
AV_CODEC_ID_G723_1,
AV_CODEC_ID_G729,
AV_CODEC_ID_8SVX_EXP,
AV_CODEC_ID_8SVX_FIB,
AV_CODEC_ID_BMV_AUDIO,
AV_CODEC_ID_RALF,
AV_CODEC_ID_IAC,
AV_CODEC_ID_ILBC,
AV_CODEC_ID_OPUS,
AV_CODEC_ID_COMFORT_NOISE,
AV_CODEC_ID_TAK,
AV_CODEC_ID_METASOUND,
AV_CODEC_ID_PAF_AUDIO,
AV_CODEC_ID_ON2AVC,
AV_CODEC_ID_DSS_SP,
AV_CODEC_ID_CODEC2,
AV_CODEC_ID_FFWAVESYNTH = 0x15800,
AV_CODEC_ID_SONIC,
AV_CODEC_ID_SONIC_LS,
AV_CODEC_ID_EVRC,
AV_CODEC_ID_SMV,
AV_CODEC_ID_DSD_LSBF,
AV_CODEC_ID_DSD_MSBF,
AV_CODEC_ID_DSD_LSBF_PLANAR,
AV_CODEC_ID_DSD_MSBF_PLANAR,
AV_CODEC_ID_4GV,
AV_CODEC_ID_INTERPLAY_ACM,
AV_CODEC_ID_XMA1,
AV_CODEC_ID_XMA2,
AV_CODEC_ID_DST,
AV_CODEC_ID_ATRAC3AL,
AV_CODEC_ID_ATRAC3PAL,
AV_CODEC_ID_DOLBY_E,
AV_CODEC_ID_APTX,
AV_CODEC_ID_APTX_HD,
AV_CODEC_ID_SBC,
AV_CODEC_ID_ATRAC9,
AV_CODEC_ID_FIRST_SUBTITLE = 0x17000,
AV_CODEC_ID_DVD_SUBTITLE = 0x17000,
AV_CODEC_ID_DVB_SUBTITLE,
AV_CODEC_ID_TEXT,
AV_CODEC_ID_XSUB,
AV_CODEC_ID_SSA,
AV_CODEC_ID_MOV_TEXT,
AV_CODEC_ID_HDMV_PGS_SUBTITLE,
AV_CODEC_ID_DVB_TELETEXT,
AV_CODEC_ID_SRT,
AV_CODEC_ID_MICRODVD = 0x17800,
AV_CODEC_ID_EIA_608,
AV_CODEC_ID_JACOSUB,
AV_CODEC_ID_SAMI,
AV_CODEC_ID_REALTEXT,
AV_CODEC_ID_STL,
AV_CODEC_ID_SUBVIEWER1,
AV_CODEC_ID_SUBVIEWER,
AV_CODEC_ID_SUBRIP,
AV_CODEC_ID_WEBVTT,
AV_CODEC_ID_MPL2,
AV_CODEC_ID_VPLAYER,
AV_CODEC_ID_PJS,
AV_CODEC_ID_ASS,
AV_CODEC_ID_HDMV_TEXT_SUBTITLE,
AV_CODEC_ID_TTML,
AV_CODEC_ID_FIRST_UNKNOWN = 0x18000,
AV_CODEC_ID_TTF = 0x18000,
AV_CODEC_ID_SCTE_35,
AV_CODEC_ID_BINTEXT = 0x18800,
AV_CODEC_ID_XBIN,
AV_CODEC_ID_IDF,
AV_CODEC_ID_OTF,
AV_CODEC_ID_SMPTE_KLV,
AV_CODEC_ID_DVD_NAV,
AV_CODEC_ID_TIMED_ID3,
AV_CODEC_ID_BIN_DATA,
AV_CODEC_ID_PROBE = 0x19000,
AV_CODEC_ID_MPEG2TS = 0x20000,
AV_CODEC_ID_MPEG4SYSTEMS = 0x20001,
AV_CODEC_ID_FFMETADATA = 0x21000,
AV_CODEC_ID_WRAPPED_AVFRAME = 0x21001,
};

enum AVPacketSideDataType {
AV_PKT_DATA_PALETTE,
AV_PKT_DATA_NEW_EXTRADATA,
AV_PKT_DATA_PARAM_CHANGE,
AV_PKT_DATA_H263_MB_INFO,
AV_PKT_DATA_REPLAYGAIN,
AV_PKT_DATA_DISPLAYMATRIX,
AV_PKT_DATA_STEREO3D,
AV_PKT_DATA_AUDIO_SERVICE_TYPE,
AV_PKT_DATA_QUALITY_STATS,
AV_PKT_DATA_FALLBACK_TRACK,
AV_PKT_DATA_CPB_PROPERTIES,
AV_PKT_DATA_SKIP_SAMPLES,
AV_PKT_DATA_JP_DUALMONO,
AV_PKT_DATA_STRINGS_METADATA,
AV_PKT_DATA_SUBTITLE_POSITION,
AV_PKT_DATA_MATROSKA_BLOCKADDITIONAL,
AV_PKT_DATA_WEBVTT_IDENTIFIER,
AV_PKT_DATA_WEBVTT_SETTINGS,
AV_PKT_DATA_METADATA_UPDATE,
AV_PKT_DATA_MPEGTS_STREAM_ID,
AV_PKT_DATA_MASTERING_DISPLAY_METADATA,
AV_PKT_DATA_SPHERICAL,
AV_PKT_DATA_CONTENT_LIGHT_LEVEL,
AV_PKT_DATA_A53_CC,
AV_PKT_DATA_ENCRYPTION_INIT_INFO,
AV_PKT_DATA_ENCRYPTION_INFO,
AV_PKT_DATA_AFD,
AV_PKT_DATA_NB
};

enum AVDiscard{
AVDISCARD_NONE =-16,
AVDISCARD_DEFAULT = 0,
AVDISCARD_NONREF = 8,
AVDISCARD_BIDIR = 16,
AVDISCARD_NONINTRA= 24,
AVDISCARD_NONKEY = 32,
AVDISCARD_ALL = 48,
};

enum AVSampleFormat {
AV_SAMPLE_FMT_NONE = -1,
AV_SAMPLE_FMT_U8,
AV_SAMPLE_FMT_S16,
AV_SAMPLE_FMT_S32,
AV_SAMPLE_FMT_FLT,
AV_SAMPLE_FMT_DBL,
AV_SAMPLE_FMT_U8P,
AV_SAMPLE_FMT_S16P,
AV_SAMPLE_FMT_S32P,
AV_SAMPLE_FMT_FLTP,
AV_SAMPLE_FMT_DBLP,
AV_SAMPLE_FMT_S64,
AV_SAMPLE_FMT_S64P,
AV_SAMPLE_FMT_NB
};

enum AVFieldOrder {
AV_FIELD_UNKNOWN,
AV_FIELD_PROGRESSIVE,
AV_FIELD_TT,
AV_FIELD_BB,
AV_FIELD_TB,
AV_FIELD_BT,
};

enum AVAudioServiceType {
AV_AUDIO_SERVICE_TYPE_MAIN = 0,
AV_AUDIO_SERVICE_TYPE_EFFECTS = 1,
AV_AUDIO_SERVICE_TYPE_VISUALLY_IMPAIRED = 2,
AV_AUDIO_SERVICE_TYPE_HEARING_IMPAIRED = 3,
AV_AUDIO_SERVICE_TYPE_DIALOGUE = 4,
AV_AUDIO_SERVICE_TYPE_COMMENTARY = 5,
AV_AUDIO_SERVICE_TYPE_EMERGENCY = 6,
AV_AUDIO_SERVICE_TYPE_VOICE_OVER = 7,
AV_AUDIO_SERVICE_TYPE_KARAOKE = 8,
AV_AUDIO_SERVICE_TYPE_NB ,
};

enum AVIODataMarkerType {
AVIO_DATA_MARKER_HEADER,
AVIO_DATA_MARKER_SYNC_POINT,
AVIO_DATA_MARKER_BOUNDARY_POINT,
AVIO_DATA_MARKER_UNKNOWN,
AVIO_DATA_MARKER_TRAILER,
AVIO_DATA_MARKER_FLUSH_POINT,
};

enum AVStreamParseType {
AVSTREAM_PARSE_NONE,
AVSTREAM_PARSE_FULL,
AVSTREAM_PARSE_HEADERS,
AVSTREAM_PARSE_TIMESTAMPS,
AVSTREAM_PARSE_FULL_ONCE,
AVSTREAM_PARSE_FULL_RAW,
};

enum AVDurationEstimationMethod {
AVFMT_DURATION_FROM_PTS,
AVFMT_DURATION_FROM_STREAM,
AVFMT_DURATION_FROM_BITRATE
};

struct AVFormatContext;

typedef struct AVRational{
int num;
int den;
} AVRational;

struct AVOptionRanges;

typedef struct AVClass {
const char* class_name;
const char* (*item_name)(void* ctx);
const struct AVOption *option;
int version;
int log_level_offset_offset;
int parent_log_context_offset;
void* (*child_next)(void *obj, void *prev);
const struct AVClass* (*child_class_next)(const struct AVClass *prev);
AVClassCategory category;
AVClassCategory (*get_category)(void* ctx);
int (*query_ranges)(struct AVOptionRanges **, void *obj, const char *key, int flags);
} AVClass;

typedef struct AVProfile {
int profile;
const char *name;
} AVProfile;

typedef struct AVBuffer AVBuffer;

typedef struct AVBufferRef {
AVBuffer *buffer;
uint8_t *data;
int size;
} AVBufferRef;
typedef struct AVDictionary AVDictionary;

typedef struct AVFrameSideData {
enum AVFrameSideDataType type;
uint8_t *data;
int size;
AVDictionary *metadata;
AVBufferRef *buf;
} AVFrameSideData;

typedef struct AVFrame {
uint8_t *data[8];
int linesize[8];
uint8_t **extended_data;
int width, height;
int nb_samples;
int format;
int key_frame;
enum AVPictureType pict_type;
AVRational sample_aspect_ratio;
int64_t pts;
__attribute__((deprecated))
int64_t pkt_pts;
int64_t pkt_dts;
int coded_picture_number;
int display_picture_number;
int quality;
void *opaque;
__attribute__((deprecated))
uint64_t error[8];
int repeat_pict;
int interlaced_frame;
int top_field_first;
int palette_has_changed;
int64_t reordered_opaque;
int sample_rate;
uint64_t channel_layout;
AVBufferRef *buf[8];
AVBufferRef **extended_buf;
int nb_extended_buf;
AVFrameSideData **side_data;
int nb_side_data;
int flags;
enum AVColorRange color_range;
enum AVColorPrimaries color_primaries;
enum AVColorTransferCharacteristic color_trc;
enum AVColorSpace colorspace;
enum AVChromaLocation chroma_location;
int64_t best_effort_timestamp;
int64_t pkt_pos;
int64_t pkt_duration;
AVDictionary *metadata;
int decode_error_flags;
int channels;
int pkt_size;
__attribute__((deprecated))
int8_t *qscale_table;
__attribute__((deprecated))
int qstride;
__attribute__((deprecated))
int qscale_type;
__attribute__((deprecated))
AVBufferRef *qp_table_buf;
AVBufferRef *hw_frames_ctx;
AVBufferRef *opaque_ref;
size_t crop_top;
size_t crop_bottom;
size_t crop_left;
size_t crop_right;
AVBufferRef *private_ref;
} AVFrame;

typedef struct RcOverride{
int start_frame;
int end_frame;
int qscale;
float quality_factor;
} RcOverride;

typedef struct AVCodecDescriptor {
enum AVCodecID id;
enum AVMediaType type;
const char *name;
const char *long_name;
int props;
const char *const *mime_types;
const struct AVProfile *profiles;
} AVCodecDescriptor;

typedef struct AVPacketSideData {
uint8_t *data;
int size;
enum AVPacketSideDataType type;
} AVPacketSideData;

typedef struct AVCodecContext {
const AVClass *av_class;
int log_level_offset;
enum AVMediaType codec_type;
const struct AVCodec *codec;
enum AVCodecID codec_id;
unsigned int codec_tag;
void *priv_data;
struct AVCodecInternal *internal;
void *opaque;
int64_t bit_rate;
int bit_rate_tolerance;
int global_quality;
int compression_level;
int flags;
int flags2;
uint8_t *extradata;
int extradata_size;
AVRational time_base;
int ticks_per_frame;
int delay;
int width, height;
int coded_width, coded_height;
int gop_size;
enum AVPixelFormat pix_fmt;
void (*draw_horiz_band)(struct AVCodecContext *s,
const AVFrame *src, int offset[8],
int y, int type, int height);
enum AVPixelFormat (*get_format)(struct AVCodecContext *s, const enum AVPixelFormat * fmt);
int max_b_frames;
float b_quant_factor;
__attribute__((deprecated))
int b_frame_strategy;
float b_quant_offset;
int has_b_frames;
__attribute__((deprecated))
int mpeg_quant;
float i_quant_factor;
float i_quant_offset;
float lumi_masking;
float temporal_cplx_masking;
float spatial_cplx_masking;
float p_masking;
float dark_masking;
int slice_count;
__attribute__((deprecated))
int prediction_method;
int *slice_offset;
AVRational sample_aspect_ratio;
int me_cmp;
int me_sub_cmp;
int mb_cmp;
int ildct_cmp;
int dia_size;
int last_predictor_count;
__attribute__((deprecated))
int pre_me;
int me_pre_cmp;
int pre_dia_size;
int me_subpel_quality;
int me_range;
int slice_flags;
int mb_decision;
uint16_t *intra_matrix;
uint16_t *inter_matrix;
__attribute__((deprecated))
int scenechange_threshold;
__attribute__((deprecated))
int noise_reduction;
int intra_dc_precision;
int skip_top;
int skip_bottom;
int mb_lmin;
int mb_lmax;
__attribute__((deprecated))
int me_penalty_compensation;
int bidir_refine;
__attribute__((deprecated))
int brd_scale;
int keyint_min;
int refs;
__attribute__((deprecated))
int chromaoffset;
int mv0_threshold;
__attribute__((deprecated))
int b_sensitivity;
enum AVColorPrimaries color_primaries;
enum AVColorTransferCharacteristic color_trc;
enum AVColorSpace colorspace;
enum AVColorRange color_range;
enum AVChromaLocation chroma_sample_location;
int slices;
enum AVFieldOrder field_order;
int sample_rate;
int channels;
enum AVSampleFormat sample_fmt;
int frame_size;
int frame_number;
int block_align;
int cutoff;
uint64_t channel_layout;
uint64_t request_channel_layout;
enum AVAudioServiceType audio_service_type;
enum AVSampleFormat request_sample_fmt;
int (*get_buffer2)(struct AVCodecContext *s, AVFrame *frame, int flags);
__attribute__((deprecated))
int refcounted_frames;
float qcompress;
float qblur;
int qmin;
int qmax;
int max_qdiff;
int rc_buffer_size;
int rc_override_count;
RcOverride *rc_override;
int64_t rc_max_rate;
int64_t rc_min_rate;
float rc_max_available_vbv_use;
float rc_min_vbv_overflow_use;
int rc_initial_buffer_occupancy;
__attribute__((deprecated))
int coder_type;
__attribute__((deprecated))
int context_model;
__attribute__((deprecated))
int frame_skip_threshold;
__attribute__((deprecated))
int frame_skip_factor;
__attribute__((deprecated))
int frame_skip_exp;
__attribute__((deprecated))
int frame_skip_cmp;
int trellis;
__attribute__((deprecated))
int min_prediction_order;
__attribute__((deprecated))
int max_prediction_order;
__attribute__((deprecated))
int64_t timecode_frame_start;
__attribute__((deprecated))
void (*rtp_callback)(struct AVCodecContext *avctx, void *data, int size, int mb_nb);
__attribute__((deprecated))
int rtp_payload_size;
__attribute__((deprecated))
int mv_bits;
__attribute__((deprecated))
int header_bits;
__attribute__((deprecated))
int i_tex_bits;
__attribute__((deprecated))
int p_tex_bits;
__attribute__((deprecated))
int i_count;
__attribute__((deprecated))
int p_count;
__attribute__((deprecated))
int skip_count;
__attribute__((deprecated))
int misc_bits;
__attribute__((deprecated))
int frame_bits;
char *stats_out;
char *stats_in;
int workaround_bugs;
int strict_std_compliance;
int error_concealment;
int debug;
int err_recognition;
int64_t reordered_opaque;
const struct AVHWAccel *hwaccel;
void *hwaccel_context;
uint64_t error[8];
int dct_algo;
int idct_algo;
int bits_per_coded_sample;
int bits_per_raw_sample;
int lowres;
__attribute__((deprecated)) AVFrame *coded_frame;
int thread_count;
int thread_type;
int active_thread_type;
int thread_safe_callbacks;
int (*execute)(struct AVCodecContext *c, int (*func)(struct AVCodecContext *c2, void *arg), void *arg2, int *ret, int count, int size);
int (*execute2)(struct AVCodecContext *c, int (*func)(struct AVCodecContext *c2, void *arg, int jobnr, int threadnr), void *arg2, int *ret, int count);
int nsse_weight;
int profile;
int level;
enum AVDiscard skip_loop_filter;
enum AVDiscard skip_idct;
enum AVDiscard skip_frame;
uint8_t *subtitle_header;
int subtitle_header_size;
__attribute__((deprecated))
uint64_t vbv_delay;
__attribute__((deprecated))
int side_data_only_packets;
int initial_padding;
AVRational framerate;
enum AVPixelFormat sw_pix_fmt;
AVRational pkt_timebase;
const AVCodecDescriptor *codec_descriptor;
int64_t pts_correction_num_faulty_pts;
int64_t pts_correction_num_faulty_dts;
int64_t pts_correction_last_pts;
int64_t pts_correction_last_dts;
char *sub_charenc;
int sub_charenc_mode;
int skip_alpha;
int seek_preroll;
int debug_mv;
uint16_t *chroma_intra_matrix;
uint8_t *dump_separator;
char *codec_whitelist;
unsigned properties;
AVPacketSideData *coded_side_data;
int nb_coded_side_data;
AVBufferRef *hw_frames_ctx;
int sub_text_format;
int trailing_padding;
int64_t max_pixels;
AVBufferRef *hw_device_ctx;
int hwaccel_flags;
int apply_cropping;
int extra_hw_frames;
} AVCodecContext;

typedef struct AVCodecDefault AVCodecDefault;

typedef struct AVPacket {
AVBufferRef *buf;
int64_t pts;
int64_t dts;
uint8_t *data;
int size;
int stream_index;
int flags;
AVPacketSideData *side_data;
int side_data_elems;
int64_t duration;
int64_t pos;
__attribute__((deprecated))
int64_t convergence_duration;
} AVPacket;

typedef struct AVCodec {
const char *name;
const char *long_name;
enum AVMediaType type;
enum AVCodecID id;
int capabilities;
const AVRational *supported_framerates;
const enum AVPixelFormat *pix_fmts;
const int *supported_samplerates;
const enum AVSampleFormat *sample_fmts;
const uint64_t *channel_layouts;
uint8_t max_lowres;
const AVClass *priv_class;
const AVProfile *profiles;
const char *wrapper_name;
int priv_data_size;
struct AVCodec *next;
int (*init_thread_copy)(AVCodecContext *);
int (*update_thread_context)(AVCodecContext *dst, const AVCodecContext *src);
const AVCodecDefault *defaults;
void (*init_static_data)(struct AVCodec *codec);
int (*init)(AVCodecContext *);
int (*encode_sub)(AVCodecContext *, uint8_t *buf, int buf_size,
const struct AVSubtitle *sub);
int (*encode2)(AVCodecContext *avctx, AVPacket *avpkt, const AVFrame *frame,
int *got_packet_ptr);
int (*decode)(AVCodecContext *, void *outdata, int *outdata_size, AVPacket *avpkt);
int (*close)(AVCodecContext *);
int (*send_frame)(AVCodecContext *avctx, const AVFrame *frame);
int (*receive_packet)(AVCodecContext *avctx, AVPacket *avpkt);
int (*receive_frame)(AVCodecContext *avctx, AVFrame *frame);
void (*flush)(AVCodecContext *);
int caps_internal;
const char *bsfs;
const struct AVCodecHWConfigInternal **hw_configs;
} AVCodec;

typedef struct AVIOContext {
const AVClass *av_class;
unsigned char *buffer;
int buffer_size;
unsigned char *buf_ptr;
unsigned char *buf_end;
void *opaque;
int (*read_packet)(void *opaque, uint8_t *buf, int buf_size);
int (*write_packet)(void *opaque, uint8_t *buf, int buf_size);
int64_t (*seek)(void *opaque, int64_t offset, int whence);
int64_t pos;
int eof_reached;
int write_flag;
int max_packet_size;
unsigned long checksum;
unsigned char *checksum_ptr;
unsigned long (*update_checksum)(unsigned long checksum, const uint8_t *buf, unsigned int size);
int error;
int (*read_pause)(void *opaque, int pause);
int64_t (*read_seek)(void *opaque, int stream_index,
int64_t timestamp, int flags);
int seekable;
int64_t maxsize;
int direct;
int64_t bytes_read;
int seek_count;
int writeout_count;
int orig_buffer_size;
int short_seek_threshold;
const char *protocol_whitelist;
const char *protocol_blacklist;
int (*write_data_type)(void *opaque, uint8_t *buf, int buf_size,
enum AVIODataMarkerType type, int64_t time);
int ignore_boundary_point;
enum AVIODataMarkerType current_type;
int64_t last_time;
int (*short_seek_get)(void *opaque);
int64_t written;
unsigned char *buf_ptr_max;
int min_packet_size;
} AVIOContext;

typedef struct AVIndexEntry {
int64_t pos;
int64_t timestamp;
int flags:2;
int size:30;
int min_distance;
} AVIndexEntry;

typedef struct AVStreamInternal AVStreamInternal;

typedef struct AVCodecParameters {
enum AVMediaType codec_type;
enum AVCodecID codec_id;
uint32_t codec_tag;
uint8_t *extradata;
int extradata_size;
int format;
int64_t bit_rate;
int bits_per_coded_sample;
int bits_per_raw_sample;
int profile;
int level;
int width;
int height;
AVRational sample_aspect_ratio;
enum AVFieldOrder field_order;
enum AVColorRange color_range;
enum AVColorPrimaries color_primaries;
enum AVColorTransferCharacteristic color_trc;
enum AVColorSpace color_space;
enum AVChromaLocation chroma_location;
int video_delay;
uint64_t channel_layout;
int channels;
int sample_rate;
int block_align;
int frame_size;
int initial_padding;
int trailing_padding;
int seek_preroll;
} AVCodecParameters;

typedef struct AVProbeData {
const char *filename;
unsigned char *buf;
int buf_size;
const char *mime_type;
} AVProbeData;

typedef struct AVStream {
int index;
int id;
__attribute__((deprecated))
AVCodecContext *codec;
void *priv_data;
AVRational time_base;
int64_t start_time;
int64_t duration;
int64_t nb_frames;
int disposition;
enum AVDiscard discard;
AVRational sample_aspect_ratio;
AVDictionary *metadata;
AVRational avg_frame_rate;
AVPacket attached_pic;
AVPacketSideData *side_data;
int nb_side_data;
int event_flags;
AVRational r_frame_rate;
__attribute__((deprecated))
char *recommended_encoder_configuration;
AVCodecParameters *codecpar;
struct {
int64_t last_dts;
int64_t duration_gcd;
int duration_count;
int64_t rfps_duration_sum;
double (*duration_error)[2][(30*12+30+3+6)];
int64_t codec_info_duration;
int64_t codec_info_duration_fields;
int frame_delay_evidence;
int found_decoder;
int64_t last_duration;
int64_t fps_first_dts;
int fps_first_dts_idx;
int64_t fps_last_dts;
int fps_last_dts_idx;
} *info;
int pts_wrap_bits;
int64_t first_dts;
int64_t cur_dts;
int64_t last_IP_pts;
int last_IP_duration;
int probe_packets;
int codec_info_nb_frames;
enum AVStreamParseType need_parsing;
struct AVCodecParserContext *parser;
struct AVPacketList *last_in_packet_buffer;
AVProbeData probe_data;
int64_t pts_buffer[16 +1];
AVIndexEntry *index_entries;
int nb_index_entries;
unsigned int index_entries_allocated_size;
int stream_identifier;
int program_num;
int pmt_version;
int pmt_stream_idx;
int64_t interleaver_chunk_size;
int64_t interleaver_chunk_duration;
int request_probe;
int skip_to_keyframe;
int skip_samples;
int64_t start_skip_samples;
int64_t first_discard_sample;
int64_t last_discard_sample;
int nb_decoded_frames;
int64_t mux_ts_offset;
int64_t pts_wrap_reference;
int pts_wrap_behavior;
int update_initial_durations_done;
int64_t pts_reorder_error[16 +1];
uint8_t pts_reorder_error_count[16 +1];
int64_t last_dts_for_order_check;
uint8_t dts_ordered;
uint8_t dts_misordered;
int inject_global_side_data;
AVRational display_aspect_ratio;
AVStreamInternal *internal;
} AVStream;

typedef struct AVProgram {
int id;
int flags;
enum AVDiscard discard;
unsigned int *stream_index;
unsigned int nb_stream_indexes;
AVDictionary *metadata;
int program_num;
int pmt_pid;
int pcr_pid;
int pmt_version;
int64_t start_time;
int64_t end_time;
int64_t pts_wrap_reference;
int pts_wrap_behavior;
} AVProgram;

typedef struct AVChapter {
int id;
AVRational time_base;
int64_t start, end;
AVDictionary *metadata;
} AVChapter;

typedef struct AVIOInterruptCB {
int (*callback)(void*);
void *opaque;
} AVIOInterruptCB;

typedef struct AVFormatInternal AVFormatInternal;

typedef int (*av_format_control_message)(struct AVFormatContext *s, int type,
void *data, size_t data_size);

typedef struct AVFormatContext {
const AVClass *av_class;
struct AVInputFormat *iformat;
struct AVOutputFormat *oformat;
void *priv_data;
AVIOContext *pb;
int ctx_flags;
unsigned int nb_streams;
AVStream **streams;
__attribute__((deprecated))
char filename[1024];
char *url;
int64_t start_time;
int64_t duration;
int64_t bit_rate;
unsigned int packet_size;
int max_delay;
int flags;
int64_t probesize;
int64_t max_analyze_duration;
const uint8_t *key;
int keylen;
unsigned int nb_programs;
AVProgram **programs;
enum AVCodecID video_codec_id;
enum AVCodecID audio_codec_id;
enum AVCodecID subtitle_codec_id;
unsigned int max_index_size;
unsigned int max_picture_buffer;
unsigned int nb_chapters;
AVChapter **chapters;
AVDictionary *metadata;
int64_t start_time_realtime;
int fps_probe_size;
int error_recognition;
AVIOInterruptCB interrupt_callback;
int debug;
int64_t max_interleave_delta;
int strict_std_compliance;
int event_flags;
int max_ts_probe;
int avoid_negative_ts;
int ts_id;
int audio_preload;
int max_chunk_duration;
int max_chunk_size;
int use_wallclock_as_timestamps;
int avio_flags;
enum AVDurationEstimationMethod duration_estimation_method;
int64_t skip_initial_bytes;
unsigned int correct_ts_overflow;
int seek2any;
int flush_packets;
int probe_score;
int format_probesize;
char *codec_whitelist;
char *format_whitelist;
AVFormatInternal *internal;
int io_repositioned;
AVCodec *video_codec;
AVCodec *audio_codec;
AVCodec *subtitle_codec;
AVCodec *data_codec;
int metadata_header_padding;
void *opaque;
av_format_control_message control_message_cb;
int64_t output_ts_offset;
uint8_t *dump_separator;
enum AVCodecID data_codec_id;
__attribute__((deprecated))
int (*open_cb)(struct AVFormatContext *s, AVIOContext **p, const char *url, int flags, const AVIOInterruptCB *int_cb, AVDictionary **options);
char *protocol_whitelist;
int (*io_open)(struct AVFormatContext *s, AVIOContext **pb, const char *url,
int flags, AVDictionary **options);
void (*io_close)(struct AVFormatContext *s, AVIOContext *pb);
char *protocol_blacklist;
int max_streams;
int skip_estimate_duration_from_pts;
} AVFormatContext;

typedef struct AVInputFormat {
const char *name;
const char *long_name;
int flags;
const char *extensions;
const struct AVCodecTag * const *codec_tag;
const AVClass *priv_class;
const char *mime_type;
struct AVInputFormat *next;
int raw_codec_id;
int priv_data_size;
int (*read_probe)(AVProbeData *);
int (*read_header)(struct AVFormatContext *);
int (*read_packet)(struct AVFormatContext *, AVPacket *pkt);
int (*read_close)(struct AVFormatContext *);
int (*read_seek)(struct AVFormatContext *,
int stream_index, int64_t timestamp, int flags);
int64_t (*read_timestamp)(struct AVFormatContext *s, int stream_index,
int64_t *pos, int64_t pos_limit);
int (*read_play)(struct AVFormatContext *);
int (*read_pause)(struct AVFormatContext *);
int (*read_seek2)(struct AVFormatContext *s, int stream_index, int64_t min_ts, int64_t ts, int64_t max_ts, int flags);
int (*get_device_list)(struct AVFormatContext *s, struct AVDeviceInfoList *device_list);
int (*create_device_capabilities)(struct AVFormatContext *s, struct AVDeviceCapabilitiesQuery *caps);
int (*free_device_capabilities)(struct AVFormatContext *s, struct AVDeviceCapabilitiesQuery *caps);
} AVInputFormat;

int avcodec_open2(AVCodecContext *avctx, const AVCodec *codec, AVDictionary **options);
int avcodec_close(AVCodecContext *avctx);
int avcodec_decode_video2(AVCodecContext *avctx, AVFrame *picture, int *got_picture_ptr, const AVPacket *avpkt);
void av_free_packet(AVPacket *pkt);
int avformat_open_input(AVFormatContext **ps, const char *url, AVInputFormat *fmt, AVDictionary **options);
void avformat_close_input(AVFormatContext **s);
int avformat_find_stream_info(AVFormatContext *ic, AVDictionary **options);

int av_find_best_stream(AVFormatContext *ic,
enum AVMediaType type,
int wanted_stream_nb,
int related_stream,
AVCodec **decoder_ret,
int flags);

int av_read_frame(AVFormatContext *s, AVPacket *pkt);
int av_seek_frame(AVFormatContext *s, int stream_index, int64_t timestamp, int flags);
AVFrame *av_frame_alloc(void);
void av_free_packet(AVPacket *pkt);

int av_image_fill_arrays(uint8_t *dst_data[4], int dst_linesize[4],
const uint8_t *src,
enum AVPixelFormat pix_fmt, int width, int height, int align);

int64_t av_frame_get_best_effort_timestamp(const AVFrame *frame);

typedef struct SwsVector {
double *coeff;
int length;
} SwsVector;
typedef struct SwsFilter {
SwsVector *lumH;
SwsVector *lumV;
SwsVector *chrH;
SwsVector *chrV;
} SwsFilter;

struct SwsContext *sws_getContext(int srcW, int srcH, enum AVPixelFormat srcFormat,
int dstW, int dstH, enum AVPixelFormat dstFormat,
int flags, SwsFilter *srcFilter,
SwsFilter *dstFilter, const double *param);

void sws_freeContext(struct SwsContext *swsContext);

int sws_scale(struct SwsContext *c, const uint8_t *const srcSlice[],
const int srcStride[], int srcSliceY, int srcSliceH,
uint8_t *const dst[], const int dstStride[]);

__attribute__((deprecated))
void av_register_all(void);

__attribute__((deprecated))
void avcodec_register_all(void);

void av_free(void *ptr);

]]

ffi.cdef(header)

local ffmpeg = {}

local dl = require("aqua.dl")

ffmpeg.avcodec = ffi.load(dl.get("avcodec"))
ffmpeg.avformat = ffi.load(dl.get("avformat"))
ffmpeg.avutil = ffi.load(dl.get("avutil"))
ffmpeg.swscale = ffi.load(dl.get("swscale"))

ffmpeg.avformat.av_register_all()
ffmpeg.avcodec.avcodec_register_all()

return ffmpeg
