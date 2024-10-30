local ffi = require("ffi")

local _7z = ffi.load("/usr/lib/p7zip/7z.so")

ffi.cdef[[
	void * malloc(size_t size);
	void free(void * ptr);

	typedef unsigned int UInt32;
	typedef int64_t Int64;
	typedef uint64_t UInt64;
	typedef int SRes;
	typedef unsigned char Byte;
	typedef size_t SizeT;
	typedef short Int16;
	typedef unsigned short UInt16;

	typedef UInt16 CLzmaProb;

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
		int level;
		UInt32 dictSize;
		int lc;
		int lp;
		int pb;
		int algo;
		int fb;
		int btMode;
		int numHashBytes;
		unsigned numHashOutBits;
		UInt32 mc;
		unsigned writeEndMark;
		int numThreads;
		UInt64 reduceSize;
		UInt64 affinity;
	} CLzmaEncProps;

	typedef const struct ICompressProgress_ *ICompressProgressPtr;

	struct ICompressProgress_ {
		SRes (*Progress)(ICompressProgressPtr p, UInt64 inSize, UInt64 outSize);
	};

	void LzmaEncProps_Init(CLzmaEncProps *p);
	void LzmaEncProps_Normalize(CLzmaEncProps *p);

	SRes LzmaDecode(Byte *dest, SizeT *destLen, const Byte *src, SizeT *srcLen,
	const Byte *propData, unsigned propSize, ELzmaFinishMode finishMode,
	ELzmaStatus *status, ISzAllocPtr alloc);

	SRes LzmaEncode(Byte *dest, SizeT *destLen, const Byte *src, SizeT srcLen,
	const CLzmaEncProps *props, Byte *propsEncoded, SizeT *propsSize, int writeEndMark,
	ICompressProgressPtr progress, ISzAllocPtr alloc, ISzAllocPtr allocBig);

	typedef struct ISeqInStream *ISeqInStreamPtr;
	typedef struct ISeqInStream ISeqInStream;
	struct ISeqInStream {
		SRes (*Read)(ISeqInStreamPtr p, void *buf, size_t *size);
			/* if (input(*size) != 0 && output(*size) == 0) means end_of_stream.
			(output(*size) < input(*size)) is allowed */
	};

	typedef struct ISeqOutStream *ISeqOutStreamPtr;
	typedef struct ISeqOutStream ISeqOutStream;
	struct ISeqOutStream {
		size_t (*Write)(ISeqOutStreamPtr p, const void *buf, size_t size);
			/* Returns: result - the number of actually written bytes.
			(result < size) means error */
	};

	typedef struct CLzmaEnc CLzmaEnc;
	typedef CLzmaEnc * CLzmaEncHandle;

	CLzmaEncHandle LzmaEnc_Create(ISzAllocPtr alloc);
	void LzmaEnc_Destroy(CLzmaEncHandle p, ISzAllocPtr alloc, ISzAllocPtr allocBig);

	SRes LzmaEnc_SetProps(CLzmaEncHandle p, const CLzmaEncProps *props);
	void LzmaEnc_SetDataSize(CLzmaEncHandle p, UInt64 expectedDataSiize);
	SRes LzmaEnc_WriteProperties(CLzmaEncHandle p, Byte *properties, SizeT *size);
	unsigned LzmaEnc_IsWriteEndMark(CLzmaEncHandle p);

	SRes LzmaEnc_Encode(CLzmaEncHandle p, ISeqOutStreamPtr outStream, ISeqInStreamPtr inStream,
		ICompressProgressPtr progress, ISzAllocPtr alloc, ISzAllocPtr allocBig);
	SRes LzmaEnc_MemEncode(CLzmaEncHandle p, Byte *dest, SizeT *destLen, const Byte *src, SizeT srcLen,
		int writeEndMark, ICompressProgressPtr progress, ISzAllocPtr alloc, ISzAllocPtr allocBig);

	typedef struct {
		Byte lc;
		Byte lp;
		Byte pb;
		Byte _pad_;
		UInt32 dicSize;
	} CLzmaProps;

	typedef struct {
		CLzmaProps prop;
		CLzmaProb *probs;
		CLzmaProb *probs_1664;
		Byte *dic;
		SizeT dicBufSize;
		SizeT dicPos;
		const Byte *buf;
		UInt32 range;
		UInt32 code;
		UInt32 processedPos;
		UInt32 checkDicSize;
		UInt32 reps[4];
		UInt32 state;
		UInt32 remainLen;
		UInt32 numProbs;
		unsigned tempBufSize;
		Byte tempBuf[20];
	} CLzmaDec;

	void LzmaDec_Init(CLzmaDec *p);

	SRes LzmaDec_AllocateProbs(CLzmaDec *p, const Byte *props, unsigned propsSize, ISzAllocPtr alloc);
		void LzmaDec_FreeProbs(CLzmaDec *p, ISzAllocPtr alloc);

	SRes LzmaDec_Allocate(CLzmaDec *p, const Byte *props, unsigned propsSize, ISzAllocPtr alloc);
		void LzmaDec_Free(CLzmaDec *p, ISzAllocPtr alloc);

	SRes LzmaDec_DecodeToBuf(CLzmaDec *p, Byte *dest, SizeT *destLen,
		const Byte *src, SizeT *srcLen, ELzmaFinishMode finishMode, ELzmaStatus *status);
]]

local res_codes = {
	SZ_OK = 0,
	SZ_ERROR_DATA = 1,
	SZ_ERROR_MEM = 2,
	SZ_ERROR_CRC = 3,
	SZ_ERROR_UNSUPPORTED = 4,
	SZ_ERROR_PARAM = 5,
	SZ_ERROR_INPUT_EOF = 6,
	SZ_ERROR_OUTPUT_EOF = 7,
	SZ_ERROR_READ = 8,
	SZ_ERROR_WRITE = 9,
	SZ_ERROR_PROGRESS = 10,
	SZ_ERROR_FAIL = 11,
	SZ_ERROR_THREAD = 12,
	SZ_ERROR_ARCHIVE = 16,
	SZ_ERROR_NO_ARCHIVE = 17,
}

local g_Alloc = ffi.new("ISzAlloc[1]")

g_Alloc[0].Alloc = function(p, size)
	return ffi.C.malloc(size)
end
g_Alloc[0].Free = function(p, address)
	return ffi.C.free(address)
end

local LZMA_PROPS_SIZE = 5

local function get_default_props()
	local props = ffi.new("CLzmaEncProps[1]")
	_7z.LzmaEncProps_Init(props)
	props[0].level = -1
	props[0].dictSize = 0
	props[0].lc = -1
	props[0].lp = -1
	props[0].pb = -1
	props[0].fb = -1
	props[0].numThreads = -1
	_7z.LzmaEncProps_Normalize(props)
	return props
end

local function Encode(enc_handle, read, write)
	local in_stream = ffi.new('ISeqInStream[1]')

	in_stream[0].Read = function(p, buf, size)  -- ISeqInStreamPtr p, void *buf, size_t *size
		if read(buf, size) then
			return 0
		end
		return res_codes.SZ_ERROR_INPUT_EOF
	end

	local out_stream = ffi.new('ISeqOutStream[1]')

	out_stream[0].Write = function(p, buf, size)  -- ISeqOutStreamPtr p, const void *buf, size_t size
		return write(buf, size)  -- the number of actually written bytes, (result < size) means error
	end

	local res = _7z.LzmaEnc_Encode(enc_handle, out_stream, in_stream, nil, g_Alloc, g_Alloc)
	assert(res == res_codes.SZ_OK, res)

	_7z.LzmaEnc_Destroy(enc_handle, g_Alloc, g_Alloc)
end

local function Compress(src, src_size)
	local enc_handle = _7z.LzmaEnc_Create(g_Alloc)

	local props = get_default_props()
	props[0].writeEndMark = 1

	assert(_7z.LzmaEnc_SetProps(enc_handle, props) == res_codes.SZ_OK)

	local outPropsSize = ffi.new("size_t[1]", LZMA_PROPS_SIZE)
	local outProps = ffi.new("unsigned char[?]", LZMA_PROPS_SIZE)
	local res = _7z.LzmaEnc_WriteProperties(enc_handle, outProps, outPropsSize)
	assert(res == res_codes.SZ_OK and outPropsSize[0] == LZMA_PROPS_SIZE)

	local out = {}
	table.insert(out, ffi.string(outProps, outPropsSize[0]))

	local function read(buf, size)
		if src_size == 0 then
			size[0] = 0  -- end of stream
			return true
		end

		local copy_size = src_size
		if copy_size > size[0] then
			copy_size = size[0]
		end

		ffi.copy(buf, src, copy_size)
		size[0] = copy_size
		src_size = src_size - copy_size
		src = src + copy_size

		return true
	end

	local function write(buf, size)
		table.insert(out, ffi.string(buf, size))
		return size
	end

	Encode(enc_handle, read, write)

	return table.concat(out)
end

local data = ("test"):rep(100)
local src = ffi.cast("const unsigned char *", data)
local srcLen = ffi.new("size_t[1]", #data)

-- local p, size = Compress(src, #data)

local comp_data = Compress(src, #data)
print(comp_data, #comp_data)


local function LzmaCompress(dest, destLen, src, srcLen, outProps, outPropsSize)
	local props = get_default_props()
	return _7z.LzmaEncode(dest, destLen, src, srcLen, props, outProps, outPropsSize, 0, nil, g_Alloc, g_Alloc)
end

-- local dstLen = ffi.new("size_t[1]", 100)
-- local dst = ffi.new("unsigned char[?]", dstLen[0])

-- local outPropsSize = ffi.new("size_t[1]", LZMA_PROPS_SIZE)
-- local outProps = ffi.new("unsigned char[?]", LZMA_PROPS_SIZE)
-- local res = LzmaCompress(dst, dstLen, src, srcLen[0], outProps, outPropsSize)
-- print(res, dstLen[0], ffi.string(dst, dstLen[0]))
-- print(ffi.string(dst, dstLen[0]) == comp_data)

-- do return end

local src = ffi.cast("const unsigned char *", comp_data)
local srcSize = ffi.new("size_t[1]", #comp_data)

--------------------------------------------------------------------------------

local function Uncompress(in_buf, in_len)
	local dec = ffi.new("CLzmaDec[1]")

	local res = _7z.LzmaDec_Allocate(dec, in_buf, LZMA_PROPS_SIZE, g_Alloc)  -- read pointer to props
	assert(res == res_codes.SZ_OK)

	in_buf = in_buf + LZMA_PROPS_SIZE
	in_len = in_len - LZMA_PROPS_SIZE

	_7z.LzmaDec_Init(dec)

	local inPos = 0
	local status = ffi.new("ELzmaStatus[1]")

	local BUF_SIZE = 128
	local out_buf = ffi.new("unsigned char[?]", BUF_SIZE)
	local dst_len = ffi.new("size_t[1]", BUF_SIZE)

	local src_len = ffi.new("size_t[1]", in_len)

	local out = {}

	while true do
		print("decode",
			inPos,
			src_len[0],
			inPos == in_len and "LZMA_FINISH_END" or "LZMA_FINISH_ANY",
			status[0])
		local res = _7z.LzmaDec_DecodeToBuf(
			dec,
			out_buf,
			dst_len,
			in_buf + inPos,
			src_len,
			inPos == in_len and "LZMA_FINISH_END" or "LZMA_FINISH_ANY",
			status
		)
		assert(res == res_codes.SZ_OK, res)
		table.insert(out, ffi.string(out_buf, dst_len[0]))
		print(status[0], src_len[0], #table.concat(out))

		if inPos == in_len then
			break
		end

		dst_len[0] = BUF_SIZE
		inPos = inPos + src_len[0]
		src_len[0] = in_len - inPos
		-- src_len[0] = src_len[0] -
		if status[0] == 1 then
		-- if status == LZMA_STATUS_FINISHED_WITH_MARK then
			break
		end
	end

	_7z.LzmaDec_Free(dec, g_Alloc)

	return table.concat(out)
end

local res = Uncompress(src, srcSize[0])
-- print(res, #res)
-- print(data, #data)
assert(res == data)

-- local function LzmaUncompress(dest, destLen, src, srcLen, props, propsSize)
-- 	local status = ffi.new("ELzmaStatus[1]")
-- 	return _7z.LzmaDecode(dest, destLen, src, srcLen, props, propsSize, "LZMA_FINISH_ANY", status, g_Alloc)
-- end

-- local dstLen2 = ffi.new("size_t[1]", #data * 2)
-- local dst2 = ffi.new("unsigned char[?]", dstLen2[0])

-- local res = LzmaUncompress(dst2, dstLen2, src, srcSize, outProps, outPropsSize[0])
-- print(res, dstLen2[0], ffi.string(dst2, dstLen2[0]))

return {
	Uncompress = Uncompress,
	Compress = Compress,
}
