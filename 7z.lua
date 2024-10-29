local ffi = require("ffi")
local bit = require("bit")

local _7z = ffi.load("/usr/lib/p7zip/7z.so")

ffi.cdef[[
	void * malloc(size_t size);
	void * realloc(void * ptr, size_t newsize);
	void free(void * ptr);

	typedef unsigned int UInt32;
	typedef int64_t Int64;
	typedef uint64_t UInt64;
	typedef int SRes;
	typedef unsigned char Byte;
	typedef size_t SizeT;
	typedef enum {
		LZMA_FINISH_ANY,
		LZMA_FINISH_END
	} ELzmaFinishMode;
	typedef enum {
		LZMA_STATUS_NOT_SPECIFIED,
		LZMA_STATUS_FINISHED_WITH_MARK,
		LZMA_STATUS_NOT_FINISHED,
		LZMA_STATUS_NEEDS_MORE_INPUT,
		LZMA_STATUS_MAYBE_FINISHED_WITHOUT_MARK
	} ELzmaStatus;

	typedef struct ISzAlloc ISzAlloc;
	typedef const ISzAlloc * ISzAllocPtr;

	struct ISzAlloc {
		void *(*Alloc)(ISzAllocPtr p, size_t size);
		void (*Free)(ISzAllocPtr p, void *address);
	};

	typedef struct {
		int level;       /* 0 <= level <= 9 */
		UInt32 dictSize; /* (1 << 12) <= dictSize <= (1 << 27) for 32-bit version
							(1 << 12) <= dictSize <= (3 << 29) for 64-bit version
							default = (1 << 24) */
		int lc;          /* 0 <= lc <= 8, default = 3 */
		int lp;          /* 0 <= lp <= 4, default = 0 */
		int pb;          /* 0 <= pb <= 4, default = 2 */
		int algo;        /* 0 - fast, 1 - normal, default = 1 */
		int fb;          /* 5 <= fb <= 273, default = 32 */
		int btMode;      /* 0 - hashChain Mode, 1 - binTree mode - normal, default = 1 */
		int numHashBytes; /* 2, 3 or 4, default = 4 */
		unsigned numHashOutBits;  /* default = ? */
		UInt32 mc;       /* 1 <= mc <= (1 << 30), default = 32 */
		unsigned writeEndMark;  /* 0 - do not write EOPM, 1 - write EOPM, default = 0 */
		int numThreads;  /* 1 or 2, default = 2 */

		// int _pad;

		UInt64 reduceSize; /* estimated size of data that will be compressed. default = (UInt64)(Int64)-1.
								Encoder uses this value to reduce dictionary size */

		UInt64 affinity;
	} CLzmaEncProps;

	typedef const struct ICompressProgress_ *ICompressProgressPtr;

	struct ICompressProgress_ {
		SRes (*Progress)(ICompressProgressPtr p, UInt64 inSize, UInt64 outSize);
	};

	void LzmaEncProps_Init(CLzmaEncProps *p);

	SRes LzmaDecode(Byte *dest, SizeT *destLen, const Byte *src, SizeT *srcLen,
	const Byte *propData, unsigned propSize, ELzmaFinishMode finishMode,
	ELzmaStatus *status, ISzAllocPtr alloc);

	SRes LzmaEncode(Byte *dest, SizeT *destLen, const Byte *src, SizeT srcLen,
	const CLzmaEncProps *props, Byte *propsEncoded, SizeT *propsSize, int writeEndMark,
	ICompressProgressPtr progress, ISzAllocPtr alloc, ISzAllocPtr allocBig);

	int LzmaCompress(unsigned char *dest, size_t *destLen, const unsigned char *src, size_t srcLen,
		unsigned char *outProps, size_t *outPropsSize, /* *outPropsSize must be = 5 */
		int level,      /* 0 <= level <= 9, default = 5 */
		unsigned dictSize,  /* default = (1 << 24) */
		int lc,        /* 0 <= lc <= 8, default = 3  */
		int lp,        /* 0 <= lp <= 4, default = 0  */
		int pb,        /* 0 <= pb <= 4, default = 2  */
		int fb,        /* 5 <= fb <= 273, default = 32 */
		int numThreads /* 1 or 2, default = 2 */
	);

	int LzmaUncompress(unsigned char *dest, size_t *destLen, const unsigned char *src, size_t *srcLen,
	const unsigned char *props, size_t propsSize);
]]

local data = ("test"):rep(100)
local src = ffi.cast("const unsigned char *", data)
local srcLen = ffi.new("size_t[1]", #data)

local dst = ffi.new("unsigned char[?]", #data)
local dstLen = ffi.new("size_t[1]", #data)

local LZMA_PROPS_SIZE = 5
local outPropsSize = ffi.new("size_t[1]", LZMA_PROPS_SIZE)
local outProps = ffi.new("unsigned char[?]", LZMA_PROPS_SIZE)
-- local res = _7z.LzmaCompress(dst, #data, src, #data, outProps, outPropsSize, 5, bit.lshift(1, 24), 3, 0, 2, 32, 2)

local g_Alloc = ffi.new("ISzAlloc[1]")

g_Alloc[0].Alloc = function(p, size)
	return ffi.C.malloc(size)
end
g_Alloc[0].Free = function(p, address)
	return ffi.C.free(address)
end

local function LzmaCompress(dest, destLen, src, srcLen, outProps, outPropsSize, level, dictSize, lc, lp, pb, fb, numThreads)
	local props = ffi.new("CLzmaEncProps[1]")
	_7z.LzmaEncProps_Init(props)
	props[0].level = level
	props[0].dictSize = dictSize
	props[0].lc = lc
	props[0].lp = lp
	props[0].pb = pb
	props[0].fb = fb
	props[0].numThreads = numThreads

	return _7z.LzmaEncode(dest, destLen, src, srcLen, props, outProps, outPropsSize, 0, nil, g_Alloc, g_Alloc)
end

local res = LzmaCompress(dst, dstLen, src, srcLen[0], outProps, outPropsSize, 5, bit.lshift(1, 24), 3, 0, 2, 32, 2)
print(res, dstLen[0], ffi.string(dst, dstLen[0]))

